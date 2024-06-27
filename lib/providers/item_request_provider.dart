// import 'package:flutter/material.dart';
// import '../models/item_request.dart';

// class ItemRequestProvider with ChangeNotifier {
//   List<ItemRequest> _requests = [];

//   List<ItemRequest> get requests => _requests;

//   void fetchRequests() {
//     // Simulate fetching data from a database
//     _requests = [
//       ItemRequest(userName: 'User1', items: ['Item1', 'Item2']),
//       ItemRequest(userName: 'User2', items: ['Item3', 'Item4']),
//     ];
//     notifyListeners();
//   }

//   void approveRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }

//   void rejectRequest(int index) {
//     _requests.removeAt(index);
//     notifyListeners();
//   }
// }
