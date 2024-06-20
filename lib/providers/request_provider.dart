import 'package:flutter/material.dart';

class RequestProvider with ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];

  List<Map<String, dynamic>> get requests => _requests;

  void addRequest(List<Map<String, dynamic>> items, String location,
      String pickerName, String pickerContact, String note) {
    _requests.add({
      'items': items,
      'status': 'pending',
      'timestamp': DateTime.now(),
      'location': location,
      'pickerName': pickerName,
      'pickerContact': pickerContact,
      'note': note,
    });
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

  void updateRequest(int index, List<Map<String, dynamic>> items,
      String location, String pickerName, String pickerContact, String note) {
    if (_requests[index]['status'] == 'pending') {
      _requests[index]['items'] = items;
      _requests[index]['location'] = location;
      _requests[index]['pickerName'] = pickerName;
      _requests[index]['pickerContact'] = pickerContact;
      _requests[index]['note'] = note;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getPendingRequests() {
    return _requests
        .where((request) => request['status'] == 'pending')
        .toList();
  }

  List<Map<String, dynamic>> getCompletedRequests() {
    return _requests
        .where((request) =>
            request['status'] != 'pending' &&
            DateTime.now().difference(request['timestamp']).inDays < 1)
        .toList();
  }
}
