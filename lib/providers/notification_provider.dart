import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
}

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<Notification> _notifications = [];

  List<Notification> get notifications => _notifications;

  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _initFCM();
  }

  Future<void> _initFCM() async {
    // await _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen(_handleFCMMessage);
    await _initializeLocalNotifications();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    // await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _handleFCMMessage(RemoteMessage message) {
    _showLocalNotification(message);
    fetchNotifications(
        message.data['userId'] ?? '', message.data['userRole'] ?? '');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
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
  }

  Future<void> fetchNotifications(String userId, String userRole) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('userRole', isEqualTo: userRole)
          .where('expirationDate', isGreaterThan: Timestamp.now())
          .orderBy('expirationDate', descending: true)
          .orderBy('timestamp', descending: true)
          .get();

      _notifications =
          snapshot.docs.map((doc) => Notification.fromMap(doc.data())).toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index].isRead = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> addNotification(Notification notification) async {
    try {
      await _firestore.collection('notifications').add(notification.toMap());
      _notifications.insert(0, notification);
      notifyListeners();

      await _sendFCMMessage(notification);
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  Future<void> _sendFCMMessage(Notification notification) async {
    try {
      final data = {
        'title': notification.title,
        'body': notification.body,
        'userId': notification.userId,
        'userRole': notification.userRole,
      };

      if (notification.requestId != null) {
        data['requestId'] = notification.requestId!;
      }

      await _firebaseMessaging.sendMessage(
        to: '/topics/${notification.userRole.toLowerCase()}',
        data: data,
      );
    } catch (e) {
      print('Error sending FCM message: $e');
    }
  }

  Future<void> addUserNotification(String userId, String title, String body,
      {String? requestId}) async {
    await addNotification(Notification(
      id: UniqueKey().toString(),
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      userRole: 'User',
      requestId: requestId,
      expirationDate: DateTime.now().add(Duration(days: 7)),
    ));
  }

  Future<void> addManagerNotification(String userId, String title, String body,
      {String? requestId}) async {
    await addNotification(Notification(
      id: UniqueKey().toString(),
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      userRole: 'Manager',
      requestId: requestId,
      expirationDate: DateTime.now().add(Duration(days: 7)),
    ));
  }

  Future<void> addGatemanNotification(String userId, String title, String body,
      {String? requestId}) async {
    await addNotification(Notification(
      id: UniqueKey().toString(),
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      userRole: 'Gate Man',
      requestId: requestId,
      expirationDate: DateTime.now().add(Duration(days: 7)),
    ));
  }

  Future<void> addAdminNotification(String userId, String title, String body,
      {String? requestId}) async {
    await addNotification(Notification(
      id: UniqueKey().toString(),
      userId: userId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      userRole: 'Admin',
      requestId: requestId,
      expirationDate: DateTime.now().add(Duration(days: 7)),
    ));
  }

  Future<void> addNotificationForAllAdmins(String title, String body,
      {String? requestId}) async {
    try {
      QuerySnapshot adminUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Admin')
          .get();

      for (var adminDoc in adminUsers.docs) {
        String adminId = adminDoc.id;
        await addAdminNotification(adminId, title, body, requestId: requestId);
      }
    } catch (e) {
      print('Error adding notification for all admins: $e');
    }
  }

  Future<void> addNotificationForAllManagers(String title, String body,
      {String? requestId}) async {
    try {
      QuerySnapshot managerUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Manager')
          .get();

      for (var managerDoc in managerUsers.docs) {
        String managerId = managerDoc.id;
        await addManagerNotification(managerId, title, body,
            requestId: requestId);
      }
    } catch (e) {
      print('Error adding notification for all managers: $e');
    }
  }

  Future<void> handleRequestCreationNotification(
      String creatorId, String creatorRole, String requestId) async {
    await addUserNotification(creatorId, 'Request Created',
        'Your request (ID: $requestId) has been created successfully.',
        requestId: requestId);

    await addNotificationForAllAdmins('New Request Created',
        'A new request (ID: $requestId) has been created by a $creatorRole.',
        requestId: requestId);

    if (creatorRole != 'Manager') {
      await addNotificationForAllManagers('New Request Created',
          'A new request (ID: $requestId) has been created by a $creatorRole.',
          requestId: requestId);
    }
  }

  Future<void> handleRequestStatusUpdateNotification(String requestId,
      String newStatus, String updaterId, String updaterRole) async {
    DocumentSnapshot requestDoc =
        await _firestore.collection('requests').doc(requestId).get();
    String creatorId = requestDoc['createdBy'];

    await addUserNotification(creatorId, 'Request Status Updated',
        'Your request (ID: $requestId) has been $newStatus.',
        requestId: requestId);

    await addNotificationForAllAdmins('Request Status Updated',
        'Request (ID: $requestId) has been $newStatus by a $updaterRole.',
        requestId: requestId);

    if (updaterRole != 'Manager') {
      await addNotificationForAllManagers('Request Status Updated',
          'Request (ID: $requestId) has been $newStatus by a $updaterRole.',
          requestId: requestId);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> subscribeToTopics(List<String> topics) async {
    for (String topic in topics) {
      await _firebaseMessaging.subscribeToTopic(topic.toLowerCase());
    }
  }

  Future<void> unsubscribeFromTopics(List<String> topics) async {
    for (String topic in topics) {
      await _firebaseMessaging.unsubscribeFromTopic(topic.toLowerCase());
    }
  }
}

// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class Notification {
//   final String id;
//   final String userId;
//   final String title;
//   final String body;
//   final DateTime timestamp;
//   final String userRole;
//   final String? requestId; // Changed to nullable
//   bool isRead;
//   final DateTime expirationDate;

//   Notification({
//     required this.id,
//     required this.userId,
//     required this.title,
//     required this.body,
//     required this.timestamp,
//     required this.userRole,
//     this.requestId, // Now optional
//     this.isRead = false,
//     required this.expirationDate,
//   });

//   factory Notification.fromMap(Map<String, dynamic> map) {
//     return Notification(
//       id: map['id'] as String,
//       userId: map['userId'] as String,
//       title: map['title'] as String,
//       body: map['body'] as String,
//       timestamp: (map['timestamp'] as Timestamp).toDate(),
//       userRole: map['userRole'] as String,
//       requestId: map['requestId'] as String?, // Now nullable
//       isRead: map['isRead'] as bool? ?? false,
//       expirationDate: (map['expirationDate'] as Timestamp).toDate(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'userId': userId,
//       'title': title,
//       'body': body,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'userRole': userRole,
//       'requestId': requestId, // This can be null
//       'isRead': isRead,
//       'expirationDate': Timestamp.fromDate(expirationDate),
//     };
//   }
// }

// class NotificationProvider with ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   List<Notification> _notifications = [];

//   List<Notification> get notifications => _notifications;

//   int get unreadNotificationsCount =>
//       _notifications.where((n) => !n.isRead).length;

//   NotificationProvider() {
//     _initFCM();
//   }

//   Future<void> _initFCM() async {
//     await _firebaseMessaging.requestPermission();
//     FirebaseMessaging.onMessage.listen(_handleFCMMessage);
//     await _initializeLocalNotifications();
//   }

//   Future<void> _initializeLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     final DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings();
//     final InitializationSettings initializationSettings =
//         InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );
//     await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
//   }

//   void _handleFCMMessage(RemoteMessage message) {
//     _showLocalNotification(message);
//     fetchNotifications(_currentUserId!, _currentUserRole!);
//   }

//   Future<void> _showLocalNotification(RemoteMessage message) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'your_channel_id',
//       'your_channel_name',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);

//     await _flutterLocalNotificationsPlugin.show(
//       0,
//       message.notification?.title ?? '',
//       message.notification?.body ?? '',
//       platformChannelSpecifics,
//       payload: message.data['requestId'],
//     );
//   }

//   String? _currentUserId;
//   String? _currentUserRole;

//   Future<void> fetchNotifications(String userId, String userRole) async {
//     _currentUserId = userId;
//     _currentUserRole = userRole;
//     try {
//       final snapshot = await _firestore
//           .collection('notifications')
//           .where('userId', isEqualTo: userId)
//           .where('userRole', isEqualTo: userRole)
//           .where('expirationDate', isGreaterThan: Timestamp.now())
//           .orderBy('expirationDate', descending: true)
//           .orderBy('timestamp', descending: true)
//           .get();

//       _notifications =
//           snapshot.docs.map((doc) => Notification.fromMap(doc.data())).toList();
//       notifyListeners();
//     } catch (e) {
//       print('Error fetching notifications: $e');
//     }
//   }

//   Future<void> markAsRead(String notificationId) async {
//     try {
//       await _firestore
//           .collection('notifications')
//           .doc(notificationId)
//           .update({'isRead': true});

//       final index = _notifications.indexWhere((n) => n.id == notificationId);
//       if (index != -1) {
//         _notifications[index].isRead = true;
//         notifyListeners();
//       }
//     } catch (e) {
//       print('Error marking notification as read: $e');
//     }
//   }

//   Future<void> deleteNotification(String notificationId) async {
//     try {
//       await _firestore.collection('notifications').doc(notificationId).delete();

//       _notifications.removeWhere((n) => n.id == notificationId);
//       notifyListeners();
//     } catch (e) {
//       print('Error deleting notification: $e');
//     }
//   }

//   Future<void> addNotification(Notification notification) async {
//     try {
//       await _firestore.collection('notifications').add(notification.toMap());
//       _notifications.insert(0, notification);
//       notifyListeners();

//       // Send FCM message
//       await _sendFCMMessage(notification);
//     } catch (e) {
//       print('Error adding notification: $e');
//     }
//   }

//   Future<void> _sendFCMMessage(Notification notification) async {
//     try {
//       await _firebaseMessaging.sendMessage(
//         to: '/topics/${notification.userRole.toLowerCase()}',
//         data: {
//           'title': notification.title,
//           'body': notification.body,
//           'requestId': notification.requestId,
//         },
//       );
//     } catch (e) {
//       print('Error sending FCM message: $e');
//     }
//   }

//   Future<void> subscribeToTopics(List<String> topics) async {
//     for (String topic in topics) {
//       await _firebaseMessaging.subscribeToTopic(topic.toLowerCase());
//     }
//   }

//   Future<void> unsubscribeFromTopics(List<String> topics) async {
//     for (String topic in topics) {
//       await _firebaseMessaging.unsubscribeFromTopic(topic.toLowerCase());
//     }
//   }

//   // Add methods for specific notification scenarios
//   Future<void> notifyRequestUpdate(
//       String requestId, String status, String userEmail) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: userEmail,
//       title: 'Request Update',
//       body: 'Your request (ID: $requestId) has been $status.',
//       timestamp: DateTime.now(),
//       userRole: 'User',
//       requestId: requestId,
//       expirationDate: DateTime.now().add(Duration(days: 7)),
//     ));
//   }

//   Future<void> notifyNewRequest(String requestId, String creatorRole) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: 'admin',
//       title: 'New Request',
//       body:
//           'A new request (ID: $requestId) has been created by a $creatorRole.',
//       timestamp: DateTime.now(),
//       userRole: 'Admin',
//       requestId: requestId,
//       expirationDate: DateTime.now().add(Duration(days: 7)),
//     ));

//     if (creatorRole != 'Manager') {
//       await addNotification(Notification(
//         id: UniqueKey().toString(),
//         userId: 'manager',
//         title: 'New Request',
//         body:
//             'A new request (ID: $requestId) has been created by a $creatorRole.',
//         timestamp: DateTime.now(),
//         userRole: 'Manager',
//         requestId: requestId,
//         expirationDate: DateTime.now().add(Duration(days: 7)),
//       ));
//     }
//   }

//   Future<void> notifyLowStock(String itemName, int currentQuantity) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: 'manager',
//       title: 'Low Stock Alert',
//       body: 'Item $itemName is running low. Current quantity: $currentQuantity',
//       timestamp: DateTime.now(),
//       userRole: 'Manager',
//       expirationDate: DateTime.now().add(Duration(days: 7)),
//     ));

//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: 'admin',
//       title: 'Low Stock Alert',
//       body: 'Item $itemName is running low. Current quantity: $currentQuantity',
//       timestamp: DateTime.now(),
//       userRole: 'Admin',
//       expirationDate: DateTime.now().add(Duration(days: 7)),
//     ));
//   }
// }


// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class Notification {
//   final String id;
//   final String userId;
//   final String title;
//   final String body;
//   final DateTime timestamp;
//   final String userRole;
//   bool isRead;

//   Notification({
//     required this.id,
//     required this.userId,
//     required this.title,
//     required this.body,
//     required this.timestamp,
//     required this.userRole,
//     this.isRead = false,
//   });

//   factory Notification.fromMap(Map<String, dynamic> map) {
//     return Notification(
//       id: map['id'],
//       userId: map['userId'],
//       title: map['title'],
//       body: map['body'],
//       timestamp: (map['timestamp'] as Timestamp).toDate(),
//       userRole: map['userRole'],
//       isRead: map['isRead'] ?? false,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'userId': userId,
//       'title': title,
//       'body': body,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'userRole': userRole,
//       'isRead': isRead,
//     };
//   }
// }

// class NotificationProvider with ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   List<Notification> _notifications = [];

//   List<Notification> get notifications => _notifications;

//   int get unreadNotificationsCount =>
//       _notifications.where((n) => !n.isRead).length;

//   Future<void> fetchNotifications(String userId, String userRole) async {
//     try {
//       final snapshot = await _firestore
//           .collection('notifications')
//           .where('userId', isEqualTo: userId)
//           .where('userRole', isEqualTo: userRole)
//           .orderBy('timestamp', descending: true)
//           .get();

//       _notifications =
//           snapshot.docs.map((doc) => Notification.fromMap(doc.data())).toList();
//       notifyListeners();
//     } catch (e) {
//       print('Error fetching notifications: $e');
//     }
//   }

//   Future<void> markAsRead(String notificationId) async {
//     try {
//       await _firestore
//           .collection('notifications')
//           .doc(notificationId)
//           .update({'isRead': true});

//       final index = _notifications.indexWhere((n) => n.id == notificationId);
//       if (index != -1) {
//         _notifications[index].isRead = true;
//         notifyListeners();
//       }
//     } catch (e) {
//       print('Error marking notification as read: $e');
//     }
//   }

//   Future<void> addNotification(Notification notification) async {
//     try {
//       await _firestore.collection('notifications').add(notification.toMap());
//       _notifications.insert(0, notification);
//       notifyListeners();
//     } catch (e) {
//       print('Error adding notification: $e');
//     }
//   }

//   Future<void> addUserNotification(
//       String userId, String title, String body) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: userId,
//       title: title,
//       body: body,
//       timestamp: DateTime.now(),
//       userRole: 'User',
//     ));
//   }

//   Future<void> addManagerNotification(
//       String userId, String title, String body) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: userId,
//       title: title,
//       body: body,
//       timestamp: DateTime.now(),
//       userRole: 'Manager',
//     ));
//   }

//   Future<void> addGatemanNotification(
//       String userId, String title, String body) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: userId,
//       title: title,
//       body: body,
//       timestamp: DateTime.now(),
//       userRole: 'Gate Man',
//     ));
//   }

//   Future<void> addAdminNotification(
//       String userId, String title, String body) async {
//     await addNotification(Notification(
//       id: UniqueKey().toString(),
//       userId: userId,
//       title: title,
//       body: body,
//       timestamp: DateTime.now(),
//       userRole: 'Admin',
//     ));
//   }

//   // New method to add notifications for all admins
//   Future<void> addNotificationForAllAdmins(String title, String body) async {
//     try {
//       QuerySnapshot adminUsers = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'Admin')
//           .get();

//       for (var adminDoc in adminUsers.docs) {
//         String adminId = adminDoc.id;
//         await addAdminNotification(adminId, title, body);
//       }
//     } catch (e) {
//       print('Error adding notification for all admins: $e');
//     }
//   }

//   // New method to add notifications for all managers
//   Future<void> addNotificationForAllManagers(String title, String body) async {
//     try {
//       QuerySnapshot managerUsers = await _firestore
//           .collection('users')
//           .where('role', isEqualTo: 'Manager')
//           .get();

//       for (var managerDoc in managerUsers.docs) {
//         String managerId = managerDoc.id;
//         await addManagerNotification(managerId, title, body);
//       }
//     } catch (e) {
//       print('Error adding notification for all managers: $e');
//     }
//   }

//   // New method to handle request creation notifications
//   Future<void> handleRequestCreationNotification(
//       String creatorId, String creatorRole, String requestId) async {
//     // Notify the creator
//     await addUserNotification(creatorId, 'Request Created',
//         'Your request (ID: $requestId) has been created successfully.');

//     // Notify all admins
//     await addNotificationForAllAdmins('New Request Created',
//         'A new request (ID: $requestId) has been created by a $creatorRole.');

//     // If the creator is not a manager, notify all managers
//     if (creatorRole != 'Manager') {
//       await addNotificationForAllManagers('New Request Created',
//           'A new request (ID: $requestId) has been created by a $creatorRole.');
//     }
//   }

//   // New method to handle request status update notifications
//   Future<void> handleRequestStatusUpdateNotification(String requestId,
//       String newStatus, String updaterId, String updaterRole) async {
//     // Fetch the request details to get the creator's ID
//     DocumentSnapshot requestDoc =
//         await _firestore.collection('requests').doc(requestId).get();
//     String creatorId = requestDoc['createdBy'];

//     // Notify the creator
//     await addUserNotification(creatorId, 'Request Status Updated',
//         'Your request (ID: $requestId) has been $newStatus.');

//     // Notify all admins
//     await addNotificationForAllAdmins('Request Status Updated',
//         'Request (ID: $requestId) has been $newStatus by a $updaterRole.');

//     // If the updater is not a manager, notify all managers
//     if (updaterRole != 'Manager') {
//       await addNotificationForAllManagers('Request Status Updated',
//           'Request (ID: $requestId) has been $newStatus by a $updaterRole.');
//     }
//   }
// }
