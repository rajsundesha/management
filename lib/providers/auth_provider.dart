import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  User? _user;
  String? _role;
  String? _email;
  bool _isCreatingUser = false;

  User? get user => _user;
  String? get role => _role;
  String? get currentUserEmail => _email;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<User?> login(String email, String password) async {
    email = email.trim();
    if (email.isEmpty || password.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-input',
        message: "Email and password cannot be empty.",
      );
    }

    if (!EmailValidator.validate(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: "The email address is not valid.",
      );
    }

    try {
      print("Attempting to sign in with email: $email");
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      print("Sign in successful");
      _user = userCredential.user;

      if (_user != null) {
        print("User is not null, reloading user data");
        await _user!.reload();
        _user = _auth.currentUser;

        print("Email verification is skipped for backend registered users");
        _email = _user?.email;
        await refreshUserData();
        notifyListeners();
      } else {
        print("User is null after sign in");
      }
      return _user;
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException during login: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected error during login: $e");
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    print("Auth state changed. User: ${user?.email}");
    if (user != null) {
      _user = user;
      _email = _user?.email;
      await refreshUserData();
      print("User authenticated. Email: $_email, Role: $_role");
    } else {
      _user = null;
      _email = null;
      _role = null;
      print("User signed out");
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      _user = null;
      _role = null;
      _email = null;
      notifyListeners();
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign-out-failed',
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  Future<void> refreshUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(_user!.uid).get();
        if (doc.exists) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          _role = userData['role'] as String?;
          _email = userData['email'] as String?;
        } else {
          await _createOrUpdateUserInFirestore(_user!);
        }
      } catch (e) {
        print("Error refreshing user data: $e");
      }
    }
  }

  Future<void> _createOrUpdateUserInFirestore(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'phoneNumber': user.phoneNumber,
      'email': user.email,
      'role': 'User', // Default role
      'lastSignInTime': FieldValue.serverTimestamp(),
      'creationTime': user.metadata.creationTime,
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter your email address.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> createUserWithAdmin(
      String email, String password, String role, String name) async {
    User? adminUser = _auth.currentUser;
    if (adminUser == null) {
      throw Exception('Admin must be logged in to create a new user');
    }

    _isCreatingUser = true;
    try {
      FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'tempApp', options: Firebase.app().options);

      try {
        UserCredential userCredential = await FirebaseAuth.instanceFor(
                app: tempApp)
            .createUserWithEmailAndPassword(email: email, password: password);

        String uid = userCredential.user!.uid;

        await _firestore.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': role,
          'mobile': '',
        });

        print("User created successfully: $email");
      } catch (e) {
        print("Error during user creation: $e");
        rethrow;
      } finally {
        await tempApp.delete();
      }

      await refreshUserData();
      notifyListeners();
    } catch (e) {
      print("Error during user creation: $e");
      rethrow;
    } finally {
      _isCreatingUser = false;
    }
  }

  Future<bool> shouldAllowAutoLogin(User user) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        String role = (doc.data() as Map<String, dynamic>)['role'] as String;
        return ['Admin', 'Manager', 'User', 'Gate Man'].contains(role);
      }
    } catch (e) {
      print("Error checking user role: $e");
      return false;
    }
    return false;
  }

  Future<void> signOutIfUnauthorized() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        bool shouldAllow = await shouldAllowAutoLogin(currentUser);
        if (!shouldAllow) {
          print("User not authorized, logging out: ${currentUser.email}");
          await logout();
        } else {
          print("User authorized, staying logged in: ${currentUser.email}");
          await refreshUserData();
        }
      } catch (e) {
        print("Error checking authorization, logging out: $e");
        await logout();
      }
    } else {
      print("No current user, no action needed");
    }
  }

  Future<void> ensureUserDocument() async {
    if (_user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (!doc.exists) {
        print("Creating missing user document for ${_user!.email}");
        await _firestore.collection('users').doc(_user!.uid).set({
          'email': _user!.email,
          'role': 'User',
        });
      }
      _role = await _getUserRole(_user!.uid);
      notifyListeners();
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      if (_user != null && _user!.uid == uid) {
        _role = data['role'] ?? _role;
        _email = data['email'] ?? _email;
        notifyListeners();
      }
    } catch (e) {
      print("Error during user update: $e");
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      print("Attempting to delete user with UID: $uid");
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('deleteUser');
      print("Calling Cloud Function: deleteUser");
      final result = await callable.call({"uid": uid});
      print("Cloud Function result: ${result.data}");

      if (result.data["success"]) {
        print("User deleted successfully: $uid");
        if (_auth.currentUser?.uid == uid) {
          await logout();
        }
      } else {
        print("Failed to delete user. Error: ${result.data["message"]}");
        throw FirebaseException(
          plugin: "cloud_functions",
          code: "delete-failed",
          message: "Failed to delete user: ${result.data["message"]}",
        );
      }
    } catch (e) {
      print("Error during user deletion: $e");
      if (e is FirebaseFunctionsException) {
        print("Firebase Functions error code: ${e.code}");
        print("Firebase Functions error details: ${e.details}");
        print("Firebase Functions error message: ${e.message}");
      }
      rethrow;
    }
  }

  Future<String?> _getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        String? role = (doc.data() as Map<String, dynamic>?)?['role'];
        print("Retrieved role for user $uid: $role");
        return role;
      } else {
        print("No document found for user $uid. Creating one.");
        await _firestore.collection('users').doc(uid).set({
          'email': _user!.email,
          'role': 'User',
        });
        return 'User';
      }
    } catch (e) {
      print("Error getting user role for $uid: $e");
    }
    return null;
  }

  Future<void> _signInWithCredential(AuthCredential credential) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      await _createOrUpdateUserInFirestore(_user!);
      await refreshUserData();
      notifyListeners();
    } catch (e) {
      print("Error signing in with credential: $e");
      rethrow;
    }
  }

  Future<void> _createOrSignInWithEmail(String email) async {
    try {
      List<String> signInMethods =
          await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isEmpty) {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: _generateRandomPassword(),
        );
        _user = userCredential.user;
        await _createOrUpdateUserInFirestore(_user!);
      } else {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: _generateRandomPassword(),
        );
        _user = userCredential.user;
      }
      await refreshUserData();
      notifyListeners();
    } catch (e) {
      print("Error creating or signing in user with email: $e");
      rethrow;
    }
  }

  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    return List.generate(12, (index) => chars[Random().nextInt(chars.length)])
        .join();
  }
}


