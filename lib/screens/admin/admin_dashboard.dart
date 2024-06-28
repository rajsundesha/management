import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
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
}


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
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: () {
//               Provider.of<AuthProvider>(context, listen: false).logout();
//               Navigator.pushReplacementNamed(context, '/');
//             },
//           ),
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





















// import 'package:flutter/material.dart';

// class AdminDashboardScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
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


// import 'package:flutter/material.dart';

// class AdminDashboardScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
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


// import 'package:flutter/material.dart';

// class AdminDashboardScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Dashboard'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Expanded(
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 children: [
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.request_page,
//                     label: 'Manage Requests',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/requests');
//                     },
//                   ),
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.inventory,
//                     label: 'Manage Inventory',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/inventory');
//                     },
//                   ),
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.people,
//                     label: 'Manage Users',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/users');
//                     },
//                   ),
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.analytics,
//                     label: 'Reports & Analytics',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/reports');
//                     },
//                   ),
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.settings,
//                     label: 'Settings',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/settings');
//                     },
//                   ),
//                   _buildDashboardItem(
//                     context,
//                     icon: Icons.notifications,
//                     label: 'Notifications',
//                     onTap: () {
//                       Navigator.pushNamed(context, '/admin/notifications');
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDashboardItem(BuildContext context,
//       {required IconData icon,
//       required String label,
//       required Function() onTap}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Card(
//         margin: const EdgeInsets.all(8.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               size: 50,
//               color: Theme.of(context).primaryColor,
//             ),
//             SizedBox(height: 16),
//             Text(
//               label,
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


