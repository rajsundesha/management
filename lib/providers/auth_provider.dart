import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:dhavla_road_project/screens/common/listener_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:provider/provider.dart'; // Ensure this import is available

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final ListenerManager _listenerManager; // Inject ListenerManager

  User? _user;
  String? _role;
  String? _email;
  bool _isCreatingUser = false;
  String _userName = '';
  String get userName => _userName;

  User? get user => _user;
  String? get role => _role;
  String? get currentUserEmail => _email;

  AuthProvider(this._listenerManager) {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }
  // AuthProvider() {
  //   _auth.authStateChanges().listen(_onAuthStateChanged);
  // }
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

        print("Fetching user document from Firestore");
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_user!.uid).get();

        if (userDoc.exists) {
          print("User document found in Firestore");
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          // Check if the user is disabled
          bool isDisabled = userData['isDisabled'] ?? false;
          if (isDisabled) {
            print("User account is disabled");
            await _auth.signOut();
            throw FirebaseAuthException(
              code: 'user-disabled',
              message:
                  "This account has been disabled. Please contact an administrator.",
            );
          }

          // Set user role
          _role = userData['role'] as String?;
          print("User role set to: $_role");

          // Set user email
          _email = _user?.email;

          await refreshUserData();
          notifyListeners();

          print("Login successful. User: $_email, Role: $_role");
        } else {
          print("User document not found in Firestore");
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: "User data not found. Please contact an administrator.",
          );
        }
      } else {
        print("User is null after sign in");
        throw FirebaseAuthException(
          code: 'null-user',
          message: "Failed to retrieve user data after sign in.",
        );
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

  // Future<User?> login(String email, String password) async {
  //   email = email.trim();
  //   if (email.isEmpty || password.isEmpty) {
  //     throw FirebaseAuthException(
  //       code: 'invalid-input',
  //       message: "Email and password cannot be empty.",
  //     );
  //   }

  //   if (!EmailValidator.validate(email)) {
  //     throw FirebaseAuthException(
  //       code: 'invalid-email',
  //       message: "The email address is not valid.",
  //     );
  //   }

  //   try {
  //     print("Attempting to sign in with email: $email");
  //     UserCredential userCredential = await _auth.signInWithEmailAndPassword(
  //         email: email, password: password);
  //     print("Sign in successful");
  //     _user = userCredential.user;

  //     if (_user != null) {
  //       print("User is not null, reloading user data");
  //       await _user!.reload();
  //       _user = _auth.currentUser;

  //       // Check if the user is disabled
  //       DocumentSnapshot userDoc =
  //           await _firestore.collection('users').doc(_user!.uid).get();
  //       if (userDoc.exists) {
  //         bool isDisabled = userDoc.get('isDisabled') ?? false;
  //         if (isDisabled) {
  //           await _auth.signOut(); // Sign out the user if they're disabled
  //           throw FirebaseAuthException(
  //             code: 'user-disabled',
  //             message:
  //                 "This account has been disabled. Please contact an administrator.",
  //           );
  //         }
  //       }

  //       _email = _user?.email;
  //       await refreshUserData();
  //       notifyListeners();
  //     } else {
  //       print("User is null after sign in");
  //     }
  //     return _user;
  //   } on FirebaseAuthException catch (e) {
  //     print("FirebaseAuthException during login: ${e.code} - ${e.message}");
  //     rethrow;
  //   } catch (e) {
  //     print("Unexpected error during login: $e");
  //     throw FirebaseAuthException(
  //       code: 'unknown',
  //       message: 'An unexpected error occurred. Please try again.',
  //     );
  //   }
  // }

  // Future<User?> login(String email, String password) async {
  //   email = email.trim();
  //   if (email.isEmpty || password.isEmpty) {
  //     throw FirebaseAuthException(
  //       code: 'invalid-input',
  //       message: "Email and password cannot be empty.",
  //     );
  //   }

  //   if (!EmailValidator.validate(email)) {
  //     throw FirebaseAuthException(
  //       code: 'invalid-email',
  //       message: "The email address is not valid.",
  //     );
  //   }

  //   try {
  //     print("Attempting to sign in with email: $email");
  //     UserCredential userCredential = await _auth.signInWithEmailAndPassword(
  //         email: email, password: password);
  //     print("Sign in successful");
  //     _user = userCredential.user;

  //     if (_user != null) {
  //       print("User is not null, reloading user data");
  //       await _user!.reload();
  //       _user = _auth.currentUser;

  //       _email = _user?.email;
  //       await refreshUserData();
  //       notifyListeners();
  //     } else {
  //       print("User is null after sign in");
  //     }
  //     return _user;
  //   } on FirebaseAuthException catch (e) {
  //     print("FirebaseAuthException during login: ${e.code} - ${e.message}");
  //     rethrow;
  //   } catch (e) {
  //     print("Unexpected error during login: $e");
  //     throw FirebaseAuthException(
  //       code: 'unknown',
  //       message: 'An unexpected error occurred. Please try again.',
  //     );
  //   }
  // }

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

  Future<void> disableUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isDisabled': true,
      });
      notifyListeners();
    } catch (e) {
      print("Error disabling user: $e");
      rethrow;
    }
  }

  Future<void> enableUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isDisabled': false,
      });
      notifyListeners();
    } catch (e) {
      print("Error enabling user: $e");
      rethrow;
    }
  }

  Future<bool> isUserDisabled(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return userDoc.get('isDisabled') as bool? ?? false;
      } else {
        print("User document not found for uid: $uid");
        return false;
      }
    } catch (e) {
      print("Error checking user disabled status: $e");
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      // Retrieve the InventoryProvider from the context
      InventoryProvider inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      // Cancel all active listeners using ListenerManager
      await _listenerManager.cancelAllListeners();

      // Cancel any specific listeners directly
      await inventoryProvider.cancelListener();

      // Sign out the user from Firebase
      await _auth.signOut();

      // Clear user-related state variables
      _user = null;
      _role = null;
      _email = null;

      // Notify listeners to update the UI or other parts of the app
      notifyListeners();

      print("User signed out and listeners canceled.");
    } catch (e) {
      throw FirebaseAuthException(
        code: 'sign-out-failed',
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  // Future<void> logout() async {
  //   try {
  //     await _auth.signOut();
  //     _user = null;
  //     _role = null;
  //     _email = null;
  //     notifyListeners();
  //   } catch (e) {
  //     throw FirebaseAuthException(
  //       code: 'sign-out-failed',
  //       message: 'Failed to sign out. Please try again.',
  //     );
  //   }
  // }

  Future<void> requestAccountDeletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to request account deletion');
    }

    try {
      await FirebaseFirestore.instance.collection('deletion_requests').add({
        'userId': user.uid,
        'email': user.email,
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      print('Error requesting account deletion: $e');
      rethrow;
    }
  }

  Future<String?> getUserRole() async {
    if (_user != null) {
      try {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(_user!.uid).get();
        if (doc.exists) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          return userData['role'] as String?;
        } else {
          print("No document found for user ${_user!.uid}.");
          return null;
        }
      } catch (e) {
        print("Error getting user role: $e");
        return null;
      }
    }
    return null;
  }

  Future<void> updateAccountDeletionRequestStatus(
      String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('deletion_requests')
          .doc(requestId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'approved') {
        await FirebaseFirestore.instance
            .collection('deletion_requests')
            .doc(requestId)
            .update({
          'scheduledDeletionDate':
              Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        });
      }

      // Notify the user of the status change
      DocumentSnapshot requestDoc = await FirebaseFirestore.instance
          .collection('deletion_requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        String userId = requestDoc['userId'];
        await _notifyUserOfDeletionRequestStatus(userId, newStatus);
      }

      notifyListeners();
    } catch (e) {
      print("Error updating account deletion request status: $e");
      rethrow;
    }
  }

  Future<void> cancelAccountDeletionRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to cancel account deletion');
    }

    try {
      final requestSnapshot = await FirebaseFirestore.instance
          .collection('deletion_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestSnapshot.docs.isNotEmpty) {
        final requestId = requestSnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('deletion_requests')
            .doc(requestId)
            .update({'status': 'canceled'});
        notifyListeners();
      }
    } catch (e) {
      print('Error canceling account deletion request: $e');
      rethrow;
    }
  }

  Future<void> processAccountDeletionRequest(
      String userId, bool approved) async {
    try {
      String newStatus = approved ? 'approved' : 'rejected';

      await FirebaseFirestore.instance
          .collection('deletion_requests')
          .doc(userId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (approved) {
        await FirebaseFirestore.instance
            .collection('deletion_requests')
            .doc(userId)
            .update({
          'scheduledDeletionDate':
              Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        });
      }

      // Notify the user of the status change
      await _notifyUserOfDeletionRequestStatus(userId, newStatus);

      notifyListeners();
    } catch (e) {
      print("Error processing account deletion request: $e");
      rethrow;
    }
  }

  Future<void> _notifyUserOfDeletionRequestStatus(
      String userId, String status) async {
    try {
      String message;
      switch (status) {
        case 'approved':
          message =
              'Your account deletion request has been approved. Your account will be deleted in 7 days.';
          break;
        case 'rejected':
          message = 'Your account deletion request has been rejected.';
          break;
        default:
          message =
              'There has been an update to your account deletion request.';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': 'Account Deletion Request Update',
        'body': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print("Error notifying user of deletion request status: $e");
    }
  }

  Future<void> _notifyAdminOfDeletionRequest(String userId) async {
    try {
      QuerySnapshot adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Admin')
          .get();

      for (var adminDoc in adminSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': adminDoc.id,
          'title': 'Account Deletion Request',
          'body': 'User $userId has requested account deletion.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      print("Error notifying admin of deletion request: $e");
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
          _userName = userData['name'] as String? ?? '';

          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _updateFCMToken(fcmToken);
          }
        } else {
          await _createOrUpdateUserInFirestore(_user!);
        }
      } catch (e) {
        print("Error refreshing user data: $e");
      }
    }
  }

  void updateUserNameLocally(String newName) {
    _userName = newName;
    notifyListeners();
  }

  Future<void> updateUserName(String newName) async {
    updateUserNameLocally(newName);
    if (_user != null) {
      try {
        await _firestore.collection('users').doc(_user!.uid).update({
          'name': newName,
        });
      } catch (e) {
        print("Error updating user name: $e");
        // Revert local change if update fails
        _userName = '';
        notifyListeners();
        throw e;
      }
    }
  }

  Future<void> _updateFCMToken(String token) async {
    try {
      await _firestore.collection('users').doc(_user!.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      print('FCM Token updated in Firestore successfully');
    } catch (e) {
      print('Error updating FCM token: $e');
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

  Future<String> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    try {
      // Check if the email exists in Firestore
      QuerySnapshot userDocs = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userDocs.docs.isEmpty) {
        // User doesn't exist, but we return a generic message
        return 'If an account exists for this email, a password reset link will be sent. Please check your email.';
      }

      // User exists, send the reset email
      await _auth.sendPasswordResetEmail(email: email);
      return 'A password reset link has been sent to your email address. Please check your inbox.';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-not-found':
          // We still return a generic message to avoid revealing account existence
          return 'If an account exists for this email, a password reset link will be sent. Please check your email.';
        default:
          return 'An error occurred. Please try again later.';
      }
    } catch (e) {
      print("Unexpected error in sendPasswordResetEmail: $e");
      return 'An unexpected error occurred. Please try again later.';
    }
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

  Future<void> signOutIfUnauthorized(BuildContext context) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        bool shouldAllow = await shouldAllowAutoLogin(currentUser);
        if (!shouldAllow) {
          print("User not authorized, logging out: ${currentUser.email}");
          await logout(context); // Pass the context to the logout method
        } else {
          print("User authorized, staying logged in: ${currentUser.email}");
          await refreshUserData();
        }
      } catch (e) {
        print("Error checking authorization, logging out: $e");
        await logout(
            context); // Pass the context to the logout method in case of error
      }
    } else {
      print("No current user, no action needed");
    }
  }

  // Future<void> signOutIfUnauthorized() async {
  //   User? currentUser = _auth.currentUser;
  //   if (currentUser != null) {
  //     try {
  //       bool shouldAllow = await shouldAllowAutoLogin(currentUser);
  //       if (!shouldAllow) {
  //         print("User not authorized, logging out: ${currentUser.email}");
  //         await logout(context);
  //       } else {
  //         print("User authorized, staying logged in: ${currentUser.email}");
  //         await refreshUserData();
  //       }
  //     } catch (e) {
  //       print("Error checking authorization, logging out: $e");
  //       await logout();
  //     }
  //   } else {
  //     print("No current user, no action needed");
  //   }
  // }

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

  // Future<void> deleteUser(String uid) async {
  //   try {
  //     print("Attempting to delete user with UID: $uid");

  //     final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  //     final callable = functions.httpsCallable('deleteUser');

  //     final result = await callable.call({"uid": uid});

  //     if (result.data["success"] == true) {
  //       print("User deletion result: ${result.data["message"]}");

  //       // If this was the current user, log them out
  //       if (_auth.currentUser?.uid == uid) {
  //         await logout();
  //       }

  //       notifyListeners();
  //     } else {
  //       throw FirebaseException(
  //         plugin: "cloud_functions",
  //         code: "delete-failed",
  //         message: result.data["message"] ?? "Failed to delete user",
  //       );
  //     }
  //   } catch (e) {
  //     print("Error during user deletion: $e");
  //     if (e is FirebaseFunctionsException) {
  //       print("Firebase Functions error code: ${e.code}");
  //       print("Firebase Functions error details: ${e.details}");
  //       print("Firebase Functions error message: ${e.message}");
  //     }
  //     rethrow;
  //   }
  // }
  Future<void> deleteUser(String uid, BuildContext context) async {
    try {
      print("Attempting to delete user with UID: $uid");

      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('deleteUser');

      final result = await callable.call({"uid": uid});

      if (result.data["success"] == true) {
        print("User deletion result: ${result.data["message"]}");

        // If this was the current user, log them out
        if (_auth.currentUser?.uid == uid) {
          await logout(context); // Pass the context to logout
        }

        notifyListeners();
      } else {
        throw FirebaseException(
          plugin: "cloud_functions",
          code: "delete-failed",
          message: result.data["message"] ?? "Failed to delete user",
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
