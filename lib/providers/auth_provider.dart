import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  String? _role;

  String? get role => _role;

  void login(String role) {
    _role = role;
    notifyListeners();
  }

  void logout() {
    _role = null;
    notifyListeners();
  }
}
