import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart' as app_notifications;
import '../common/request_details_screen.dart';
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';
    final userRole = authProvider.role ?? '';
    final notificationProvider =
        Provider.of<app_notifications.NotificationProvider>(context,
            listen: false);

    print("Building NotificationsScreen for user: $userId, role: $userRole");

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () =>
                notificationProvider.refreshNotifications(userId, userRole),
          ),
        ],
      ),
      body: StreamBuilder<List<app_notifications.Notification>>(
        stream: notificationProvider.getNotificationsStream(userId, userRole),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error fetching notifications: ${snapshot.error}");
            return Center(
                child: Text('Error loading notifications. Please try again.'));
          }

          final notifications = snapshot.data ?? [];
          print("Retrieved ${notifications.length} notifications");

          if (notifications.isEmpty) {
            return Center(child: Text('No notifications'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _deleteNotification(context,
                    notification, userId, userRole, notificationProvider),
                child: ListTile(
                  title: Text(notification.title),
                  subtitle: Text(notification.body),
                  trailing: Text(
                    '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
                  ),
                  leading: Icon(
                    Icons.notifications,
                    color: notification.isRead
                        ? Colors.grey
                        : _getNotificationColor(userRole),
                  ),
                  onTap: () => _onNotificationTap(context, notification, userId,
                      userRole, notificationProvider),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _deleteNotification(
    BuildContext context,
    app_notifications.Notification notification,
    String userId,
    String userRole,
    app_notifications.NotificationProvider notificationProvider,
  ) async {
    try {
      print('Deleting notification with ID: ${notification.id}');
      await notificationProvider.deleteNotification(
          notification.id, userId, userRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification: $e')),
      );
    }
  }

  void _onNotificationTap(
    BuildContext context,
    app_notifications.Notification notification,
    String userId,
    String userRole,
    app_notifications.NotificationProvider notificationProvider,
  ) {
    notificationProvider.markAsRead(notification.id, userId, userRole);
    if (notification.requestId != null) {
      _navigateToRequestDetails(
          context, notification.requestId!, notification.title);
    }
  }

  void _navigateToRequestDetails(
      BuildContext context, String requestId, String notificationType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          requestId: requestId,
          isStockRequest: notificationType.toLowerCase().contains('stock'),
        ),
      ),
    );
  }

  Color _getNotificationColor(String userRole) {
    switch (userRole.toLowerCase()) {
      case 'user':
        return Colors.blue;
      case 'manager':
        return Colors.orange;
      case 'gate man':
        return Colors.green;
      case 'admin':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart' as app_notifications;
// import '../common/request_details_screen.dart';

// class NotificationsScreen extends StatefulWidget {
//   const NotificationsScreen({Key? key}) : super(key: key);

//   @override
//   _NotificationsScreenState createState() => _NotificationsScreenState();
// }

// class _NotificationsScreenState extends State<NotificationsScreen> {
//   late Stream<List<app_notifications.Notification>> _notificationsStream;
//   late String _userId;
//   late String _userRole;

//   @override
//   void initState() {
//     super.initState();
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final notificationProvider =
//         Provider.of<app_notifications.NotificationProvider>(context,
//             listen: false);
//     _userId = authProvider.user?.uid ?? '';
//     _userRole = authProvider.role ?? '';

//     if (_userId.isNotEmpty && _userRole.isNotEmpty) {
//       _notificationsStream =
//           notificationProvider.getNotificationsStream(_userId, _userRole);
//     }
//   }

//   void _navigateToRequestDetails(
//       BuildContext context, String requestId, String notificationType) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => RequestDetailsScreen(
//           requestId: requestId,
//           isStockRequest: notificationType.toLowerCase().contains('stock'),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     print("Building NotificationsScreen for user: $_userId, role: $_userRole");

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: _userId.isEmpty
//           ? Center(child: Text('Please log in to view notifications'))
//           : StreamBuilder<List<app_notifications.Notification>>(
//               stream: _notificationsStream,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }

//                 if (snapshot.hasError) {
//                   print("Error fetching notifications: ${snapshot.error}");
//                   return Center(
//                       child: Text(
//                           'Error loading notifications. Please try again.'));
//                 }

//                 final notifications = snapshot.data ?? [];
//                 print("Retrieved ${notifications.length} notifications");

//                 if (notifications.isEmpty) {
//                   return Center(child: Text('No notifications'));
//                 }

//                 return ListView.builder(
//                   itemCount: notifications.length,
//                   itemBuilder: (context, index) {
//                     final notification = notifications[index];
//                     return Dismissible(
//                       key: Key(notification.id),
//                       background: Container(
//                         color: Colors.red,
//                         alignment: Alignment.centerRight,
//                         padding: EdgeInsets.only(right: 20.0),
//                         child: Icon(Icons.delete, color: Colors.white),
//                       ),
//                       onDismissed: (direction) {
//                         Provider.of<app_notifications.NotificationProvider>(
//                                 context,
//                                 listen: false)
//                             .deleteNotification(
//                                 notification.id, _userId, _userRole);
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text('Notification deleted')),
//                         );
//                       },
//                       child: ListTile(
//                         title: Text(notification.title),
//                         subtitle: Text(notification.body),
//                         trailing: Text(
//                           '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                         ),
//                         leading: Icon(
//                           Icons.notifications,
//                           color: notification.isRead
//                               ? Colors.grey
//                               : _getNotificationColor(_userRole),
//                         ),
//                         onTap: () {
//                           Provider.of<app_notifications.NotificationProvider>(
//                                   context,
//                                   listen: false)
//                               .markAsRead(notification.id, _userId, _userRole);
//                           if (notification.requestId != null) {
//                             _navigateToRequestDetails(context,
//                                 notification.requestId!, notification.title);
//                           }
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//     );
//   }

//   Color _getNotificationColor(String userRole) {
//     switch (userRole.toLowerCase()) {
//       case 'user':
//         return Colors.blue;
//       case 'manager':
//         return Colors.orange;
//       case 'gate man':
//         return Colors.green;
//       case 'admin':
//         return Colors.red;
//       default:
//         return Colors.blue;
//     }
//   }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart' as app_notifications;
// import '../common/request_details_screen.dart';

// class NotificationsScreen extends StatefulWidget {
//   const NotificationsScreen({Key? key}) : super(key: key);

//   @override
//   _NotificationsScreenState createState() => _NotificationsScreenState();
// }

// class _NotificationsScreenState extends State<NotificationsScreen> {
//   late Stream<List<app_notifications.Notification>> _notificationsStream;

//   @override
//   void initState() {
//     super.initState();
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final notificationProvider =
//         Provider.of<app_notifications.NotificationProvider>(context,
//             listen: false);
//     final userId = authProvider.user?.uid;
//     final userRole = authProvider.role;

//     if (userId != null && userRole != null) {
//       _notificationsStream =
//           notificationProvider.getNotificationsStream(userId, userRole);
//     }
//   }

//   void _navigateToRequestDetails(
//       BuildContext context, String requestId, String notificationType) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => RequestDetailsScreen(
//           requestId: requestId,
//           isStockRequest: notificationType.toLowerCase().contains('stock'),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final userId = authProvider.user?.uid;
//     final userRole = authProvider.role;

//     print("Building NotificationsScreen for user: $userId, role: $userRole");

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: userId == null
//           ? Center(child: Text('Please log in to view notifications'))
//           : StreamBuilder<List<app_notifications.Notification>>(
//               stream: _notificationsStream,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }

//                 if (snapshot.hasError) {
//                   print("Error fetching notifications: ${snapshot.error}");
//                   return Center(
//                       child: Text(
//                           'Error loading notifications: ${snapshot.error}'));
//                 }

//                 final notifications = snapshot.data ?? [];
//                 print("Retrieved ${notifications.length} notifications");

//                 if (notifications.isEmpty) {
//                   return Center(child: Text('No notifications'));
//                 }

//                 return ListView.builder(
//                   itemCount: notifications.length,
//                   itemBuilder: (context, index) {
//                     final notification = notifications[index];
//                     return Dismissible(
//                       key: Key(notification.id),
//                       background: Container(
//                         color: Colors.red,
//                         alignment: Alignment.centerRight,
//                         padding: EdgeInsets.only(right: 20.0),
//                         child: Icon(Icons.delete, color: Colors.white),
//                       ),
//                       onDismissed: (direction) {
//                         Provider.of<app_notifications.NotificationProvider>(
//                                 context,
//                                 listen: false)
//                             .deleteNotification(notification.id);
//                       },
//                       child: ListTile(
//                         title: Text(notification.title),
//                         subtitle: Text(notification.body),
//                         trailing: Text(
//                           '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                         ),
//                         leading: Icon(
//                           Icons.notifications,
//                           color: notification.isRead
//                               ? Colors.grey
//                               : _getNotificationColor(userRole ?? ''),
//                         ),
//                         onTap: () {
//                           Provider.of<app_notifications.NotificationProvider>(
//                                   context,
//                                   listen: false)
//                               .markAsRead(notification.id);
//                           if (notification.requestId != null) {
//                             _navigateToRequestDetails(context,
//                                 notification.requestId!, notification.title);
//                           }
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//     );
//   }

//   Color _getNotificationColor(String userRole) {
//     switch (userRole.toLowerCase()) {
//       case 'user':
//         return Colors.blue;
//       case 'manager':
//         return Colors.orange;
//       case 'gate man':
//         return Colors.green;
//       case 'admin':
//         return Colors.red;
//       default:
//         return Colors.blue;
//     }
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../common/request_details_screen.dart';

// class NotificationsScreen extends StatelessWidget {
//   const NotificationsScreen({Key? key}) : super(key: key);

//   void _navigateToRequestDetails(
//       BuildContext context, String requestId, String notificationType) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => RequestDetailsScreen(
//           requestId: requestId,
//           isStockRequest: notificationType.toLowerCase().contains('stock'),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final userId = authProvider.user?.uid;
//     final userRole = authProvider.role;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: userId == null
//           ? Center(child: Text('Please log in to view notifications'))
//           : Consumer<NotificationProvider>(
//               builder: (context, notificationProvider, child) {
//                 return FutureBuilder(
//                   future: notificationProvider.fetchNotifications(
//                       userId, userRole!),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return Center(child: CircularProgressIndicator());
//                     }

//                     final notifications = notificationProvider
//                         .getRelevantNotifications(userId, userRole);

//                     if (notifications.isEmpty) {
//                       return Center(child: Text('No notifications'));
//                     }

//                     return ListView.builder(
//                       itemCount: notifications.length,
//                       itemBuilder: (context, index) {
//                         final notification = notifications[index];
//                         return Dismissible(
//                           key: Key(notification.id),
//                           background: Container(
//                             color: Colors.red,
//                             alignment: Alignment.centerRight,
//                             padding: EdgeInsets.only(right: 20.0),
//                             child: Icon(Icons.delete, color: Colors.white),
//                           ),
//                           onDismissed: (direction) {
//                             notificationProvider
//                                 .deleteNotification(notification.id);
//                           },
//                           child: ListTile(
//                             title: Text(notification.title),
//                             subtitle: Text(notification.body),
//                             trailing: Text(
//                               '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                             ),
//                             leading: Icon(
//                               Icons.notifications,
//                               color: notification.isRead
//                                   ? Colors.grey
//                                   : _getNotificationColor(userRole),
//                             ),
//                             onTap: () {
//                               notificationProvider.markAsRead(notification.id);
//                               if (notification.requestId != null) {
//                                 _navigateToRequestDetails(
//                                     context,
//                                     notification.requestId!,
//                                     notification.title);
//                               }
//                             },
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//     );
//   }

//   Color _getNotificationColor(String userRole) {
//     switch (userRole.toLowerCase()) {
//       case 'user':
//         return Colors.blue;
//       case 'manager':
//         return Colors.orange;
//       case 'gate man':
//         return Colors.green;
//       case 'admin':
//         return Colors.red;
//       default:
//         return Colors.blue;
//     }
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/request_details_screen.dart';

// class NotificationsScreen extends StatelessWidget {
//   final String userId;
//   final String userRole;

//   const NotificationsScreen({
//     Key? key,
//     required this.userId,
//     required this.userRole,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     void _navigateToRequestDetails(
//         BuildContext context, String requestId, String notificationType) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => RequestDetailsScreen(
//             requestId: requestId,
//             isStockRequest: notificationType.toLowerCase().contains('stock'),
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: Consumer<NotificationProvider>(
//         builder: (context, notificationProvider, child) {
//           final notifications =
//               notificationProvider.getRelevantNotifications(userId, userRole);
//           if (notifications.isEmpty) {
//             return Center(child: Text('No notifications'));
//           }
//           return ListView.builder(
//             itemCount: notifications.length,
//             itemBuilder: (context, index) {
//               final notification = notifications[index];
//               return Dismissible(
//                 key: Key(notification.id),
//                 background: Container(
//                   color: Colors.red,
//                   alignment: Alignment.centerRight,
//                   padding: EdgeInsets.only(right: 20.0),
//                   child: Icon(Icons.delete, color: Colors.white),
//                 ),
//                 onDismissed: (direction) {
//                   notificationProvider.deleteNotification(notification.id);
//                 },
//                 child: ListTile(
//                   title: Text(notification.title),
//                   subtitle: Text(notification.body),
//                   trailing: Text(
//                     '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                   ),
//                   leading: Icon(
//                     Icons.notifications,
//                     color: notification.isRead ? Colors.grey : Colors.blue,
//                   ),
//                   onTap: () {
//                     notificationProvider.markAsRead(notification.id);
//                     if (notification.requestId != null) {
//                       _navigateToRequestDetails(
//                           context, notification.requestId!, notification.title);
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// import 'package:dhavla_road_project/screens/common/request_details_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/notification_provider.dart';
// // import '../../screens/request_details_screen.dart'; // Import the new screen

// class NotificationsScreen extends StatelessWidget {
//   final String userId;
//   final String userRole;

//   const NotificationsScreen({
//     Key? key,
//     required this.userId,
//     required this.userRole,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // ... (previous code remains the same)

//     void _navigateToRequestDetails(
//         BuildContext context, String requestId, String notificationType) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => RequestDetailsScreen(
//             requestId: requestId,
//             isStockRequest: notificationType.toLowerCase().contains('stock'),
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: Consumer<NotificationProvider>(
//         builder: (context, notificationProvider, child) {
//           final notifications =
//               notificationProvider.getRelevantNotifications(userId, userRole);
//           if (notifications.isEmpty) {
//             return Center(child: Text('No notifications'));
//           }
//           return ListView.builder(
//             itemCount: notifications.length,
//             itemBuilder: (context, index) {
//               final notification = notifications[index];
//               return Dismissible(
//                 key: Key(notification.id),
//                 background: Container(
//                   color: Colors.red,
//                   alignment: Alignment.centerRight,
//                   padding: EdgeInsets.only(right: 20.0),
//                   child: Icon(Icons.delete, color: Colors.white),
//                 ),
//                 onDismissed: (direction) {
//                   notificationProvider.deleteNotification(notification.id);
//                 },
//                 child: ListTile(
//                   title: Text(notification.title),
//                   subtitle: Text(notification.body),
//                   trailing: Text(
//                     '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                   ),
//                   leading: Icon(
//                     Icons.notifications,
//                     color: notification.isRead ? Colors.grey : Colors.blue,
//                   ),
//                   onTap: () {
//                     notificationProvider.markAsRead(notification.id);
//                     if (notification.requestId != null) {
//                       _navigateToRequestDetails(
//                           context, notification.requestId!, notification.title);
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
