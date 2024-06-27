import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  List<Map<String, dynamic>> _users = [];

  List<Map<String, dynamic>> get users => _users;

  void addUser(Map<String, dynamic> user) {
    _users.add(user);
    notifyListeners();
  }

  void updateUser(int index, Map<String, dynamic> user) {
    _users[index] = user;
    notifyListeners();
  }

  void deleteUser(int index) {
    _users.removeAt(index);
    notifyListeners();
  }
}
