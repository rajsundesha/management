import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/request_provider.dart';
import '../common/notification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.displayName ?? 'Admin';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(userName),
            SliverPadding(
              padding: EdgeInsets.all(16),
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
                    _buildDashboardGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(String userName) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Dashboard'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.indigo],
            ),
          ),
        ),
      ),
      actions: [
        _buildNotificationIcon(),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildDashboardCard(
            context, 'Manage Requests', Icons.request_page, '/manage_requests'),
        _buildDashboardCard(
            context, 'Manage Inventory', Icons.inventory, '/manage_inventory'),
        _buildDashboardCard(
            context, 'User Management', Icons.people, '/user_management'),
        _buildDashboardCard(context, 'Reports', Icons.bar_chart, '/reports'),
        _buildDashboardCard(context, 'Stock Requests', Icons.add_shopping_cart,
            '/admin_manage_stock_requests'),
        _buildDashboardCard(context, 'Account Deletion', Icons.delete_forever,
            '/account_deletion_requests'),
        _buildDashboardCard(context, 'Manage Locations', Icons.location_on,
            '/manage_locations'),
        _buildDashboardCard(context, 'Settings', Icons.settings, '/settings'),
      ],
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, String title, IconData icon, String route) {
    return GestureDetector(
      onTap: () => _navigateTo(context, title, route),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.blue.shade100],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.blue.shade700),
                SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String title, String route) {
    try {
      Navigator.pushNamed(context, route);
    } catch (e) {
      print("Error navigating to $title: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $title. Please try again.')),
      );
    }
  }

  Widget _buildNotificationIcon() {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        final userId = authProvider.user?.uid ?? '';
        final userRole = authProvider.role ?? 'Admin';
        int unreadCount =
            notificationProvider.getUnreadNotificationsCount(userId, userRole);

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () => _navigateToNotificationsScreen(
                  userId, userRole, notificationProvider),
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
  }

  Future<void> _navigateToNotificationsScreen(String userId, String userRole,
      NotificationProvider notificationProvider) async {
    try {
      await notificationProvider.fetchNotifications(userId, userRole);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationsScreen()),
      ).then((_) => notificationProvider.fetchNotifications(userId, userRole));
    } catch (e) {
      print("Error fetching notifications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading notifications. Please try again.')),
      );
    }
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _logout,
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text('Logout'),
    );
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);

      await Future.wait([
        notificationProvider.fetchNotifications(
            authProvider.user?.uid ?? '', authProvider.role ?? 'Admin'),
        _refreshAccountDeletionRequests(),
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard refreshed successfully')),
      );
    } catch (e) {
      print("Error refreshing dashboard: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to refresh dashboard. Please try again.')),
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshAccountDeletionRequests() async {
    try {
      final deletionRequests = await FirebaseFirestore.instance
          .collection('deletion_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      print(
          'Fetched ${deletionRequests.docs.length} pending deletion requests');
      // TODO: Update a provider or state with the fetched deletion requests
    } catch (e) {
      print('Error refreshing account deletion requests: $e');
      throw e; // Re-throw the error to be caught by the _refreshDashboard method
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await Provider.of<RequestProvider>(context, listen: false)
          .cancelListeners();
      await Provider.of<AuthProvider>(context, listen: false).logout();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAccountDeletionRequest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('You must be logged in to request account deletion.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('deletion_requests').add({
        'userId': user.uid,
        'email': user.email,
        'requestDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'scheduledDeletionDate':
            Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Account deletion request submitted successfully. It will be processed in 7 days.')),
      );
    } catch (e) {
      print('Error submitting account deletion request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to submit account deletion request. You may not have permission to perform this action.')),
      );
    }
  }
}
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../providers/request_provider.dart';
// import '../common/notification_screen.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   @override
//   _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   bool _isLoading = false;
//   bool _isRefreshing = false;

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final userName = authProvider.user?.displayName ?? 'Admin';

//     return Scaffold(
//       body: RefreshIndicator(
//         onRefresh: _refreshDashboard,
//         child: CustomScrollView(
//           slivers: [
//             _buildSliverAppBar(userName),
//             SliverPadding(
//               padding: EdgeInsets.all(16),
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
//                     _buildDashboardGrid(),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar(String userName) {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: Text('Dashboard'),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Colors.blue, Colors.indigo],
//             ),
//           ),
//         ),
//       ),
//       actions: [
//         _buildNotificationIcon(),
//         _buildLogoutButton(),
//       ],
//     );
//   }

