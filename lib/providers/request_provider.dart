import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
// import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dhavla_road_project/providers/notification_provider.dart'
    as custom_notification;

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _requests = [];
  StreamSubscription<QuerySnapshot>? _requestSubscription;

  List<Map<String, dynamic>> get requests => _requests;

  RequestProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _listenToRequests(user.uid);
      } else {
        cancelListeners();
      }
    });
  }

  String generateUniqueCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString().padLeft(6, '0');
  }
  // String generateUniqueCode() {
  //   final random = Random();
  //   return (100000 + random.nextInt(900000)).toString();
  // }

  void _listenToRequests(String userId) {
    if (FirebaseAuth.instance.currentUser == null) {
      print("User is not authenticated. Cannot listen to requests.");
      return;
    }
    _requestSubscription =
        _firestore.collection('requests').snapshots().listen((snapshot) {
      _requests = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        if (data['timestamp'] != null) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
        } else {
          data['timestamp'] = DateTime.now(); // Use current time as fallback
        }
        return data;
      }).toList();
      print("Total requests fetched: ${_requests.length}");
      notifyListeners();
    }, onError: (error) {
      print("Error listening to requests: $error");
    });
  }

  // Add a BuildContext field
  BuildContext? _context;

  // Method to set the context
  void setContext(BuildContext context) {
    _context = context;
  }

  // Helper method to get the NotificationProvider
  custom_notification.NotificationProvider get _notificationProvider {
    if (_context == null) {
      throw Exception('Context not set in RequestProvider');
    }
    return Provider.of<custom_notification.NotificationProvider>(_context!,
        listen: false);
  }

  InventoryProvider get _inventoryProvider {
    if (_context == null) {
      throw Exception('Context not set in RequestProvider');
    }
    return Provider.of<InventoryProvider>(_context!, listen: false);
  }

  Future<void> addRequest(
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
    String createdByEmail,
    InventoryProvider inventoryProvider,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to create a request');
      }

      String? userRole = await getUserRole(user.uid);
      String uniqueCode = generateUniqueCode();

      Map<String, Map<String, dynamic>> combinedItems = {};
      for (var item in items) {
        String itemId = item['id'];
        if (combinedItems.containsKey(itemId)) {
          combinedItems[itemId]!['quantity'] =
              (combinedItems[itemId]!['quantity'] as int) +
                  (item['quantity'] as int);
        } else {
          combinedItems[itemId] = Map.from(item);
        }
      }

      List<Map<String, dynamic>> getTodayRequests() {
        final now = DateTime.now();
        return requests.where((request) {
          final requestDate = request['timestamp'] as DateTime;
          return requestDate.year == now.year &&
              requestDate.month == now.month &&
              requestDate.day == now.day;
        }).toList();
      }

      List<Map<String, dynamic>> getApprovedRequests(String searchQuery) {
        return requests.where((request) {
          return request['status'] == 'approved' &&
              (request['pickerName']
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  request['pickerContact'].toString().contains(searchQuery));
        }).toList();
      }

      List<Map<String, dynamic>> updatedItems = combinedItems.values.toList();

      await _firestore.runTransaction((transaction) async {
        // First, perform all reads
        List<DocumentSnapshot> inventorySnapshots = await Future.wait(
          updatedItems.map((item) => transaction
              .get(_firestore.collection('inventory').doc(item['id']))),
        );

        // Now, prepare the writes (but don't execute them yet)
        List<Map<String, dynamic>> itemUpdates = [];
        for (int i = 0; i < updatedItems.length; i++) {
          var item = updatedItems[i];
          var inventorySnapshot = inventorySnapshots[i];

          if (inventorySnapshot.exists) {
            int currentQuantity = inventorySnapshot.get('quantity') as int;
            int requestedQuantity = item['quantity'] as int;
            int fulfillableQuantity =
                math.min(currentQuantity, requestedQuantity);

            itemUpdates.add({
              'ref': _firestore.collection('inventory').doc(item['id']),
              'data': {'quantity': currentQuantity - fulfillableQuantity},
            });

            item['quantityFulfilled'] = fulfillableQuantity;
            item['quantityPending'] = requestedQuantity - fulfillableQuantity;
          } else {
            item['quantityFulfilled'] = 0;
            item['quantityPending'] = item['quantity'];
          }
        }

        // Prepare the request document
        DocumentReference requestRef = _firestore.collection('requests').doc();
        Map<String, dynamic> requestData = {
          'items': updatedItems,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
          'location': location,
          'pickerName': pickerName,
          'pickerContact': pickerContact,
          'note': note,
          'uniqueCode': uniqueCode,
          'codeValid': true,
          'createdBy': user.uid,
          'createdByEmail': createdByEmail,
          'createdByName': user.displayName ?? 'Unknown User',
        };

        // Now perform all writes
        for (var update in itemUpdates) {
          transaction.update(update['ref'], update['data']);
        }
        transaction.set(requestRef, requestData);
      });

      // Add notification for the user who created the request
      await _notificationProvider.addUserNotification(
        createdByEmail,
        'New Request Created',
        'Your request has been successfully created and is pending approval.',
      );

      // Add notification for managers
      List<String> managerIds = await _getManagerIds();
      for (String managerId in managerIds) {
        await _notificationProvider.addManagerNotification(
          managerId,
          'New Request Pending',
          'A new request has been created and is waiting for your approval.',
        );
      }

      notifyListeners();
      await inventoryProvider.fetchItems();
    } catch (e) {
      print("Error in addRequest: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  List<Map<String, dynamic>> getApprovedRequests(String searchQuery) {
    return _requests.where((request) {
      return request['status'] == 'approved' &&
          (request['pickerName']
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ||
              request['pickerContact'].toString().contains(searchQuery));
    }).toList();
  }

  List<Map<String, dynamic>> getTodayRequests() {
    final now = DateTime.now();
    return _requests.where((request) {
      final requestDate = request['timestamp'] as DateTime;
      return requestDate.year == now.year &&
          requestDate.month == now.month &&
          requestDate.day == now.day;
    }).toList();
  }

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] as String?;
      }
    } catch (e) {
      print("Error getting user role: $e");
    }
    return null;
  }

  Future<void> updateRequestStatus(String id, String status) async {
    try {
      await _firestore
          .collection('requests')
          .doc(id)
          .update({'status': status});
      // Add notification based on the new status
      final request = await _firestore.collection('requests').doc(id).get();
      final requestData = request.data() as Map<String, dynamic>;
      final userEmail = requestData['createdByEmail'];

      switch (status) {
        case 'approved':
          await _notificationProvider.addUserNotification(
            userEmail,
            'Request Approved',
            'Your request has been approved.',
          );
          break;
        case 'rejected':
          await _notificationProvider.addUserNotification(
            userEmail,
            'Request Rejected',
            'Your request has been rejected.',
          );
          break;
        case 'fulfilled':
          await _notificationProvider.addUserNotification(
            userEmail,
            'Request Fulfilled',
            'Your request has been fulfilled.',
          );
          break;
      }

      print("Request status updated successfully");
      notifyListeners();
    } catch (e) {
      print("Error updating request status: $e");
      rethrow;
    }
  }

