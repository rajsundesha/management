import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/common/listener_manager.dart'; // Import the ListenerManager class
import 'package:flutter/foundation.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationProvider _notificationProvider;
  final InventoryProvider _inventoryProvider;
  final ListenerManager _listenerManager =
      ListenerManager(); // Add ListenerManager
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _fulfilledRequests = []; // Add this line
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _requestSubscription;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> get requests => _requests;
  List<Map<String, dynamic>> get fulfilledRequests => _fulfilledRequests;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore; // Add this getter
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  Timer? _periodicCheckTimer;

  RequestProvider(this._notificationProvider, this._inventoryProvider) {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _listenToRequests(user.uid);
        startAutoRefresh();
      } else {
        cancelListeners();
        stopAutoRefresh();
      }
    });
    // Set up periodic check every 5 minutes
    _periodicCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      checkAndUpdatePartiallyFulfilledRequests();
    });
  }

  void startAutoRefresh() {
    // Refresh immediately when starting
    refreshFulfilledRequests();

    // Set up a timer to refresh every 5 minutes (adjust as needed)
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (_) {
      refreshFulfilledRequests();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  String generateUniqueCode() {
    final random = math.Random();
    return (100000 + random.nextInt(900000)).toString().padLeft(6, '0');
  }

  Future<void> refreshRequests(String userEmail, String userRole) async {
    _isLoading = true;
    _hasMore = true;
    _lastDocument = null;
    _requests.clear();
    notifyListeners();

    try {
      await _loadMoreRequests(userEmail, userRole);
    } catch (e) {
      print("Error refreshing requests: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getRecentRequests() async {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));
    QuerySnapshot snapshot = await _firestore
        .collection('requests')
        .where('timestamp', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getRecentApprovedRequestsStream() {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));

    return _firestore
        .collection('requests')
        .where('status', whereIn: ['approved', 'fulfilled'])
        .where('approvedAt', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('approvedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            if (data['approvedAt'] is Timestamp) {
              data['approvedAt'] = (data['approvedAt'] as Timestamp).toDate();
            }
            if (data['fulfilledAt'] is Timestamp) {
              data['fulfilledAt'] = (data['fulfilledAt'] as Timestamp).toDate();
            }
            return data;
          }).toList();
        });
  }

  Future<List<String>> getUniqueCreators() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('requests').get();
      Set<String> uniqueCreators = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String creator =
            data['createdByName'] ?? data['createdByEmail'] ?? 'Unknown';
        uniqueCreators.add(creator);
      }

      return uniqueCreators.toList()..sort();
    } catch (e) {
      print("Error fetching unique creators: $e");
      return [];
    }
  }

  Future<void> updateRequestItems(
      String requestId, List<Map<String, dynamic>> updatedItems) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'items': updatedItems,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print("Items updated for request $requestId");
      notifyListeners();
    } catch (e) {
      print("Error updating request items: $e");
      throw Exception('Failed to update request items: $e');
    }
  }

  /// Updates the fulfillment status of a request in Firestore.
  ///
  /// [requestId]: The ID of the request document in Firestore.
  /// [confirmedItems]: A list of maps containing 'id' and 'receivedQuantity' for each confirmed item.
  /// [gateManId]: The ID of the gate man fulfilling the request.
  Future<void> updateRequestFulfillment(String requestId,
      List<Map<String, dynamic>> confirmedItems, String gateManId) async {
    try {
      print('Starting transaction for requestId: $requestId');

      await _firestore.runTransaction((transaction) async {
        DocumentReference requestRef =
            _firestore.collection('requests').doc(requestId);
        DocumentSnapshot requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          print('Request not found: $requestId');
          throw Exception('Request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;

        // Validate that 'items' exists and is a list
        if (!requestData.containsKey('items') ||
            requestData['items'] is! List<dynamic>) {
          print('Invalid or missing "items" field in request.');
          throw Exception('Invalid or missing "items" field in request.');
        }

        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(requestData['items']);

        const double epsilon =
            1e-6; // To handle floating-point precision issues
        bool isFullyFulfilled = true;

        // Iterate over confirmed items to update quantities
        for (var confirmedItem in confirmedItems) {
          String itemId = confirmedItem['id'];
          double receivedQty =
              (confirmedItem['receivedQuantity'] as num?)?.toDouble() ?? 0.0;

          // Find item index by 'id'
          int index = items.indexWhere((item) => item['id'] == itemId);
          if (index == -1) {
            print('Item with id $itemId not found in request items. Skipping.');
            continue; // Skip to next confirmedItem
          }

          double existingReceivedQty =
              (items[index]['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
          double totalReceivedQty = existingReceivedQty + receivedQty;

          double totalQuantity =
              (items[index]['quantity'] as num?)?.toDouble() ?? 0.0;
          double remainingQty = totalQuantity - totalReceivedQty;

          // Handle floating-point precision
          remainingQty = remainingQty.abs() < epsilon ? 0.0 : remainingQty;

          // Prevent over-fulfillment
          if (remainingQty < 0) {
            print(
                'Received quantity for item ID $itemId exceeds total quantity. Capping to total quantity.');
            totalReceivedQty = totalQuantity;
            remainingQty = 0.0;
          }

          // Update quantities
          items[index]['receivedQuantity'] = totalReceivedQty;
          items[index]['remainingQuantity'] = remainingQty;

          print(
              'Item ID: $itemId - Received: $totalReceivedQty, Remaining: $remainingQty');

          if (remainingQty > epsilon) {
            isFullyFulfilled = false;
          }
        }

        // Recalculate if the entire request is fully fulfilled
        isFullyFulfilled = items.every((item) {
          double remainingQty =
              (item['remainingQuantity'] as num?)?.toDouble() ?? 0.0;
          return remainingQty <= epsilon;
        });

        String newStatus =
            isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';

        print('Determined new status: $newStatus');

        // Prepare data to update
        Map<String, dynamic> updateData = {
          'items': items,
          'status': newStatus,
          'fulfilledBy': gateManId,
        };

        if (isFullyFulfilled) {
          updateData['fulfilledAt'] = FieldValue.serverTimestamp();
        } else {
          // Optionally, reset 'fulfilledAt' if not fully fulfilled
          updateData['fulfilledAt'] = null;
        }

        print('Fields being updated: ${updateData.keys.toList()}');

        // Update Firestore document
        transaction.update(requestRef, updateData);
      });

      print('Transaction successfully completed for requestId: $requestId');
      notifyListeners();
    } catch (e) {
      print('Error updating request fulfillment: $e');
      rethrow;
    }
  }

  Future<void> loadMoreRequests(String userEmail, String userRole) async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      await _loadMoreRequests(userEmail, userRole);
    } catch (e) {
      print("Error loading more requests: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMoreRequests(String userEmail, String userRole) async {
    Query query = _firestore
        .collection('requests')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (userRole != 'Admin' && userRole != 'Manager') {
      query = query.where('createdByEmail', isEqualTo: userEmail);
    }

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final QuerySnapshot snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      _hasMore = false;
      return;
    }

    _lastDocument = snapshot.docs.last;

    final newRequests = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      if (data['timestamp'] is Timestamp) {
        data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
      }
      return data;
    }).toList();

    _requests.addAll(newRequests);
    _hasMore = newRequests.length == _pageSize;
  }

  List<Map<String, dynamic>> getFilteredRequests({
    required String searchQuery,
    required String status,
    required String location,
    DateTimeRange? dateRange,
  }) {
    return _requests.where((request) {
      final matchesSearch = request['createdByName']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      final matchesStatus =
          status == 'All' || request['status'] == status.toLowerCase();
      final matchesLocation =
          location == 'All' || request['location'] == location;
      final matchesDate = dateRange == null ||
          (request['timestamp'].isAfter(dateRange.start) &&
              request['timestamp']
                  .isBefore(dateRange.end.add(Duration(days: 1))));

      return matchesSearch && matchesStatus && matchesLocation && matchesDate;
    }).toList();
  }

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
        data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
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

  // Future<void> updateRequestStatus(String id, String status) async {
  //   try {
  //     String? userId;
  //     String? userRole;

  //     await _firestore.runTransaction((transaction) async {
  //       print("Starting transaction for request: $id");
  //       DocumentSnapshot requestDoc =
  //           await transaction.get(_firestore.collection('requests').doc(id));

  //       if (!requestDoc.exists) {
  //         throw Exception('Request not found');
  //       }

  //       Map<String, dynamic> requestData =
  //           requestDoc.data() as Map<String, dynamic>;
  //       userId = requestData['createdBy'] as String?;
  //       final String currentStatus = requestData['status'] as String;
  //       print("Current status: $currentStatus, New status: $status");

  //       if (userId != null) {
  //         userRole = await getUserRole(userId!);
  //       } else {
  //         print("Warning: userId is null in the request data");
  //         userRole = 'Unknown';
  //       }

  //       List<Map<String, dynamic>> items =
  //           List<Map<String, dynamic>>.from(requestData['items']);

  //       if (status == 'rejected' && currentStatus != 'rejected') {
  //         print("Handling rejection...");
  //         for (var item in items) {
  //           await _adjustInventory(transaction, item, true);
  //           _resetItemFulfillment(item);
  //           if (!item.containsKey('originalRequestedQuantity')) {
  //             item['originalRequestedQuantity'] =
  //                 item['isPipe'] == true ? item['meters'] : item['quantity'];
  //           }
  //           print(
  //               "Item ${item['id']} original quantity: ${item['originalRequestedQuantity']}");
  //         }
  //       } else if (status == 'approved') {
  //         print("Handling approval...");
  //         for (var item in items) {
  //           num originalQuantity = item['originalRequestedQuantity'] ??
  //               (item['isPipe'] == true ? item['meters'] : item['quantity']);
  //           print("Item ${item['id']} original quantity: $originalQuantity");
  //           if (currentStatus == 'rejected' || currentStatus == 'pending') {
  //             print("Deducting from inventory for item ${item['id']}");
  //             await _adjustInventory(
  //                 transaction, item, false, originalQuantity);
  //           } else {
  //             print(
  //                 "Unexpected current status: $currentStatus. Not adjusting inventory.");
  //           }
  //           _resetItemFulfillment(item);
  //         }
  //       } else if (status == 'fulfilled' || status == 'partially_fulfilled') {
  //         print("Handling fulfillment...");
  //         bool allItemsFulfilled = _checkAllItemsFulfilled(items);
  //         status = allItemsFulfilled ? 'fulfilled' : 'partially_fulfilled';
  //       }

  //       print("Updating request status to: $status");
  //       transaction.update(_firestore.collection('requests').doc(id), {
  //         'status': status,
  //         'lastUpdated': FieldValue.serverTimestamp(),
  //         'items': items,
  //       });
  //     });

  //     if (userId != null) {
  //       await _sendStatusUpdateNotifications(
  //           id, status, userId!, userRole ?? 'Unknown');
  //     } else {
  //       print("Warning: userId is null, notifications not sent");
  //     }

  //     print("Request status updated successfully to: $status");
  //     notifyListeners();
  //   } catch (e) {
  //     print("Error updating request status: $e");
  //     print("Stack trace: ${StackTrace.current}");
  //     rethrow;
  //   }
  // }

  Future<void> updateRequestStatus(String id, String status) async {
    try {
      String? userId;
      String? userRole;

      await _firestore.runTransaction((transaction) async {
        print("Starting transaction for request: $id");
        DocumentSnapshot requestDoc =
            await transaction.get(_firestore.collection('requests').doc(id));

        if (!requestDoc.exists) {
          throw CustomException('Request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;
        userId = requestData['createdBy'] as String?;
        final String currentStatus = requestData['status'] as String;
        print("Current status: $currentStatus, New status: $status");

        if (userId != null) {
          userRole = await getUserRole(userId!);
        } else {
          print("Warning: userId is null in the request data");
          userRole = 'Unknown';
        }

        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(requestData['items']);

        if (status == 'rejected' && currentStatus != 'rejected') {
          await _handleRejection(transaction, items);
        } else if (status == 'approved') {
          await _handleApproval(transaction, items, currentStatus);
        } else if (status == 'fulfilled' || status == 'partially_fulfilled') {
          status = await _handleFulfillment(items);
        }

        print("Updating request status to: $status");
        transaction.update(_firestore.collection('requests').doc(id), {
          'status': status,
          'lastUpdated': FieldValue.serverTimestamp(),
          'items': items,
        });
      });

      if (userId != null) {
        await _sendStatusUpdateNotifications(
            id, status, userId!, userRole ?? 'Unknown');
      } else {
        print("Warning: userId is null, notifications not sent");
      }

      print("Request status updated successfully to: $status");
      notifyListeners();
    } catch (e, stackTrace) {
      print("Error updating request status: $e");
      print("Stack trace: $stackTrace");
      if (e is CustomException) {
        rethrow;
      } else {
        throw CustomException(
            'An error occurred while updating the request status. Please try again. Error: $e');
      }
    }
  }

  Future<void> _handleRejection(
      Transaction transaction, List<Map<String, dynamic>> items) async {
    print("Handling rejection...");
    for (var item in items) {
      try {
        await _adjustInventory(transaction, item, true);
        _resetItemFulfillment(item);

        if (!item.containsKey('originalRequestedQuantity')) {
          item['originalRequestedQuantity'] = _getQuantity(item);
        }

        item['currentInventoryImpact'] = 0.0;
      } catch (e) {
        print("Error handling rejection for item ${item['id']}: $e");
        throw CustomException(
            'Error processing item ${item['name']}. Please try again.');
      }
    }
  }

  Future<void> _handleApproval(Transaction transaction,
      List<Map<String, dynamic>> items, String currentStatus) async {
    print("Handling approval...");
    for (var item in items) {
      try {
        double originalQuantity = _getQuantity(item);
        print("Item ${item['id']} original quantity: $originalQuantity");

        if (currentStatus == 'rejected' || currentStatus == 'pending') {
          if (item['currentInventoryImpact'] == 0.0) {
            print("Deducting from inventory for item ${item['id']}");
            await _adjustInventory(transaction, item, false, originalQuantity);
            item['currentInventoryImpact'] = originalQuantity;
          }
        } else {
          print(
              "Unexpected current status: $currentStatus. Not adjusting inventory.");
        }

        _resetItemFulfillment(item);
      } catch (e) {
        print("Error handling approval for item ${item['id']}: $e");
        throw CustomException(
            'Error processing item ${item['name']}. Please try again.');
      }
    }
  }

  Future<String> _handleFulfillment(List<Map<String, dynamic>> items) async {
    print("Handling fulfillment...");
    bool allItemsFulfilled = _checkAllItemsFulfilled(items);
    return allItemsFulfilled ? 'fulfilled' : 'partially_fulfilled';
  }

  Future<void> _adjustInventory(
      Transaction transaction, Map<String, dynamic> item, bool isReturning,
      [double? originalQuantity]) async {
    DocumentReference inventoryRef =
        _firestore.collection('inventory').doc(item['id']);
    DocumentSnapshot inventoryDoc = await transaction.get(inventoryRef);

    if (inventoryDoc.exists) {
      Map<String, dynamic> inventoryData =
          inventoryDoc.data() as Map<String, dynamic>;
      double currentQuantity = (inventoryData['quantity'] as num).toDouble();
      print("Current inventory for item ${item['id']}: $currentQuantity");

      double adjustmentQuantity = originalQuantity ?? _getQuantity(item);
      adjustmentQuantity =
          isReturning ? adjustmentQuantity : -adjustmentQuantity;

      print(
          "Adjusting inventory for item ${item['id']} by $adjustmentQuantity");
      print("isReturning: $isReturning, originalQuantity: $originalQuantity");

      double newQuantity = currentQuantity + adjustmentQuantity;
      transaction.update(inventoryRef, {'quantity': newQuantity});

      print(
          "New inventory quantity for item ${item['id']} should be: $newQuantity");
    } else {
      print("Inventory item ${item['id']} not found!");
      throw CustomException("Inventory item ${item['id']} not found!");
    }
  }

  double _getQuantity(Map<String, dynamic> item) {
    if (item['isPipe'] == true) {
      return (item['meters'] as num).toDouble();
    } else {
      return (item['quantity'] as num).toDouble();
    }
  }

  void _resetItemFulfillment(Map<String, dynamic> item) {
    double originalQuantity = _getQuantity(item);
    if (item['isPipe'] == true) {
      item['metersFulfilled'] = 0.0;
      item['pcsFulfilled'] = 0;
      item['metersPending'] = originalQuantity;
      item['pcsPending'] =
          (originalQuantity / (item['pipeLength'] as num).toDouble()).ceil();
    } else {
      item['quantityFulfilled'] = 0;
      item['quantityPending'] = originalQuantity.round();
    }
  }

  bool _checkAllItemsFulfilled(List<Map<String, dynamic>> items) {
    return items.every((item) {
      if (item['isPipe'] == true) {
        double requestedMeters = (item['meters'] as num).toDouble();
        double fulfilledMeters = (item['metersFulfilled'] as num).toDouble();
        return (requestedMeters - fulfilledMeters).abs() < 0.001;
      } else {
        int requestedQuantity = (item['quantity'] as num).round();
        int fulfilledQuantity = (item['quantityFulfilled'] as num).round();
        return requestedQuantity == fulfilledQuantity;
      }
    });
  }

  // double _getQuantity(Map<String, dynamic> item) {
  //   if (item['isPipe'] == true) {
  //     return _parseDouble(item['meters']) ?? 0.0;
  //   } else {
  //     return _parseDouble(item['quantity']) ?? 0.0;
  //   }
  // }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // void _resetItemFulfillment(Map<String, dynamic> item) {
  //   double originalQuantity = _getQuantity(item);
  //   if (item['isPipe'] == true) {
  //     item['metersFulfilled'] = 0.0;
  //     item['pcsFulfilled'] = 0.0;
  //     item['metersPending'] = originalQuantity;
  //     item['pcsPending'] =
  //         originalQuantity / (_parseDouble(item['pipeLength']) ?? 1.0);
  //   } else {
  //     item['quantityFulfilled'] = 0.0;
  //     item['quantityPending'] = originalQuantity;
  //   }
  // }

  // Future<void> _adjustInventory(
  //     Transaction transaction, Map<String, dynamic> item, bool isReturning,
  //     [num? originalQuantity]) async {
  //   DocumentReference inventoryRef =
  //       _firestore.collection('inventory').doc(item['id']);
  //   DocumentSnapshot inventoryDoc = await transaction.get(inventoryRef);

  //   if (inventoryDoc.exists) {
  //     Map<String, dynamic> inventoryData =
  //         inventoryDoc.data() as Map<String, dynamic>;
  //     double currentQuantity = (inventoryData['quantity'] as num).toDouble();
  //     print("Current inventory for item ${item['id']}: $currentQuantity");

  //     double adjustmentQuantity;
  //     if (item['isPipe'] == true) {
  //       double meters = (originalQuantity ?? item['meters'] as num).toDouble();
  //       double pipeLength = (item['pipeLength'] as num?)?.toDouble() ?? 1.0;
  //       adjustmentQuantity = meters / pipeLength;
  //     } else {
  //       adjustmentQuantity =
  //           (originalQuantity ?? item['quantity'] as num).toDouble();
  //     }

  //     adjustmentQuantity =
  //         isReturning ? adjustmentQuantity : -adjustmentQuantity;

  //     print(
  //         "Adjusting inventory for item ${item['id']} by $adjustmentQuantity");
  //     print("isReturning: $isReturning, originalQuantity: $originalQuantity");

  //     transaction.update(inventoryRef, {
  //       'quantity': FieldValue.increment(adjustmentQuantity),
  //     });

  //     print(
  //         "New inventory quantity for item ${item['id']} should be: ${currentQuantity + adjustmentQuantity}");
  //   } else {
  //     print("Inventory item ${item['id']} not found!");
  //   }
  // }

  // void _resetItemFulfillment(Map<String, dynamic> item) {
  //   item['quantityFulfilled'] = 0.0;
  //   item['quantityPending'] = (item['quantity'] as num).toDouble();
  //   if (item['isPipe'] == true) {
  //     item['metersFulfilled'] = 0.0;
  //     item['pcsFulfilled'] = 0.0;
  //     item['metersPending'] = (item['meters'] as num).toDouble();
  //     item['pcsPending'] = (item['pcs'] as num).toDouble();
  //   }
  // }

  // bool _checkAllItemsFulfilled(List<Map<String, dynamic>> items) {
  //   return items.every((item) {
  //     if (item['isPipe'] == true) {
  //       double requestedMeters = (item['meters'] as num).toDouble();
  //       double fulfilledMeters =
  //           (item['metersFulfilled'] as num?)?.toDouble() ?? 0.0;
  //       return (requestedMeters - fulfilledMeters).abs() < 0.001;
  //     } else {
  //       double requestedQuantity = (item['quantity'] as num).toDouble();
  //       double fulfilledQuantity =
  //           (item['quantityFulfilled'] as num?)?.toDouble() ?? 0.0;
  //       return (requestedQuantity - fulfilledQuantity).abs() < 0.001;
  //     }
  //   });
  // }

  Future<void> _sendStatusUpdateNotifications(
      String id, String status, String userId, String? userRole) async {
    switch (status) {
      case 'approved':
        await _notificationProvider.sendNotification(
          userId,
          'Request Approved',
          'Your request has been approved.',
          userRole: userRole ?? 'User',
          requestId: id,
        );
        await _notificationProvider.addNotificationForRole(
          'New Approved Request',
          'A new request has been approved and is ready for fulfillment.',
          'Gate Man',
          requestId: id,
        );
        break;
      case 'rejected':
        await _notificationProvider.sendNotification(
          userId,
          'Request Rejected',
          'Your request has been rejected and items returned to inventory.',
          userRole: userRole ?? 'User',
          requestId: id,
        );
        break;
      case 'fulfilled':
        await _notificationProvider.sendNotification(
          userId,
          'Request Fulfilled',
          'Your request has been completely fulfilled.',
          userRole: userRole ?? 'User',
          requestId: id,
        );
        break;
      case 'partially_fulfilled':
        await _notificationProvider.sendNotification(
          userId,
          'Request Partially Fulfilled',
          'Your request has been partially fulfilled.',
          userRole: userRole ?? 'User',
          requestId: id,
        );
        break;
    }
  }

  Future<void> addStockRequest({
    required List<Map<String, dynamic>> items,
    required String note,
    required String createdBy,
  }) async {
    try {
      for (var item in items) {
        if (!item.containsKey('id') ||
            item['id'] == null ||
            item['id'].isEmpty) {
          throw Exception('Item ${item['name']} is missing an ID');
        }
      }

      DocumentReference docRef =
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
        'receivedAt': null,
      });

      String? userRole = await getUserRole(createdBy);

      _sendNotification(
        createdBy,
        'Stock Request Created',
        'Your stock request has been successfully created and is pending approval.',
        userRole: userRole ?? 'Manager',
      );

      _sendNotificationToRole(
        'New Stock Request',
        'A new stock request has been created by a manager and is waiting for your approval.',
        'Admin',
      );

      notifyListeners();
    } catch (e) {
      print('Error adding stock request: $e');
      rethrow;
    }
  }

  Future<void> updateStockRequestStatus(
    String id,
    String status,
    String adminEmail, {
    String? rejectionReason,
  }) async {
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
        case 'rejected':
          updateData['rejectedBy'] = adminEmail;
          updateData['rejectedAt'] = FieldValue.serverTimestamp();
          if (rejectionReason != null) {
            updateData['rejectionReason'] = rejectionReason;
          }
          break;
        case 'fulfilled':
          updateData['fulfilledBy'] = adminEmail;
          updateData['fulfilledAt'] = FieldValue.serverTimestamp();
          updateData['receivedAt'] = FieldValue.serverTimestamp();
          break;
      }

      await _firestore.collection('stock_requests').doc(id).update(updateData);

      final stockRequest =
          await _firestore.collection('stock_requests').doc(id).get();
      final stockRequestData = stockRequest.data() as Map<String, dynamic>;
      final createdBy = stockRequestData['createdBy'];
      String? userRole = await getUserRole(createdBy);

      switch (status) {
        case 'approved':
          _sendNotification(
            createdBy,
            'Stock Request Approved',
            'Your stock request has been approved.',
            userRole: userRole ?? 'Manager',
          );
          _sendNotificationToRole(
            'New Approved Stock Request',
            'A new stock request has been approved and is ready for fulfillment.',
            'Gate Man',
          );
          break;
        case 'rejected':
          _sendNotification(
            createdBy,
            'Stock Request Rejected',
            'Your stock request has been rejected. Reason: ${rejectionReason ?? "Not provided"}',
            userRole: userRole ?? 'Manager',
          );
          break;
        case 'fulfilled':
          _sendNotification(
            createdBy,
            'Stock Request Fulfilled',
            'Your stock request has been fulfilled and items were received.',
            userRole: userRole ?? 'Manager',
          );
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Error updating stock request status: $e');
      rethrow;
    }
  }

  void _sendNotification(String userId, String title, String body,
      {required String userRole}) {
    try {
      _notificationProvider.sendNotification(
        userId,
        title,
        body,
        userRole: userRole,
      );
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  void _sendNotificationToRole(
    String title,
    String body,
    String role, {
    String? requestId,
    String? excludeUserId,
  }) {
    try {
      _notificationProvider.addNotificationForRole(
        title,
        body,
        role,
        requestId: requestId,
        excludeUserId: excludeUserId,
      );
    } catch (e) {
      print("Error sending notification to role: $e");
    }
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

  Future<List<Map<String, dynamic>>> getNonFulfilledStockRequests(
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore.collection('stock_requests').where('status',
          whereIn: [
            'pending',
            'approved',
            'partially_fulfilled'
          ]).orderBy('createdAt', descending: true);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      QuerySnapshot querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convert Timestamps to DateTime
        if (data['createdAt'] != null) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        if (data['receivedAt'] != null) {
          data['receivedAt'] = (data['receivedAt'] as Timestamp).toDate();
        }

        return data;
      }).toList();
    } catch (e) {
      print("Error fetching non-fulfilled stock requests: $e");
      return [];
    }
  }

  Future<String> addRequest(
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

      String uniqueCode = generateUniqueCode();
      List<Map<String, dynamic>> updatedItems = [];

      late String requestId;

      await _firestore.runTransaction<void>(
        (transaction) async {
          print("Starting transaction for new request");

          for (var item in items) {
            bool isPipe = item['isPipe'] == true;

            Map<String, dynamic> updatedItem = {
              ...item,
              'currentInventoryImpact': 0.0, // No impact on creation
            };

            if (isPipe) {
              double requestedMeters =
                  (item['meters'] as num?)?.toDouble() ?? 0.0;
              updatedItem['metersFulfilled'] = 0;
              updatedItem['pcsFulfilled'] = 0;
              updatedItem['metersPending'] = requestedMeters;
              updatedItem['pcsPending'] = item['pcs'];
            } else {
              double requestedQuantity =
                  (item['quantity'] as num?)?.toDouble() ?? 0.0;
              updatedItem['quantityFulfilled'] = 0;
              updatedItem['quantityPending'] = requestedQuantity;
            }

            updatedItems.add(updatedItem);
          }

          DocumentReference requestRef =
              _firestore.collection('requests').doc();
          requestId = requestRef.id;
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

          transaction.set(requestRef, requestData);
          print("Request data prepared for Firestore: $requestData");
        },
        timeout: Duration(seconds: 30),
      );

      print("New request created with ID: $requestId");

      await _notifyManagersAndAdmins(requestId, createdByEmail);

      notifyListeners();
      // No need to fetch items as inventory hasn't changed
      print("Request creation process completed successfully");

      return requestId;
    } catch (e) {
      print("Error in addRequest: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Future<String> addRequest(
  //   List<Map<String, dynamic>> items,
  //   String location,
  //   String pickerName,
  //   String pickerContact,
  //   String note,
  //   String createdByEmail,
  //   InventoryProvider inventoryProvider,
  // ) async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) {
  //       throw Exception('User must be logged in to create a request');
  //     }

  //     String uniqueCode = generateUniqueCode();
  //     List<Map<String, dynamic>> updatedItems = List.from(items);

  //     late String requestId;

  //     await _firestore.runTransaction<void>(
  //       (transaction) async {
  //         print("Starting transaction for new request");

  //         for (var item in updatedItems) {
  //           bool isPipe = item['isPipe'] == true;
  //           String itemId = item['id'];

  //           if (isPipe) {
  //             double requestedMeters =
  //                 (item['meters'] as num?)?.toDouble() ?? 0.0;
  //             await inventoryProvider.updateInventoryQuantity(
  //                 itemId, -requestedMeters, // Changed to negative
  //                 unit: 'meters');

  //             item['metersFulfilled'] = 0; // Changed to 0
  //             item['pcsFulfilled'] = 0; // Changed to 0
  //             item['metersPending'] = requestedMeters;
  //             item['pcsPending'] = item['pcs'];
  //             item['currentInventoryImpact'] =
  //                 requestedMeters; // Added this line
  //           } else {
  //             double requestedQuantity =
  //                 (item['quantity'] as num?)?.toDouble() ?? 0.0;
  //             await inventoryProvider.updateInventoryQuantity(
  //                 itemId, -requestedQuantity); // Changed to negative

  //             item['quantityFulfilled'] = 0; // Changed to 0
  //             item['quantityPending'] = requestedQuantity;
  //             item['currentInventoryImpact'] =
  //                 requestedQuantity; // Added this line
  //           }
  //         }

  //         DocumentReference requestRef =
  //             _firestore.collection('requests').doc();
  //         requestId = requestRef.id;
  //         Map<String, dynamic> requestData = {
  //           'items': updatedItems,
  //           'status': 'pending',
  //           'timestamp': FieldValue.serverTimestamp(),
  //           'location': location,
  //           'pickerName': pickerName,
  //           'pickerContact': pickerContact,
  //           'note': note,
  //           'uniqueCode': uniqueCode,
  //           'codeValid': true,
  //           'createdBy': user.uid,
  //           'createdByEmail': createdByEmail,
  //           'createdByName': user.displayName ?? 'Unknown User',
  //         };

  //         transaction.set(requestRef, requestData);
  //         print("Request data prepared for Firestore: $requestData");
  //       },
  //       timeout: Duration(seconds: 30),
  //     );

  //     print("New request created with ID: $requestId");

  //     await _notifyManagersAndAdmins(requestId, createdByEmail);

  //     notifyListeners();
  //     await inventoryProvider.fetchItems();
  //     print("Request creation process completed successfully");

  //     return requestId;
  //   } catch (e) {
  //     print("Error in addRequest: $e");
  //     print("Stack trace: ${StackTrace.current}");
  //     rethrow;
  //   }
  // }

  // Future<String> addRequest(
  //   List<Map<String, dynamic>> items,
  //   String location,
  //   String pickerName,
  //   String pickerContact,
  //   String note,
  //   String createdByEmail,
  //   InventoryProvider inventoryProvider,
  // ) async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) {
  //       throw Exception('User must be logged in to create a request');
  //     }

  //     String uniqueCode = generateUniqueCode();
  //     List<Map<String, dynamic>> updatedItems = List.from(items);

  //     late String requestId;

  //     await _firestore.runTransaction<void>(
  //       (transaction) async {
  //         print("Starting transaction for new request");

  //         for (var item in updatedItems) {
  //           bool isPipe = item['isPipe'] == true;
  //           String itemId = item['id'];

  //           if (isPipe) {
  //             double requestedMeters =
  //                 (item['meters'] as num?)?.toDouble() ?? 0.0;
  //             await inventoryProvider.updateInventoryQuantity(
  //                 itemId, requestedMeters,
  //                 unit: 'meters');

  //             item['metersFulfilled'] = requestedMeters;
  //             item['pcsFulfilled'] = item['pcs'];
  //             item['metersPending'] = 0;
  //             item['pcsPending'] = 0;
  //           } else {
  //             double requestedQuantity =
  //                 (item['quantity'] as num?)?.toDouble() ?? 0.0;
  //             await inventoryProvider.updateInventoryQuantity(
  //                 itemId, requestedQuantity);

  //             item['quantityFulfilled'] = requestedQuantity;
  //             item['quantityPending'] = 0;
  //           }
  //         }

  //         DocumentReference requestRef =
  //             _firestore.collection('requests').doc();
  //         requestId = requestRef.id;
  //         Map<String, dynamic> requestData = {
  //           'items': updatedItems,
  //           'status': 'pending',
  //           'timestamp': FieldValue.serverTimestamp(),
  //           'location': location,
  //           'pickerName': pickerName,
  //           'pickerContact': pickerContact,
  //           'note': note,
  //           'uniqueCode': uniqueCode,
  //           'codeValid': true,
  //           'createdBy': user.uid,
  //           'createdByEmail': createdByEmail,
  //           'createdByName': user.displayName ?? 'Unknown User',
  //         };

  //         transaction.set(requestRef, requestData);
  //         print("Request data prepared for Firestore: $requestData");
  //       },
  //       timeout: Duration(seconds: 30),
  //     );

  //     print("New request created with ID: $requestId");

  //     await _notifyManagersAndAdmins(requestId, createdByEmail);

  //     notifyListeners();
  //     await inventoryProvider.fetchItems();
  //     print("Request creation process completed successfully");

  //     return requestId;
  //   } catch (e) {
  //     print("Error in addRequest: $e");
  //     print("Stack trace: ${StackTrace.current}");
  //     rethrow;
  //   }
  // }

  Future<void> _notifyManagersAndAdmins(
      String requestId, String userEmail) async {
    try {
      WriteBatch batch = _firestore.batch();

      List<String> managerIds = await _getManagerIds();
      List<String> adminIds = await _getAdminIds();

      DateTime now = DateTime.now();

      for (String managerId in managerIds) {
        DocumentReference notificationRef =
            _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': managerId,
          'title': 'New Request Pending',
          'body':
              'A new request has been created by $userEmail and is waiting for your approval.',
          'userRole': 'Manager',
          'requestId': requestId,
          'timestamp': now,
          'isRead': false,
        });
      }

      for (String adminId in adminIds) {
        DocumentReference notificationRef =
            _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': adminId,
          'title': 'New Request Created',
          'body': 'A new request has been created by $userEmail.',
          'userRole': 'Admin',
          'requestId': requestId,
          'timestamp': now,
          'isRead': false,
        });
      }

      await batch.commit();
      print("Notifications sent to managers and admins");
    } catch (e) {
      print("Error in _notifyManagersAndAdmins: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getApprovedRequestsStream() {
    print("Starting getApprovedRequestsStream");
    return _firestore
        .collection('requests')
        .where('status', whereIn: ['approved', 'partially_fulfilled'])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          print(
              "Snapshot received in getApprovedRequestsStream. Document count: ${snapshot.docs.length}");
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            print(
                "Processing approved request: ${doc.id} - Status: ${data['status']}");

            if (data['items'] != null && data['items'] is List) {
              data['items'] = (data['items'] as List).map((item) {
                if (item is Map<String, dynamic>) {
                  item['quantity'] =
                      (item['quantity'] as num?)?.toDouble() ?? 0.0;
                  item['fulfilledQuantity'] =
                      (item['fulfilledQuantity'] as num?)?.toDouble() ?? 0.0;
                  item['remainingQuantity'] =
                      (item['quantity'] as num).toDouble() -
                          (item['fulfilledQuantity'] as num).toDouble();
                  print(
                      "Item: ${item['name']}, Quantity: ${item['quantity']}, Fulfilled: ${item['fulfilledQuantity']}, Remaining: ${item['remainingQuantity']}");
                }
                return item;
              }).toList();
            }

            return data;
          }).toList();
        });
  }

  Future<bool> checkIfFullyFulfilled(
      String requestId, Map<String, dynamic> requestData) async {
    List<dynamic> items = requestData['items'] ?? [];
    for (var item in items) {
      double requestedQuantity = item['quantity'] ?? 0;
      double fulfilledQuantity = item['fulfilledQuantity'] ?? 0;
      if (fulfilledQuantity < requestedQuantity) {
        return false;
      }
    }
    return true;
  }

  // Keep the existing method for backwards compatibility
  List<Map<String, dynamic>> getApprovedRequests(String searchQuery) {
    return _requests.where((request) {
      bool statusMatch = request['status'] == 'approved' ||
          request['status'] == 'partially_fulfilled';
      bool searchMatch = request['pickerName']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          request['pickerContact'].toString().contains(searchQuery);

      return statusMatch && searchMatch;
    }).toList();
  }

  // List<Map<String, dynamic>> getApprovedRequests(String searchQuery) {
  //   return _requests.where((request) {
  //     bool statusMatch = request['status'] == 'approved' ||
  //         request['status'] == 'partially_fulfilled';
  //     bool searchMatch = request['pickerName']
  //             .toString()
  //             .toLowerCase()
  //             .contains(searchQuery.toLowerCase()) ||
  //         request['pickerContact'].toString().contains(searchQuery);

  //     return statusMatch && searchMatch;
  //   }).toList();
  // }

  List<Map<String, dynamic>> getTodayRequests() {
    final now = DateTime.now();
    return _requests.where((request) {
      final requestDate = request['timestamp'];
      if (requestDate is DateTime) {
        return requestDate.year == now.year &&
            requestDate.month == now.month &&
            requestDate.day == now.day;
      }
      return false;
    }).toList();
  }

  Stream<Map<String, int>> getDashboardStats(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    StreamController<Map<String, int>> controller =
        StreamController<Map<String, int>>();

    void updateStats() async {
      try {
        QuerySnapshot regularSnapshot = await _firestore
            .collection('requests')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .get();

        QuerySnapshot stockSnapshot = await _firestore
            .collection('stock_requests')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .where('createdAt', isLessThanOrEqualTo: endOfDay)
            .get();

        int totalRequests =
            regularSnapshot.docs.length + stockSnapshot.docs.length;
        int pendingRequests = regularSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] == 'pending')
                .length +
            stockSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] == 'pending')
                .length;
        int approvedRequests = regularSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] ==
                    'approved')
                .length +
            stockSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] ==
                    'approved')
                .length;
        int fulfilledRequests = regularSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] ==
                    'fulfilled')
                .length +
            stockSnapshot.docs
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['status'] ==
                    'fulfilled')
                .length;

        controller.add({
          'total': totalRequests,
          'pending': pendingRequests,
          'approved': approvedRequests,
          'fulfilled': fulfilledRequests,
        });
      } catch (e) {
        controller.addError(e);
      }
    }

    updateStats();

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getRecentActivityStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    StreamController<List<Map<String, dynamic>>> controller =
        StreamController<List<Map<String, dynamic>>>();

    void updateActivity() async {
      try {
        QuerySnapshot regularSnapshot = await _firestore
            .collection('requests')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        QuerySnapshot stockSnapshot = await _firestore
            .collection('stock_requests')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .where('createdAt', isLessThanOrEqualTo: endOfDay)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        List<Map<String, dynamic>> recentActivity = [];

        recentActivity.addAll(regularSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'type': 'Regular',
            'status': data['status'],
            'timestamp': data['timestamp'],
          };
        }));

        recentActivity.addAll(stockSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'type': 'Stock',
            'status': data['status'],
            'timestamp': data['createdAt'],
          };
        }));

        recentActivity.sort((a, b) => (b['timestamp'] as Timestamp)
            .compareTo(a['timestamp'] as Timestamp));
        controller.add(recentActivity.take(5).toList());
      } catch (e) {
        controller.addError(e);
      }
    }

    updateActivity();

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> getRecentFulfilledRequests() async {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));
    QuerySnapshot snapshot = await _firestore
        .collection('requests')
        .where('status', isEqualTo: 'fulfilled')
        .where('fulfilledAt', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('fulfilledAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      if (data['fulfilledAt'] is Timestamp) {
        data['fulfilledAt'] = (data['fulfilledAt'] as Timestamp).toDate();
      }
      return data;
    }).toList();
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
          double quantityFulfilled =
              (item['quantityFulfilled'] as num?)?.toDouble() ?? 0;
          if (quantityFulfilled > 0) {
            DocumentReference inventoryRef =
                _firestore.collection('inventory').doc(item['id']);
            transaction.update(inventoryRef, {
              'quantity': FieldValue.increment(quantityFulfilled),
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
        String currentStatus = requestData['status'] as String;

        print("Old items: $oldItems");
        print("Current status: $currentStatus");

        Map<String, DocumentSnapshot> inventorySnapshots = {};
        for (var item in newItems) {
          DocumentSnapshot snapshot = await transaction
              .get(_firestore.collection('inventory').doc(item['id']));
          inventorySnapshots[item['id']] = snapshot;
        }

        List<Map<String, dynamic>> updatedItems = [];
        Map<String, double> inventoryAdjustments = {};

        for (var newItem in newItems) {
          var oldItem = oldItems.firstWhere(
            (item) => item['id'] == newItem['id'],
            orElse: () => <String, dynamic>{},
          );
          var inventorySnapshot = inventorySnapshots[newItem['id']]!;

          bool isPipe = newItem['isPipe'] == true;
          double pipeLength = isPipe
              ? (inventorySnapshot.data() as Map<String, dynamic>)['pipeLength']
                      is int
                  ? (inventorySnapshot.data()
                          as Map<String, dynamic>)['pipeLength']
                      .toDouble()
                  : (inventorySnapshot.data()
                      as Map<String, dynamic>)['pipeLength']
              : 1.0;

          print("Fetched pipe length for item ${newItem['id']}: $pipeLength");

          double oldQuantity = (oldItem['quantity'] as num).toDouble();
          double newQuantity = (newItem['quantity'] as num).toDouble();

          double oldMeters = isPipe
              ? (oldItem['meters'] as num).toDouble()
              : oldQuantity * pipeLength;
          double newMeters = isPipe
              ? (newItem['meters'] as num).toDouble()
              : newQuantity * pipeLength;

          double oldImpact =
              (oldItem['currentInventoryImpact'] as num).toDouble();

          double quantityDifference;
          if (isPipe) {
            double oldPieces = oldMeters / pipeLength;
            double newPieces = newMeters / pipeLength;
            quantityDifference = newPieces - oldPieces;
            newQuantity = newPieces;
          } else {
            quantityDifference = newQuantity - oldQuantity;
          }

          double newImpact = oldImpact;

          if (currentStatus == 'approved' ||
              currentStatus == 'partially_fulfilled') {
            newImpact = oldImpact - quantityDifference;
            inventoryAdjustments[newItem['id']] = -quantityDifference;
          }

          print(
              "Item ${newItem['id']}: Old Quantity: $oldQuantity, New Quantity: $newQuantity, Old Meters: $oldMeters, New Meters: $newMeters, Old Impact: $oldImpact, New Impact: $newImpact, Is Pipe: $isPipe, Pipe Length: $pipeLength");

          Map<String, dynamic> updatedItem = {
            ...newItem,
            'currentInventoryImpact': newImpact,
            'quantity': newQuantity,
            'quantityFulfilled': newQuantity,
            'quantityPending': 0,
          };

          if (isPipe) {
            updatedItem['meters'] = newMeters;
            updatedItem['metersFulfilled'] = newMeters;
            updatedItem['metersPending'] = 0;
          }

          updatedItems.add(updatedItem);
        }

        print("Updated items: $updatedItems");
        print("Inventory adjustments: $inventoryAdjustments");

        transaction.update(_firestore.collection('requests').doc(requestId), {
          'items': updatedItems,
          'location': location,
          'pickerName': pickerName,
          'pickerContact': pickerContact,
          'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (var update in inventoryAdjustments.entries) {
          DocumentReference inventoryRef =
              _firestore.collection('inventory').doc(update.key);
          DocumentSnapshot inventorySnapshot = inventorySnapshots[update.key]!;

          if (inventorySnapshot.exists) {
            double currentQuantity = (inventorySnapshot.data()
                    as Map<String, dynamic>)['quantity'] is int
                ? (inventorySnapshot.data() as Map<String, dynamic>)['quantity']
                    .toDouble()
                : (inventorySnapshot.data()
                    as Map<String, dynamic>)['quantity'];
            double newQuantity = currentQuantity + update.value;
            print(
                "Updating inventory for item ${update.key}: Current: $currentQuantity, Adjustment: ${update.value}, New: $newQuantity");
            transaction.update(inventoryRef, {'quantity': newQuantity});
          } else {
            print("Creating new inventory item: ${update.key}");
            var newItemData =
                newItems.firstWhere((item) => item['id'] == update.key);
            transaction.set(inventoryRef, {
              'name': newItemData['name'] ?? 'Unknown Item',
              'quantity': update.value,
              'isPipe': newItemData['isPipe'] ?? false,
              'pipeLength': newItemData['pipeLength'] ?? 1.0,
              'category': newItemData['category'] ?? '',
              'subcategory': newItemData['subcategory'] ?? '',
              'unit': newItemData['unit'] ?? 'pcs',
            });
          }
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

  // Stream<List<Map<String, dynamic>>>
  //     getRecentApprovedAndFulfilledRequestsStream() {
  //   final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));

  //   return _firestore
  //       .collection('requests')
  //       .where('status', whereIn: ['approved', 'fulfilled'])
  //       .where('approvedAt', isGreaterThanOrEqualTo: twoDaysAgo)
  //       .orderBy('approvedAt', descending: true)
  //       .snapshots()
  //       .map((snapshot) {
  //         return snapshot.docs.map((doc) {
  //           final data = doc.data() as Map<String, dynamic>;
  //           data['id'] = doc.id;
  //           if (data['approvedAt'] is Timestamp) {
  //             data['approvedAt'] = (data['approvedAt'] as Timestamp).toDate();
  //           }
  //           if (data['fulfilledAt'] is Timestamp) {
  //             data['fulfilledAt'] = (data['fulfilledAt'] as Timestamp).toDate();
  //           }
  //           return data;
  //         }).toList();
  //       });
  // }

  Stream<List<Map<String, dynamic>>>
      getRecentApprovedAndFulfilledRequestsStream() {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));
    print(
        "Fetching requests approved after: ${twoDaysAgo.toIso8601String()}"); // Debug print

    return _firestore
        .collection('requests')
        .where('status',
            whereIn: ['approved', 'fulfilled', 'partially_fulfilled'])
        .where('approvedAt', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('approvedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print(
              "Snapshot received. Document count: ${snapshot.docs.length}"); // Debug print

          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  print("Processing document ${doc.id}:"); // Debug print
                  print("  Status: ${data['status']}"); // Debug print
                  print("  ApprovedAt: ${data['approvedAt']}"); // Debug print

                  if (data['approvedAt'] is Timestamp) {
                    data['approvedAt'] =
                        (data['approvedAt'] as Timestamp).toDate();
                  }
                  if (data['fulfilledAt'] is Timestamp) {
                    data['fulfilledAt'] =
                        (data['fulfilledAt'] as Timestamp).toDate();
                  }

                  return data;
                } catch (e) {
                  print(
                      "Error processing document ${doc.id}: $e"); // Debug print
                  return null;
                }
              })
              .where((doc) => doc != null)
              .cast<Map<String, dynamic>>()
              .toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getRecentFulfilledRequestsStream(
      String userEmail, String userRole) {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));

    print(
        "Starting getRecentFulfilledRequestsStream for user: $userEmail, role: $userRole");
    print("Two days ago: ${twoDaysAgo.toIso8601String()}");

    Query query = _firestore
        .collection('requests')
        .where('status', isEqualTo: 'fulfilled')
        .where('fulfilledAt', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('fulfilledAt', descending: true);

    if (userRole != 'Admin' && userRole != 'Manager') {
      query = query.where('createdByEmail', isEqualTo: userEmail);
    }

    return query.snapshots().map((snapshot) {
      print("Snapshot received. Document count: ${snapshot.docs.length}");

      final requests = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data == null) {
              print("Warning: Null data for document ${doc.id}");
              return null;
            }

            if (data is! Map<String, dynamic>) {
              print(
                  "Warning: Data is not a Map<String, dynamic> for document ${doc.id}");
              return null;
            }

            final requestData = Map<String, dynamic>.from(data);
            requestData['id'] = doc.id;

            print("Processing document ${doc.id}:");
            print("  Status: ${requestData['status']}");
            print("  FulfilledAt: ${requestData['fulfilledAt']}");

            if (requestData['fulfilledAt'] is Timestamp) {
              requestData['fulfilledAt'] =
                  (requestData['fulfilledAt'] as Timestamp).toDate();
              print("  Converted fulfilledAt: ${requestData['fulfilledAt']}");
            } else {
              print(
                  "  fulfilledAt is not a Timestamp: ${requestData['fulfilledAt']}");
            }

            return requestData;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      print("Processed ${requests.length} fulfilled requests");
      return requests;
    });
  }

  Future<void> refreshFulfilledRequests() async {
    try {
      final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));
      print("Refreshing fulfilled requests");
      print("Two days ago: ${twoDaysAgo.toIso8601String()}");

      QuerySnapshot snapshot = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'fulfilled')
          .where('fulfilledAt', isGreaterThanOrEqualTo: twoDaysAgo)
          .orderBy('fulfilledAt', descending: true)
          .get();

      print("Fetched ${snapshot.docs.length} fulfilled requests");

      _fulfilledRequests = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        print("Request ${doc.id}:");
        print("  Status: ${data['status']}");
        print("  FulfilledAt: ${data['fulfilledAt']}");
        return data;
      }).toList();

      notifyListeners();
    } catch (e) {
      print("Error refreshing fulfilled requests: $e");
    }
  }

  Future<void> fulfillRequest(String requestId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference requestRef =
            _firestore.collection('requests').doc(requestId);
        DocumentSnapshot requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;
        String currentStatus = requestData['status'] as String;

        if (currentStatus == 'fulfilled') {
          throw CustomException('This request has already been fulfilled');
        }

        bool isFullyFulfilled =
            true; // You might need to determine this based on your business logic
        String newStatus =
            isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';

        transaction.update(requestRef, {
          'status': newStatus,
          'fulfilledAt': FieldValue.serverTimestamp(),
        });

        // Send notifications
        String creatorId = requestData['createdBy'];
        String fulfillmentStatus = isFullyFulfilled ? 'fully' : 'partially';

        _sendNotification(
          creatorId,
          'Request Update',
          'Your request has been $fulfillmentStatus fulfilled by a Gate Man.',
          userRole: 'User',
        );

        _sendNotificationToRole(
          'Request Update',
          'A request has been $fulfillmentStatus fulfilled by a Gate Man.',
          'Admin',
        );

        _sendNotificationToRole(
          'Request Update',
          'A request has been $fulfillmentStatus fulfilled by a Gate Man.',
          'Manager',
        );
      });

      notifyListeners();
    } catch (e) {
      print("Error fulfilling request: $e");
      rethrow;
    }
  }

  Future<void> fulfillRequestByCode(String code) async {
    try {
      print("Attempting to fulfill request with code: $code");

      // Fetch current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw CustomException('No authenticated user found.');
      }

      // Fetch user details (if needed)
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      String userRole = userDoc.get('role') ?? 'Gate Man';
      print("Current user role: $userRole");

      // Query for the request with the given unique code
      QuerySnapshot querySnapshot = await _firestore
          .collection('requests')
          .where('uniqueCode', isEqualTo: code)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw CustomException('No request found for this code');
      }

      DocumentSnapshot requestDoc = querySnapshot.docs.first;
      String requestId = requestDoc.id;
      Map<String, dynamic> requestData =
          requestDoc.data() as Map<String, dynamic>;

      if (requestData['status'] == 'fulfilled') {
        throw CustomException('This request has already been fulfilled');
      }

      bool isFullyFulfilled =
          await _firestore.runTransaction<bool>((transaction) async {
        DocumentSnapshot freshRequestDoc =
            await transaction.get(requestDoc.reference);
        if (!freshRequestDoc.exists) {
          throw CustomException('Request does not exist');
        }

        Map<String, dynamic> freshRequestData =
            freshRequestDoc.data() as Map<String, dynamic>;

        List<dynamic> items = freshRequestData['items'] as List<dynamic>;
        bool allItemsFulfilled = true;
        List<Map<String, dynamic>> updatedItems = [];

        for (var item in items) {
          // Safely access 'quantity' and 'receivedQuantity'
          double requestedQuantity =
              (item['quantity'] as num?)?.toDouble() ?? 0.0;
          double currentReceivedQuantity =
              (item['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
          double remainingQuantity =
              requestedQuantity - currentReceivedQuantity;

          // Prevent negative remainingQuantity
          if (remainingQuantity < 0) {
            print(
                "Warning: Received quantity exceeds requested quantity for item '${item['name']}'. Capping to requested quantity.");
            currentReceivedQuantity = requestedQuantity;
            remainingQuantity = 0.0;
          }

          // If there's still remaining quantity, the request isn't fully fulfilled
          if (remainingQuantity > 0.0) {
            allItemsFulfilled = false;
          }

          updatedItems.add({
            ...item,
            'receivedQuantity': currentReceivedQuantity,
            'remainingQuantity': remainingQuantity,
          });

          print(
              "Item: ${item['name']}, Requested: $requestedQuantity, Received: $currentReceivedQuantity, Remaining: $remainingQuantity");
        }

        String newStatus =
            allItemsFulfilled ? 'fulfilled' : 'partially_fulfilled';
        print("Calculated new status: $newStatus");

        Map<String, dynamic> updatedFields = {
          'status': newStatus,
          'items': updatedItems,
          'codeValid': false,
          'lastUpdated': FieldValue.serverTimestamp(),
          'fulfillmentTimestamp': FieldValue.serverTimestamp(),
          'fulfilledBy': currentUser.uid, // Set to current user's UID
        };

        if (newStatus == 'fulfilled') {
          updatedFields['fulfilledAt'] = FieldValue.serverTimestamp();
        } else {
          updatedFields['fulfilledAt'] = null;
        }

        // Add logging for fields being updated
        print("Fields being updated: ${updatedFields.keys.toList()}");

        transaction.update(requestDoc.reference, updatedFields);

        return allItemsFulfilled;
      });

      print(
          "Request $requestId updated successfully. Fully fulfilled: $isFullyFulfilled");
      notifyListeners();

      // Send notifications
      String creatorId = requestData['createdBy'];
      String fulfillmentStatus = isFullyFulfilled ? 'fully' : 'partially';

      _sendNotification(
        creatorId,
        'Request Update',
        'Your request has been $fulfillmentStatus fulfilled.',
        userRole: 'User',
      );

      _sendNotificationToRole(
        'Request Update',
        'A request has been $fulfillmentStatus fulfilled.',
        'Admin',
      );

      _sendNotificationToRole(
        'Request Update',
        'A request has been $fulfillmentStatus fulfilled.',
        'Manager',
      );
    } catch (e) {
      print("Error fulfilling request by code: $e");
      rethrow;
    }
  }

  Future<void> fulfillStockRequest(
    String requestId,
    List<Map<String, dynamic>> receivedItems,
    String gateManId,
    bool allowOverReceipt,
  ) async {
    try {
      List<Map<String, dynamic>> overReceivedItems = [];
      String fulfillmentStatus = 'partially';

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot requestDoc = await transaction
            .get(_firestore.collection('stock_requests').doc(requestId));

        if (!requestDoc.exists) {
          throw Exception('Stock request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;
        List<dynamic> requestItems = requestData['items'] ?? [];
        List<Map<String, dynamic>> updatedItems = [];

        bool isFullyFulfilled = true;
        double epsilon =
            1e-6; // Small value to handle floating-point comparisons

        for (var originalItem in requestItems) {
          var receivedItem = receivedItems.firstWhere(
            (item) => item['id'] == originalItem['id'],
            orElse: () => <String, dynamic>{},
          );

          double requestedQuantity =
              (originalItem['quantity'] as num?)?.toDouble() ?? 0;
          double previouslyReceived =
              (originalItem['receivedQuantity'] as num?)?.toDouble() ?? 0;
          double newlyReceived =
              (receivedItem['receivedQuantity'] as num?)?.toDouble() ?? 0;
          double totalReceived = previouslyReceived + newlyReceived;

          // Check for over-receipt
          if (totalReceived > requestedQuantity + epsilon) {
            if (!allowOverReceipt) {
              throw Exception(
                  'Over-receipt not allowed for ${originalItem['name']}');
            }
            overReceivedItems.add({
              'name': originalItem['name'],
              'overReceivedQuantity': totalReceived - requestedQuantity,
              'unit': originalItem['unit'],
            });
          }

          double remainingQuantity =
              math.max(0, requestedQuantity - totalReceived);

          updatedItems.add({
            ...originalItem,
            'receivedQuantity': totalReceived,
            'remainingQuantity': remainingQuantity,
          });

          if (remainingQuantity > epsilon) {
            isFullyFulfilled = false;
          }

          // Update inventory
          if (newlyReceived > epsilon) {
            String? itemId = originalItem['id'] as String?;
            if (itemId != null && itemId.isNotEmpty) {
              await _inventoryProvider.updateInventoryQuantity(
                itemId,
                newlyReceived,
                unit: originalItem['isPipe'] == true
                    ? originalItem['unit']
                    : null,
              );
            }
          }
        }

        String currentStatus = requestData['status'] as String? ?? '';
        String newStatus;

        if (isFullyFulfilled) {
          newStatus = 'fulfilled';
          fulfillmentStatus = 'fully';
        } else if (currentStatus == 'approved') {
          newStatus = 'partially_fulfilled';
        } else {
          newStatus =
              currentStatus; // Maintain current status if already partially fulfilled
        }

        Map<String, dynamic> updateData = {
          'items': updatedItems,
          'status': newStatus,
          'lastUpdated': FieldValue.serverTimestamp(),
          'fulfilledBy': gateManId,
        };

        if (newStatus == 'fulfilled') {
          updateData['fulfilledAt'] = FieldValue.serverTimestamp();
        }

        if (overReceivedItems.isNotEmpty) {
          updateData['overReceivedItems'] = overReceivedItems;
          updateData['allowedOverReceipt'] = allowOverReceipt;
        }

        transaction.update(
            _firestore.collection('stock_requests').doc(requestId), updateData);

        print("Transaction completed. New status: $newStatus");
      });

      // Fetch the updated stock request data
      final updatedStockRequest =
          await _firestore.collection('stock_requests').doc(requestId).get();
      final updatedStockRequestData =
          updatedStockRequest.data() as Map<String, dynamic>;
      final createdBy = updatedStockRequestData['createdBy'];
      String? creatorRole = await getUserRole(createdBy);

      _sendNotification(
        createdBy,
        'Stock Request Update',
        'Your stock request has been $fulfillmentStatus fulfilled by a Gate Man.',
        userRole: creatorRole ?? 'Manager',
      );

      _sendNotificationToRole(
        'Stock Request Update',
        'A stock request has been $fulfillmentStatus fulfilled by a Gate Man.',
        'Admin',
      );

      _sendNotificationToRole(
        'Stock Request Update',
        'A stock request has been $fulfillmentStatus fulfilled by a Gate Man.',
        'Manager',
      );

      if (overReceivedItems.isNotEmpty) {
        _notifyOverReceipt(requestId, overReceivedItems, allowOverReceipt);
      }

      notifyListeners();
    } catch (e) {
      print("Error fulfilling stock request: $e");
      rethrow;
    }
  }

