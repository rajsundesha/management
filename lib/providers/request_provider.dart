import 'package:flutter/material.dart';

class RequestProvider with ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];

  List<Map<String, dynamic>> get requests => _requests;

  void addRequest(List<Map<String, dynamic>> items) {
    _requests.add({'items': items, 'status': 'pending'});
    notifyListeners();
  }

  void updateRequestStatus(int index, String status) {
    _requests[index]['status'] = status;
    notifyListeners();
  }

  void cancelRequest(int index) {
    _requests.removeAt(index);
    notifyListeners();
  }

  void updateRequest(int index, List<Map<String, dynamic>> items) {
    _requests[index]['items'] = items;
    notifyListeners();
  }
}
