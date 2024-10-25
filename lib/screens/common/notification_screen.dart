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