//   Widget _buildDashboardGrid() {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       crossAxisSpacing: 16,
//       mainAxisSpacing: 16,
//       children: [
//         _buildDashboardCard(
//             context, 'Manage Requests', Icons.request_page, '/manage_requests'),
//         _buildDashboardCard(
//             context, 'Manage Inventory', Icons.inventory, '/manage_inventory'),
//         _buildDashboardCard(
//             context, 'User Management', Icons.people, '/user_management'),
//         _buildDashboardCard(context, 'Reports', Icons.bar_chart, '/reports'),
//         _buildDashboardCard(context, 'Stock Requests', Icons.add_shopping_cart,
//             '/admin_manage_stock_requests'),
//         _buildDashboardCard(context, 'Account Deletion', Icons.delete_forever,
//             '/account_deletion_requests'),
//         _buildDashboardCard(context, 'Settings', Icons.settings, '/settings'),
//       ],
//     );
//   }

//   Widget _buildDashboardCard(
//       BuildContext context, String title, IconData icon, String route) {
//     return GestureDetector(
//       onTap: () => _navigateTo(context, title, route),
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Colors.blue.shade50, Colors.blue.shade100],
//             ),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(icon, size: 48, color: Colors.blue.shade700),
//                 SizedBox(height: 8),
//                 Text(
//                   title,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue.shade900),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _navigateTo(BuildContext context, String title, String route) {
//     try {
//       Navigator.pushNamed(context, route);
//     } catch (e) {
//       print("Error navigating to $title: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error opening $title. Please try again.')),
//       );
//     }
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Admin';
//         int unreadCount =
//             notificationProvider.getUnreadNotificationsCount(userId, userRole);

//         return Stack(
//           children: [
//             IconButton(
//               icon: Icon(Icons.notifications),
//               onPressed: () => _navigateToNotificationsScreen(
//                   userId, userRole, notificationProvider),
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
//                   constraints: BoxConstraints(minWidth: 16, minHeight: 16),
//                   child: Text(
//                     '$unreadCount',
//                     style: TextStyle(color: Colors.white, fontSize: 10),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _navigateToNotificationsScreen(String userId, String userRole,
//       NotificationProvider notificationProvider) async {
//     try {
//       await notificationProvider.fetchNotifications(userId, userRole);
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => NotificationsScreen()),
//       ).then((_) => notificationProvider.fetchNotifications(userId, userRole));
//     } catch (e) {
//       print("Error fetching notifications: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error loading notifications. Please try again.')),
//       );
//     }
//   }

//   Widget _buildLogoutButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _logout,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               ),
//             )
//           : Text('Logout'),
//     );
//   }

//   Future<void> _refreshDashboard() async {
//     if (_isRefreshing) return;
//     setState(() => _isRefreshing = true);

//     try {
//       final authProvider = Provider.of<AuthProvider>(context, listen: false);
//       final notificationProvider =
//           Provider.of<NotificationProvider>(context, listen: false);

//       await Future.wait([
//         notificationProvider.fetchNotifications(
//             authProvider.user?.uid ?? '', authProvider.role ?? 'Admin'),
//         _refreshAccountDeletionRequests(),
//       ]);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Dashboard refreshed successfully')),
//       );
//     } catch (e) {
//       print("Error refreshing dashboard: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Failed to refresh dashboard. Please try again.')),
//       );
//     } finally {
//       setState(() => _isRefreshing = false);
//     }
//   }

//   Future<void> _refreshAccountDeletionRequests() async {
//     try {
//       final deletionRequests = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('status', isEqualTo: 'pending')
//           .get();

//       print(
//           'Fetched ${deletionRequests.docs.length} pending deletion requests');
//       // TODO: Update a provider or state with the fetched deletion requests
//     } catch (e) {
//       print('Error refreshing account deletion requests: $e');
//       throw e; // Re-throw the error to be caught by the _refreshDashboard method
//     }
//   }

//   Future<void> _logout() async {
//     if (!mounted) return;

//     setState(() => _isLoading = true);

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();

//       if (!mounted) return;
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       if (!mounted) return;
//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _handleAccountDeletionRequest() async {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final user = authProvider.user;

//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text('You must be logged in to request account deletion.')),
//       );
//       return;
//     }

