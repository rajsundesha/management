import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/request_provider.dart';
import '../common/notification_screen.dart';
import 'manager_create_request_screen.dart';
import 'manager_stock_request_screen.dart';
import 'manager_manage_request_screen.dart';
import 'manager_approved_requests_screen.dart';
import 'manager_completed_requests_screen.dart';
import 'manager_inventory_screen.dart';
import 'manager_statistics_screen.dart';

class ManagerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Manager Dashboard',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue, Colors.purple],
                    ),
                  ),
                ),
              ),
              actions: [
                _buildNotificationIcon(),
                IconButton(
                  icon: Icon(Icons.logout, color: Colors.white),
                  onPressed: () => _logout(context),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                ),
                delegate: SliverChildListDelegate([
                  _buildDashboardCard(
                    context,
                    'Create Request',
                    Icons.add_box,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CreateManagerRequestScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Create Stock Request',
                    Icons.add_shopping_cart,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerStockRequestScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Manage Requests',
                    Icons.assignment,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerManageRequestsScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Approved Requests',
                    Icons.approval,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ManagerApprovedRequestsScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Completed Requests',
                    Icons.check_circle,
                    Colors.teal,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ManagerCompletedRequestsScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Inventory Details',
                    Icons.inventory,
                    Colors.indigo,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerInventoryScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Statistics',
                    Icons.bar_chart,
                    Colors.red,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerStatisticsScreen()),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        try {
          onTap();
        } catch (e) {
          print("Error navigating to $title: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening $title. Please try again.')),
          );
        }
      },
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        final userId = authProvider.user?.uid ?? '';
        final userRole = authProvider.role ?? 'Manager';
        int unreadCount =
            notificationProvider.getUnreadNotificationsCount(userId, userRole);

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () async {
                try {
                  await notificationProvider.fetchNotifications(
                      userId, userRole);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationsScreen()),
                  ).then((_) {
                    notificationProvider.fetchNotifications(userId, userRole);
                  });
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

  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          Center(child: CircularProgressIndicator()),
    );

    try {
      await Provider.of<RequestProvider>(context, listen: false)
          .cancelListeners();
      await Provider.of<AuthProvider>(context, listen: false).logout(context);
      Navigator.of(context).pop(); // Dismiss the loading indicator
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss the loading indicator
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out. Please try again.')),
      );
    }
  }
}


// import 'package:dhavla_road_project/providers/request_provider.dart';
// import 'package:dhavla_road_project/screens/manager/manager_manage_request_screen.dart';
// import 'package:dhavla_road_project/screens/manager/manager_stock_request_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../common/notification_screen.dart';
// import 'manager_create_request_screen.dart';
// import 'manager_inventory_screen.dart';
// import 'manager_approved_requests_screen.dart';
// import 'manager_completed_requests_screen.dart';
// import 'manager_statistics_screen.dart';

// class ManagerDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manager Dashboard'),
//         actions: [
//           _buildNotificationIcon(),
//           ElevatedButton(
//             onPressed: () => _logout(context),
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
//               'Manager Dashboard',
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
//                     'Create Request',
//                     Icons.add_box,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => CreateManagerRequestScreen()),
//                     ),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Create Stock Request',
//                     Icons.add_shopping_cart,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => ManagerStockRequestScreen()),
//                     ),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Manage Requests',
//                     Icons.assignment,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => ManagerManageRequestsScreen()),
//                     ),
//                   ),
//                   // _buildDashboardCard(
//                   //   context,
//                   //   'Pending Requests',
//                   //   Icons.pending,
//                   //   () => Navigator.push(
//                   //     context,
//                   //     MaterialPageRoute(
//                   //         builder: (context) => ManagerPendingRequestsScreen()),
//                   //   ),
//                   // ),
//                   _buildDashboardCard(
//                     context,
//                     'Approved Requests',
//                     Icons.approval,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) =>
//                               ManagerApprovedRequestsScreen()),
//                     ),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Completed Requests',
//                     Icons.check_circle,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) =>
//                               ManagerCompletedRequestsScreen()),
//                     ),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Inventory Details',
//                     Icons.inventory,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => ManagerInventoryScreen()),
//                     ),
//                   ),
//                   _buildDashboardCard(
//                     context,
//                     'Statistics',
//                     Icons.bar_chart,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => ManagerStatisticsScreen()),
//                     ),
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
//       BuildContext context, String title, IconData icon, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: () {
//         try {
//           onTap();
//         } catch (e) {
//           print("Error navigating to $title: $e");
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error opening $title. Please try again.')),
//           );
//         }
//       },
//       child: Card(
//         elevation: 4,
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 48),
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
//         final userRole = authProvider.role ?? 'Manager';
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
//       await Provider.of<AuthProvider>(context, listen: false).logout(context);
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       Navigator.of(context).pushReplacementNamed('/login');
//     } catch (e) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       print("Error during logout: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error logging out. Please try again.')),
//       );
//     }
//   }
// }
