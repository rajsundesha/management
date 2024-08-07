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

class UserDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
                    _buildDashboardGrid(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the SliverAppBar with a gradient background
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

  // Creates a staggered grid layout for the dashboard cards
  Widget _buildDashboardGrid(BuildContext context) {
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
        ),
        _buildDashboardTile(
          context,
          'Completed',
          Icons.check_circle,
          Colors.blue,
          CompletedRequestsScreen(),
          description: 'See your completed requests',
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
  }

  // Reusable widget for dashboard cards
  Widget _buildDashboardTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget screen, {
    String description = '',
    int crossAxisCount = 1,
    int mainAxisCount = 1,
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
      ),
    );
  }

  // Builds the notification icon with unread count badge
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

  // Displays the user avatar with an option to logout
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

  // Navigate to the notifications screen
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

  // Navigate to the specified screen
  void _navigateTo(BuildContext context, Widget screen, String screenName) {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $screenName. Please try again.')),
      );
    }
  }

  // Show logout confirmation dialog
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

  // Perform logout action
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
      await Provider.of<AuthProvider>(context, listen: false).logout();
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

  DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
    this.description = '',
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
                    Icon(icon, size: 32, color: Colors.white),
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

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userName = authProvider.userName;
//     final userRole = authProvider.role ?? 'User';

//     return Scaffold(
//       body: RefreshIndicator(
//         onRefresh: () async {
//           final notificationProvider =
//               Provider.of<NotificationProvider>(context, listen: false);
//           await notificationProvider.fetchNotifications(
//               user?.uid ?? '', userRole);
//         },
//         child: CustomScrollView(
//           slivers: [
//             _buildSliverAppBar(context, userName),
//             SliverPadding(
//               padding: EdgeInsets.all(16.0),
//               sliver: SliverToBoxAdapter(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Welcome back,',
//                       style:
//                           TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
//                     ),
//                     Text(
//                       userName,
//                       style:
//                           TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 24),
//                     _buildDashboardGrid(context),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar(BuildContext context, String userName) {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: Text('Dashboard'),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topRight,
//               end: Alignment.bottomLeft,
//               colors: [Colors.blue.shade400, Colors.indigo.shade600],
//             ),
//           ),
//           child: Stack(
//             children: [
//               Positioned(
//                 right: -50,
//                 top: -50,
//                 child: Container(
//                   width: 200,
//                   height: 200,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.white.withOpacity(0.1),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 left: -30,
//                 bottom: -30,
//                 child: Container(
//                   width: 140,
//                   height: 140,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.white.withOpacity(0.1),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         _buildNotificationIcon(context),
//         _buildUserAvatar(context, userName),
//       ],
//     );
//   }

