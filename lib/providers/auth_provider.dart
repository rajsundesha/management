import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String? _role;
  String? _email;

  User? get user => _user;
  String? get role => _role;
  String? get currentUserEmail => _email;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      _email = _user?.email;
      _role = await _getUserRole(_user!.uid);
      notifyListeners();
    } catch (e) {
      print(e);
      throw e;
    }
  }

  Future<void> createUser(String email, String password, String role) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? newUser = userCredential.user;
      await _firestore.collection('users').doc(newUser!.uid).set({
        'email': email,
        'role': role,
      });
      _user = newUser;
      _email = newUser.email;
      _role = role;
      notifyListeners();
    } catch (e) {
      print(e);
      throw e;
    }
  }

  Future<String?> _getUserRole(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data() as Map<String, dynamic>?)?['role'];
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _role = null;
    _email = null;
    notifyListeners();
  }

  void _onAuthStateChanged(User? user) async {
    _user = user;
    if (_user != null) {
      _email = _user!.email;
      _role = await _getUserRole(_user!.uid);
    } else {
      _email = null;
      _role = null;
    }
    notifyListeners();
  }
}



// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class AuthProvider with ChangeNotifier {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   User? _user;
//   String? _role;
//   String? _email;

//   User? get user => _user;
//   String? get role => _role;
//   String? get currentUserEmail => _email;

//   AuthProvider() {
//     _auth.authStateChanges().listen(_onAuthStateChanged);
//   }

//   Future<void> login(String email, String password) async {
//     try {
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       _user = userCredential.user;
//       _email = _user?.email;
//       _role = await _getUserRole(_user!.uid);
//       notifyListeners();
//     } catch (e) {
//       print(e);
//       throw e;
//     }
//   }

//   Future<String?> _getUserRole(String uid) async {
//     DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
//     return (doc.data() as Map<String, dynamic>?)?['role'];
//   }

//   Future<void> logout() async {
//     await _auth.signOut();
//     _user = null;
//     _role = null;
//     _email = null;
//     notifyListeners();
//   }

//   void _onAuthStateChanged(User? user) {
//     _user = user;
//     notifyListeners();
//   }
// }


// import 'package:flutter/material.dart';

// class AuthProvider with ChangeNotifier {
//   String? _role;
//   String? _email;

//   String? get role => _role;
//   String? get currentUserEmail => _email;

//   void login(String role, String email) {
//     _role = role;
//     _email = email;
//     notifyListeners();
//   }

//   void logout() {
//     _role = null;
//     _email = null;
//     notifyListeners();
//   }
// }


// import 'package:flutter/material.dart';

// class AuthProvider with ChangeNotifier {
//   String? _role;

//   String? get role => _role;

//   void login(String role) {
//     _role = role;
//     notifyListeners();
//   }

//   void logout() {
//     _role = null;
//     notifyListeners();
//   }
// }
