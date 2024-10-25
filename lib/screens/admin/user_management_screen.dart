import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/auth_provider.dart';
import 'package:dhavla_road_project/screens/admin/edit_user_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'All';
  List<String> _roles = ['All', 'Admin', 'Manager', 'User', 'Gate Man'];
  String _statusMessage = '';
  bool _isStatusError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addUser(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _isStatusError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addUser(context),
        child: Icon(Icons.person_add),
        tooltip: 'Add User',
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Users',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterRole,
            decoration: InputDecoration(
              labelText: 'Filter by Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: _roles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) => setState(() => _filterRole = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data!.docs;
        final filteredUsers = users.where((user) {
          final userData = user.data() as Map<String, dynamic>;
          final userName = userData['name']?.toLowerCase() ?? '';
          final userEmail = userData['email']?.toLowerCase() ?? '';
          final userRole = userData['role'] ?? '';
          final searchTerm = _searchController.text.toLowerCase();
          final roleFilter = _filterRole == 'All' || userRole == _filterRole;
          return (userName.contains(searchTerm) ||
                  userEmail.contains(searchTerm)) &&
              roleFilter;
        }).toList();

        if (filteredUsers.isEmpty) {
          return Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final userData = user.data() as Map<String, dynamic>;
            return _buildUserTile(user.id, userData);
          },
        );
      },
    );
  }

  Widget _buildUserTile(String userId, Map<String, dynamic> userData) {
    final userName = userData['name'] ?? 'Unnamed';
    final userEmail = userData['email'] ?? 'No Email';
    final userRole = userData['role'] ?? 'No Role';
    final isDisabled = userData['isDisabled'] ?? false;

    return Slidable(
      key: Key(userId),
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _editUser(context, userId, userData),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (context) => _deleteUser(userId),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
          SlidableAction(
            onPressed: (context) => _toggleUserStatus(userId, isDisabled),
            backgroundColor: isDisabled ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
            icon: isDisabled ? Icons.lock_open : Icons.lock,
            label: isDisabled ? 'Enable' : 'Disable',
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(userName[0].toUpperCase()),
          backgroundColor: isDisabled ? Colors.grey : Colors.blue,
        ),
        title: Text(
          userName,
          style: TextStyle(
            color: isDisabled ? Colors.grey : Colors.black,
            decoration: isDisabled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userEmail),
            Text(userRole),
            if (isDisabled)
              Text('DISABLED', style: TextStyle(color: Colors.red)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _deleteUser(String userId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text(
              "Are you sure you want to delete this user? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performDelete(userId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDelete(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.deleteUser(userId, context);
      _updateStatus('User deleted successfully', isError: false);

      await authProvider.refreshUserData();
    } catch (e) {
      String errorMessage = 'Error deleting user';
      if (e is FirebaseException) {
        errorMessage += ': ${e.message}';
      }
      _updateStatus(errorMessage, isError: true);
      print("Error deleting user: $e");
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _toggleUserStatus(String userId, bool currentStatus) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (currentStatus) {
        await authProvider.enableUser(userId);
        _updateStatus('User account enabled', isError: false);
      } else {
        await authProvider.disableUser(userId);
        _updateStatus('User account disabled', isError: false);
      }
      setState(() {});
    } catch (e) {
      _updateStatus('Error updating user status: $e', isError: true);
    }
  }

  void _updateStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _isStatusError = isError;
      });
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    }
  }

  void _addUser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditUserBottomSheet(),
      ),
    ).then(_handleUserOperationResult);
  }

  void _editUser(BuildContext context, String id, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditUserBottomSheet(
        userId: id,
        user: user,
      ),
    ).then(_handleUserOperationResult);
  }

  void _handleUserOperationResult(dynamic result) async {
    if (result == true) {
      _updateStatus('User operation successful', isError: false);
    } else if (result is String) {
      _updateStatus(result, isError: true);
    }
    try {
      await Provider.of<AuthProvider>(context, listen: false).refreshUserData();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error refreshing admin data: $e");
      _updateStatus('Error refreshing user data', isError: true);
    }
  }
}
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart';
// import 'package:dhavla_road_project/screens/admin/edit_user_bottom_sheet.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:provider/provider.dart';

// class UserManagementScreen extends StatefulWidget {
//   @override
//   _UserManagementScreenState createState() => _UserManagementScreenState();
// }

// class _UserManagementScreenState extends State<UserManagementScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _filterRole = 'All';
//   List<String> _roles = ['All', 'Admin', 'Manager', 'User', 'Gate Man'];
//   String _statusMessage = '';
//   bool _isStatusError = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Management'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () => _addUser(context),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildSearchAndFilter(),
//           if (_statusMessage.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 _statusMessage,
//                 style: TextStyle(
//                   color: _isStatusError ? Colors.red : Colors.green,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           Expanded(
//             child: _buildUserList(),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _addUser(context),
//         child: Icon(Icons.person_add),
//         tooltip: 'Add User',
//       ),
//     );
//   }