// import 'dart:math';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:email_validator/email_validator.dart';

// class AuthProvider with ChangeNotifier {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseFunctions _functions = FirebaseFunctions.instance;

//   User? _user;
//   String? _role;
//   String? _email;
//   bool _isCreatingUser = false;

//   User? get user => _user;
//   String? get role => _role;
//   String? get currentUserEmail => _email;

//   AuthProvider() {
//     _auth.authStateChanges().listen(_onAuthStateChanged);
//   }

//   Future<User?> login(String email, String password) async {
//     email = email.trim();
//     if (email.isEmpty || password.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-input',
//         message: "Email and password cannot be empty.",
//       );
//     }

//     if (!EmailValidator.validate(email)) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: "The email address is not valid.",
//       );
//     }

//     try {
//       print("Attempting to sign in with email: $email");
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email, password: password);
//       print("Sign in successful");
//       _user = userCredential.user;

//       if (_user != null) {
//         print("User is not null, reloading user data");
//         await _user!.reload();
//         _user = _auth.currentUser;

//         print("Email verification is skipped for backend registered users");
//         _email = _user?.email;
//         await refreshUserData();
//         notifyListeners();
//       } else {
//         print("User is null after sign in");
//       }
//       return _user;
//     } on FirebaseAuthException catch (e) {
//       print("FirebaseAuthException during login: ${e.code} - ${e.message}");
//       rethrow;
//     } catch (e) {
//       print("Unexpected error during login: $e");
//       throw FirebaseAuthException(
//         code: 'unknown',
//         message: 'An unexpected error occurred. Please try again.',
//       );
//     }
//   }

//   Future<void> _onAuthStateChanged(User? user) async {
//     print("Auth state changed. User: ${user?.email}");
//     if (user != null) {
//       _user = user;
//       _email = _user?.email;
//       await refreshUserData();
//       print("User authenticated. Email: $_email, Role: $_role");
//     } else {
//       _user = null;
//       _email = null;
//       _role = null;
//       print("User signed out");
//     }
//     notifyListeners();
//   }

//   Future<void> logout() async {
//     try {
//       await _auth.signOut();
//       _user = null;
//       _role = null;
//       _email = null;
//       notifyListeners();
//     } catch (e) {
//       throw FirebaseAuthException(
//         code: 'sign-out-failed',
//         message: 'Failed to sign out. Please try again.',
//       );
//     }
//   }

//   Future<void> refreshUserData() async {
//     if (_user != null) {
//       try {
//         DocumentSnapshot doc =
//             await _firestore.collection('users').doc(_user!.uid).get();
//         if (doc.exists) {
//           Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
//           _role = userData['role'] as String?;
//           _email = userData['email'] as String?;
//         } else {
//           await _createOrUpdateUserInFirestore(_user!);
//         }
//       } catch (e) {
//         print("Error refreshing user data: $e");
//       }
//     }
//   }

//   Future<void> _createOrUpdateUserInFirestore(User user) async {
//     await _firestore.collection('users').doc(user.uid).set({
//       'phoneNumber': user.phoneNumber,
//       'email': user.email,
//       'role': 'User', // Default role
//       'lastSignInTime': FieldValue.serverTimestamp(),
//       'creationTime': user.metadata.creationTime,
//     }, SetOptions(merge: true));
//   }

//   Future<void> sendPasswordResetEmail(String email) async {
//     if (email.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: 'Please enter your email address.',
//       );
//     }
//     await _auth.sendPasswordResetEmail(email: email);
//   }

//   Future<void> createUserWithAdmin(
//       String email, String password, String role, String name) async {
//     User? adminUser = _auth.currentUser;
//     if (adminUser == null) {
//       throw Exception('Admin must be logged in to create a new user');
//     }

//     _isCreatingUser = true;
//     try {
//       FirebaseApp tempApp = await Firebase.initializeApp(
//           name: 'tempApp', options: Firebase.app().options);

//       try {
//         UserCredential userCredential = await FirebaseAuth.instanceFor(
//                 app: tempApp)
//             .createUserWithEmailAndPassword(email: email, password: password);

//         String uid = userCredential.user!.uid;

//         await _firestore.collection('users').doc(uid).set({
//           'name': name,
//           'email': email,
//           'role': role,
//           'mobile': '',
//         });