// Method to check and update partially fulfilled requests
  Future<void> checkAndUpdatePartiallyFulfilledRequests() async {
    try {
      // Check stock requests
      await _checkAndUpdateRequests('stock_requests', isStockRequest: true);

      // Check regular requests
      await _checkAndUpdateRequests('requests', isStockRequest: false);

      notifyListeners();
    } catch (e) {
      print("Error checking and updating partially fulfilled requests: $e");
    }
  }

// Helper method to process requests and update their fulfillment status
  Future<void> _checkAndUpdateRequests(String collectionName,
      {required bool isStockRequest}) async {
    QuerySnapshot partiallyFulfilledRequests = await _firestore
        .collection(collectionName)
        .where('status', isEqualTo: 'partially_fulfilled')
        .get();

    for (QueryDocumentSnapshot doc in partiallyFulfilledRequests.docs) {
      Map<String, dynamic> requestData = doc.data() as Map<String, dynamic>;
      List<dynamic> items = requestData['items'] ?? [];

      // Check if all items in the request are fully fulfilled
      bool isFullyFulfilled = items.every((item) {
        double requestedQuantity = (item['quantity'] as num).toDouble();
        double fulfilledQuantity = isStockRequest
            ? (item['receivedQuantity'] as num?)?.toDouble() ?? 0.0
            : (item['quantityFulfilled'] as num?)?.toDouble() ?? 0.0;
        return fulfilledQuantity >= requestedQuantity;
      });

      if (isFullyFulfilled) {
        await _firestore.collection(collectionName).doc(doc.id).update({
          'status': 'fulfilled',
          'fulfilledAt': FieldValue.serverTimestamp(),
        });

        print(
            "Updated ${isStockRequest ? 'stock request' : 'request'} ${doc.id} from partially_fulfilled to fulfilled");

        // Send notifications
        String createdBy = requestData['createdBy'];
        String? creatorRole = await getUserRole(createdBy);

        String requestType = isStockRequest ? 'Stock Request' : 'Request';

        _sendNotification(
          createdBy,
          '$requestType Fulfilled',
          'Your partially fulfilled $requestType is now completely fulfilled.',
          userRole: creatorRole ?? (isStockRequest ? 'Manager' : 'User'),
        );

        _sendNotificationToRole(
          '$requestType Fulfilled',
          'A partially fulfilled $requestType is now completely fulfilled.',
          'Admin',
        );

        _sendNotificationToRole(
          '$requestType Fulfilled',
          'A partially fulfilled $requestType is now completely fulfilled.',
          'Manager',
        );
      }
    }
  }

  void _notifyOverReceipt(
    String requestId,
    List<Map<String, dynamic>> overReceivedItems,
    bool allowedOverReceipt,
  ) {
    String itemsList = overReceivedItems
        .map((item) =>
            "${item['name']}: ${item['overReceivedQuantity'].toStringAsFixed(2)} ${item['unit']}")
        .join(", ");

    String action = allowedOverReceipt ? "Allowed" : "Attempted";
    String message = "$action over-receipt for stock request (ID: $requestId). "
        "Over-received items: $itemsList";

    _sendNotificationToRole(
      'Stock Request Over-Receipt',
      message,
      'Admin',
      requestId: requestId,
    );

    _sendNotificationToRole(
      'Stock Request Over-Receipt',
      message,
      'Manager',
      requestId: requestId,
    );

    print("Over-receipt notification sent for request $requestId: $message");
  }

  Future<void> correctStockRequest(
      String requestId, List<Map<String, dynamic>> corrections) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference requestRef =
            _firestore.collection('stock_requests').doc(requestId);
        DocumentSnapshot requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('Stock request not found');
        }

        Map<String, dynamic> requestData =
            requestDoc.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(requestData['items']);

        for (var correction in corrections) {
          int index =
              items.indexWhere((item) => item['id'] == correction['id']);
          if (index != -1) {
            double oldReceivedQuantity = items[index]['receivedQuantity'];
            double newReceivedQuantity = correction['correctedQuantity'];
            double quantityDifference =
                newReceivedQuantity - oldReceivedQuantity;

            items[index]['receivedQuantity'] = newReceivedQuantity;
            items[index]['remainingQuantity'] = math.max(
                0.0,
                (items[index]['quantity'] as num).toDouble() -
                    newReceivedQuantity);

            // Update inventory
            await _inventoryProvider.updateInventoryQuantity(
              correction['id'],
              quantityDifference,
              unit: items[index]['isPipe'] ? items[index]['unit'] : null,
            );
          }
        }

        transaction.update(requestRef, {
          'items': items,
          'corrected': true,
          'correctedAt': FieldValue.serverTimestamp(),
        });
      });

      _sendNotificationToRole(
        'Stock Request Corrected',
        'A stock request has been corrected by an admin.',
        'Admin',
      );

      _sendNotificationToRole(
        'Stock Request Corrected',
        'A stock request has been corrected by an admin.',
        'Manager',
      );

      notifyListeners();
    } catch (e) {
      print('Error correcting stock request: $e');
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

  String _formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
    } catch (e) {
      print("Error formatting date: $e");
      return 'Unknown date';
    }
  }

  String _handleTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return _formatDateTime(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return _formatDateTime(timestamp);
    } else {
      print("Unexpected timestamp type: ${timestamp.runtimeType}");
      return 'Unknown date';
    }
  }

  Future<List<Map<String, dynamic>>> _convertQuerySnapshotToList(
      QuerySnapshot snapshot) async {
    List<Map<String, dynamic>> requests = [];
    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Handle timestamp
        if (data.containsKey('timestamp')) {
          data['timestamp'] = _handleTimestamp(data['timestamp']);
        } else {
          print("Document ${doc.id} is missing timestamp");
          data['timestamp'] = 'Unknown date';
        }

        // Fetch user data if not already in the request
        if (data['createdByName'] == null && data['createdBy'] != null) {
          try {
            DocumentSnapshot userDoc = await _firestore
                .collection('users')
                .doc(data['createdBy'])
                .get();
            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              data['createdByName'] = userData['name'] ?? 'Unknown User';
            } else {
              data['createdByName'] = 'Unknown User';
            }
          } catch (e) {
            print("Error fetching user data for document ${doc.id}: $e");
            data['createdByName'] = 'Unknown User';
          }
        }

        print("Request data: $data"); // Debug print
        requests.add(data);
      } catch (e) {
        print("Error processing document ${doc.id}: $e");
        // Continue to the next document
      }
    }
    print("Fetched ${requests.length} requests from Firestore");
    return requests;
  }

  Stream<List<Map<String, dynamic>>> getRequestsStream(
      String userEmail, String userRole, String status) {
    print("Fetching $status requests for user: $userEmail, role: $userRole");
    Query query = _firestore.collection('requests');

    // Only apply status filter if status is not 'All'
    if (status.toLowerCase() != 'all') {
      query = query.where('status', isEqualTo: status.toLowerCase());
    }

    if (userRole == 'Manager' || userRole == 'Admin') {
      // Managers and Admins can see all requests
      query = query.orderBy('timestamp', descending: true);
    } else {
      // Regular users can only see their own requests from the last 7 days
      DateTime sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
      query = query
          .where('createdByEmail', isEqualTo: userEmail)
          .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
          .orderBy('timestamp', descending: true);
    }

    return query.snapshots().asyncMap((snapshot) {
      try {
        return _convertQuerySnapshotToList(snapshot);
      } catch (e) {
        print("Error processing request stream: $e");
        return []; // Return an empty list in case of error
      }
    });
  }

  // Future<List<Map<String, dynamic>>> _convertQuerySnapshotToList(
  //     QuerySnapshot snapshot) async {
  //   List<Map<String, dynamic>> requests = [];
  //   for (var doc in snapshot.docs) {
  //     try {
  //       final data = doc.data() as Map<String, dynamic>;
  //       data['id'] = doc.id;
  //       if (data['timestamp'] is Timestamp) {
  //         DateTime dateTime = (data['timestamp'] as Timestamp).toDate();
  //         data['timestamp'] = _formatDateTime(dateTime);
  //       }

  //       // Fetch user data if not already in the request
  //       if (data['createdByName'] == null && data['createdBy'] != null) {
  //         try {
  //           DocumentSnapshot userDoc = await _firestore
  //               .collection('users')
  //               .doc(data['createdBy'])
  //               .get();
  //           if (userDoc.exists) {
  //             Map<String, dynamic> userData =
  //                 userDoc.data() as Map<String, dynamic>;
  //             data['createdByName'] = userData['name'] ?? 'Unknown User';
  //           }
  //         } catch (e) {
  //           print("Error fetching user data: $e");
  //           data['createdByName'] = 'Unknown User';
  //         }
  //       }

  //       print("Request data: $data"); // Debug print
  //       requests.add(data);
  //     } catch (e) {
  //       print("Error processing document: $e");
  //       // Continue to the next document
  //     }
  //   }
  //   print("Fetched ${requests.length} requests from Firestore");
  //   return requests;
  // }

  Future<Map<String, int>> getRequestCountsByStatus(
      String userEmail, String userRole) async {
    Map<String, int> counts = {
      'pending': 0,
      'approved': 0,
      'partially_fulfilled': 0,
      'fulfilled': 0,
      'completed': 0,
    };

    try {
      Query baseQuery = _firestore.collection('requests');
      if (userRole != 'Manager' && userRole != 'Admin') {
        DateTime sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
        baseQuery = baseQuery
            .where('createdByEmail', isEqualTo: userEmail)
            .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo);
      }

      for (String status in counts.keys) {
        QuerySnapshot snapshot =
            await baseQuery.where('status', isEqualTo: status).get();
        counts[status] = snapshot.docs.length;
      }
    } catch (e) {
      print("Error getting request counts: $e");
      // Return the counts map with all zeros in case of error
    }

    return counts;
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

  Future<Map<String, dynamic>?> getRequestById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('requests').doc(id).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
    } catch (e) {
      print("Error fetching request: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getStockRequestById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('stock_requests').doc(id).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
    } catch (e) {
      print("Error fetching stock request: $e");
    }
    return null;
  }

  Future<void> cancelListeners() async {
    await _requestSubscription?.cancel();
  }

  Future<void> handleRequestCreationNotification(
      String creatorId, String creatorRole, String requestId) async {
    try {
      await _notificationProvider.sendNotification(
        creatorId,
        'Request Created',
        'Your request (ID: $requestId) has been created successfully.',
        userRole: creatorRole,
        requestId: requestId,
      );

      await _notificationProvider.addNotificationForAllUsersWithRole(
        'New Request Created',
        'A new request (ID: $requestId) has been created by a $creatorRole.',
        userRole: 'Admin',
        requestId: requestId,
      );

      if (creatorRole != 'Manager') {
        await _notificationProvider.addNotificationForAllUsersWithRole(
          'New Request Created',
          'A new request (ID: $requestId) has been created by a $creatorRole.',
          userRole: 'Manager',
          requestId: requestId,
        );
      }
    } catch (e) {
      print('Error handling request creation notification: $e');
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

  Future<List<Map<String, dynamic>>> getPendingStockRequests() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('stock_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("Error fetching pending stock requests: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompletedStockRequests() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('stock_requests')
          .where('status', isEqualTo: 'fulfilled')
          .orderBy('fulfilledAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("Error fetching completed stock requests: $e");
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getActiveStockRequestsStream() {
    print("Starting getActiveStockRequestsStream");
    return _firestore
        .collection('stock_requests')
        .where('status', whereIn: ['approved', 'partially_fulfilled'])
        .snapshots()
        .map((snapshot) {
          print("Snapshot received. Document count: ${snapshot.docs.length}");
          List<Map<String, dynamic>> activeRequests = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                print(
                    "Processing stock request: ${doc.id} - ${data['status']}");

                // Check if any items have remaining quantity
                bool hasRemainingItems =
                    (data['items'] as List<dynamic>).any((item) {
                  double totalQuantity = (item['quantity'] as num).toDouble();
                  double receivedQuantity =
                      (item['receivedQuantity'] as num? ?? 0).toDouble();
                  double remainingQuantity = totalQuantity - receivedQuantity;
                  print(
                      "Item: ${item['name']}, Total: $totalQuantity, Received: $receivedQuantity, Remaining: $remainingQuantity");
                  return remainingQuantity > 0;
                });

                // Only return requests that have remaining items
                if (hasRemainingItems) {
                  print(
                      "Request ${doc.id} has remaining items. Including in active list.");
                  return data;
                } else {
                  print(
                      "Request ${doc.id} is fully fulfilled. Excluding from active list.");
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();

          print("Final active requests count: ${activeRequests.length}");
          return activeRequests;
        });
  }

  Stream<List<Map<String, dynamic>>> getApprovedStockRequestsStream() {
    return _firestore
        .collection('stock_requests')
        .where('status', whereIn: ['approved', 'partially_fulfilled'])
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
    _listenerManager
        .cancelAllListeners(); // Cancel all listeners when the provider is disposed
    _requestSubscription?.cancel();
    cancelListeners();
    stopAutoRefresh();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
}

class CustomException implements Exception {
  final String message;
  CustomException(this.message);
  @override
  String toString() => message;
}
