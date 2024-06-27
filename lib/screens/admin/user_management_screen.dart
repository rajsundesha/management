import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'edit_user_bottom_sheet.dart';

class UserManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  return ListView.builder(
                    itemCount: userProvider.users.length,
                    itemBuilder: (context, index) {
                      final user = userProvider.users[index];
                      return Card(
                        child: ListTile(
                          title: Text(user['name']),
                          subtitle: Text(user['email']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editUser(context, index, user);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  userProvider.deleteUser(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _addUser(context);
                },
                child: Text('Add User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addUser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditUserBottomSheet(),
    );
  }

  void _editUser(BuildContext context, int index, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditUserBottomSheet(
        index: index,
        user: user,
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/user_provider.dart';
// import 'edit_user_bottom_sheet.dart';

// class UserManagementScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Management'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Users',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: Consumer<UserProvider>(
//                 builder: (context, userProvider, child) {
//                   return ListView.builder(
//                     itemCount: userProvider.users.length,
//                     itemBuilder: (context, index) {
//                       final user = userProvider.users[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text(user['name']),
//                           subtitle: Text(user['email']),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editUser(context, index, user);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   userProvider.deleteUser(index);
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   _addUser(context);
//                 },
//                 child: Text('Add User'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _addUser(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserBottomSheet(),
//     );
//   }

//   void _editUser(BuildContext context, int index, Map<String, dynamic> user) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserBottomSheet(
//         index: index,
//         user: user,
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';

// import 'edit_user_bottom_sheet.dart';

// class UserManagementScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Management'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Users',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: 10, // Replace with the actual count of users
//                 itemBuilder: (context, index) {
//                   return Card(
//                     child: ListTile(
//                       title:
//                           Text('User $index'), // Replace with actual user data
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(
//                             icon: Icon(Icons.edit, color: Colors.blue),
//                             onPressed: () {
//                               _editUser(context, index);
//                             },
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               _deleteUser(context, index);
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   _addUser(context);
//                 },
//                 child: Text('Add User'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _addUser(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserBottomSheet(),
//     );
//   }

//   void _editUser(BuildContext context, int index) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserBottomSheet(
//         index: index,
//         user: {'name': 'User $index'}, // Replace with actual user data
//       ),
//     );
//   }

//   void _deleteUser(BuildContext context, int index) {
//     // Implement user deletion logic here
//   }
// }