//         print("User created successfully: $email");
//       } catch (e) {
//         print("Error during user creation: $e");
//         rethrow;
//       } finally {
//         await tempApp.delete();
//       }

//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error during user creation: $e");
//       rethrow;
//     } finally {
//       _isCreatingUser = false;
//     }
//   }

//   Future<bool> shouldAllowAutoLogin(User user) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(user.uid).get();
//       if (doc.exists) {
//         String role = (doc.data() as Map<String, dynamic>)['role'] as String;
//         return ['Admin', 'Manager', 'User', 'Gate Man'].contains(role);
//       }
//     } catch (e) {
//       print("Error checking user role: $e");
//       return false;
//     }
//     return false;
//   }

//   Future<void> signOutIfUnauthorized() async {
//     User? currentUser = _auth.currentUser;
//     if (currentUser != null) {
//       try {
//         bool shouldAllow = await shouldAllowAutoLogin(currentUser);
//         if (!shouldAllow) {
//           print("User not authorized, logging out: ${currentUser.email}");
//           await logout();
//         } else {
//           print("User authorized, staying logged in: ${currentUser.email}");
//           await refreshUserData();
//         }
//       } catch (e) {
//         print("Error checking authorization, logging out: $e");
//         await logout();
//       }
//     } else {
//       print("No current user, no action needed");
//     }
//   }

//   Future<void> ensureUserDocument() async {
//     if (_user != null) {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(_user!.uid).get();
//       if (!doc.exists) {
//         print("Creating missing user document for ${_user!.email}");
//         await _firestore.collection('users').doc(_user!.uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//       }
//       _role = await _getUserRole(_user!.uid);
//       notifyListeners();
//     }
//   }

//   Future<void> updateUser(String uid, Map<String, dynamic> data) async {
//     try {
//       await _firestore.collection('users').doc(uid).update(data);
//       if (_user != null && _user!.uid == uid) {
//         _role = data['role'] ?? _role;
//         _email = data['email'] ?? _email;
//         notifyListeners();
//       }
//     } catch (e) {
//       print("Error during user update: $e");
//       rethrow;
//     }
//   }

//   Future<void> deleteUser(String uid) async {
//     try {
//       print("Attempting to delete user with UID: $uid");
//       final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
//       final callable = functions.httpsCallable('deleteUser');
//       print("Calling Cloud Function: deleteUser");
//       final result = await callable.call({"uid": uid});
//       print("Cloud Function result: ${result.data}");

//       if (result.data["success"]) {
//         print("User deleted successfully: $uid");
//         if (_auth.currentUser?.uid == uid) {
//           await logout();
//         }
//       } else {
//         print("Failed to delete user. Error: ${result.data["message"]}");
//         throw FirebaseException(
//           plugin: "cloud_functions",
//           code: "delete-failed",
//           message: "Failed to delete user: ${result.data["message"]}",
//         );
//       }
//     } catch (e) {
//       print("Error during user deletion: $e");
//       if (e is FirebaseFunctionsException) {
//         print("Firebase Functions error code: ${e.code}");
//         print("Firebase Functions error details: ${e.details}");
//         print("Firebase Functions error message: ${e.message}");
//       }
//       rethrow;
//     }
//   }

//   Future<String?> _getUserRole(String uid) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         String? role = (doc.data() as Map<String, dynamic>?)?['role'];
//         print("Retrieved role for user $uid: $role");
//         return role;
//       } else {
//         print("No document found for user $uid. Creating one.");
//         await _firestore.collection('users').doc(uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//         return 'User';
//       }
//     } catch (e) {
//       print("Error getting user role for $uid: $e");
//     }
//     return null;
//   }

//   Future<void> _signInWithCredential(AuthCredential credential) async {
//     try {
//       UserCredential userCredential =
//           await _auth.signInWithCredential(credential);
//       _user = userCredential.user;
//       await _createOrUpdateUserInFirestore(_user!);
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error signing in with credential: $e");
//       rethrow;
//     }
//   }

//   Future<void> _createOrSignInWithEmail(String email) async {
//     try {
//       List<String> signInMethods =
//           await _auth.fetchSignInMethodsForEmail(email);
//       if (signInMethods.isEmpty) {
//         UserCredential userCredential =
//             await _auth.createUserWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//         await _createOrUpdateUserInFirestore(_user!);
//       } else {
//         UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//       }
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error creating or signing in user with email: $e");
//       rethrow;
//     }
//   }

//   String _generateRandomPassword() {
//     const chars =
//         'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
//     return List.generate(12, (index) => chars[Random().nextInt(chars.length)])
//         .join();
//   }
// }


// import 'dart:math';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:email_validator/email_validator.dart';

// class AuthProvider with ChangeNotifier {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseFunctions _functions = FirebaseFunctions.instance;

//   User? _user;
//   String? _role;
//   String? _email;
//   bool _isCreatingUser = false;

//   User? get user => _user;
//   String? get role => _role;
//   String? get currentUserEmail => _email;
//   bool get isEmailVerified => _user?.emailVerified ?? false;

//   AuthProvider() {
//     _auth.authStateChanges().listen(_onAuthStateChanged);
//   }

//   Future<User?> login(String email, String password) async {
//     email = email.trim();
//     if (email.isEmpty || password.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-input',
//         message: "Email and password cannot be empty.",
//       );
//     }

