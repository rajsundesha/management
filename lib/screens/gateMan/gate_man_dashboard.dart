import 'package:dhavla_road_project/providers/request_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/common/notification_screen.dart';
import 'StockRequestsTab.dart';
import 'OtherTabs.dart';

class GateManDashboard extends StatefulWidget {
  @override
  _GateManDashboardState createState() => _GateManDashboardState();
}

class _GateManDashboardState extends State<GateManDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.user == null || authProvider.role != 'Gate Man') {
          return Scaffold(
            body: Center(
              child: Text('You do not have permission to access this page.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Gate Man Dashboard'),
            actions: [
              if (_currentIndex == 2)
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    Provider.of<RequestProvider>(context, listen: false)
                        .refreshFulfilledRequests();
                  },
                ),
              _buildNotificationIcon(),
              _buildLogoutButton(context, authProvider),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              OverviewTab(),
              ApprovedRequestsTab(),
              RecentRequestsTab(),
              StockRequestsTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard), label: 'Overview'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle), label: 'Approved'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history), label: 'Recent'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.inventory), label: 'Stock'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        final userId = authProvider.user?.uid ?? '';
        final userRole = authProvider.role ?? 'Gate Man';
        return ValueListenableBuilder<int>(
          valueListenable: ValueNotifier<int>(notificationProvider
              .getUnreadNotificationsCount(userId, userRole)),
          builder: (context, unreadCount, child) {
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () async {
                    try {
                      await notificationProvider.fetchNotifications(
                          userId, userRole);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsScreen()),
                      ).then((_) => setState(() {}));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Error loading notifications. Please try again.')),
                      );
                    }
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await authProvider.logout(context);
          Navigator.of(context).pushReplacementNamed('/login');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out. Please try again.')),
          );
        }
      },
      child: Text('Logout'),
    );
  }
}
