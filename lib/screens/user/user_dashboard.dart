import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/notification_provider.dart';
import '../common/notification_screen.dart';
import 'completed_requests_screen.dart';
import 'create_request_screen.dart';
import 'edit_profile_screen.dart';
import 'pending_request_screen.dart';
import 'ApprovedRequestsScreen.dart';
import 'PartiallyFulfilledRequestsScreen.dart';

class UserDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final user = authProvider.user;
    final userName = authProvider.userName;
    final userRole = authProvider.role ?? 'User';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final notificationProvider =
              Provider.of<NotificationProvider>(context, listen: false);
          await notificationProvider.fetchNotifications(
              user?.uid ?? '', userRole);
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, userName),
            SliverPadding(
              padding: EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                    ),
                    Text(
                      userName,
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24),
                    FutureBuilder<Map<String, int>>(
                      future: requestProvider.getRequestCountsByStatus(
                          authProvider.currentUserEmail ?? '', userRole),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final counts = snapshot.data ?? {};
                        return _buildDashboardGrid(context, counts);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String userName) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Dashboard'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.blue.shade400, Colors.indigo.shade600],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _buildNotificationIcon(context),
        _buildUserAvatar(context, userName),
      ],
    );
  }

  // Widget _buildDashboardGrid(BuildContext context, Map<String, int> counts) {
  //   return StaggeredGrid.count(
  //     crossAxisCount: 2,
  //     mainAxisSpacing: 16,
  //     crossAxisSpacing: 16,
  //     children: [
  //       _buildDashboardTile(
  //         context,
  //         'Create New Request',
  //         Icons.add_box,
  //         Colors.green,
  //         CreateUserRequestScreen(),
  //         description: 'Start a new request here',
  //         crossAxisCount: 2,
  //       ),
  //       _buildDashboardTile(
  //         context,
  //         'Pending',
  //         Icons.pending,
  //         Colors.orange,
  //         UserPendingRequestsScreen(),
  //         description: 'View your pending requests',
  //         count: counts['pending'] ?? 0,
  //       ),
  //       _buildDashboardTile(
  //         context,
  //         'Approved',
  //         Icons.check_circle_outline,
  //         Colors.blue,
  //         ApprovedRequestsScreen(),
  //         description: 'View your approved requests',
  //         count: counts['approved'] ?? 0,
  //       ),
  //       _buildDashboardTile(
  //         context,
  //         'Partially Fulfilled',
  //         Icons.hourglass_bottom,
  //         Colors.amber,
  //         PartiallyFulfilledRequestsScreen(),
  //         description: 'View your partially fulfilled requests',
  //         count: counts['partially_fulfilled'] ?? 0,
  //       ),
  //       _buildDashboardTile(
  //         context,
  //         'Completed',
  //         Icons.check_circle,
  //         Colors.indigo,
  //         CompletedRequestsScreen(),
  //         description: 'See your completed requests from the last 7 days',
  //         count: counts['completed'] ?? 0,
  //       ),
  //       _buildDashboardTile(
  //         context,
  //         'Edit Profile',
  //         Icons.person,
  //         Colors.purple,
  //         EditProfileScreen(),
  //         description: 'Update your personal information',
  //         crossAxisCount: 2,
  //       ),
  //     ],
  //   );
  // }

  Widget _buildDashboardGrid(BuildContext context, Map<String, int> counts) {
    return FutureBuilder<Map<String, int>>(
      future: Provider.of<RequestProvider>(context, listen: false)
          .getRequestCountsByStatus(
              Provider.of<AuthProvider>(context, listen: false)
                      .currentUserEmail ??
                  '',
              Provider.of<AuthProvider>(context, listen: false).role ?? 'User'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // Log the error to the console
          print('Error fetching request counts: ${snapshot.error}');
          // Show a user-friendly error message on the screen
          return Center(
            child: Text(
              'Unable to load dashboard data. Please try again later.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        final counts = snapshot.data ?? {};
        return StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildDashboardTile(
              context,
              'Create New Request',
              Icons.add_box,
              Colors.green,
              CreateUserRequestScreen(),
              description: 'Start a new request here',
              crossAxisCount: 2,
            ),
            _buildDashboardTile(
              context,
              'Pending',
              Icons.pending,
              Colors.orange,
              UserPendingRequestsScreen(),
              description: 'View your pending requests',
              count: counts['pending'] ?? 0,
            ),
            _buildDashboardTile(
              context,
              'Approved',
              Icons.check_circle_outline,
              Colors.blue,
              ApprovedRequestsScreen(),
              description: 'View your approved requests',
              count: counts['approved'] ?? 0,
            ),
            _buildDashboardTile(
              context,
              'Partially Fulfilled',
              Icons.hourglass_bottom,
              Colors.amber,
              PartiallyFulfilledRequestsScreen(),
              description: 'View your partially fulfilled requests',
              count: counts['partially_fulfilled'] ?? 0,
            ),
            _buildDashboardTile(
              context,
              'Completed',
              Icons.check_circle,
              Colors.indigo,
              CompletedRequestsScreen(),
              description: 'See your completed requests from the last 7 days',
              count: counts['completed'] ?? 0,
            ),
            _buildDashboardTile(
              context,
              'Edit Profile',
              Icons.person,
              Colors.purple,
              EditProfileScreen(),
              description: 'Update your personal information',
              crossAxisCount: 2,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen, {
    required String description,
    int crossAxisCount = 1,
    int mainAxisCount = 1,
    int count = 0,
  }) {
    return StaggeredGridTile.count(
      crossAxisCellCount: crossAxisCount,
      mainAxisCellCount: mainAxisCount,
      child: DashboardCard(
        title: title,
        icon: icon,
        color: color,
        screen: screen,
        description: description,
        count: count,
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        final userId = authProvider.user?.uid ?? '';
        final userRole = authProvider.role ?? 'User';

        return StreamBuilder<int>(
          stream: notificationProvider.getUnreadNotificationsCountStream(
              userId, userRole),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Icon(Icons.error);
            }

            int unreadCount = snapshot.data ?? 0;

            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.white),
                  onPressed: () =>
                      _navigateToNotifications(context, userId, userRole),
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
                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
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

  Widget _buildUserAvatar(BuildContext context, String userName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Text(
            userName[0].toUpperCase(),
            style: TextStyle(
                color: Colors.blue.shade700, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _navigateToNotifications(
      BuildContext context, String userId, String userRole) async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.fetchNotifications(userId, userRole);

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationsScreen()),
      );

      await notificationProvider.updateUnreadCount(userId, userRole);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading notifications. Please try again.')),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      await Provider.of<RequestProvider>(context, listen: false)
          .cancelListeners();
      await Provider.of<AuthProvider>(context, listen: false).logout(context);
      Navigator.of(context).pop(); // Dismiss loading dialog
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String description;
  final int count;

  DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
    required this.description,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateTo(context, screen, title),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.7), color],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(icon, size: 32, color: Colors.white),
                        if (count > 0)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: constraints.maxHeight * 0.1),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: constraints.maxHeight * 0.05),
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen, String screenName) {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $screenName. Please try again.')),
      );
    }
  }
}