//     try {
//       await FirebaseFirestore.instance.collection('deletion_requests').add({
//         'userId': user.uid,
//         'email': user.email,
//         'requestDate': FieldValue.serverTimestamp(),
//         'status': 'pending',
//         'scheduledDeletionDate':
//             Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(
//                 'Account deletion request submitted successfully. It will be processed in 7 days.')),
//       );
//     } catch (e) {
//       print('Error submitting account deletion request: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(
//                 'Failed to submit account deletion request. You may not have permission to perform this action.')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../providers/request_provider.dart';
// import '../common/notification_screen.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   @override
//   _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   bool _isLoading = false;
//   bool _isRefreshing = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//         actions: [
//           _buildNotificationIcon(),
//           _buildLogoutButton(),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refreshDashboard,
//         child: Stack(
//           children: [
//             SingleChildScrollView(
//               physics: AlwaysScrollableScrollPhysics(),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Admin Dashboard',
//                       style:
//                           TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 16),
//                     _buildDashboardGrid(),
//                   ],
//                 ),
//               ),
//             ),
//             if (_isRefreshing)
//               Container(
//                 color: Colors.black.withOpacity(0.3),
//                 child: Center(
//                   child: CircularProgressIndicator(),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDashboardGrid() {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       crossAxisSpacing: 16,
//       mainAxisSpacing: 16,
//       children: [
//         _buildDashboardCard(
//             context, 'Manage Requests', Icons.request_page, '/manage_requests'),
//         _buildDashboardCard(
//             context, 'Manage Inventory', Icons.inventory, '/manage_inventory'),
//         _buildDashboardCard(
//             context, 'User Management', Icons.people, '/user_management'),
//         _buildDashboardCard(context, 'Reports', Icons.report, '/reports'),
//         _buildDashboardCard(context, 'Manage Stock Requests',
//             Icons.add_shopping_cart, '/admin_manage_stock_requests'),
//         _buildDashboardCard(context, 'Account Deletion Requests',
//             Icons.delete_forever, '/account_deletion_requests'),
//         _buildDashboardCard(context, 'Settings', Icons.settings, '/settings'),
//       ],
//     );
//   }

//   Widget _buildDashboardCard(
//       BuildContext context, String title, IconData icon, String route) {
//     return GestureDetector(
//       onTap: () {
//         try {
//           Navigator.pushNamed(context, route);
//         } catch (e) {
//           print("Error navigating to $title: $e");
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error opening $title. Please try again.')),
//           );
//         }
//       },
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: Colors.blue),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Admin';
//         int unreadCount =
//             notificationProvider.getUnreadNotificationsCount(userId, userRole);

//         return Stack(
//           children: [
//             IconButton(
//               icon: Icon(Icons.notifications),
//               onPressed: () => _navigateToNotificationsScreen(
//                   userId, userRole, notificationProvider),
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
//                     style: TextStyle(color: Colors.white, fontSize: 10),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _navigateToNotificationsScreen(String userId, String userRole,
//       NotificationProvider notificationProvider) async {
//     try {
//       await notificationProvider.fetchNotifications(userId, userRole);
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => NotificationsScreen()),
//       ).then((_) => notificationProvider.fetchNotifications(userId, userRole));
//     } catch (e) {
//       print("Error fetching notifications: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error loading notifications. Please try again.')),
//       );
//     }
//   }

//   Widget _buildLogoutButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _logout,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               ),
//             )
//           : Text('Logout'),
//     );
//   }

//   Future<void> _refreshDashboard() async {
//     if (_isRefreshing) return;
//     setState(() => _isRefreshing = true);

//     try {
//       final authProvider = Provider.of<AuthProvider>(context, listen: false);
//       final notificationProvider =
//           Provider.of<NotificationProvider>(context, listen: false);

//       await Future.wait([
//         notificationProvider.fetchNotifications(
//             authProvider.user?.uid ?? '', authProvider.role ?? 'Admin'),
//         _refreshAccountDeletionRequests(),
//       ]);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Dashboard refreshed successfully')),
//       );
//     } catch (e) {
//       print("Error refreshing dashboard: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Failed to refresh dashboard. Please try again.')),
//       );
//     } finally {
//       setState(() => _isRefreshing = false);
//     }
//   }

//   Future<void> _refreshAccountDeletionRequests() async {
//     try {
//       final deletionRequests = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('status', isEqualTo: 'pending')
//           .get();

//       print(
//           'Fetched ${deletionRequests.docs.length} pending deletion requests');
//       // Process the deletionRequests as needed
//     } catch (e) {
//       print('Error refreshing account deletion requests: $e');
//     }
//   }

//   Future<void> _logout() async {
//     if (!mounted) return;

//     setState(() => _isLoading = true);

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();