//   Widget _buildDashboardGrid(BuildContext context) {
//     return StaggeredGrid.count(
//       crossAxisCount: 2,
//       mainAxisSpacing: 16,
//       crossAxisSpacing: 16,
//       children: [
//         StaggeredGridTile.count(
//           crossAxisCellCount: 2,
//           mainAxisCellCount: 1,
//           child: _buildDashboardCard(
//             context,
//             'Create New Request',
//             Icons.add_box,
//             Colors.green,
//             CreateUserRequestScreen(),
//             description: 'Start a new request here',
//           ),
//         ),
//         StaggeredGridTile.count(
//           crossAxisCellCount: 1,
//           mainAxisCellCount: 1,
//           child: _buildDashboardCard(
//             context,
//             'Pending',
//             Icons.pending,
//             Colors.orange,
//             UserPendingRequestsScreen(),
//             description: 'View your pending requests',
//           ),
//         ),
//         StaggeredGridTile.count(
//           crossAxisCellCount: 1,
//           mainAxisCellCount: 1,
//           child: _buildDashboardCard(
//             context,
//             'Completed',
//             Icons.check_circle,
//             Colors.blue,
//             CompletedRequestsScreen(),
//             description: 'See your completed requests',
//           ),
//         ),
//         StaggeredGridTile.count(
//           crossAxisCellCount: 2,
//           mainAxisCellCount: 1,
//           child: _buildDashboardCard(
//             context,
//             'Edit Profile',
//             Icons.person,
//             Colors.purple,
//             EditProfileScreen(),
//             description: 'Update your personal information',
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     Widget screen, {
//     String description = '',
//   }) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () => _navigateTo(context, screen, title),
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [color.withOpacity(0.7), color],
//             ),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: LayoutBuilder(
//               builder: (context, constraints) {
//                 return Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Icon(icon, size: 32, color: Colors.white),
//                     SizedBox(height: constraints.maxHeight * 0.1),
//                     Text(
//                       title,
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     if (description.isNotEmpty) ...[
//                       SizedBox(height: constraints.maxHeight * 0.05),
//                       Expanded(
//                         child: Text(
//                           description,
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.white.withOpacity(0.8),
//                           ),
//                           overflow: TextOverflow.fade,
//                         ),
//                       ),
//                     ],
//                   ],
//                 );
//               },
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNotificationIcon(BuildContext context) {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'User';

//         return StreamBuilder<int>(
//           stream: notificationProvider.getUnreadNotificationsCountStream(
//               userId, userRole),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return CircularProgressIndicator();
//             }

//             if (snapshot.hasError) {
//               return Icon(Icons.error);
//             }

//             int unreadCount = snapshot.data ?? 0;

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications, color: Colors.white),
//                   onPressed: () =>
//                       _navigateToNotifications(context, userId, userRole),
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(minWidth: 16, minHeight: 16),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(color: Colors.white, fontSize: 10),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildUserAvatar(BuildContext context, String userName) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: GestureDetector(
//         onTap: () => _showLogoutDialog(context),
//         child: CircleAvatar(
//           backgroundColor: Colors.white,
//           child: Text(
//             userName[0].toUpperCase(),
//             style: TextStyle(
//                 color: Colors.blue.shade700, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ),
//     );
//   }

//   void _navigateToNotifications(
//       BuildContext context, String userId, String userRole) async {
//     try {
//       final notificationProvider =
//           Provider.of<NotificationProvider>(context, listen: false);
//       await notificationProvider.fetchNotifications(userId, userRole);

//       await Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => NotificationsScreen()),
//       );

//       await notificationProvider.updateUnreadCount(userId, userRole);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error loading notifications. Please try again.')),
//       );
//     }
//   }

//   void _navigateTo(BuildContext context, Widget screen, String screenName) {
//     try {
//       Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error opening $screenName. Please try again.')),
//       );
//     }
//   }

//   void _showLogoutDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Logout'),
//           content: Text('Are you sure you want to logout?'),
//           actions: [
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//             TextButton(
//               child: Text('Logout'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _logout(context);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _logout(BuildContext context) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to log out. Please try again.')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userEmail = user?.email ?? 'User';
//     final userRole = authProvider.role ?? 'User';

//     return Scaffold(
//       body: RefreshIndicator(
//         onRefresh: () async {
//           final notificationProvider =
//               Provider.of<NotificationProvider>(context, listen: false);
//           await notificationProvider.fetchNotifications(
//               user?.uid ?? '', userRole);
//         },
//         child: CustomScrollView(
//           slivers: [
//             SliverAppBar(
//               expandedHeight: 200.0,
//               floating: false,
//               pinned: true,
//               flexibleSpace: FlexibleSpaceBar(
//                 title: Text('Welcome, $userEmail'),
//                 background: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topRight,
//                       end: Alignment.bottomLeft,
//                       colors: [Colors.blue, Colors.indigo],
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 _buildNotificationIcon(context),
//                 IconButton(
//                   icon: Icon(Icons.logout),
//                   onPressed: () => _logout(context),
//                   tooltip: 'Logout',
//                 ),
//               ],
//             ),
//             SliverPadding(
//               padding: EdgeInsets.all(16.0),
//               sliver: SliverGrid(
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   childAspectRatio: 1.0,
//                   crossAxisSpacing: 16.0,
//                   mainAxisSpacing: 16.0,
//                 ),
//                 delegate: SliverChildListDelegate([
//                   _buildDashboardCard(
//                     context,
//                     'Create New Request',
//                     Icons.add_box,
//                     Colors.green,
//                     CreateUserRequestScreen(),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Pending Requests',
//                     Icons.pending,
//                     Colors.orange,
//                     UserPendingRequestsScreen(),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Completed Requests',
//                     Icons.check_circle,
//                     Colors.blue,
//                     CompletedRequestsScreen(),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Edit Profile',
//                     Icons.person,
//                     Colors.purple,
//                     EditProfileScreen(),
//                   ),
//                 ]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     Widget screen,
//   ) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () => _navigateTo(context, screen, title),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: color),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNotificationIcon(BuildContext context) {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'User';

//         return StreamBuilder<int>(
//           stream: notificationProvider.getUnreadNotificationsCountStream(
//               userId, userRole),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return CircularProgressIndicator();
//             }

//             if (snapshot.hasError) {
//               return Icon(Icons.error);
//             }

//             int unreadCount = snapshot.data ?? 0;

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () =>
//                       _navigateToNotifications(context, userId, userRole),
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   void _navigateToNotifications(
//       BuildContext context, String userId, String userRole) async {
//     try {
//       final notificationProvider =
//           Provider.of<NotificationProvider>(context, listen: false);
//       await notificationProvider.fetchNotifications(userId, userRole);

//       await Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => NotificationsScreen(),
//         ),
//       );

//       await notificationProvider.updateUnreadCount(userId, userRole);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error loading notifications. Please try again.')),
//       );
//     }
//   }

//   void _navigateTo(BuildContext context, Widget screen, String screenName) {
//     try {
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => screen),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error opening $screenName. Please try again.')),
//       );
//     }
//   }

//   void _logout(BuildContext context) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to log out. Please try again.')),
//       );
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userEmail = user?.email ?? 'User';
//     final userRole = authProvider.role ?? 'User';

//     return Scaffold(
//       body: RefreshIndicator(
//         onRefresh: () async {
//           final notificationProvider =
//               Provider.of<NotificationProvider>(context, listen: false);
//           await notificationProvider.fetchNotifications(
//               user?.uid ?? '', userRole);
//         },
//         child: CustomScrollView(
//           slivers: [
//             SliverAppBar(
//               expandedHeight: 200.0,
//               floating: false,
//               pinned: true,
//               flexibleSpace: FlexibleSpaceBar(
//                 title: Text('Welcome, $userEmail'),
//                 background: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topRight,
//                       end: Alignment.bottomLeft,
//                       colors: [Colors.blue, Colors.indigo],
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 _buildNotificationIcon(context),
//                 IconButton(
//                   icon: Icon(Icons.logout),
//                   onPressed: () => _logout(context),
//                   tooltip: 'Logout',
//                 ),
//               ],
//             ),
//             SliverPadding(
//               padding: EdgeInsets.all(16.0),
//               sliver: SliverGrid(
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   childAspectRatio: 1.0,
//                   crossAxisSpacing: 16.0,
//                   mainAxisSpacing: 16.0,
//                 ),
//                 delegate: SliverChildListDelegate([
//                   _buildDashboardCard(
//                     context,
//                     'Create New Request',
//                     Icons.add_box,
//                     Colors.green,
//                     _navigateToCreateRequest,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Pending Requests',
//                     Icons.pending,
//                     Colors.orange,
//                     _navigateToPendingRequests,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Completed Requests',
//                     Icons.check_circle,
//                     Colors.blue,
//                     _navigateToCompletedRequests,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Edit Profile',
//                     Icons.person,
//                     Colors.purple,
//                     _navigateToEditProfile,
//                   ),
//                 ]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     Function(BuildContext) onTap,
//   ) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () {
//           try {
//             onTap(context);
//           } catch (e) {
//             print("Error navigating to $title: $e");
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                   content: Text('Error opening $title. Please try again.')),
//             );
//           }
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: color),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNotificationIcon(BuildContext context) {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'User';
//         LoggingService.log(
//             "Building notification icon for user: $userId, role: $userRole");

//         return StreamBuilder<int>(
//           stream: notificationProvider.getUnreadNotificationsCountStream(
//               userId, userRole),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               LoggingService.log("Waiting for unread count stream...");
//               return CircularProgressIndicator();
//             }

//             if (snapshot.hasError) {
//               LoggingService.log(
//                   "Error in unread count stream: ${snapshot.error}");
//               return Icon(Icons.error);
//             }

//             int unreadCount = snapshot.data ?? 0;
//             LoggingService.log("Unread notifications count: $unreadCount");

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () =>
//                       _navigateToNotifications(context, userId, userRole),
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }


// void _navigateToNotifications(
//       BuildContext context, String userId, String userRole) async {
//     LoggingService.log("Notification icon pressed");
//     try {
//       final notificationProvider =
//           Provider.of<NotificationProvider>(context, listen: false);
//       LoggingService.log("Fetching notifications");
//       await notificationProvider.fetchNotifications(userId, userRole);
//       LoggingService.log("Notifications fetched successfully");

//       await Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => NotificationsScreen(),
//         ),
//       );
//       LoggingService.log("Returned from NotificationsScreen");
//       // Refresh unread count after returning from NotificationsScreen
//       LoggingService.log("Updating unread count");
//       await notificationProvider.updateUnreadCount(userId, userRole);
//       LoggingService.log("Unread count updated");
//     } catch (e) {
//       LoggingService.log("Error handling notifications: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error loading notifications. Please try again.')),
//       );
//     }
//   }

//   // void _navigateToNotifications(
//   //     BuildContext context, String userId, String userRole) async {
//   //   print("Notification icon pressed");
//   //   try {
//   //     final notificationProvider =
//   //         Provider.of<NotificationProvider>(context, listen: false);
//   //     await notificationProvider.fetchNotifications(userId, userRole);
//   //     print("Notifications fetched successfully");

//   //     Navigator.push(
//   //       context,
//   //       MaterialPageRoute(
//   //         builder: (context) => NotificationsScreen(),
//   //       ),
//   //     ).then((_) {
//   //       notificationProvider.fetchNotifications(userId, userRole);
//   //     });
//   //   } catch (e) {
//   //     print("Error fetching notifications: $e");
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //           content: Text('Error loading notifications. Please try again.')),
//   //     );
//   //   }
//   // }

//   void _navigateToCreateRequest(BuildContext context) {
//     _navigateTo(context, CreateUserRequestScreen(), 'Create Request');
//   }

//   void _navigateToPendingRequests(BuildContext context) {
//     _navigateTo(context, UserPendingRequestsScreen(), 'Pending Requests');
//   }

//   void _navigateToCompletedRequests(BuildContext context) {
//     _navigateTo(context, CompletedRequestsScreen(), 'Completed Requests');
//   }

//   void _navigateToEditProfile(BuildContext context) {
//     _navigateTo(context, EditProfileScreen(), 'Edit Profile');
//   }

//   void _navigateTo(BuildContext context, Widget screen, String screenName) {
//     try {
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => screen),
//       );
//     } catch (e) {
//       print("Error navigating to $screenName screen: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error opening $screenName. Please try again.')),
//       );
//     }
//   }