//   Widget _buildSearchAndFilter() {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Column(
//         children: [
//           TextField(
//             controller: _searchController,
//             decoration: InputDecoration(
//               labelText: 'Search Users',
//               prefixIcon: Icon(Icons.search),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             onChanged: (value) => setState(() {}),
//           ),
//           SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             value: _filterRole,
//             decoration: InputDecoration(
//               labelText: 'Filter by Role',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             items: _roles
//                 .map((role) => DropdownMenuItem(value: role, child: Text(role)))
//                 .toList(),
//             onChanged: (value) => setState(() => _filterRole = value!),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance.collection('users').snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         }
//         final users = snapshot.data!.docs;
//         final filteredUsers = users.where((user) {
//           final userData = user.data() as Map<String, dynamic>;
//           final userName = userData['name']?.toLowerCase() ?? '';
//           final userEmail = userData['email']?.toLowerCase() ?? '';
//           final userRole = userData['role'] ?? '';
//           final searchTerm = _searchController.text.toLowerCase();
//           final roleFilter = _filterRole == 'All' || userRole == _filterRole;
//           return (userName.contains(searchTerm) ||
//                   userEmail.contains(searchTerm)) &&
//               roleFilter;
//         }).toList();

//         if (filteredUsers.isEmpty) {
//           return Center(child: Text('No users found'));
//         }

//         return ListView.builder(
//           itemCount: filteredUsers.length,
//           itemBuilder: (context, index) {
//             final user = filteredUsers[index];
//             final userData = user.data() as Map<String, dynamic>;
//             return _buildUserTile(user.id, userData);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildUserTile(String userId, Map<String, dynamic> userData) {
//     final userName = userData['name'] ?? 'Unnamed';
//     final userEmail = userData['email'] ?? 'No Email';
//     final userRole = userData['role'] ?? 'No Role';

//     return Slidable(
//       key: Key(userId),
//       endActionPane: ActionPane(
//         motion: ScrollMotion(),
//         children: [
//           SlidableAction(
//             onPressed: (context) => _editUser(context, userId, userData),
//             backgroundColor: Colors.blue,
//             foregroundColor: Colors.white,
//             icon: Icons.edit,
//             label: 'Edit',
//           ),
//           SlidableAction(
//             onPressed: (context) => _deleteUser(userId),
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//             icon: Icons.delete,
//             label: 'Delete',
//           ),
//         ],
//       ),
//       child: ListTile(
//         leading: CircleAvatar(
//           child: Text(userName[0].toUpperCase()),
//           backgroundColor: Colors.blue,
//         ),
//         title: Text(userName),
//         subtitle: Text('$userEmail\n$userRole'),
//         isThreeLine: true,
//       ),
//     );
//   }

//   void _deleteUser(String userId) {
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text("Confirm Delete"),
//           content: Text(
//               "Are you sure you want to delete this user? This action cannot be undone."),
//           actions: <Widget>[
//             TextButton(
//               child: Text("Cancel"),
//               onPressed: () => Navigator.of(dialogContext).pop(),
//             ),
//             TextButton(
//               child: Text("Delete"),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//                 _performDelete(userId);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

// Future<void> _performDelete(String userId) async {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     try {
//       // Pass context to the deleteUser method
//       await authProvider.deleteUser(userId, context);
//       _updateStatus('User deleted successfully', isError: false);

//       // Refresh user data
//       await authProvider.refreshUserData();
//     } catch (e) {
//       String errorMessage = 'Error deleting user';
//       if (e is FirebaseException) {
//         errorMessage += ': ${e.message}';
//       }
//       _updateStatus(errorMessage, isError: true);
//       print("Error deleting user: $e");
//     }

//     // Refresh the user list
//     if (mounted) {
//       setState(() {});
//     }
//   }



//   void _updateStatus(String message, {bool isError = false}) {
//     if (mounted) {
//       setState(() {
//         _statusMessage = message;
//         _isStatusError = isError;
//       });
//       // Clear the status message after 3 seconds
//       Future.delayed(Duration(seconds: 3), () {
//         if (mounted) {
//           setState(() {
//             _statusMessage = '';
//           });
//         }
//       });
//     }
//   }

//   void _addUser(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: EditUserBottomSheet(),
//       ),
//     ).then(_handleUserOperationResult);
//   }

//   void _editUser(BuildContext context, String id, Map<String, dynamic> user) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => EditUserBottomSheet(
//         userId: id,
//         user: user,
//       ),
//     ).then(_handleUserOperationResult);
//   }

//   void _handleUserOperationResult(dynamic result) async {
//     if (result == true) {
//       _updateStatus('User operation successful', isError: false);
//     } else if (result is String) {
//       _updateStatus(result, isError: true);
//     }
//     try {
//       await Provider.of<AuthProvider>(context, listen: false).refreshUserData();
//       if (mounted) {
//         setState(() {});
//       }
//     } catch (e) {
//       print("Error refreshing admin data: $e");
//       _updateStatus('Error refreshing user data', isError: true);
//     }
//   }
// }
