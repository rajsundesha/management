// import 'package:flutter/material.dart';
// import '../models/approved_request.dart';
// import 'dart:math';

// class ApprovedRequestProvider with ChangeNotifier {
//   List<ApprovedRequest> _approvedRequests = [];
//   final Map<String, String> _otpMap = {};

//   List<ApprovedRequest> get approvedRequests => _approvedRequests;

//   void fetchApprovedRequests() {
//     // Simulate fetching data from a database
//     _approvedRequests = [
//       ApprovedRequest(userName: 'User1', items: ['Item1', 'Item2']),
//       ApprovedRequest(userName: 'User2', items: ['Item3', 'Item4']),
//     ];
//     notifyListeners();
//   }

//   void distributeItems(int index) {
//     String userName = _approvedRequests[index].userName;
//     String otp = _generateOTP();
//     _otpMap[userName] = otp;
//     // Here, you would integrate with a service to send OTP to the user
//     print('Sending OTP $otp to $userName');
//     _approvedRequests.removeAt(index);
//     notifyListeners();
//   }

//   String _generateOTP() {
//     Random random = Random();
//     String otp = '';
//     for (int i = 0; i < 6; i++) {
//       otp += random.nextInt(10).toString();
//     }
//     return otp;
//   }

//   String? getOTPForUser(String userName) {
//     return _otpMap[userName];
//   }
// }

