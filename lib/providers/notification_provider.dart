import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dhavla_road_project/screens/common/global_keys.dart';
import 'package:dhavla_road_project/screens/common/request_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

class LoggingService {
  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp - $message\n';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');
      await file.writeAsString(logMessage, mode: FileMode.append);
      print(logMessage);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }
}

class Notification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime timestamp;
  final String userRole;
  final String? requestId;
  bool isRead;
  final DateTime expirationDate;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.userRole,
    this.requestId,
    this.isRead = false,
    required this.expirationDate,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      userRole: map['userRole'] as String,
      requestId: map['requestId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      expirationDate: (map['expirationDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'userRole': userRole,
      'isRead': isRead,
      'expirationDate': Timestamp.fromDate(expirationDate),
    };
    if (requestId != null) {
      map['requestId'] = requestId as Object;
    }
    return map;
  }

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    DateTime? timestamp,
    String? userRole,
    String? requestId,
    bool? isRead,
    DateTime? expirationDate,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      userRole: userRole ?? this.userRole,
      requestId: requestId ?? this.requestId,
      isRead: isRead ?? this.isRead,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  List<Notification> _notifications = [];
  final _unreadCountController = StreamController<int>.broadcast();

  NotificationProvider() {
    _initFCM();
  }

  Future<void> _initFCM() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleFCMMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMMessageOpenedApp);
      await _initializeLocalNotifications();

      if (Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null) {
          LoggingService.log('APNS Token: $apnsToken');
        } else {
          LoggingService.log('Failed to get APNS token');
        }
      }

      String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        LoggingService.log('FCM Token: $fcmToken');
        await _updateFCMToken(fcmToken);
      } else {
        LoggingService.log('Failed to get FCM token');
      }
    } catch (e) {
      LoggingService.log('Error initializing FCM: $e');
    }
  }

  Future<void> _updateFCMToken(String token) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        LoggingService.log('FCM Token updated in Firestore successfully');
      } else {
        LoggingService.log('Error: User ID is null, cannot update FCM token');
      }
    } catch (e) {
      LoggingService.log('Error updating FCM token: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  void _handleFCMMessage(RemoteMessage message) {
    LoggingService.log('Handling a foreground message: ${message.messageId}');
    _showLocalNotification(message);
    fetchNotifications(
        message.data['userId'] ?? '', message.data['userRole'] ?? '');
  }

  void _handleFCMMessageOpenedApp(RemoteMessage message) {
    LoggingService.log('A new onMessageOpenedApp event was published!');
    if (message.data['requestId'] != null) {
      navigateToRequestDetails(
          message.data['requestId'], message.data['isStockRequest'] == 'true');
    }
  }

  void navigateToRequestDetails(String requestId, bool isStockRequest) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          requestId: requestId,
          isStockRequest: isStockRequest,
        ),
      ),
    );
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    LoggingService.log('Notification tapped: ${response.payload}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        platformChannelSpecifics,
        payload: message.data['requestId'],
      );
    } catch (e) {
      LoggingService.log('Error showing local notification: $e');
    }
  }

  Future<void> fetchNotifications(String userId, String userRole) async {
    try {
      LoggingService.log(
          "Fetching notifications for user: $userId, role: $userRole");
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userRole', whereIn: [userRole, 'All'])
          .where('expirationDate', isGreaterThan: Timestamp.now())
          .orderBy('expirationDate', descending: true)
          .orderBy('timestamp', descending: true)
          .get();

      _notifications = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Notification.fromMap(data);
      }).toList();

      LoggingService.log("Fetched ${_notifications.length} notifications");
      await updateUnreadCount(userId, userRole);
      notifyListeners();
    } catch (e) {
      LoggingService.log('Error fetching notifications: $e');
      rethrow;
    }
  }

  Stream<List<Notification>> getNotificationsStream(
      String userId, String userRole) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('userRole', whereIn: [userRole, 'All'])
        .where('expirationDate', isGreaterThan: Timestamp.now())
        .orderBy('expirationDate', descending: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;
            return Notification.fromMap(data);
          }).toList();
        });
  }

  Future<void> markAsRead(
      String notificationId, String userId, String userRole) async {
    LoggingService.log(
        'Attempting to mark notification as read: $notificationId');
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference notificationRef =
            _firestore.collection('notifications').doc(notificationId);
        DocumentSnapshot notificationDoc =
            await transaction.get(notificationRef);

        if (!notificationDoc.exists) {
          LoggingService.log('Notification does not exist');
          _notifications.removeWhere((n) => n.id == notificationId);
          return;
        }

        transaction.update(notificationRef, {'isRead': true});

        int index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index].isRead = true;
        }
      });

      LoggingService.log('Notification marked as read successfully');
      await updateUnreadCount(userId, userRole);
      notifyListeners();
    } catch (e) {
      LoggingService.log('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> addNotification(Notification notification) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference docRef = _firestore.collection('notifications').doc();
        String notificationId = docRef.id;

        Notification updatedNotification =
            notification.copyWith(id: notificationId);

        transaction.set(docRef, updatedNotification.toMap());

        _notifications.insert(0, updatedNotification);
      });

      await updateUnreadCount(notification.userId, notification.userRole);
      notifyListeners();

      LoggingService.log('Notification added with ID: ${notification.id}');
      await _sendFCMThroughCloudFunction(notification);
    } catch (e) {
      LoggingService.log('Error adding notification: $e');
      rethrow;
    }
  }

  Future<void> _sendFCMThroughCloudFunction(Notification notification) async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('sendFCMNotification');
      final result = await callable.call({
        'userId': notification.userId,
        'title': notification.title,
        'body': notification.body,
        'userRole': notification.userRole,
        'requestId': notification.requestId,
      });
      LoggingService.log('Cloud Function result: ${result.data}');
    } catch (e) {
      LoggingService.log('Error sending FCM through Cloud Function: $e');
    }
  }

  Future<void> sendNotification(String userId, String title, String body,
      {required String userRole, String? requestId}) async {
    try {
      await addNotification(Notification(
        id: UniqueKey().toString(),
        userId: userId,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        userRole: userRole,
        requestId: requestId,
        expirationDate: DateTime.now().add(Duration(days: 7)),
      ));

      try {
        final HttpsCallable callable =
            FirebaseFunctions.instanceFor(region: 'asia-south1')
                .httpsCallable('sendFCMNotification');
        String uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        final result = await callable.call({
          'userId': userId,
          'title': title,
          'body': body,
          'userRole': userRole,
          'requestId': requestId,
          'uniqueId': uniqueId,
        });
        LoggingService.log('Cloud Function result: ${result.data}');
      } catch (e) {
        LoggingService.log('Error calling Cloud Function: $e');
      }
    } catch (e) {
      LoggingService.log('Error sending notification: $e');
    }
  }

  Future<void> addNotificationForAllUsersWithRole(String title, String body,
      {required String userRole, String? requestId}) async {
    try {
      QuerySnapshot users = await _firestore
          .collection('users')
          .where('role', isEqualTo: userRole)
          .get();
      List<Future<void>> notificationFutures = [];
      for (var userDoc in users.docs) {
        String userId = userDoc.id;
        notificationFutures.add(sendNotification(userId, title, body,
            userRole: userRole, requestId: requestId));
      }
      await Future.wait(notificationFutures);
      LoggingService.log('Notifications sent to all users with role $userRole');
    } catch (e) {
      LoggingService.log('Error adding notification for all $userRole: $e');
    }
  }

  Future<void> handleRequestCreationNotification(
      String creatorId, String creatorRole, String requestId) async {
    try {
      await sendNotification(
        creatorId,
        'Request Created',
        'Your request (ID: $requestId) has been created successfully.',
        userRole: creatorRole,
        requestId: requestId,
      );

      await addNotificationForAllUsersWithRole(
        'New Request Created',
        'A new request (ID: $requestId) has been created by a $creatorRole.',
        userRole: 'Admin',
        requestId: requestId,
      );

      if (creatorRole != 'Manager') {
        await addNotificationForAllUsersWithRole(
          'New Request Created',
          'A new request (ID: $requestId) has been created by a $creatorRole.',
          userRole: 'Manager',
          requestId: requestId,
        );
      }
    } catch (e) {
      LoggingService.log('Error handling request creation notification: $e');
    }
  }

  Future<void> handleRequestStatusUpdateNotification(String requestId,
      String newStatus, String updaterId, String updaterRole) async {
    try {
      DocumentSnapshot requestDoc =
          await _firestore.collection('requests').doc(requestId).get();
      String creatorId = requestDoc['createdBy'];
      String creatorRole = requestDoc['creatorRole'] ?? 'User';

      await sendNotification(
        creatorId,
        'Request Status Updated',
        'Your request (ID: $requestId) has been $newStatus.',
        userRole: creatorRole,
        requestId: requestId,
      );

      await addNotificationForAllUsersWithRole(
        'Request Status Updated',
        'Request (ID: $requestId) has been $newStatus by a $updaterRole.',
        userRole: 'Admin',
        requestId: requestId,
      );

      if (updaterRole != 'Manager') {
        await addNotificationForAllUsersWithRole(
          'Request Status Updated',
          'Request (ID: $requestId) has been $newStatus by a $updaterRole.',
          userRole: 'Manager',
          requestId: requestId,
        );
      }
    } catch (e) {
      LoggingService.log(
          'Error handling request status update notification: $e');
    }
  }

  Future<void> subscribeToTopics(List<String> topics) async {
    for (String topic in topics) {
      try {
        await _firebaseMessaging.subscribeToTopic(topic.toLowerCase());
        LoggingService.log('Subscribed to topic: $topic');
      } catch (e) {
        LoggingService.log('Error subscribing to topic $topic: $e');
      }
    }
  }

  Future<void> unsubscribeFromTopics(List<String> topics) async {
    for (String topic in topics) {
      try {
        await _firebaseMessaging.unsubscribeFromTopic(topic.toLowerCase());
        LoggingService.log('Unsubscribed from topic: $topic');
      } catch (e) {
        LoggingService.log('Error unsubscribing from topic $topic: $e');
      }
    }
  }

  Future<void> clearAllNotifications(String userId, String userRole) async {
    try {
      QuerySnapshot notificationsToDelete = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (DocumentSnapshot doc in notificationsToDelete.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _notifications.removeWhere((n) => n.userId == userId);
      await updateUnreadCount(userId, userRole);
      notifyListeners();
      LoggingService.log('Cleared all notifications for user: $userId');
    } catch (e) {
      LoggingService.log('Error clearing all notifications: $e');
    }
  }

  Future<void> updateFCMToken(String userId, String newToken) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
      });
      LoggingService.log('FCM token updated for user: $userId');
    } catch (e) {
      LoggingService.log('Error updating FCM token: $e');
    }
  }

  List<Notification> getRelevantNotifications(String userId, String userRole) {
    return _notifications.where((notification) {
      if (notification.userId == userId) return true;
      if ((userRole == 'Manager' && notification.userRole == 'Manager') ||
          (userRole == 'Admin' && notification.userRole == 'Admin')) {
        return true;
      }
      return false;
    }).toList();
  }

  int getUnreadNotificationsCount(String userId, String userRole) {
    return _notifications
        .where((n) => !n.isRead && n.userId == userId && n.userRole == userRole)
        .length;
  }

  Stream<int> getUnreadNotificationsCountStream(
      String userId, String userRole) {
    LoggingService.log(
        "Getting unread count stream for user: $userId, role: $userRole");
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('userRole', whereIn: [userRole, 'All'])
        .where('isRead', isEqualTo: false)
        .where('expirationDate', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
          int count = snapshot.docs.length;
          LoggingService.log("Unread count from Firestore: $count");
          return count;
        });
  }

  Future<void> updateUnreadCount(String userId, String userRole) async {
    try {
      LoggingService.log(
          "Updating unread count for user: $userId, role: $userRole");
      QuerySnapshot unreadSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userRole', whereIn: [userRole, 'All'])
          .where('isRead', isEqualTo: false)
          .where('expirationDate', isGreaterThan: Timestamp.now())
          .get();

      int unreadCount = unreadSnapshot.docs.length;
      LoggingService.log(
          "Updated unread count for user $userId, role $userRole: $unreadCount");
      _unreadCountController.add(unreadCount);
      notifyListeners();
    } catch (e) {
      LoggingService.log("Error updating unread count: $e");
    }
  }

  Future<void> addNotificationForRole(String title, String body, String role,
      {String? requestId, String? excludeUserId}) async {
    try {
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      for (var userDoc in userSnapshot.docs) {
        if (userDoc.id != excludeUserId) {
          await sendNotification(
            userDoc.id,
            title,
            body,
            userRole: role,
            requestId: requestId,
          );
        }
      }
      LoggingService.log(
          'Notifications sent to all users with role $role (excluding $excludeUserId)');
    } catch (e) {
      LoggingService.log('Error adding notification for role $role: $e');
    }
  }

  Future<void> sendTestNotification(String userId, String userRole) async {
    try {
      LoggingService.log(
          'Sending test notification for user: $userId, role: $userRole');
      final HttpsCallable callable =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('sendFCMNotification');
      final result = await callable.call({
        'userId': userId,
        'title': 'Test Notification',
        'body': 'This is a test notification sent from the app',
        'userRole': userRole,
        'requestId': 'test-request-id',
      });
      LoggingService.log('Test notification sent. Result: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      LoggingService.log('Firebase Functions error: [${e.code}] ${e.message}');
      LoggingService.log('Error details: ${e.details}');
      rethrow;
    } catch (e) {
      LoggingService.log('Unexpected error sending test notification: $e');
      rethrow;
    }
  }

  Future<void> testCloudFunction() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('testFunction');
      final result = await callable.call();
      LoggingService.log('Test function result: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      LoggingService.log('Cloud Functions error: [${e.code}] ${e.message}');
      LoggingService.log('Error details: ${e.details}');
    } catch (e) {
      LoggingService.log('Unexpected error testing Cloud Function: $e');
    }
  }

  Future<void> simulateIncomingNotification(
      String userId, String title, String body,
      {required String userRole, String? requestId}) async {
    await addNotification(Notification(
      id: UniqueKey().toString(),
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      userRole: userRole,
      requestId: requestId,
      expirationDate: DateTime.now().add(Duration(days: 7)),
    ));

    _handleFCMMessage(RemoteMessage(
      data: {
        'userId': userId,
        'userRole': userRole,
        'requestId': requestId,
      },
      notification: RemoteNotification(
        title: title,
        body: body,
      ),
    ));
  }

  Future<void> testCloudFunctionCall(String userId, String title, String body,
      {required String userRole, String? requestId}) async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('sendFCMNotification');
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'userRole': userRole,
        'requestId': requestId,
      });
      LoggingService.log('Cloud Function result: ${result.data}');
    } catch (e) {
      LoggingService.log('Error calling Cloud Function: $e');
    }
  }

  Future<void> refreshNotifications(String userId, String userRole) async {
    try {
      LoggingService.log(
          "Refreshing notifications for user: $userId, role: $userRole");
      await fetchNotifications(userId, userRole);
      notifyListeners();
    } catch (e) {
      LoggingService.log('Error refreshing notifications: $e');
      rethrow;
    }
  }

  Future<Notification?> getNotificationById(String notificationId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();
      if (doc.exists) {
        return Notification.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      LoggingService.log('Error getting notification by ID: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(
      String notificationId, String userId, String userRole) async {
    LoggingService.log(
        'Attempting to delete notification: $notificationId for user: $userId, role: $userRole');
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference notificationRef =
            _firestore.collection('notifications').doc(notificationId);
        DocumentSnapshot notificationDoc =
            await transaction.get(notificationRef);

        if (!notificationDoc.exists) {
          LoggingService.log(
              'Notification does not exist in Firestore: $notificationId');
          return;
        }

        transaction.delete(notificationRef);

        _notifications.removeWhere((n) => n.id == notificationId);
      });

      await updateUnreadCount(userId, userRole);
      notifyListeners();
      LoggingService.log('Notification fully deleted and state updated');
    } catch (e) {
      LoggingService.log('Error deleting notification $notificationId: $e');
      rethrow;
    }
  }

  Future<void> markAllNotificationsAsRead(
      String userId, String userRole) async {
    try {
      WriteBatch batch = _firestore.batch();
      QuerySnapshot unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userRole', whereIn: [userRole, 'All'])
          .where('isRead', isEqualTo: false)
          .get();

      for (DocumentSnapshot doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      _notifications
          .where((n) => n.userId == userId && !n.isRead)
          .forEach((n) => n.isRead = true);
      await updateUnreadCount(userId, userRole);
      notifyListeners();
      LoggingService.log('All notifications marked as read for user: $userId');
    } catch (e) {
      LoggingService.log('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _unreadCountController.close();
    super.dispose();
  }
}

