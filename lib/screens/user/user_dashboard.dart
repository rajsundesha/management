import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'completed_requests_screen.dart';
import 'create_request_screen.dart';
import 'edit_profile_screen.dart';
import 'pending_request_screen.dart';

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
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
          children: [
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      title: Text('Create New Request'),
                      leading: Icon(Icons.add_box),
                      onTap: () => _navigateToCreateRequest(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Pending Requests'),
                      leading: Icon(Icons.pending),
                      onTap: () => _navigateToPendingRequests(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Completed Requests'),
                      leading: Icon(Icons.check_circle),
                      onTap: () => _navigateToCompletedRequests(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Edit Profile'),
                      leading: Icon(Icons.person),
                      onTap: () => _navigateToEditProfile(context),
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

  void _navigateToCreateRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateUserRequestScreen()),
    );
  }

  void _navigateToPendingRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PendingRequestsScreen()),
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
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import 'completed_requests_screen.dart';
// import 'create_request_screen.dart';
// import '../edit_profile_screen.dart';
// import 'pending_request_screen.dart'; // Assume you have an EditProfileScreen

// class UserDashboard extends StatefulWidget {
//   @override
//   _UserDashboardState createState() => _UserDashboardState();
// }

// class _UserDashboardState extends State<UserDashboard> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Dashboard'),
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
//           children: [
//             Expanded(
//               child: ListView(
//                 children: [
//                   Card(
//                     child: ListTile(
//                       title: Text('Create New Request'),
//                       leading: Icon(Icons.add_box),
//                       onTap: () => _navigateToCreateRequest(context),
//                     ),
//                   ),
//                   Card(
//                     child: ListTile(
//                       title: Text('Pending Requests'),
//                       leading: Icon(Icons.pending),
//                       onTap: () => _navigateToPendingRequests(context),
//                     ),
//                   ),
//                   Card(
//                     child: ListTile(
//                       title: Text('Completed Requests'),
//                       leading: Icon(Icons.check_circle),
//                       onTap: () => _navigateToCompletedRequests(context),
//                     ),
//                   ),
//                   Card(
//                     child: ListTile(
//                       title: Text('Edit Profile'),
//                       leading: Icon(Icons.person),
//                       onTap: () => _navigateToEditProfile(context),
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

//   void _navigateToCreateRequest(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => CreateRequestScreen()),
//     );
//   }

//   void _navigateToPendingRequests(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => PendingRequestsScreen()),
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
// }