//     if (!EmailValidator.validate(email)) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: "The email address is not valid.",
//       );
//     }

//     try {
//       print("Attempting to sign in with email: $email");
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email, password: password);
//       print("Sign in successful");
//       _user = userCredential.user;

//       if (_user != null) {
//         print("User is not null, reloading user data");
//         await _user!.reload();
//         _user = _auth.currentUser;

//         print("Checking email verification");
//         if (!_user!.emailVerified) {
//           print("Email not verified, sending verification email");
//           await _user!.sendEmailVerification();
//           print("Email verification sent");
//           await logout();
//           throw FirebaseAuthException(
//             code: 'email-not-verified',
//             message: 'Please verify your email before logging in.',
//           );
//         }

//         print("Email verified, refreshing user data");
//         _email = _user?.email;
//         await refreshUserData();
//         notifyListeners();
//       } else {
//         print("User is null after sign in");
//       }
//       return _user;
//     } on FirebaseAuthException catch (e) {
//       print("FirebaseAuthException during login: ${e.code} - ${e.message}");
//       rethrow;
//     } catch (e) {
//       print("Unexpected error during login: $e");
//       throw FirebaseAuthException(
//         code: 'unknown',
//         message: 'An unexpected error occurred. Please try again.',
//       );
//     }
//   }

//   Future<void> _onAuthStateChanged(User? user) async {
//     print("Auth state changed. User: ${user?.email}");
//     if (user != null) {
//       // Force refresh the token to ensure the most up-to-date information
//       await user.reload();
//       _user = _auth.currentUser;

//       if (!_user!.emailVerified) {
//         print("User email not verified. Signing out.");
//         await logout();
//       } else {
//         _email = _user?.email;
//         await refreshUserData();
//         print("User authenticated. Email: $_email, Role: $_role");
//       }
//     } else {
//       _user = null;
//       _email = null;
//       _role = null;
//       print("User signed out");
//     }
//     notifyListeners();
//   }

//   Future<void> logout() async {
//     try {
//       await _auth.signOut();
//       _user = null;
//       _role = null;
//       _email = null;
//       notifyListeners();
//     } catch (e) {
//       throw FirebaseAuthException(
//         code: 'sign-out-failed',
//         message: 'Failed to sign out. Please try again.',
//       );
//     }
//   }

//   Future<void> refreshUserData() async {
//     if (_user != null) {
//       try {
//         DocumentSnapshot doc =
//             await _firestore.collection('users').doc(_user!.uid).get();
//         if (doc.exists) {
//           Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
//           _role = userData['role'] as String?;
//           _email = userData['email'] as String?;
//         } else {
//           await _createOrUpdateUserInFirestore(_user!);
//         }
//       } catch (e) {
//         print("Error refreshing user data: $e");
//       }
//     }
//   }

//   Future<void> _createOrUpdateUserInFirestore(User user) async {
//     await _firestore.collection('users').doc(user.uid).set({
//       'phoneNumber': user.phoneNumber,
//       'email': user.email,
//       'role': 'User', // Default role
//       'lastSignInTime': FieldValue.serverTimestamp(),
//       'creationTime': user.metadata.creationTime,
//     }, SetOptions(merge: true));
//   }

//   Future<void> sendPasswordResetEmail(String email) async {
//     if (email.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: 'Please enter your email address.',
//       );
//     }
//     await _auth.sendPasswordResetEmail(email: email);
//   }

//   Future<void> createUserWithAdmin(
//       String email, String password, String role, String name) async {
//     User? adminUser = _auth.currentUser;
//     if (adminUser == null) {
//       throw Exception('Admin must be logged in to create a new user');
//     }

//     _isCreatingUser = true;
//     try {
//       FirebaseApp tempApp = await Firebase.initializeApp(
//           name: 'tempApp', options: Firebase.app().options);

//       try {
//         UserCredential userCredential = await FirebaseAuth.instanceFor(
//                 app: tempApp)
//             .createUserWithEmailAndPassword(email: email, password: password);

//         String uid = userCredential.user!.uid;

//         await _firestore.collection('users').doc(uid).set({
//           'name': name,
//           'email': email,
//           'role': role,
//           'mobile': '',
//         });

//         print("User created successfully: $email");
//       } catch (e) {
//         print("Error during user creation: $e");
//         rethrow;
//       } finally {
//         await tempApp.delete();
//       }

//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error during user creation: $e");
//       rethrow;
//     } finally {
//       _isCreatingUser = false;
//     }
//   }

//   Future<bool> shouldAllowAutoLogin(User user) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(user.uid).get();
//       if (doc.exists) {
//         String role = (doc.data() as Map<String, dynamic>)['role'] as String;
//         return ['Admin', 'Manager', 'User', 'Gate Man'].contains(role);
//       }
//     } catch (e) {
//       print("Error checking user role: $e");
//       return false;
//     }
//     return false;
//   }

//   Future<void> signOutIfUnauthorized() async {
//     User? currentUser = _auth.currentUser;
//     if (currentUser != null) {
//       try {
//         bool shouldAllow = await shouldAllowAutoLogin(currentUser);
//         if (!shouldAllow) {
//           print("User not authorized, logging out: ${currentUser.email}");
//           await logout();
//         } else {
//           print("User authorized, staying logged in: ${currentUser.email}");
//           await refreshUserData();
//         }
//       } catch (e) {
//         print("Error checking authorization, logging out: $e");
//         await logout();
//       }
//     } else {
//       print("No current user, no action needed");
//     }
//   }

