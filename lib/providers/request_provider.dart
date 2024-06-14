import 'package:flutter/material.dart';

class RequestProvider with ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];

  List<Map<String, dynamic>> get requests => _requests;

  void addRequest(List<String> items) {
    _requests.add({'items': items, 'status': 'pending'});
    notifyListeners();
  }

  void updateRequestStatus(int index, String status) {
    _requests[index]['status'] = status;
    notifyListeners();
  }
}
