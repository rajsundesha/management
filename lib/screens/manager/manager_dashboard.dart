import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'manager_create_request_screen.dart';
import 'manager_inventory_screen.dart';
import 'manager_pending_requests_screen.dart';
import 'manager_approved_requests_screen.dart';
import 'manager_completed_requests_screen.dart'; // Import the completed requests screen
import 'manager_statistics_screen.dart';

class ManagerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manager Dashboard'),
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
}



// import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import '../../providers/request_provider.dart';
// import 'manager_create_request_screen.dart';
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
