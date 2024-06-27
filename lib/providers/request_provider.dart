import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _requests = [];

  List<Map<String, dynamic>> get requests => _requests;

  RequestProvider() {
    fetchRequests();
  }

  void fetchRequests() async {
    final querySnapshot = await _firestore.collection('requests').get();
    _requests = querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Include document ID in the request data
      return data;
    }).toList();
    notifyListeners();
  }

  String generateUniqueCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> addRequest(
      List<Map<String, dynamic>> items,
      String location,
      String pickerName,
      String pickerContact,
      String note,
      String createdBy) async {
    String uniqueCode = generateUniqueCode();
    final request = {
      'items': items,
      'status': 'pending',
      'timestamp': DateTime.now(),
      'location': location,
      'pickerName': pickerName,
      'pickerContact': pickerContact,
      'note': note,
      'uniqueCode': uniqueCode,
      'codeValid': false,
      'createdBy': createdBy,
    };
    final docRef = await _firestore.collection('requests').add(request);
    request['id'] = docRef.id; // Add document ID to the request
    _requests.add(request);
    notifyListeners();
  }

  Future<void> updateRequestStatus(String id, String status) async {
    final index = _requests.indexWhere((request) => request['id'] == id);
    if (index != -1) {
      _requests[index]['status'] = status;
      if (status == 'approved') {
        setCodeValid(index, true);
      }
      await _firestore
          .collection('requests')
          .doc(id)
          .update({'status': status});
      notifyListeners();
    }
  }

  Future<void> cancelRequest(String id) async {
    final index = _requests.indexWhere((request) => request['id'] == id);
    if (index != -1) {
      _requests.removeAt(index);
      await _firestore.collection('requests').doc(id).delete();
      notifyListeners();
    }
  }

  Future<void> updateRequest(
      String id,
      List<Map<String, dynamic>> items,
      String location,
      String pickerName,
      String pickerContact,
      String note,
      String userEmail) async {
    final index = _requests.indexWhere((request) => request['id'] == id);
    if (index != -1 &&
        (_requests[index]['createdBy'] == userEmail || userEmail == 'admin')) {
      _requests[index]['items'] = items;
      _requests[index]['location'] = location;
      _requests[index]['pickerName'] = pickerName;
      _requests[index]['pickerContact'] = pickerContact;
      _requests[index]['note'] = note;
      await _firestore.collection('requests').doc(id).update({
        'items': items,
        'location': location,
        'pickerName': pickerName,
        'pickerContact': pickerContact,
        'note': note,
      });
      notifyListeners();
    }
  }

  void setCodeValid(int index, bool isValid) {
    _requests[index]['codeValid'] = isValid;
    _firestore
        .collection('requests')
        .doc(_requests[index]['id'])
        .update({'codeValid': isValid});
    notifyListeners();
  }

  bool verifyCode(String code) {
    try {
      final request = _requests.firstWhere(
          (req) => req['uniqueCode'] == code && req['codeValid'] == true);
      return request != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> fulfillRequestByCode(String code) async {
    final index = _requests.indexWhere(
        (req) => req['uniqueCode'] == code && req['codeValid'] == true);
    if (index != -1) {
      _requests[index]['status'] = 'fulfilled';
      await _firestore
          .collection('requests')
          .doc(_requests[index]['id'])
          .update({'status': 'fulfilled'});
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
            DateTime.now().difference(request['timestamp'].toDate()).inDays < 1)
        .toList();
  }

  List<Map<String, dynamic>> getRequestsByRole(
      String userRole, String userEmail) {
    if (userRole == 'admin') {
      return _requests;
    } else if (userRole == 'manager') {
      return _requests
          .where((request) =>
              request['createdBy'] == userEmail || request['role'] == 'user')
          .toList();
    } else if (userRole == 'user') {
      return _requests
          .where((request) => request['createdBy'] == userEmail)
          .toList();
    } else {
      return [];
    }
  }

  Map<String, dynamic>? getRequestById(String id) {
    return _requests.firstWhere(
      (request) => request['id'] == id,
      orElse: () => <String, dynamic>{}, // Return an empty map if not found
    );
  }
}



// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class RequestProvider with ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   RequestProvider() {
//     fetchRequests();
//   }

//   Future<void> fetchRequests() async {
//     QuerySnapshot snapshot = await _firestore.collection('requests').get();
//     _requests =
//         snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
//     notifyListeners();
//   }

//   Future<void> addRequest(
//       List<Map<String, dynamic>> items,
//       String location,
//       String pickerName,
//       String pickerContact,
//       String note,
//       String createdBy) async {
//     String uniqueCode = generateUniqueCode();
//     await _firestore.collection('requests').add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//       'createdBy': createdBy,
//     });
//     fetchRequests();
//   }

//   Future<void> updateRequestStatus(String id, String status) async {
//     await _firestore.collection('requests').doc(id).update({'status': status});
//     if (status == 'approved') {
//       await _firestore
//           .collection('requests')
//           .doc(id)
//           .update({'codeValid': true});
//     }
//     fetchRequests();
//   }

//   Future<void> cancelRequest(String id) async {
//     await _firestore.collection('requests').doc(id).delete();
//     fetchRequests();
//   }

//   Future<void> updateRequest(
//       String id,
//       List<Map<String, dynamic>> items,
//       String location,
//       String pickerName,
//       String pickerContact,
//       String note,
//       String userEmail) async {
//     int index = _requests.indexWhere((request) => request['id'] == id);
//     if (index != -1 &&
//         _requests[index]['status'] == 'pending' &&
//         (_requests[index]['createdBy'] == userEmail || userEmail == 'admin')) {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       await _firestore.collection('requests').doc(id).update(_requests[index]);
//       notifyListeners();
//     }
//   }

//   Future<void> fulfillRequestByCode(String code) async {
//     QuerySnapshot snapshot = await _firestore
//         .collection('requests')
//         .where('uniqueCode', isEqualTo: code)
//         .where('codeValid', isEqualTo: true)
//         .get();
//     if (snapshot.docs.isNotEmpty) {
//       String id = snapshot.docs.first.id;
//       await _firestore
//           .collection('requests')
//           .doc(id)
//           .update({'status': 'fulfilled'});
//       fetchRequests();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now()
//                     .difference((request['timestamp'] as Timestamp).toDate())
//                     .inDays <
//                 1)
//         .toList();
//   }

//   List<Map<String, dynamic>> getRequestsByRole(
//       String userRole, String userEmail) {
//     if (userRole == 'admin') {
//       return _requests;
//     } else if (userRole == 'manager') {
//       return _requests
//           .where((request) =>
//               request['createdBy'] == userEmail || request['role'] == 'user')
//           .toList();
//     } else if (userRole == 'user') {
//       return _requests
//           .where((request) => request['createdBy'] == userEmail)
//           .toList();
//     } else {
//       return [];
//     }
//   }

//   String generateUniqueCode() {
//     final random = Random();
//     return (100000 + random.nextInt(900000)).toString();
//   }
// }


// import 'dart:math';
// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   String generateUniqueCode() {
//     final random = Random();
//     return (100000 + random.nextInt(900000)).toString();
//   }

//   void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note, String createdBy) {
//     String uniqueCode = generateUniqueCode();
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//       'createdBy': createdBy,
//     });
//     notifyListeners();
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     if (status == 'approved') {
//       setCodeValid(index, true);
//     }
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(
//       int index,
//       List<Map<String, dynamic>> items,
//       String location,
//       String pickerName,
//       String pickerContact,
//       String note,
//       String userEmail) {
//     if (_requests[index]['status'] == 'pending' &&
//         (_requests[index]['createdBy'] == userEmail || userEmail == 'admin')) {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   void setCodeValid(int index, bool isValid) {
//     _requests[index]['codeValid'] = isValid;
//     notifyListeners();
//   }

//   bool verifyCode(String code) {
//     try {
//       final request = _requests.firstWhere(
//           (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//       return request != null;
//     } catch (e) {
//       return false;
//     }
//   }

//   void fulfillRequestByCode(String code) {
//     final index = _requests.indexWhere(
//         (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//     if (index != -1) {
//       _requests[index]['status'] = 'fulfilled';
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }

//   List<Map<String, dynamic>> getRequestsByRole(
//       String userRole, String userEmail) {
//     if (userRole == 'admin') {
//       return _requests;
//     } else if (userRole == 'manager') {
//       return _requests
//           .where((request) =>
//               request['createdBy'] == userEmail || request['role'] == 'user')
//           .toList();
//     } else if (userRole == 'user') {
//       return _requests
//           .where((request) => request['createdBy'] == userEmail)
//           .toList();
//     } else {
//       return [];
//     }
//   }
// }




// import 'dart:math';
// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   String generateUniqueCode() {
//     final random = Random();
//     return (100000 + random.nextInt(900000)).toString();
//   }

//   void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note, String createdBy) {
//     String uniqueCode = generateUniqueCode();
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//       'createdBy': createdBy,
//     });
//     notifyListeners();
//     // Notify user with the unique code via email/SMS
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     if (status == 'approved') {
//       setCodeValid(index, true);
//     }
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(
//       int index,
//       List<Map<String, dynamic>> items,
//       String location,
//       String pickerName,
//       String pickerContact,
//       String note,
//       String createdBy) {
//     if (_requests[index]['status'] == 'pending' &&
//         (_requests[index]['createdBy'] == createdBy || createdBy == 'admin')) {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   void setCodeValid(int index, bool isValid) {
//     _requests[index]['codeValid'] = isValid;
//     notifyListeners();
//   }

//   bool verifyCode(String code) {
//     try {
//       final request = _requests.firstWhere(
//           (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//       return request != null;
//     } catch (e) {
//       return false;
//     }
//   }

//   void fulfillRequestByCode(String code) {
//     final index = _requests.indexWhere(
//         (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//     if (index != -1) {
//       _requests[index]['status'] = 'fulfilled';
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }

//   List<Map<String, dynamic>> getRequestsByRole(
//       String userRole, String userEmail) {
//     if (userRole == 'admin') {
//       return _requests;
//     } else if (userRole == 'manager') {
//       return _requests
//           .where((request) =>
//               request['createdBy'] == userEmail || request['role'] == 'user')
//           .toList();
//     } else if (userRole == 'user') {
//       return _requests
//           .where((request) => request['createdBy'] == userEmail)
//           .toList();
//     } else {
//       return [];
//     }
//   }
// }



// import 'dart:math';
// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   String generateUniqueCode() {
//     final random = Random();
//     return (100000 + random.nextInt(900000)).toString();
//   }

//    void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note, String? createdBy) {
//     String uniqueCode = generateUniqueCode();
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//       'createdBy': createdBy ?? 'Unknown', // Handle null case
//     });
//     notifyListeners();
//     // Notify user with the unique code via email/SMS
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     if (status == 'approved') {
//       setCodeValid(index, true);
//     }
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(int index, List<Map<String, dynamic>> items,
//       String location, String pickerName, String pickerContact, String note) {
//     if (_requests[index]['status'] == 'pending') {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   void setCodeValid(int index, bool isValid) {
//     _requests[index]['codeValid'] = isValid;
//     notifyListeners();
//   }

//   bool verifyCode(String code) {
//     try {
//       final request = _requests.firstWhere(
//           (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//       return request != null;
//     } catch (e) {
//       return false;
//     }
//   }

//   void fulfillRequestByCode(String code) {
//     final index = _requests.indexWhere(
//         (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//     if (index != -1) {
//       _requests[index]['status'] = 'fulfilled';
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }
// }


// import 'dart:math';
// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   String generateUniqueCode() {
//     final random = Random();
//     const digits = '0123456789';
//     return List.generate(6, (index) => digits[random.nextInt(digits.length)])
//         .join();
//   }

//   void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note) {
//     String uniqueCode = generateUniqueCode();
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//     });
//     notifyListeners();
//     // Notify user with the unique code via email/SMS
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     if (status == 'approved') {
//       setCodeValid(index, true); // Mark code as valid when approved
//     }
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(int index, List<Map<String, dynamic>> items,
//       String location, String pickerName, String pickerContact, String note) {
//     if (_requests[index]['status'] == 'pending') {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   void setCodeValid(int index, bool isValid) {
//     _requests[index]['codeValid'] = isValid;
//     notifyListeners();
//   }

//   bool verifyCode(String code) {
//     try {
//       final request = _requests.firstWhere(
//           (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//       return request != null;
//     } catch (e) {
//       return false;
//     }
//   }

//   void fulfillRequestByCode(String code) {
//     final index = _requests.indexWhere(
//         (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//     if (index != -1) {
//       _requests[index]['status'] = 'fulfilled';
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }
// }


// import 'dart:math';
// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   String generateUniqueCode() {
//     final random = Random();
//     return List.generate(6, (index) => random.nextInt(10).toString()).join();
//   }

//   void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note) {
//     String uniqueCode = generateUniqueCode();
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//       'uniqueCode': uniqueCode,
//       'codeValid': false,
//     });
//     notifyListeners();
//     // Notify user with the unique code via email/SMS
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     if (status == 'approved') {
//       setCodeValid(index, true); // Mark code as valid when approved
//     }
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(int index, List<Map<String, dynamic>> items,
//       String location, String pickerName, String pickerContact, String note) {
//     if (_requests[index]['status'] == 'pending') {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   void setCodeValid(int index, bool isValid) {
//     _requests[index]['codeValid'] = isValid;
//     notifyListeners();
//   }

//   bool verifyCode(String code) {
//     try {
//       final request = _requests.firstWhere(
//           (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//       return request != null;
//     } catch (e) {
//       return false;
//     }
//   }

//   void fulfillRequestByCode(String code) {
//     final index = _requests.indexWhere(
//         (req) => req['uniqueCode'] == code && req['codeValid'] == true);
//     if (index != -1) {
//       _requests[index]['status'] = 'fulfilled';
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }
// }


// import 'package:flutter/material.dart';

// class RequestProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _requests = [];

//   List<Map<String, dynamic>> get requests => _requests;

//   void addRequest(List<Map<String, dynamic>> items, String location,
//       String pickerName, String pickerContact, String note) {
//     _requests.add({
//       'items': items,
//       'status': 'pending',
//       'timestamp': DateTime.now(),
//       'location': location,
//       'pickerName': pickerName,
//       'pickerContact': pickerContact,
//       'note': note,
//     });
//     notifyListeners();
//   }

//   void updateRequestStatus(int index, String status) {
//     _requests[index]['status'] = status;
//     notifyListeners();
//   }

//   void cancelRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void updateRequest(int index, List<Map<String, dynamic>> items,
//       String location, String pickerName, String pickerContact, String note) {
//     if (_requests[index]['status'] == 'pending') {
//       _requests[index]['items'] = items;
//       _requests[index]['location'] = location;
//       _requests[index]['pickerName'] = pickerName;
//       _requests[index]['pickerContact'] = pickerContact;
//       _requests[index]['note'] = note;
//       notifyListeners();
//     }
//   }

//   List<Map<String, dynamic>> getPendingRequests() {
//     return _requests
//         .where((request) => request['status'] == 'pending')
//         .toList();
//   }

//   List<Map<String, dynamic>> getCompletedRequests() {
//     return _requests
//         .where((request) =>
//             request['status'] != 'pending' &&
//             DateTime.now().difference(request['timestamp']).inDays < 1)
//         .toList();
//   }
// }