//       if (!mounted) return;
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       if (!mounted) return;
//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../providers/request_provider.dart';
// import '../common/notification_screen.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   @override
//   _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   bool _isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//         actions: [
//           _buildNotificationIcon(),
//           ElevatedButton(
//             onPressed: _isLoading ? null : _logout,
//             child: _isLoading
//                 ? SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   )
//                 : Text('Logout'),
//           )
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: () async {
//           final authProvider =
//               Provider.of<AuthProvider>(context, listen: false);
//           final notificationProvider =
//               Provider.of<NotificationProvider>(context, listen: false);
//           await notificationProvider.fetchNotifications(
//               authProvider.user?.uid ?? '', authProvider.role ?? 'Admin');
//           // Add other refresh logic as needed
//         },
//         child: SingleChildScrollView(
//           physics: AlwaysScrollableScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Admin Dashboard',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 GridView.count(
//                   shrinkWrap: true,
//                   physics: NeverScrollableScrollPhysics(),
//                   crossAxisCount: 2,
//                   crossAxisSpacing: 16,
//                   mainAxisSpacing: 16,
//                   children: [
//                     _buildDashboardCard(
//                       context,
//                       'Manage Requests',
//                       Icons.request_page,
//                       '/manage_requests',
//                     ),
//                     _buildDashboardCard(
//                       context,
//                       'Manage Inventory',
//                       Icons.inventory,
//                       '/manage_inventory',
//                     ),
//                     _buildDashboardCard(
//                       context,
//                       'User Management',
//                       Icons.people,
//                       '/user_management',
//                     ),
//                     _buildDashboardCard(
//                       context,
//                       'Reports',
//                       Icons.report,
//                       '/reports',
//                     ),
//                     _buildDashboardCard(
//                       context,
//                       'Manage Stock Requests',
//                       Icons.add_shopping_cart,
//                       '/admin_manage_stock_requests',
//                     ),
//                     _buildDashboardCard(
//                       context,
//                       'Settings',
//                       Icons.settings,
//                       '/settings',
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

// Widget _buildDashboardCard(
//     BuildContext context,
//     String title,
//     IconData icon,
//     String route,
//   ) {
//     return GestureDetector(
//       onTap: () {
//         try {
//           Navigator.pushNamed(context, route);
//         } catch (e) {
//           print("Error navigating to $title: $e");
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error opening $title. Please try again.')),
//           );
//         }
//       },
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: Colors.blue),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
  


//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Admin';
//         print(
//             "Building notification icon for user: $userId, role: $userRole"); // Debug print

//         int unreadCount =
//             notificationProvider.getUnreadNotificationsCount(userId, userRole);
//         print("Unread notifications count: $unreadCount"); // Debug print

//         return Stack(
//           children: [
//             IconButton(
//               icon: Icon(Icons.notifications),
//               onPressed: () async {
//                 print("Notification icon pressed"); // Debug print
//                 try {
//                   // Refresh notifications before navigating
//                   await notificationProvider.fetchNotifications(
//                       userId, userRole);
//                   print("Notifications fetched successfully"); // Debug print

