import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationProvider _notificationProvider;
  final InventoryProvider _inventoryProvider;
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

  Future<void> updateRequestStatus(String id, String status) async {
    try {
      await _firestore
          .collection('requests')
          .doc(id)
          .update({'status': status});
      final request = await _firestore.collection('requests').doc(id).get();
      final requestData = request.data() as Map<String, dynamic>;
      final userId = requestData['createdBy'];
      final String? userRole = await getUserRole(userId);

      switch (status) {
        case 'approved':
          _notificationProvider.sendNotification(
            userId,
            'Request Approved',
            'Your request has been approved.',
            userRole: userRole ?? 'User',
            requestId: id,
          );
          _notificationProvider.addNotificationForRole(
            'New Approved Request',
            'A new request has been approved and is ready for fulfillment.',
            'Gate Man',
            requestId: id,
          );
          break;
        case 'rejected':
          _notificationProvider.sendNotification(
            userId,
            'Request Rejected',
            'Your request has been rejected.',
            userRole: userRole ?? 'User',
            requestId: id,
          );
          break;
        case 'fulfilled':
          _notificationProvider.sendNotification(
            userId,
            'Request Fulfilled',
            'Your request has been fulfilled.',
            userRole: userRole ?? 'User',
            requestId: id,
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
        'receivedAt': null, // New field for receiving date
      });

      String requestId = docRef.id;
      String? userRole = await getUserRole(createdBy);

      _sendNotification(
        createdBy,
        'Stock Request Created',
        'Your stock request (ID: $requestId) has been successfully created on ${DateTime.now().toString()} and is pending approval.',
        userRole: userRole ?? 'Manager',
        requestId: requestId,
      );

      _sendNotificationToRole(
        'New Stock Request',
        'A new stock request (ID: $requestId) has been created by a manager on ${DateTime.now().toString()} and is waiting for your approval.',
        'Admin',
        requestId: requestId,
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
          updateData['receivedAt'] =
              FieldValue.serverTimestamp(); // Set receiving date when fulfilled
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
            'Your stock request (ID: $id) has been approved on ${DateTime.now().toString()}.',
            userRole: userRole ?? 'Manager',
            requestId: id,
          );
          _sendNotificationToRole(
            'New Approved Stock Request',
            'A new stock request (ID: $id) has been approved on ${DateTime.now().toString()} and is ready for fulfillment.',
            'Gate Man',
            requestId: id,
          );
          break;
        case 'rejected':
          _sendNotification(
            createdBy,
            'Stock Request Rejected',
            'Your stock request (ID: $id) has been rejected on ${DateTime.now().toString()}. Reason: ${rejectionReason ?? "Not provided"}',
            userRole: userRole ?? 'Manager',
            requestId: id,
          );
          break;
        case 'fulfilled':
          _sendNotification(
            createdBy,
            'Stock Request Fulfilled',
            'Your stock request (ID: $id) has been fulfilled and items were received on ${DateTime.now().toString()}.',
            userRole: userRole ?? 'Manager',
            requestId: id,
          );
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Error updating stock request status: $e');
      rethrow;
    }
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
  Future<void> fulfillStockRequest(
    String requestId,
    List<Map<String, dynamic>> receivedItems,
    String gateManId,
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
        List<Map<String, dynamic>> updatedItems = [];

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
          double remainingQuantity = requestedQuantity - totalReceived;

          bool isPipe = originalItem['isPipe'] as bool? ?? false;
          String unit = originalItem['unit'] as String? ?? 'N/A';
          double pipeLength =
              (originalItem['pipeLength'] as num?)?.toDouble() ?? 20.0;

          double totalReceivedLength = totalReceived;
          double remainingLength = remainingQuantity;

          if (isPipe && unit == 'pcs') {
            totalReceivedLength = totalReceived * pipeLength;
            remainingLength = remainingQuantity * pipeLength;
          }

          updatedItems.add({
            ...originalItem,
            'receivedQuantity': totalReceived,
            'remainingQuantity': remainingQuantity,
            'totalReceivedLength': totalReceivedLength,
            'remainingLength': remainingLength,
          });

          if (remainingQuantity > 0) {
            isFullyFulfilled = false;
          }

          // Update inventory if needed
          if (newlyReceived > 0) {
            String? itemId = originalItem['id'] as String?;
            if (itemId != null && itemId.isNotEmpty) {
              await _inventoryProvider.updateInventoryQuantity(
                itemId,
                newlyReceived,
                unit: isPipe ? unit : null,
              );
            }
          }
        }

        String newStatus =
            isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';
        transaction
            .update(_firestore.collection('stock_requests').doc(requestId), {
          'items': updatedItems,
          'status': newStatus,
          'lastUpdated': FieldValue.serverTimestamp(),
          'fulfilledBy': gateManId,
          'fulfilledAt': FieldValue.serverTimestamp(),
        });

        print("Transaction completed. New status: $newStatus");
      }, timeout: Duration(seconds: 30));

      // Fetch the updated stock request data
      final updatedStockRequest =
          await _firestore.collection('stock_requests').doc(requestId).get();
      final updatedStockRequestData =
          updatedStockRequest.data() as Map<String, dynamic>;
      final createdBy = updatedStockRequestData['createdBy'];
      String? creatorRole = await getUserRole(createdBy);
      String fulfillmentStatus = isFullyFulfilled ? 'fully' : 'partially';

      _sendNotification(
        createdBy,
        'Stock Request $fulfillmentStatus Fulfilled',
        'Your stock request (ID: $requestId) has been $fulfillmentStatus fulfilled by a Gate Man.',
        userRole: creatorRole ?? 'Manager',
        requestId: requestId,
      );

      _sendNotificationToRole(
        'Stock Request $fulfillmentStatus Fulfilled',
        'Stock request (ID: $requestId) has been $fulfillmentStatus fulfilled by a Gate Man.',
        'Admin',
        requestId: requestId,
      );

      _sendNotificationToRole(
        'Stock Request $fulfillmentStatus Fulfilled',
        'Stock request (ID: $requestId) has been $fulfillmentStatus fulfilled by a Gate Man.',
        'Manager',
        requestId: requestId,
        excludeUserId: creatorRole == 'Manager' ? createdBy : null,
      );

      notifyListeners();
    } catch (e) {
      print("Error fulfilling stock request: $e");
      rethrow;
    }
  }

  void _sendNotification(String userId, String title, String body,
      {required String userRole, String? requestId}) {
    try {
      _notificationProvider.sendNotification(
        userId,
        title,
        body,
        userRole: userRole,
        requestId: requestId,
      );
    } catch (e) {
      print("Error sending notification: $e");
      // Consider whether to rethrow or just log the error
    }
  }

  void _sendNotificationToRole(String title, String body, String role,
      {String? requestId, String? excludeUserId}) {
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
      // Consider whether to rethrow or just log the error
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
      List<Map<String, dynamic>> updatedItems = List.from(items);

      late String requestId;

      await _firestore.runTransaction<void>(
        (transaction) async {
          print("Starting transaction for new request");

          List<DocumentSnapshot> inventorySnapshots = await Future.wait(
            updatedItems.map((item) => transaction
                .get(_firestore.collection('inventory').doc(item['id']))),
          );

          for (int i = 0; i < updatedItems.length; i++) {
            var item = updatedItems[i];
            var inventorySnapshot = inventorySnapshots[i];

            print("Processing item: ${item['name']}, ID: ${item['id']}");

            if (inventorySnapshot.exists) {
              Map<String, dynamic> inventoryData =
                  inventorySnapshot.data() as Map<String, dynamic>;
              double currentQuantity =
                  (inventoryData['quantity'] as num?)?.toDouble() ?? 0.0;
              bool isPipe = item['isPipe'] == true;
              double pipeLength = isPipe
                  ? (inventoryData['pipeLength'] as num?)?.toDouble() ?? 1.0
                  : 0.0;

              if (isPipe) {
                // ... (pipe logic remains the same)
              } else {
                // Non-pipe items (unchanged)
                double requestedQuantity =
                    (item['quantity'] as num?)?.toDouble() ?? 0.0;
                double fulfillableQuantity =
                    math.min(currentQuantity, requestedQuantity);

                transaction.update(
                  _firestore.collection('inventory').doc(item['id']),
                  {'quantity': FieldValue.increment(-fulfillableQuantity)},
                );

                item['quantityFulfilled'] = fulfillableQuantity;
                item['quantityPending'] =
                    math.max(0, requestedQuantity - fulfillableQuantity);
              }
            } else {
              print("Inventory item not found: ${item['id']}");
              if (item['isPipe'] == true) {
                item['pcsFulfilled'] = 0;
                item['metersFulfilled'] = 0.0;
                item['pcsPending'] = item['pcs'] ?? 0;
                item['metersPending'] = item['meters'] ?? 0.0;
              } else {
                item['quantityFulfilled'] = 0.0;
                item['quantityPending'] = item['quantity'] ?? 0.0;
              }
            }
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

      await _notifyManagersAndAdmins(requestId, user.email ?? 'Unknown');

      notifyListeners();
      await inventoryProvider.fetchItems();
      print("Request creation process completed successfully");

      return requestId;
    } catch (e) {
      print("Error in addRequest: $e");
      print("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

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

        // Get the request snapshot
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

        // Fetch all relevant inventory items
        List<DocumentSnapshot> inventorySnapshots = await Future.wait(
          newItems.map((item) => transaction
              .get(_firestore.collection('inventory').doc(item['id']))),
        );

        List<Map<String, dynamic>> updatedItems = [];
        Map<String, int> inventoryAdjustments = {};

        // Restore previous inventory quantities
        for (var oldItem in oldItems) {
          int quantityFulfilled =
              (oldItem['quantityFulfilled'] as num?)?.toInt() ?? 0;
          if (quantityFulfilled > 0) {
            inventoryAdjustments[oldItem['id']] =
                (inventoryAdjustments[oldItem['id']] ?? 0) + quantityFulfilled;
          }

          // Handle restoring for pipes
          if (oldItem['isPipe'] == true) {
            int pcsFulfilled = (oldItem['pcs'] as num?)?.toInt() ?? 0;
            if (pcsFulfilled > 0) {
              inventoryAdjustments[oldItem['id']] =
                  (inventoryAdjustments[oldItem['id']] ?? 0) + pcsFulfilled;
            }
          }
        }

        // Process new items
        for (int i = 0; i < newItems.length; i++) {
          var newItem = newItems[i];
          var inventorySnapshot = inventorySnapshots[i];

          print("Processing item: ${newItem['name']}, ID: ${newItem['id']}");

          if (inventorySnapshot.exists) {
            var rawQuantity = inventorySnapshot.get('quantity');
            print("Raw inventory quantity: $rawQuantity");
            int currentQuantity = (rawQuantity as num?)?.toInt() ?? 0;

            // Determine quantities for non-pipe items
            if (newItem['isPipe'] != true) {
              var rawRequestedQuantity = newItem['quantity'];
              print("Raw requested quantity: $rawRequestedQuantity");
              int requestedQuantity =
                  (rawRequestedQuantity as num?)?.toInt() ?? 0;

              print(
                  "Current quantity: $currentQuantity, Requested quantity: $requestedQuantity");

              int fulfillableQuantity =
                  math.min(currentQuantity, requestedQuantity);
              print("Fulfillable quantity: $fulfillableQuantity");

              updatedItems.add({
                ...newItem,
                'quantityFulfilled': fulfillableQuantity,
                'quantityPending':
                    math.max(0, requestedQuantity - fulfillableQuantity),
              });

              inventoryAdjustments[newItem['id']] =
                  (inventoryAdjustments[newItem['id']] ?? 0) -
                      fulfillableQuantity;
            } else {
              // Handle pipe-specific logic
              double pipeLength = newItem['pipeLength'] as double? ?? 20.0;
              var rawRequestedPcs = newItem['pcs'];
              var rawRequestedMeters = newItem['meters'];
              int requestedPcs = (rawRequestedPcs as num?)?.toInt() ?? 0;
              double requestedMeters =
                  (rawRequestedMeters as num?)?.toDouble() ?? 0.0;

              int fulfillablePcs = math.min(currentQuantity, requestedPcs);
              double fulfillableMeters = fulfillablePcs * pipeLength;

              // Adjust for meters if requested
              if (requestedMeters > 0) {
                fulfillableMeters =
                    math.min(currentQuantity * pipeLength, requestedMeters);
                fulfillablePcs = (fulfillableMeters / pipeLength).floor();
              }

              updatedItems.add({
                ...newItem,
                'pcsFulfilled': fulfillablePcs,
                'metersFulfilled': fulfillableMeters,
                'pcsPending': math.max(0, requestedPcs - fulfillablePcs),
                'metersPending':
                    math.max(0, requestedMeters - fulfillableMeters),
              });

              inventoryAdjustments[newItem['id']] =
                  (inventoryAdjustments[newItem['id']] ?? 0) - fulfillablePcs;
            }
          } else {
            // If inventory item does not exist
            print("Inventory item not found: ${newItem['id']}");
            updatedItems.add({
              ...newItem,
              'quantityFulfilled': 0,
              'quantityPending': newItem['quantity'] ?? 0,
              'pcsFulfilled': 0,
              'metersFulfilled': 0.0,
              'pcsPending': newItem['pcs'] ?? 0,
              'metersPending': newItem['meters'] ?? 0.0,
            });
          }
        }

        print("Updated items: $updatedItems");
        print("Inventory adjustments: $inventoryAdjustments");

        // Update the request document
        transaction.update(_firestore.collection('requests').doc(requestId), {
          'items': updatedItems,
          'location': location,
          'pickerName': pickerName,
          'pickerContact': pickerContact,
          'note': note,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Apply inventory adjustments
        for (var update in inventoryAdjustments.entries) {
          transaction.update(
            _firestore.collection('inventory').doc(update.key),
            {'quantity': FieldValue.increment(update.value)},
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

  Stream<List<Map<String, dynamic>>>
      getRecentApprovedAndFulfilledRequestsStream() {
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

  Stream<List<Map<String, dynamic>>> getRecentFulfilledRequestsStream() {
    final twoDaysAgo = DateTime.now().subtract(Duration(days: 2));

    print("Starting getRecentFulfilledRequestsStream");
    print("Two days ago: ${twoDaysAgo.toIso8601String()}");

    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'fulfilled')
        .where('fulfilledAt', isGreaterThanOrEqualTo: twoDaysAgo)
        .orderBy('fulfilledAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print("Snapshot received. Document count: ${snapshot.docs.length}");

      if (snapshot.docs.isEmpty) {
        print("No documents found in the snapshot");
      }

      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        print("Processing document ${doc.id}:");
        print("  Status: ${data['status']}");
        print("  FulfilledAt: ${data['fulfilledAt']}");

        if (data['fulfilledAt'] is Timestamp) {
          data['fulfilledAt'] = (data['fulfilledAt'] as Timestamp).toDate();
          print("  Converted fulfilledAt: ${data['fulfilledAt']}");
        } else {
          print("  fulfilledAt is not a Timestamp: ${data['fulfilledAt']}");
        }

        return data;
      }).toList();

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
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'fulfilled',
        'fulfilledAt': FieldValue.serverTimestamp(),
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
        'fulfilledAt': FieldValue.serverTimestamp(),
      });

      print("Request fulfilled successfully: $requestId");

      // Send notifications (keep the existing notification code)

      notifyListeners();

      // Refresh the fulfilled requests list
      await refreshFulfilledRequests();
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

  Stream<List<Map<String, dynamic>>> getActiveStockRequestsStream() {
    print("Starting getActiveStockRequestsStream");
    return _firestore
        .collection('stock_requests')
        .where('status', whereIn: ['approved', 'partially_fulfilled'])
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
    cancelListeners();
    stopAutoRefresh();
    super.dispose();
  }
}

class CustomException implements Exception {
  final String message;
  CustomException(this.message);
  @override
  String toString() => message;
}