//   Future<void> ensureUserDocument() async {
//     if (_user != null) {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(_user!.uid).get();
//       if (!doc.exists) {
//         print("Creating missing user document for ${_user!.email}");
//         await _firestore.collection('users').doc(_user!.uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//       }
//       _role = await _getUserRole(_user!.uid);
//       notifyListeners();
//     }
//   }

//   Future<void> updateUser(String uid, Map<String, dynamic> data) async {
//     try {
//       await _firestore.collection('users').doc(uid).update(data);
//       if (_user != null && _user!.uid == uid) {
//         _role = data['role'] ?? _role;
//         _email = data['email'] ?? _email;
//         notifyListeners();
//       }
//     } catch (e) {
//       print("Error during user update: $e");
//       rethrow;
//     }
//   }

//   Future<void> deleteUser(String uid) async {
//     try {
//       print("Attempting to delete user with UID: $uid");
//       final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
//       final callable = functions.httpsCallable('deleteUser');
//       print("Calling Cloud Function: deleteUser");
//       final result = await callable.call({"uid": uid});
//       print("Cloud Function result: ${result.data}");

//       if (result.data["success"]) {
//         print("User deleted successfully: $uid");
//         if (_auth.currentUser?.uid == uid) {
//           await logout();
//         }
//       } else {
//         print("Failed to delete user. Error: ${result.data["message"]}");
//         throw FirebaseException(
//           plugin: "cloud_functions",
//           code: "delete-failed",
//           message: "Failed to delete user: ${result.data["message"]}",
//         );
//       }
//     } catch (e) {
//       print("Error during user deletion: $e");
//       if (e is FirebaseFunctionsException) {
//         print("Firebase Functions error code: ${e.code}");
//         print("Firebase Functions error details: ${e.details}");
//         print("Firebase Functions error message: ${e.message}");
//       }
//       rethrow;
//     }
//   }

//   Future<String?> _getUserRole(String uid) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         String? role = (doc.data() as Map<String, dynamic>?)?['role'];
//         print("Retrieved role for user $uid: $role");
//         return role;
//       } else {
//         print("No document found for user $uid. Creating one.");
//         await _firestore.collection('users').doc(uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//         return 'User';
//       }
//     } catch (e) {
//       print("Error getting user role for $uid: $e");
//     }
//     return null;
//   }

//   Future<void> _signInWithCredential(AuthCredential credential) async {
//     try {
//       UserCredential userCredential =
//           await _auth.signInWithCredential(credential);
//       _user = userCredential.user;
//       await _createOrUpdateUserInFirestore(_user!);
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error signing in with credential: $e");
//       rethrow;
//     }
//   }

//   Future<void> _createOrSignInWithEmail(String email) async {
//     try {
//       List<String> signInMethods =
//           await _auth.fetchSignInMethodsForEmail(email);
//       if (signInMethods.isEmpty) {
//         UserCredential userCredential =
//             await _auth.createUserWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//         await _createOrUpdateUserInFirestore(_user!);
//       } else {
//         UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//       }
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error creating or signing in user with email: $e");
//       rethrow;
//     }
//   }

//   String _generateRandomPassword() {
//     const chars =
//         'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
//     return List.generate(12, (index) => chars[Random().nextInt(chars.length)])
//         .join();
//   }
// }







// import 'dart:math';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/services.dart';
// import 'package:email_validator/email_validator.dart';

// class AuthProvider with ChangeNotifier {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseFunctions _functions = FirebaseFunctions.instance;

//   User? _user;
//   String? _role;
//   String? _email;
//   bool _isCreatingUser = false;

//   User? get user => _user;
//   String? get role => _role;
//   String? get currentUserEmail => _email;
//   bool get isEmailVerified => _user?.emailVerified ?? false;

//   AuthProvider() {
//     _auth.authStateChanges().listen(_onAuthStateChanged);
//   }

//   Future<User?> login(String email, String password) async {
//     email = email.trim();
//     if (email.isEmpty || password.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-input',
//         message: "Email and password cannot be empty.",
//       );
//     }

//     if (!EmailValidator.validate(email)) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: "The email address is not valid.",
//       );
//     }

//     try {
//       print("Attempting to sign in with email: $email");
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email, password: password);
//       print("Sign in successful");
//       _user = userCredential.user;

//       if (_user != null) {
//         print("User is not null, reloading user data");
//         await _user!.reload();
//         _user = _auth.currentUser;

//         print("Checking email verification");
//         if (!_user!.emailVerified) {
//           print("Email not verified, sending verification email");
//           await _user!.sendEmailVerification();
//           throw FirebaseAuthException(
//             code: 'email-not-verified',
//             message: 'Please verify your email before logging in.',
//           );
//         }

//         print("Email verified, refreshing user data");
//         _email = _user?.email;
//         await refreshUserData();
//         notifyListeners();
//       } else {
//         print("User is null after sign in");
//       }
//       return _user;
//     } on FirebaseAuthException catch (e) {
//       print("FirebaseAuthException during login: ${e.code} - ${e.message}");
//       rethrow;
//     } catch (e) {
//       print("Unexpected error during login: $e");
//       throw FirebaseAuthException(
//         code: 'unknown',
//         message: 'An unexpected error occurred. Please try again.',
//       );
//     }
//   }

