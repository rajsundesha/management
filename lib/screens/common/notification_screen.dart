import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class NotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final notifications = notificationProvider.notifications;
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
                  padding: EdgeInsets.only(right: 20.0),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  notificationProvider.deleteNotification(notification.id);
                },
                child: ListTile(
                  title: Text(notification.title),
                  subtitle: Text(notification.body),
                  trailing: Text(
                    '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
                  ),
                  leading: Icon(
                    Icons.notifications,
                    color: notification.isRead ? Colors.grey : Colors.blue,
                  ),
                  onTap: () {
                    notificationProvider.markAsRead(notification.id);
                    if (notification.requestId != null) {
                      _navigateToRequestDetails(
                          context, notification.requestId!);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToRequestDetails(BuildContext context, String requestId) {
    // Navigate to the request details screen
    // You'll need to implement this navigation based on your app's routing
    Navigator.pushNamed(context, '/request_details', arguments: requestId);
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/notification_provider.dart' as custom_notification;

// class NotificationsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Notifications'),
//       ),
//       body: Consumer<custom_notification.NotificationProvider>(
//         builder: (context, notificationProvider, child) {
//           final notifications = notificationProvider.notifications;
//           if (notifications.isEmpty) {
//             return Center(child: Text('No notifications'));
//           }
//           return ListView.builder(
//             itemCount: notifications.length,
//             itemBuilder: (context, index) {
//               final notification = notifications[index];
//               return ListTile(
//                 title: Text(notification.title),
//                 subtitle: Text(notification.body),
//                 trailing: Text(
//                   '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
//                 ),
//                 leading: Icon(
//                   Icons.notifications,
//                   color: notification.isRead ? Colors.grey : Colors.blue,
//                 ),
//                 onTap: () {
//                   notificationProvider.markAsRead(notification.id);
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