//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => NotificationsScreen(),
//                     ),
//                   ).then((_) {
//                     // Refresh the unread count after returning from NotificationsScreen
//                     notificationProvider.fetchNotifications(userId, userRole);
//                   });
//                 } catch (e) {
//                   print("Error fetching notifications: $e"); // Debug print
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                         content: Text(
//                             'Error loading notifications. Please try again.')),
//                   );
//                 }
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

//   Future<void> _logout() async {
//     if (!mounted) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelListeners();
//       await Provider.of<AuthProvider>(context, listen: false).logout();

//       if (!mounted) return;

//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       if (!mounted) return;

//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
// }
// import 'package:dhavla_road_project/providers/notification_provider.dart';
// import 'package:dhavla_road_project/providers/request_provider.dart';
// import 'package:dhavla_road_project/screens/common/notification_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart' as custom_notification;
// // import '../common/notifications_screen.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   @override
//   _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   bool _isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//         actions: [
//           _buildNotificationIcon(),
//           ElevatedButton(
//             onPressed: _isLoading ? null : _logout,
//             child: _isLoading
//                 ? SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   )
//                 : Text('Logout'),
//           )
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Admin Dashboard',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//                 children: [
//                   _buildDashboardCard(
//                     context,
//                     'Manage Requests',
//                     Icons.request_page,
//                     '/manage_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Inventory',
//                     Icons.inventory,
//                     '/manage_inventory',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'User Management',
//                     Icons.people,
//                     '/user_management',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Reports',
//                     Icons.report,
//                     '/reports',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Stock Requests',
//                     Icons.add_shopping_cart,
//                     '/admin_manage_stock_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Settings',
//                     Icons.settings,
//                     '/settings',
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

  // Widget _buildDashboardCard(
  //   BuildContext context,
  //   String title,
  //   IconData icon,
  //   String route,
  // ) {
  //   return GestureDetector(
  //     onTap: () {
  //       Navigator.pushNamed(context, route);
  //     },
  //     child: Card(
  //       elevation: 4,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //       ),
  //       child: Padding(
  //         padding: const EdgeInsets.all(16.0),
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Icon(icon, size: 48, color: Colors.blue),
  //             SizedBox(height: 16),
  //             Text(
  //               title,
  //               textAlign: TextAlign.center,
  //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  
// Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ??
//             'Admin'; // Replace 'User' with the appropriate default role for each dashboard
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
//                     builder: (context) => NotificationsScreen(),
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

//   Future<void> _logout() async {
//     if (!mounted) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       await Provider.of<AuthProvider>(context, listen: false).logout();

//       if (!mounted) return;

//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       if (!mounted) return;

//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';

// class AdminDashboardScreen extends StatefulWidget {
//   @override
//   _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   bool _isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//         actions: [
//           ElevatedButton(
//             onPressed: _isLoading ? null : _logout,
//             child: _isLoading
//                 ? SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   )
//                 : Text('Logout'),
//           )
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Admin Dashboard',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//                 children: [
//                   _buildDashboardCard(
//                     context,
//                     'Manage Requests',
//                     Icons.request_page,
//                     '/manage_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Inventory',
//                     Icons.inventory,
//                     '/manage_inventory',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'User Management',
//                     Icons.people,
//                     '/user_management',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Reports',
//                     Icons.report,
//                     '/reports',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Stock Requests',
//                     Icons.add_shopping_cart,
//                     '/admin_manage_stock_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Settings',
//                     Icons.settings,
//                     '/settings',
//                   ),
//                 ],
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
//     String route,
//   ) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.pushNamed(context, route);
//       },
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: Colors.blue),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _logout() async {
//     if (!mounted) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       await Provider.of<AuthProvider>(context, listen: false).logout();

//       if (!mounted) return;

//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       if (!mounted) return;

//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer<custom_notification.NotificationProvider>(
//       builder: (context, notificationProvider, child) {
//         int unreadCount = notificationProvider.unreadNotificationsCount;
//         return Stack(
//           children: [
//             IconButton(
//               icon: Icon(Icons.notifications),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                       builder: (context) => NotificationsScreen()),
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

// }

// import 'package:dhavla_road_project/screens/admin/admin_manage_stock_requests_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';

// class AdminDashboardScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//         actions: [
//           // IconButton(
//           //   icon: Icon(Icons.logout),
//           //   onPressed: () {
//           //     Provider.of<AuthProvider>(context, listen: false).logout();
//           //     Navigator.pushReplacementNamed(context, '/');
//           //   },
//           // ),
//           ElevatedButton(
//             onPressed: () async {
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (BuildContext context) {
//                   return Center(child: CircularProgressIndicator());
//                 },
//               );

//               try {
//                 await Provider.of<AuthProvider>(context, listen: false)
//                     .logout();
//                 Navigator.of(context).pop(); // Dismiss the loading indicator
//                 Navigator.of(context).pushReplacementNamed('/login');
//               } catch (e) {
//                 Navigator.of(context).pop(); // Dismiss the loading indicator
//                 print("Error during logout: $e");
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                       content: Text('Error logging out. Please try again.')),
//                 );
//               }
//             },
//             child: Text('Logout'),
//           )
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Admin Dashboard',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//                 children: [
//                   _buildDashboardCard(
//                     context,
//                     'Manage Requests',
//                     Icons.request_page,
//                     '/manage_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Inventory',
//                     Icons.inventory,
//                     '/manage_inventory',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'User Management',
//                     Icons.people,
//                     '/user_management',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Reports',
//                     Icons.report,
//                     '/reports',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Stock Requests',
//                     Icons.add_shopping_cart,
//                     '/admin_manage_stock_requests',
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Settings',
//                     Icons.settings,
//                     '/settings',
//                   ),
//                 ],
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
//     String route,
//   ) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.pushNamed(context, route);
//       },
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48, color: Colors.blue),
//               SizedBox(height: 16),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