//   // Future<User?> login(String email, String password) async {
//   //   email = email.trim();
//   //   if (email.isEmpty || password.isEmpty) {
//   //     throw FirebaseAuthException(
//   //       code: 'invalid-input',
//   //       message: "Email and password cannot be empty.",
//   //     );
//   //   }

//   //   if (!EmailValidator.validate(email)) {
//   //     throw FirebaseAuthException(
//   //       code: 'invalid-email',
//   //       message: "The email address is not valid.",
//   //     );
//   //   }

//   //   try {
//   //     UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//   //         email: email, password: password);
//   //     _user = userCredential.user;

//   //     if (_user != null) {
//   //       // Force refresh the token to ensure the most up-to-date information
//   //       await _user!.reload();
//   //       _user = _auth.currentUser;

//   //       if (!_user!.emailVerified) {
//   //         await _user!.sendEmailVerification();
//   //         throw FirebaseAuthException(
//   //           code: 'email-not-verified',
//   //           message: 'Please verify your email before logging in.',
//   //         );
//   //       }

//   //       _email = _user?.email;
//   //       await refreshUserData();
//   //       notifyListeners();
//   //     }
//   //     return _user;
//   //   } on FirebaseAuthException {
//   //     rethrow;
//   //   } catch (e) {
//   //     throw FirebaseAuthException(
//   //       code: 'unknown',
//   //       message: 'An unexpected error occurred. Please try again.',
//   //     );
//   //   }
//   // }

//   Future<void> _onAuthStateChanged(User? user) async {
//     print("Auth state changed. User: ${user?.email}");
//     if (user != null) {
//       // Force refresh the token to ensure the most up-to-date information
//       await user.reload();
//       _user = _auth.currentUser;

//       if (!_user!.emailVerified) {
//         print("User email not verified. Signing out.");
//         await logout();
//         throw FirebaseAuthException(
//           code: 'email-not-verified',
//           message: 'Please verify your email before logging in.',
//         );
//       } else {
//         _email = _user?.email;
//         await refreshUserData();
//         print("User authenticated. Email: $_email, Role: $_role");
//       }
//     } else {
//       _user = null;
//       _email = null;
//       _role = null;
//       print("User signed out");
//     }
//     notifyListeners();
//   }

//   // Future<void> _onAuthStateChanged(User? user) async {
//   //   print("Auth state changed. User: ${user?.email}");
//   //   if (user != null) {
//   //     _user = user;
//   //     _email = user.email;
//   //     await refreshUserData();
//   //     print("User authenticated. Email: $_email, Role: $_role");
//   //   } else {
//   //     _user = null;
//   //     _email = null;
//   //     _role = null;
//   //     print("User signed out");
//   //   }
//   //   notifyListeners();
//   // }

//   // Future<User?> login(String email, String password) async {
//   //   email = email.trim();
//   //   if (email.isEmpty || password.isEmpty) {
//   //     throw FirebaseAuthException(
//   //       code: 'invalid-input',
//   //       message: "Email and password cannot be empty.",
//   //     );
//   //   }

//   //   if (!EmailValidator.validate(email)) {
//   //     throw FirebaseAuthException(
//   //       code: 'invalid-email',
//   //       message: "The email address is not valid.",
//   //     );
//   //   }

//   //   try {
//   //     UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//   //         email: email, password: password);
//   //     _user = userCredential.user;
//   //     _email = _user?.email;
//   //     await refreshUserData();
//   //     notifyListeners();
//   //     return _user;
//   //   } on FirebaseAuthException {
//   //     rethrow;
//   //   } catch (e) {
//   //     throw FirebaseAuthException(
//   //       code: 'unknown',
//   //       message: 'An unexpected error occurred. Please try again.',
//   //     );
//   //   }
//   // }

//   Future<void> refreshUserData() async {
//     if (_user != null) {
//       try {
//         DocumentSnapshot doc =
//             await _firestore.collection('users').doc(_user!.uid).get();
//         if (doc.exists) {
//           Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
//           _role = userData['role'] as String?;
//           _email = userData['email'] as String?;
//         } else {
//           await _createOrUpdateUserInFirestore(_user!);
//         }
//       } catch (e) {
//         print("Error refreshing user data: $e");
//       }
//     }
//   }

//   Future<void> _createOrUpdateUserInFirestore(User user) async {
//     await _firestore.collection('users').doc(user.uid).set({
//       'phoneNumber': user.phoneNumber,
//       'email': user.email,
//       'role': 'User', // Default role
//       'lastSignInTime': FieldValue.serverTimestamp(),
//       'creationTime': user.metadata.creationTime,
//     }, SetOptions(merge: true));
//   }

//   // Future<void> sendEmailOTP(String email) async {
//   //   if (!EmailValidator.validate(email)) {
//   //     throw FirebaseAuthException(
//   //       code: 'invalid-email',
//   //       message: 'Please enter a valid email address.',
//   //     );
//   //   }

//   //   try {
//   //     String otp = _generateOTP();
//   //     await _firestore.collection('users').doc(email).set({
//   //       'email': email,
//   //       'otp': otp,
//   //       'otpCreatedAt': FieldValue.serverTimestamp(),
//   //     }, SetOptions(merge: true));

