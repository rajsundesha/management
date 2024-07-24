import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final userEmail = user?.email ?? 'User';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Welcome, $userEmail'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.blue, Colors.indigo],
                  ),
                ),
              ),
            ),
            actions: [
              _buildNotificationIcon(),
              ElevatedButton(
                onPressed: () => _logout(context),
                child: Text('Logout'),
              )
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
                  'Create New Request',
                  Icons.add_box,
                  Colors.green,
                  _navigateToCreateRequest,
                ),
                _buildDashboardCard(
                  context,
                  'Pending Requests',
                  Icons.pending,
                  Colors.orange,
                  _navigateToPendingRequests,
                ),
                _buildDashboardCard(
                  context,
                  'Completed Requests',
                  Icons.check_circle,
                  Colors.blue,
                  _navigateToCompletedRequests,
                ),
                _buildDashboardCard(
                  context,
                  'Edit Profile',
                  Icons.person,
                  Colors.purple,
                  _navigateToEditProfile,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Function(BuildContext) onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
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

  void _navigateToCreateRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateUserRequestScreen()),
    );
  }

  void _navigateToPendingRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserPendingRequestsScreen()),
    );
  }

  void _navigateToCompletedRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CompletedRequestsScreen()),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
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
      await Provider.of<AuthProvider>(context, listen: false).logout();
      Navigator.of(context).pop(); // Dismiss loading dialog
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }
}

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
