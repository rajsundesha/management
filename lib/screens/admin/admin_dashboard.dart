import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:dhavla_road_project/screens/common/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart' as custom_notification;
// import '../common/notifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          _buildNotificationIcon(),
          ElevatedButton(
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
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
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
                    'Manage Requests',
                    Icons.request_page,
                    '/manage_requests',
                  ),
                  _buildDashboardCard(
                    context,
                    'Manage Inventory',
                    Icons.inventory,
                    '/manage_inventory',
                  ),
                  _buildDashboardCard(
                    context,
                    'User Management',
                    Icons.people,
                    '/user_management',
                  ),
                  _buildDashboardCard(
                    context,
                    'Reports',
                    Icons.report,
                    '/reports',
                  ),
                  _buildDashboardCard(
                    context,
                    'Manage Stock Requests',
                    Icons.add_shopping_cart,
                    '/admin_manage_stock_requests',
                  ),
                  _buildDashboardCard(
                    context,
                    'Settings',
                    Icons.settings,
                    '/settings',
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
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.blue),
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

  Future<void> _logout() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

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
