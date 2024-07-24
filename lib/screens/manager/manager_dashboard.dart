import 'package:dhavla_road_project/screens/manager/manager_stock_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../common/notification_screen.dart';
import 'manager_create_request_screen.dart';
import 'manager_inventory_screen.dart';
import 'manager_pending_requests_screen.dart';
import 'manager_approved_requests_screen.dart';
import 'manager_completed_requests_screen.dart';
import 'manager_statistics_screen.dart';

class ManagerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager Dashboard'),
        actions: [
          _buildNotificationIcon(),
          ElevatedButton(
            onPressed: () => _logout(context),
            child: Text('Logout'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    'Create Request',
                    Icons.add_box,
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
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerStockRequestScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Pending Requests',
                    Icons.pending,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerPendingRequestsScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Approved Requests',
                    Icons.approval,
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
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ManagerStatisticsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        int unreadCount = notificationProvider.unreadNotificationsCount;
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NotificationsScreen()),
                );
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
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
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      await Provider.of<AuthProvider>(context, listen: false).logout();
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

// import 'package:dhavla_road_project/screens/manager/manager_stock_request_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// // import 'create_manager_stock_order_screen.dart';
// import 'manager_create_request_screen.dart';
// // import 'manager_create_stock_request_screen.dart'; // New screen import
// import 'manager_inventory_screen.dart';
// import 'manager_pending_requests_screen.dart';
// import 'manager_approved_requests_screen.dart';
// import 'manager_completed_requests_screen.dart'; // Import the completed requests screen
// import 'manager_statistics_screen.dart';

// class ManagerDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manager Dashboard'),
//         actions: [
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
//           // IconButton(
//           //   icon: Icon(Icons.logout),
//           //   onPressed: () {
//           //     Provider.of<AuthProvider>(context, listen: false).logout();
//           //     Navigator.pushReplacementNamed(context, '/');
//           //   },
//           // ),
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
//                     'Pending Requests',
//                     Icons.pending,
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => ManagerPendingRequestsScreen()),
//                     ),
//                   ),
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
//       onTap: onTap,
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
// }
