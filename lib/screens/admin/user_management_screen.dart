import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_user_bottom_sheet.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
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
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error fetching users'));
                  }
                  final users = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userData = user.data() as Map<String, dynamic>;

                      final userName = userData['name'] ?? 'Unnamed';
                      final userEmail = userData['email'] ?? 'No Email';
                      final userRole = userData['role'] ?? 'No Role';

                      return Card(
                        child: ListTile(
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editUser(context, user.id, userData);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _deleteUser(context, user.id);
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
                onPressed: () => _addUser(context),
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
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditUserBottomSheet(),
      ),
    ).then((result) async {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User created successfully')),
        );
      } else if (result is String) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $result')),
        );
      }

      // Refresh the admin's data to ensure we're still logged in
      try {
        await Provider.of<AuthProvider>(context, listen: false)
            .refreshUserData();
      } catch (e) {
        print("Error refreshing admin data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing admin data: $e')),
        );
      }
    });
  }

  void _editUser(BuildContext context, String id, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditUserBottomSheet(
        userId: id,
        user: user,
      ),
    );
  }

  void _deleteUser(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this user?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                // Close the dialog first
                Navigator.of(dialogContext).pop();

                // Then perform the delete operation
                _performDelete(context, userId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDelete(BuildContext context, String userId) async {
    try {
      print("Attempting to delete user with ID: $userId");
      await Provider.of<AuthProvider>(context, listen: false)
          .deleteUser(userId);

      // Check if the widget is still in the tree before showing a SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User deleted successfully')),
        );
      }
    } catch (e) {
      print("Error in _performDelete: $e");
      // Check if the widget is still in the tree before showing a SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }
}