// Implement the helper methods to get user IDs by role
  Future<List<String>> _getManagerIds() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Manager')
          .get();

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching manager IDs: $e");
      return [];
    }
  }

  Future<List<String>> _getAdminIds() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Admin')
          .get();

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching admin IDs: $e");
      return [];
    }
  }

  Future<void> deleteRequest(
      String requestId, InventoryProvider inventoryProvider) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot requestSnapshot = await transaction
            .get(_firestore.collection('requests').doc(requestId));

        if (!requestSnapshot.exists) {
          throw Exception('Request not found');
        }

        Map<String, dynamic> requestData =
            requestSnapshot.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(requestData['items']);

        // Restore inventory for fulfilled quantities
        for (var item in items) {
          if (item['quantityFulfilled'] > 0) {
            DocumentReference inventoryRef =
                _firestore.collection('inventory').doc(item['id']);
            transaction.update(inventoryRef, {
              'quantity': FieldValue.increment(item['quantityFulfilled']),
            });
          }
        }

        // Delete the request
        transaction.delete(_firestore.collection('requests').doc(requestId));
      });

      notifyListeners();
      await inventoryProvider.fetchItems(); // Refresh inventory after deletion
      print("Request deleted and inventory restored successfully");
    } catch (e) {
      print("Error deleting request and restoring inventory: $e");
      rethrow;
    }
  }

  Future<void> cancelRequest(
      String id, InventoryProvider inventoryProvider) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot requestSnapshot =
            await transaction.get(_firestore.collection('requests').doc(id));

        if (!requestSnapshot.exists) {
          throw Exception('Request not found');
        }

        Map<String, dynamic> requestData =
            requestSnapshot.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(requestData['items']);

        // Restore inventory for fulfilled quantities
        for (var item in items) {
          if (item['quantityFulfilled'] > 0) {
            DocumentReference inventoryRef =
                _firestore.collection('inventory').doc(item['id']);
            DocumentSnapshot inventorySnapshot =
                await transaction.get(inventoryRef);

            if (inventorySnapshot.exists) {
              int currentQuantity = inventorySnapshot.get('quantity') as int;
              transaction.update(inventoryRef, {
                'quantity': currentQuantity + item['quantityFulfilled'],
              });
            }
          }
        }

        // Delete the request
        transaction.delete(_firestore.collection('requests').doc(id));
      });

      await inventoryProvider
          .fetchItems(); // Refresh inventory after cancellation
      notifyListeners(); // Notify listeners after successful cancellation
    } catch (e) {
      print("Error cancelling request and restoring inventory: $e");
      rethrow;
    }
  }

  Future<void> addStockRequest({
    required List<Map<String, dynamic>> items,
    required String note,
    required String createdBy,
  }) async {
    try {
      // Ensure each item has an ID
      for (var item in items) {
        if (!item.containsKey('id') ||
            item['id'] == null ||
            item['id'].isEmpty) {
          throw Exception('Item ${item['name']} is missing an ID');
        }
      }

      await _firestore.collection('stock_requests').add({
        'items': items,
        'note': note,
        'createdBy': createdBy,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': null,
        'approvedAt': null,
        'fulfilledBy': null,
        'fulfilledAt': null,
        'rejectedBy': null,
        'rejectedAt': null,
        'rejectionReason': null,
      });

      // Add notification for the user who created the stock request
      await _notificationProvider.addUserNotification(
        createdBy,
        'Stock Request Created',
        'Your stock request has been successfully created and is pending approval.',
      );

      // Add notification for admins
      List<String> adminIds = await _getAdminIds();
      for (String adminId in adminIds) {
        await _notificationProvider.addAdminNotification(
          adminId,
          'New Stock Request',
          'A new stock request has been created and is waiting for your approval.',
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error adding stock request: $e');
      throw e;
    }
  }

  // Future<void> addStockRequest({
  //   required List<Map<String, dynamic>> items,
  //   required String note,
  //   required String createdBy,
  // }) async {
  //   try {
  //     // Ensure each item has an ID
  //     for (var item in items) {
  //       if (!item.containsKey('id') ||
  //           item['id'] == null ||
  //           item['id'].isEmpty) {
  //         throw Exception('Item ${item['name']} is missing an ID');
  //       }
  //     }

  //     await FirebaseFirestore.instance.collection('stock_requests').add({
  //       'items': items,
  //       'note': note,
  //       'createdBy': createdBy,
  //       'status': 'pending',
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'updatedAt': FieldValue.serverTimestamp(),
  //       'approvedBy': null,
  //       'approvedAt': null,
  //       'fulfilledBy': null,
  //       'fulfilledAt': null,
  //       'rejectedBy': null,
  //       'rejectedAt': null,
  //       'rejectionReason': null,
  //     });

  //     // Add notification for the user who created the stock request
  //     final notificationProvider =
  //         Provider.of<custom_notification.NotificationProvider>(context,
  //             listen: false);
  //     await notificationProvider.addUserNotification(
  //       createdBy,
  //       'Stock Request Created',
  //       'Your stock request has been successfully created and is pending approval.',
  //     );

  //     // Add notification for admins
  //     List<String> adminIds = await _getAdminIds();
  //     for (String adminId in adminIds) {
  //       await notificationProvider.addAdminNotification(
  //         adminId,
  //         'New Stock Request',
  //         'A new stock request has been created and is waiting for your approval.',
  //       );
  //     }
  //     notifyListeners();
  //   } catch (e) {
  //     print('Error adding stock request: $e');
  //     throw e;
  //   }
  // }

  Stream<List<Map<String, dynamic>>> getStockRequestsStream() {
    return FirebaseFirestore.instance
        .collection('stock_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print("Fetched ${snapshot.docs.length} stock requests");
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<Map<String, dynamic>> getStockRequestReport() async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('stock_requests').get();

    final List<Map<String, dynamic>> requests =
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    int totalRequests = requests.length;
    int pendingRequests =
        requests.where((req) => req['status'] == 'pending').length;
    int approvedRequests =
        requests.where((req) => req['status'] == 'approved').length;
    int fulfilledRequests =
        requests.where((req) => req['status'] == 'fulfilled').length;
    int rejectedRequests =
        requests.where((req) => req['status'] == 'rejected').length;

    return {
      'totalRequests': totalRequests,
      'pendingRequests': pendingRequests,
      'approvedRequests': approvedRequests,
      'fulfilledRequests': fulfilledRequests,
      'rejectedRequests': rejectedRequests,
    };
  }

  Future<List<Map<String, dynamic>>> getDetailedStockRequestReport(
      DateTimeRange? dateRange) async {
    Query query = FirebaseFirestore.instance.collection('stock_requests');

    if (dateRange != null) {
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt',
              isLessThanOrEqualTo: dateRange.end.add(Duration(days: 1)));
    }

    final QuerySnapshot snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'createdBy': data['createdBy'] ?? 'Unknown',
        'status': data['status'] ?? 'Unknown',
        'createdAt':
            (data['createdAt'] as Timestamp?)?.toDate().toString() ?? 'Unknown',
        'items': (data['items'] as List<dynamic>?)
                ?.map((item) => '${item['quantity']} x ${item['name']}')
                .join(', ') ??
            'No items',
        'note': data['note'] ?? 'No note',
        'approvedBy': data['approvedBy'] ?? 'N/A',
        'approvedAt':
            (data['approvedAt'] as Timestamp?)?.toDate().toString() ?? 'N/A',
        'fulfilledBy': data['fulfilledBy'] ?? 'N/A',
        'fulfilledAt':
            (data['fulfilledAt'] as Timestamp?)?.toDate().toString() ?? 'N/A',
        'rejectedBy': data['rejectedBy'] ?? 'N/A',
        'rejectedAt':
            (data['rejectedAt'] as Timestamp?)?.toDate().toString() ?? 'N/A',
        'rejectionReason': data['rejectionReason'] ?? 'N/A',
      };
    }).toList();
  }

  // Future<void> updateStockRequestStatus(
  //     String id, String status, String adminEmail,
  //     {String? rejectionReason}) async {
  //   try {
  //     final updateData = <String, dynamic>{
  //       'status': status,
  //       'updatedAt': FieldValue.serverTimestamp(),
  //     };

  //     switch (status) {
  //       case 'approved':
  //         updateData['approvedBy'] = adminEmail;
  //         updateData['approvedAt'] = FieldValue.serverTimestamp();
  //         break;
  //       case 'fulfilled':
  //         updateData['fulfilledBy'] = adminEmail;
  //         updateData['fulfilledAt'] = FieldValue.serverTimestamp();
  //         break;
  //       case 'rejected':
  //         updateData['rejectedBy'] = adminEmail;
  //         updateData['rejectedAt'] = FieldValue.serverTimestamp();
  //         if (rejectionReason != null) {
  //           updateData['rejectionReason'] = rejectionReason;
  //         }
  //         break;
  //     }

  //     await FirebaseFirestore.instance
  //         .collection('stock_requests')
  //         .doc(id)
  //         .update(updateData);

  //     // Add notification based on the new status
  //     final notificationProvider =
  //         Provider.of<custom_notification.NotificationProvider>(context,
  //             listen: false);
  //     final stockRequest =
  //         await _firestore.collection('stock_requests').doc(id).get();
  //     final stockRequestData = stockRequest.data() as Map<String, dynamic>;
  //     final createdBy = stockRequestData['createdBy'];

  //     switch (status) {
  //       case 'approved':
  //         await notificationProvider.addUserNotification(
  //           createdBy,
  //           'Stock Request Approved',
  //           'Your stock request has been approved.',
  //         );
  //         break;
  //       case 'rejected':
  //         await notificationProvider.addUserNotification(
  //           createdBy,
  //           'Stock Request Rejected',
  //           'Your stock request has been rejected. Reason: ${rejectionReason ?? "Not provided"}',
  //         );
  //         break;
  //       case 'fulfilled':
  //         await notificationProvider.addUserNotification(
  //           createdBy,
  //           'Stock Request Fulfilled',
  //           'Your stock request has been fulfilled.',
  //         );
  //         break;
  //     }

  //     notifyListeners();
  //   } catch (e) {
  //     print('Error updating stock request status: $e');
  //     throw e;
  //   }
  // }
  Future<void> updateStockRequestStatus(
      String id, String status, String adminEmail,
      {String? rejectionReason}) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (status) {
        case 'approved':
          updateData['approvedBy'] = adminEmail;
          updateData['approvedAt'] = FieldValue.serverTimestamp();
          break;
        case 'fulfilled':
          updateData['fulfilledBy'] = adminEmail;
          updateData['fulfilledAt'] = FieldValue.serverTimestamp();
          break;
        case 'rejected':
          updateData['rejectedBy'] = adminEmail;
          updateData['rejectedAt'] = FieldValue.serverTimestamp();
          if (rejectionReason != null) {
            updateData['rejectionReason'] = rejectionReason;
          }
          break;
      }

      await _firestore.collection('stock_requests').doc(id).update(updateData);

      // Add notification based on the new status
      final stockRequest =
          await _firestore.collection('stock_requests').doc(id).get();
      final stockRequestData = stockRequest.data() as Map<String, dynamic>;
      final createdBy = stockRequestData['createdBy'];

      switch (status) {
        case 'approved':
          await _notificationProvider.addUserNotification(
            createdBy,
            'Stock Request Approved',
            'Your stock request has been approved.',
          );
          break;
        case 'rejected':
          await _notificationProvider.addUserNotification(
            createdBy,
            'Stock Request Rejected',
            'Your stock request has been rejected. Reason: ${rejectionReason ?? "Not provided"}',
          );
          break;
        case 'fulfilled':
          await _notificationProvider.addUserNotification(
            createdBy,
            'Stock Request Fulfilled',
            'Your stock request has been fulfilled.',
          );
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Error updating stock request status: $e');
      throw e;
    }
  }

  Future<void> updateRequest(
    String requestId,
    List<Map<String, dynamic>> newItems,
    String location,
    String pickerName,
    String pickerContact,
    String note,
    String userEmail,
    InventoryProvider inventoryProvider,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        print("Starting transaction for request: $requestId");
        DocumentSnapshot requestSnapshot = await transaction
            .get(_firestore.collection('requests').doc(requestId));

        if (!requestSnapshot.exists) {
          throw Exception('Request not found');
        }

        Map<String, dynamic> requestData =
            requestSnapshot.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> oldItems =
            List<Map<String, dynamic>>.from(requestData['items']);

        print("Old items: $oldItems");

        List<DocumentSnapshot> inventorySnapshots = await Future.wait(
          newItems.map((item) => transaction
              .get(_firestore.collection('inventory').doc(item['id']))),
        );

        List<Map<String, dynamic>> updatedItems = [];
        List<Map<String, dynamic>> inventoryUpdates = [];

        for (var oldItem in oldItems) {
          int quantityFulfilled = oldItem['quantityFulfilled'] ?? 0;
          if (quantityFulfilled > 0) {
            inventoryUpdates.add({
              'id': oldItem['id'],
              'quantity': FieldValue.increment(quantityFulfilled),
            });
          }
        }

        for (int i = 0; i < newItems.length; i++) {
          var newItem = newItems[i];
          var inventorySnapshot = inventorySnapshots[i];

          print("Processing item: ${newItem['name']}, ID: ${newItem['id']}");

          if (inventorySnapshot.exists) {
            var rawQuantity = inventorySnapshot.get('quantity');
            print("Raw inventory quantity: $rawQuantity");
            int currentQuantity = (rawQuantity as num?)?.toInt() ?? 0;

            var rawRequestedQuantity = newItem['quantity'];
            print("Raw requested quantity: $rawRequestedQuantity");
            int requestedQuantity =
                (rawRequestedQuantity as num?)?.toInt() ?? 0;

            print(
                "Current quantity: $currentQuantity, Requested quantity: $requestedQuantity");

            int fulfillableQuantity;
            try {
              fulfillableQuantity =
                  math.min(currentQuantity, requestedQuantity);
            } catch (e) {
              print("Error in math.min: $e");
              fulfillableQuantity = 0; // Set a default value
            }
            print("Fulfillable quantity: $fulfillableQuantity");

            updatedItems.add({
              ...newItem,
              'quantityFulfilled': fulfillableQuantity,
              'quantityPending':
                  math.max(0, requestedQuantity - fulfillableQuantity),
            });

            inventoryUpdates.add({
              'id': newItem['id'],
              'quantity': math.max(0, currentQuantity - fulfillableQuantity),
            });
          } else {
            print("Inventory item not found: ${newItem['id']}");
            updatedItems.add({
              ...newItem,
              'quantityFulfilled': 0,
              'quantityPending': newItem['quantity'] ?? 0,
            });
          }
        }

        print("Updated items: $updatedItems");
        print("Inventory updates: $inventoryUpdates");

        transaction.update(_firestore.collection('requests').doc(requestId), {
          'items': updatedItems,
          'location': location,
          'pickerName': pickerName,
          'pickerContact': pickerContact,
          'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (var update in inventoryUpdates) {
          transaction.update(
            _firestore.collection('inventory').doc(update['id']),
            {'quantity': update['quantity']},
          );
        }
      });

      notifyListeners();
      await inventoryProvider.fetchItems();
      print("Request updated and inventory adjusted successfully");
    } catch (e) {
      print("Error updating request and adjusting inventory: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  void setCodeValid(String id, bool isValid) {
    try {
      _firestore.collection('requests').doc(id).update({'codeValid': isValid});
      print("Code validity updated successfully");
    } catch (e) {
      print("Error setting code validity: $e");
    }
  }

  bool verifyCode(String code) {
    return _requests
        .any((req) => req['uniqueCode'] == code && req['codeValid'] == true);
  }

  Future<bool> checkCodeValidity(String code) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('requests')
          .where('uniqueCode', isEqualTo: code)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking code validity: $e");
      return false;
    }
  }

  Future<void> fulfillRequestByCode(String code) async {
    try {
      print("Attempting to fulfill request with code: $code");

      QuerySnapshot querySnapshot = await _firestore
          .collection('requests')
          .where('uniqueCode', isEqualTo: code)
          .get();

      print(
          "Found ${querySnapshot.docs.length} matching requests for code: $code");

      if (querySnapshot.docs.isEmpty) {
        throw CustomException('No request found for this code');
      }

      DocumentSnapshot requestDoc = querySnapshot.docs.first;
      Map<String, dynamic> requestData =
          requestDoc.data() as Map<String, dynamic>;

      print("Request data for code $code: $requestData");

      if (requestData['status'] == 'fulfilled') {
        throw CustomException('This request has already been fulfilled');
      }

      if (requestData['status'] != 'approved') {
        throw CustomException('This request is not in approved status');
      }

      String requestId = requestDoc.id;

      print("Updating request $requestId to fulfilled status");

      await _firestore.collection('requests').doc(requestId).update({
        'status': 'fulfilled',
        'codeValid': false,
        'fulfillmentTimestamp': FieldValue.serverTimestamp(),
      });

      print("Request fulfilled successfully: $requestId");

      // Add notification for the user
      final request = await _firestore
          .collection('requests')
          .where('uniqueCode', isEqualTo: code)
          .get();
      if (request.docs.isNotEmpty) {
        final requestData = request.docs.first.data();
        final userEmail = requestData['createdByEmail'];
        await _notificationProvider.addUserNotification(
          userEmail,
          'Request Fulfilled',
          'Your request has been fulfilled.',
        );
      }
      notifyListeners();
    } catch (e) {
      print("Error fulfilling request by code: $e");
      rethrow;
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
            request['status'] == 'fulfilled' &&
            DateTime.now().difference(request['timestamp']).inDays < 1)
        .toList();
  }

  Stream<List<Map<String, dynamic>>> getRequestsStream(
      String userEmail, String userRole, String status) {
    print("Fetching $status requests for user: $userEmail, role: $userRole");
    Query query = _firestore.collection('requests');

    // Only apply status filter if status is not 'All'
    if (status.toLowerCase() != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    if (userRole == 'Manager' || userRole == 'Admin') {
      // Managers and Admins can see all requests
      query = query.orderBy('timestamp', descending: true);
    } else {
      // Regular users can only see their own requests
      query = query
          .where('createdByEmail', isEqualTo: userEmail)
          .orderBy('timestamp', descending: true);
    }

    return query.snapshots().asyncMap(_convertQuerySnapshotToList);
  }

  Future<List<Map<String, dynamic>>> _convertQuerySnapshotToList(
      QuerySnapshot snapshot) async {
    List<Map<String, dynamic>> requests = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      if (data['timestamp'] is Timestamp) {
        data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
      }

      // Fetch user data if not already in the request
      if (data['createdByName'] == null && data['createdBy'] != null) {
        try {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(data['createdBy']).get();
          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            data['createdByName'] = userData['name'] ?? 'Unknown User';
          }
        } catch (e) {
          print("Error fetching user data: $e");
          data['createdByName'] = 'Unknown User';
        }
      }

      print("Request data: $data"); // Debug print
      requests.add(data);
    }
    print("Fetched ${requests.length} requests from Firestore");
    return requests;
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
          .where((request) =>
              request['createdBy'] == userEmail &&
              request['status'] == 'pending')
          .toList();
    } else {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getUserPendingRequestsStream(
      String userEmail,
      [String? userRole]) {
    print("Fetching pending requests for user: $userEmail, role: $userRole");
    Query query =
        _firestore.collection('requests').where('status', isEqualTo: 'pending');

    if (userRole == 'Manager' || userRole == 'Admin') {
      // Managers and Admins can see all pending requests
      query = query.orderBy('timestamp', descending: true);
    } else {
      // Regular users can only see their own pending requests
      query = query
          .where('createdByEmail', isEqualTo: userEmail)
          .orderBy('timestamp', descending: true);
    }

    return query.snapshots().asyncMap(_convertQuerySnapshotToList);
  }

  Map<String, dynamic>? getRequestById(String id) {
    return _requests.firstWhere((request) => request['id'] == id,
        orElse: () => <String, dynamic>{});
  }

  Future<void> cancelListeners() async {
    await _requestSubscription?.cancel();
  }

  Future<void> fulfillStockRequest(
    String requestId,
    List<Map<String, dynamic>> receivedItems,
  ) async {
    try {
      bool isFullyFulfilled = true;

      await _firestore.runTransaction((transaction) async {
        print("Starting transaction for request: $requestId");

        DocumentSnapshot requestDoc = await transaction
            .get(_firestore.collection('stock_requests').doc(requestId));

        if (!requestDoc.exists) {
          throw Exception('Stock request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;
        List<dynamic> requestItems = requestData['items'] ?? [];

        print("Original request items: $requestItems");
        print("Received items: $receivedItems");

        List<Map<String, dynamic>> updatedItems = [];

        for (var originalItem in requestItems) {
          var receivedItem = receivedItems.firstWhere(
            (item) => item['name'] == originalItem['name'],
            orElse: () => <String, dynamic>{},
          );

          int requestedQuantity = originalItem['quantity'] ?? 0;
          int previouslyReceived = originalItem['receivedQuantity'] ?? 0;
          int newlyReceived = receivedItem['receivedQuantity'] ?? 0;
          int totalReceived = previouslyReceived + newlyReceived;
          int remainingQuantity = requestedQuantity - totalReceived;

          String? itemId = originalItem['id'] as String?;
          if (itemId == null || itemId.isEmpty) {
            print("Warning: Item ${originalItem['name']} is missing an ID");
            itemId = await _findItemIdByName(originalItem['name']);
          }

          if (itemId != null && itemId.isNotEmpty && newlyReceived > 0) {
            try {
              // Update inventory quantity
              await _inventoryProvider.updateInventoryQuantity(
                  itemId, newlyReceived);
              print(
                  "Updated inventory for item $itemId: quantity increased by $newlyReceived");
            } catch (e) {
              print("Error updating inventory for item $itemId: $e");
              throw e; // Rethrow the error to rollback the transaction
            }
          } else if (newlyReceived > 0) {
            print(
                "Skipping inventory update for item without valid ID: ${originalItem['name']}");
          }

          updatedItems.add({
            ...originalItem,
            'id': itemId,
            'receivedQuantity': totalReceived,
            'remainingQuantity': remainingQuantity,
          });

          if (remainingQuantity > 0) {
            isFullyFulfilled = false;
          }
        }

        String newStatus =
            isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';
        transaction
            .update(_firestore.collection('stock_requests').doc(requestId), {
          'items': updatedItems,
          'status': newStatus,
          'lastUpdated': FieldValue.serverTimestamp(),
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        });

        print("Transaction completed. New status: $newStatus");
      }, timeout: Duration(seconds: 30));

      // Add notification for the user
      final stockRequest =
          await _firestore.collection('stock_requests').doc(requestId).get();
      final stockRequestData = stockRequest.data() as Map<String, dynamic>;
      final createdBy = stockRequestData['createdBy'];

      if (isFullyFulfilled) {
        await _notificationProvider.addUserNotification(
          createdBy,
          'Stock Request Fully Fulfilled',
          'Your stock request has been fully fulfilled.',
        );
      } else {
        await _notificationProvider.addUserNotification(
          createdBy,
          'Stock Request Partially Fulfilled',
          'Your stock request has been partially fulfilled.',
        );
      }

      notifyListeners();
    } catch (e) {
      print("Error fulfilling stock request: $e");
      rethrow;
    }
  }

  Future<String?> _findItemIdByName(String name) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('inventory')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
    } catch (e) {
      print("Error finding item ID by name: $e");
    }
    return null;
  }

  Stream<List<Map<String, dynamic>>> getActiveStockRequestsStream() {
    print("Starting getActiveStockRequestsStream");
    return _firestore
        .collection('stock_requests')
        .where('status', whereIn: ['approved', 'partially_fulfilled'])
        // Temporarily remove the expiration date filter
        // .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
          print("Snapshot received. Document count: ${snapshot.docs.length}");
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            print("Stock request: ${doc.id} - ${data['status']}");
            return data;
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getApprovedStockRequestsStream() {
    return _firestore
        .collection('stock_requests')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }
}

class CustomException implements Exception {
  final String message;
  CustomException(this.message);
  @override
  String toString() => message;
}
