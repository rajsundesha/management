import 'package:dhavla_road_project/providers/auth_provider.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart'
    as custom_notification;



class BaseNotificationsScreen extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext, List<custom_notification.Notification>) buildNotificationList;

  BaseNotificationsScreen({
    required this.title,
    required this.buildNotificationList,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final userRole = authProvider.role;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: userId == null
          ? Center(child: Text('Please log in to view notifications'))
          : Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                return FutureBuilder(
                  future: notificationProvider.fetchNotifications(
                      userId, userRole!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final notifications = notificationProvider.notifications;

                    if (notifications.isEmpty) {
                      return Center(child: Text('No notifications'));
                    }

                    return buildNotificationList(context, notifications);
                  },
                );
              },
            ),
    );
  }
}

class UserNotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseNotificationsScreen(
      title: 'User Notifications',
      buildNotificationList: (context, notifications) {
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
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
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAsRead(notification.id);
                // Handle user-specific notification tap
              },
            );
          },
        );
      },
    );
  }
}

class ManagerNotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseNotificationsScreen(
      title: 'Manager Notifications',
      buildNotificationList: (context, notifications) {
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.body),
              trailing: Text(
                '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
              ),
              leading: Icon(
                Icons.notifications,
                color: notification.isRead ? Colors.grey : Colors.orange,
              ),
              onTap: () {
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAsRead(notification.id);
                // Handle manager-specific notification tap
              },
            );
          },
        );
      },
    );
  }
}

class GatemanNotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseNotificationsScreen(
      title: 'Gate Man Notifications',
      buildNotificationList: (context, notifications) {
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.body),
              trailing: Text(
                '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
              ),
              leading: Icon(
                Icons.notifications,
                color: notification.isRead ? Colors.grey : Colors.green,
              ),
              onTap: () {
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAsRead(notification.id);
                // Handle gateman-specific notification tap
              },
            );
          },
        );
      },
    );
  }
}

class AdminNotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseNotificationsScreen(
      title: 'Admin Notifications',
      buildNotificationList: (context, notifications) {
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.body),
              trailing: Text(
                '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}',
              ),
              leading: Icon(
                Icons.notifications,
                color: notification.isRead ? Colors.grey : Colors.red,
              ),
              onTap: () {
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAsRead(notification.id);
                // Handle admin-specific notification tap
              },
            );
          },
        );
      },
    );
  }
}