//   //     // TODO: Implement actual email sending logic here
//   //     // For now, we'll just print the OTP to the console
//   //     print("OTP for $email: $otp");

//   //     // In a production environment, you would use a service like SendGrid, Mailgun, or Firebase Cloud Functions to send the email
//   //     // Example pseudo-code:
//   //     // await sendEmail(
//   //     //   to: email,
//   //     //   subject: 'Your OTP for login',
//   //     //   body: 'Your OTP is: $otp. It will expire in 5 minutes.',
//   //     // );
//   //   } catch (e) {
//   //     print("Error sending email OTP: $e");
//   //     rethrow;
//   //   }
//   // }

//   // Future<User?> verifyEmailOTP(String email, String otp) async {
//   //   try {
//   //     DocumentSnapshot userDoc =
//   //         await _firestore.collection('users').doc(email).get();

//   //     if (!userDoc.exists) {
//   //       throw FirebaseAuthException(
//   //         code: 'user-not-found',
//   //         message: 'No user found with this email address.',
//   //       );
//   //     }

//   //     Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

//   //     if (userData['otp'] != otp) {
//   //       throw FirebaseAuthException(
//   //         code: 'invalid-otp',
//   //         message: 'Invalid OTP.',
//   //       );
//   //     }

//   //     Timestamp? createdAt = userData['otpCreatedAt'] as Timestamp?;
//   //     if (createdAt == null ||
//   //         DateTime.now().difference(createdAt.toDate()).inMinutes > 5) {
//   //       throw FirebaseAuthException(
//   //         code: 'expired-otp',
//   //         message: 'OTP has expired. Please request a new one.',
//   //       );
//   //     }

//   //     UserCredential userCredential;
//   //     try {
//   //       userCredential = await _auth.signInWithEmailAndPassword(
//   //         email: email,
//   //         password: _generateTemporaryPassword(),
//   //       );
//   //     } catch (signInError) {
//   //       if (signInError is FirebaseAuthException &&
//   //           signInError.code == 'user-not-found') {
//   //         userCredential = await _auth.createUserWithEmailAndPassword(
//   //           email: email,
//   //           password: _generateTemporaryPassword(),
//   //         );
//   //       } else {
//   //         rethrow;
//   //       }
//   //     }

//   //     _user = userCredential.user;
//   //     await _firestore.collection('users').doc(email).update({
//   //       'uid': _user!.uid,
//   //       'otp': FieldValue.delete(),
//   //       'otpCreatedAt': FieldValue.delete(),
//   //     });
//   //     await refreshUserData();
//   //     return _user;
//   //   } catch (e) {
//   //     print("Error verifying email OTP: $e");
//   //     rethrow;
//   //   }
//   // }

//   Future<void> sendEmailOTP(String email) async {
//     if (!EmailValidator.validate(email)) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: 'Please enter a valid email address.',
//       );
//     }

//     try {
//       HttpsCallable callable = _functions.httpsCallable('sendEmailOTP');
//       await callable.call({'email': email});
//     } catch (e) {
//       print("Error sending email OTP: $e");
//       rethrow;
//     }
//   }

//   Future<User?> verifyEmailOTP(String email, String otp) async {
//     try {
//       HttpsCallable callable = _functions.httpsCallable('verifyEmailOTP');
//       final result = await callable.call({'email': email, 'otp': otp});

//       if (result.data['isValid']) {
//         // OTP is valid, sign in the user
//         UserCredential userCredential = await _auth.signInWithCustomToken(
//           result.data['customToken'],
//         );
//         _user = userCredential.user;
//         await refreshUserData();
//         return _user;
//       } else {
//         throw FirebaseAuthException(
//           code: 'invalid-otp',
//           message: 'Invalid OTP. Please try again.',
//         );
//       }
//     } catch (e) {
//       print("Error verifying email OTP: $e");
//       rethrow;
//     }
//   }

//   String _generateOTP() {
//     return (100000 + Random().nextInt(900000)).toString();
//   }

//   String _generateTemporaryPassword() {
//     const chars =
//         'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
//     return List.generate(32, (index) => chars[Random().nextInt(chars.length)])
//         .join();
//   }

//   Future<void> sendPasswordResetEmail(String email) async {
//     if (email.isEmpty) {
//       throw FirebaseAuthException(
//         code: 'invalid-email',
//         message: 'Please enter your email address.',
//       );
//     }
//     await _auth.sendPasswordResetEmail(email: email);
//   }

//   Future<void> logout() async {
//     try {
//       await _auth.signOut();
//       _user = null;
//       _role = null;
//       _email = null;
//       notifyListeners();
//     } catch (e) {
//       throw FirebaseAuthException(
//         code: 'sign-out-failed',
//         message: 'Failed to sign out. Please try again.',
//       );
//     }
//   }

//   Future<void> createUserWithAdmin(
//       String email, String password, String role, String name) async {
//     User? adminUser = _auth.currentUser;
//     if (adminUser == null) {
//       throw Exception('Admin must be logged in to create a new user');
//     }

//     _isCreatingUser = true;
//     try {
//       FirebaseApp tempApp = await Firebase.initializeApp(
//           name: 'tempApp', options: Firebase.app().options);

//       try {
//         UserCredential userCredential = await FirebaseAuth.instanceFor(
//                 app: tempApp)
//             .createUserWithEmailAndPassword(email: email, password: password);

//         String uid = userCredential.user!.uid;