//   void _logout(BuildContext context) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to log out. Please try again.')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userEmail = user?.email ?? 'User';
//     final userRole = authProvider.role ?? 'User';

//     return Scaffold(
//       body: RefreshIndicator(
//         onRefresh: () async {
//           // Refresh notifications and other data here
//           final notificationProvider =
//               Provider.of<NotificationProvider>(context, listen: false);
//           await notificationProvider.fetchNotifications(
//               user?.uid ?? '', userRole);
//           // Add other refresh logic as needed
//         },
//         child: CustomScrollView(
//           slivers: [
//             SliverAppBar(
//               expandedHeight: 200.0,
//               floating: false,
//               pinned: true,
//               flexibleSpace: FlexibleSpaceBar(
//                 title: Text('Welcome, $userEmail'),
//                 background: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topRight,
//                       end: Alignment.bottomLeft,
//                       colors: [Colors.blue, Colors.indigo],
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 _buildNotificationIcon(),
//                 IconButton(
//                   icon: Icon(Icons.logout),
//                   onPressed: () => _logout(context),
//                   tooltip: 'Logout',
//                 ),
//               ],
//             ),
//             SliverPadding(
//               padding: EdgeInsets.all(16.0),
//               sliver: SliverGrid(
//                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   childAspectRatio: 1.0,
//                   crossAxisSpacing: 16.0,
//                   mainAxisSpacing: 16.0,
//                 ),
//                 delegate: SliverChildListDelegate([
//                   _buildDashboardCard(
//                     context,
//                     'Create New Request',
//                     Icons.add_box,
//                     Colors.green,
//                     _navigateToCreateRequest,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Pending Requests',
//                     Icons.pending,
//                     Colors.orange,
//                     _navigateToPendingRequests,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Completed Requests',
//                     Icons.check_circle,
//                     Colors.blue,
//                     _navigateToCompletedRequests,
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Edit Profile',
//                     Icons.person,
//                     Colors.purple,
//                     _navigateToEditProfile,
//                   ),
//                 ]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// Widget _buildDashboardCard(
//   BuildContext context,
//   String title,
//   IconData icon,
//   Color color,
//   Function(BuildContext) onTap,
// ) {
//   return Card(
//     elevation: 4,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//     child: InkWell(
//       onTap: () {
//         try {
//           onTap(context);
//         } catch (e) {
//           print("Error navigating to $title: $e");
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error opening $title. Please try again.')),
//           );
//         }
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 48, color: color),
//             SizedBox(height: 16),
//             Text(
//               title,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey[800],
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }


// Widget _buildNotificationIcon() {
//   return Consumer2<AuthProvider, NotificationProvider>(
//     builder: (context, authProvider, notificationProvider, child) {
//       final userId = authProvider.user?.uid ?? '';
//       final userRole = authProvider.role ?? 'User';
//       print(
//           "Building notification icon for user: $userId, role: $userRole"); // Debug print

//       int unreadCount =
//           notificationProvider.getUnreadNotificationsCount(userId, userRole);
//       print("Unread notifications count: $unreadCount"); // Debug print

//       return Stack(
//         children: [
//           IconButton(
//             icon: Icon(Icons.notifications),
//             onPressed: () async {
//               print("Notification icon pressed"); // Debug print
//               try {
//                 // Refresh notifications before navigating
//                 await notificationProvider.fetchNotifications(userId, userRole);
//                 print("Notifications fetched successfully"); // Debug print

//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => NotificationsScreen(),
//                   ),
//                 ).then((_) {
//                   // Refresh the unread count after returning from NotificationsScreen
//                   notificationProvider.fetchNotifications(userId, userRole);
//                 });
//               } catch (e) {
//                 print("Error fetching notifications: $e"); // Debug print
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                       content: Text(
//                           'Error loading notifications. Please try again.')),
//                 );
//               }
//             },
//           ),
//           if (unreadCount > 0)
//             Positioned(
//               right: 0,
//               top: 0,
//               child: Container(
//                 padding: EdgeInsets.all(2),
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 constraints: BoxConstraints(
//                   minWidth: 16,
//                   minHeight: 16,
//                 ),
//                 child: Text(
//                   '$unreadCount',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ),
//         ],
//       );
//     },
//   );
// }

// void _navigateToCreateRequest(BuildContext context) {
//   try {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => CreateUserRequestScreen()),
//     );
//   } catch (e) {
//     print("Error navigating to Create Request screen: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//           content: Text('Error opening Create Request. Please try again.')),
//     );
//   }
// }

// void _navigateToPendingRequests(BuildContext context) {
//   try {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => UserPendingRequestsScreen()),
//     );
//   } catch (e) {
//     print("Error navigating to Pending Requests screen: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//           content: Text('Error opening Pending Requests. Please try again.')),
//     );
//   }
// }

// void _navigateToCompletedRequests(BuildContext context) {
//   try {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => CompletedRequestsScreen()),
//     );
//   } catch (e) {
//     print("Error navigating to Completed Requests screen: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//           content: Text('Error opening Completed Requests. Please try again.')),
//     );
//   }
// }

// void _navigateToEditProfile(BuildContext context) {
//   try {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => EditProfileScreen()),
//     );
//   } catch (e) {
//     print("Error navigating to Edit Profile screen: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Error opening Edit Profile. Please try again.')),
//     );
//   }
// }


// void _logout(BuildContext context) async {
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext context) {
//       return Center(child: CircularProgressIndicator());
//     },
//   );

//   try {
//     await Provider.of<RequestProvider>(context, listen: false)
//         .cancelListeners();
//     await Provider.of<AuthProvider>(context, listen: false).logout();
//     Navigator.of(context).pop(); // Dismiss loading dialog
//     Navigator.of(context).pushReplacementNamed('/login');
//   } catch (e) {
//     Navigator.of(context).pop(); // Dismiss loading dialog
//     print("Error during logout: $e");
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Failed to log out. Please try again.')),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userEmail = user?.email ?? 'User';
//      final userRole = authProvider.role ?? 'User';

//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar(
//             expandedHeight: 200.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text('Welcome, $userEmail'),
//               background: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topRight,
//                     end: Alignment.bottomLeft,
//                     colors: [Colors.blue, Colors.indigo],
//                   ),
//                 ),
//               ),
//             ),
//             actions: [
//               _buildNotificationIcon(),
//               ElevatedButton(
//                 onPressed: () => _logout(context),
//                 child: Text('Logout'),
//               )
//             ],
//           ),
//           SliverPadding(
//             padding: EdgeInsets.all(16.0),
//             sliver: SliverGrid(
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 childAspectRatio: 1.0,
//                 crossAxisSpacing: 16.0,
//                 mainAxisSpacing: 16.0,
//               ),
//               delegate: SliverChildListDelegate([
//                 _buildDashboardCard(
//                   context,
//                   'Create New Request',
//                   Icons.add_box,
//                   Colors.green,
//                   _navigateToCreateRequest,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Pending Requests',
//                   Icons.pending,
//                   Colors.orange,
//                   _navigateToPendingRequests,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Completed Requests',
//                   Icons.check_circle,
//                   Colors.blue,
//                   _navigateToCompletedRequests,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Edit Profile',
//                   Icons.person,
//                   Colors.purple,
//                   _navigateToEditProfile,
//                 ),
//               ]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     Function(BuildContext) onTap,
//   ) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () => onTap(context),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: color),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//   Widget _buildNotificationIcon() {
//     return Consumer2<NotificationProvider, AuthProvider>(
//       builder: (context, notificationProvider, authProvider, child) {
//         String userId = authProvider.user?.uid ?? '';
//         String userRole = authProvider.role ?? 'User';
//         int unreadCount =
//             notificationProvider.getUnreadNotificationsCount(userId, userRole);
//         return Stack(
//           children: [
//             IconButton(
//               icon: Icon(Icons.notifications),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => NotificationsScreen(
//                       userId: userId,
//                       userRole: userRole,
//                     ),
//                   ),
//                 );
//               },
//             ),
//             if (unreadCount > 0)
//               Positioned(
//                 right: 0,
//                 top: 0,
//                 child: Container(
//                   padding: EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     color: Colors.red,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   constraints: BoxConstraints(
//                     minWidth: 16,
//                     minHeight: 16,
//                   ),
//                   child: Text(
//                     '$unreadCount',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/request_provider.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import 'edit_profile_screen.dart';
// import 'pending_request_screen.dart';

// class UserDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final user = authProvider.user;
//     final userEmail = user?.email ?? 'User';

//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar(
//             expandedHeight: 200.0,
//             floating: false,
//             pinned: true,
//             flexibleSpace: FlexibleSpaceBar(
//               title: Text('Welcome, $userEmail'),
//               background: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topRight,
//                     end: Alignment.bottomLeft,
//                     colors: [Colors.blue, Colors.indigo],
//                   ),
//                 ),
//               ),
//             ),
//             actions: [
//               // IconButton(
//               //   icon: Icon(Icons.logout),
//               //   onPressed: () => _confirmLogout(context),
//               // ),
//               ElevatedButton(
//                 onPressed: () async {
//                   showDialog(
//                     context: context,
//                     barrierDismissible: false,
//                     builder: (BuildContext context) {
//                       return Center(child: CircularProgressIndicator());
//                     },
//                   );

//                   try {
//                     await Provider.of<AuthProvider>(context, listen: false)
//                         .logout();
//                     Navigator.of(context)
//                         .pop(); // Dismiss the loading indicator
//                     Navigator.of(context).pushReplacementNamed('/login');
//                   } catch (e) {
//                     Navigator.of(context)
//                         .pop(); // Dismiss the loading indicator
//                     print("Error during logout: $e");
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                           content:
//                               Text('Error logging out. Please try again.')),
//                     );
//                   }
//                 },
//                 child: Text('Logout'),
//               )
//             ],
//           ),
//           SliverPadding(
//             padding: EdgeInsets.all(16.0),
//             sliver: SliverGrid(
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 childAspectRatio: 1.0,
//                 crossAxisSpacing: 16.0,
//                 mainAxisSpacing: 16.0,
//               ),
//               delegate: SliverChildListDelegate([
//                 _buildDashboardCard(
//                   context,
//                   'Create New Request',
//                   Icons.add_box,
//                   Colors.green,
//                   _navigateToCreateRequest,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Pending Requests',
//                   Icons.pending,
//                   Colors.orange,
//                   _navigateToPendingRequests,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Completed Requests',
//                   Icons.check_circle,
//                   Colors.blue,
//                   _navigateToCompletedRequests,
//                 ),
//                 _buildDashboardCard(
//                   context,
//                   'Edit Profile',
//                   Icons.person,
//                   Colors.purple,
//                   _navigateToEditProfile,
//                 ),
//               ]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     Color color,
//     Function(BuildContext) onTap,
//   ) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: InkWell(
//         onTap: () => onTap(context),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: color),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _navigateToCreateRequest(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => CreateUserRequestScreen()),
//     );
//   }

//   void _navigateToPendingRequests(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => UserPendingRequestsScreen()),
//     );
//   }

//   void _navigateToCompletedRequests(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => CompletedRequestsScreen()),
//     );
//   }

//   void _navigateToEditProfile(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => EditProfileScreen()),
//     );
//   }

//   void _confirmLogout(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Confirm Logout'),
//         content: Text('Are you sure you want to log out?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               _performLogout(context);
//             },
//             child: Text('Logout'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _performLogout(BuildContext context) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Center(child: CircularProgressIndicator()),
//     );

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
//     } catch (e) {
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to log out. Please try again.')),
//       );
//     }
//   }
// }