//         await _firestore.collection('users').doc(uid).set({
//           'name': name,
//           'email': email,
//           'role': role,
//           'mobile': '',
//         });

//         print("User created successfully: $email");
//       } catch (e) {
//         print("Error during user creation: $e");
//         rethrow;
//       } finally {
//         await tempApp.delete();
//       }

//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error during user creation: $e");
//       rethrow;
//     } finally {
//       _isCreatingUser = false;
//     }
//   }

//   Future<bool> shouldAllowAutoLogin(User user) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(user.uid).get();
//       if (doc.exists) {
//         String role = (doc.data() as Map<String, dynamic>)['role'] as String;
//         return ['Admin', 'Manager', 'User', 'Gate Man'].contains(role);
//       }
//     } catch (e) {
//       print("Error checking user role: $e");
//       return false;
//     }
//     return false;
//   }

//   Future<void> signOutIfUnauthorized() async {
//     User? currentUser = _auth.currentUser;
//     if (currentUser != null) {
//       try {
//         bool shouldAllow = await shouldAllowAutoLogin(currentUser);
//         if (!shouldAllow) {
//           print("User not authorized, logging out: ${currentUser.email}");
//           await logout();
//         } else {
//           print("User authorized, staying logged in: ${currentUser.email}");
//           await refreshUserData();
//         }
//       } catch (e) {
//         print("Error checking authorization, logging out: $e");
//         await logout();
//       }
//     } else {
//       print("No current user, no action needed");
//     }
//   }

//   Future<void> ensureUserDocument() async {
//     if (_user != null) {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(_user!.uid).get();
//       if (!doc.exists) {
//         print("Creating missing user document for ${_user!.email}");
//         await _firestore.collection('users').doc(_user!.uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//       }
//       _role = await _getUserRole(_user!.uid);
//       notifyListeners();
//     }
//   }

//   Future<void> updateUser(String uid, Map<String, dynamic> data) async {
//     try {
//       await _firestore.collection('users').doc(uid).update(data);
//       if (_user != null && _user!.uid == uid) {
//         _role = data['role'] ?? _role;
//         _email = data['email'] ?? _email;
//         notifyListeners();
//       }
//     } catch (e) {
//       print("Error during user update: $e");
//       rethrow;
//     }
//   }

//   // Future<void> deleteUser(String uid) async {
//   //   try {
//   //     await _firestore.collection('users').doc(uid).delete();
//   //     if (_user != null && _user!.uid == uid) {
//   //       await logout();
//   //     }
//   //   } catch (e) {
//   //     print("Error during user deletion: $e");
//   //     rethrow;
//   //   }
//   // }
//   Future<void> deleteUser(String uid) async {
//     try {
//       print("Attempting to delete user with UID: $uid");
//       final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
//       final callable = functions.httpsCallable('deleteUser');
//       print("Calling Cloud Function: deleteUser");
//       final result = await callable.call({"uid": uid});
//       print("Cloud Function result: ${result.data}");

//       if (result.data["success"]) {
//         print("User deleted successfully: $uid");
//         if (_auth.currentUser?.uid == uid) {
//           await logout();
//         }
//       } else {
//         print("Failed to delete user. Error: ${result.data["message"]}");
//         throw FirebaseException(
//           plugin: "cloud_functions",
//           code: "delete-failed",
//           message: "Failed to delete user: ${result.data["message"]}",
//         );
//       }
//     } catch (e) {
//       print("Error during user deletion: $e");
//       if (e is FirebaseFunctionsException) {
//         print("Firebase Functions error code: ${e.code}");
//         print("Firebase Functions error details: ${e.details}");
//         print("Firebase Functions error message: ${e.message}");
//       }
//       rethrow;
//     }
//   }

//   Future<String?> _getUserRole(String uid) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         String? role = (doc.data() as Map<String, dynamic>?)?['role'];
//         print("Retrieved role for user $uid: $role");
//         return role;
//       } else {
//         print("No document found for user $uid. Creating one.");
//         await _firestore.collection('users').doc(uid).set({
//           'email': _user!.email,
//           'role': 'User',
//         });
//         return 'User';
//       }
//     } catch (e) {
//       print("Error getting user role for $uid: $e");
//     }
//     return null;
//   }

//   Future<void> _signInWithCredential(AuthCredential credential) async {
//     try {
//       UserCredential userCredential =
//           await _auth.signInWithCredential(credential);
//       _user = userCredential.user;
//       await _createOrUpdateUserInFirestore(_user!);
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error signing in with credential: $e");
//       rethrow;
//     }
//   }

//   Future<void> _createOrSignInWithEmail(String email) async {
//     try {
//       List<String> signInMethods =
//           await _auth.fetchSignInMethodsForEmail(email);
//       if (signInMethods.isEmpty) {
//         UserCredential userCredential =
//             await _auth.createUserWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//         await _createOrUpdateUserInFirestore(_user!);
//       } else {
//         UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//           email: email,
//           password: _generateRandomPassword(),
//         );
//         _user = userCredential.user;
//       }
//       await refreshUserData();
//       notifyListeners();
//     } catch (e) {
//       print("Error creating or signing in user with email: $e");
//       rethrow;
//     }
//   }

//   String _generateRandomPassword() {
//     const chars =
//         'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
//     return List.generate(12, (index) => chars[Random().nextInt(chars.length)])
//         .join();
//   }
// }
