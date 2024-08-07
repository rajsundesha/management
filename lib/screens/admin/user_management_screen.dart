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
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(userName[0].toUpperCase()),
          backgroundColor: Colors.blue,
        ),
        title: Text(userName),
        subtitle: Text('$userEmail\n$userRole'),
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
      await authProvider.deleteUser(userId);
      _updateStatus('User deleted successfully', isError: false);

      // Refresh user data
      await authProvider.refreshUserData();
    } catch (e) {
      String errorMessage = 'Error deleting user';
      if (e is FirebaseException) {
        errorMessage += ': ${e.message}';
      }
      _updateStatus(errorMessage, isError: true);
      print("Error deleting user: $e");
    }

    // Refresh the user list
    if (mounted) {
      setState(() {});
    }
  }

  void _updateStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _isStatusError = isError;
      });
      // Clear the status message after 3 seconds
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
//               child: Text(_statusMessage, style: TextStyle(color: Colors.red)),
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

//   // ... (keep the existing _buildSearchAndFilter and _buildUserList methods)

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

//   Future<void> _performDelete(String userId) async {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     try {
//       await authProvider.deleteUser(userId);
//       _updateStatus('User deleted successfully');
//     } catch (e) {
//       String errorMessage = 'Error deleting user';
//       if (e is FirebaseException) {
//         errorMessage += ': ${e.message}';
//       }
//       _updateStatus(errorMessage);
//       print("Error deleting user: $e");
//     }

//     // Refresh the user list
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   void _updateStatus(String message) {
//     if (mounted) {
//       setState(() {
//         _statusMessage = message;
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
//       _updateStatus('User operation successful');
//     } else if (result is String) {
//       _updateStatus('Error: $result');
//     }
//     try {
//       await Provider.of<AuthProvider>(context, listen: false).refreshUserData();
//       if (mounted) {
//         setState(() {});
//       }
//     } catch (e) {
//       print("Error refreshing admin data: $e");
//     }
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
// }

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_user_bottom_sheet.dart';

// class UserManagementScreen extends StatefulWidget {
//   @override
//   _UserManagementScreenState createState() => _UserManagementScreenState();
// }

// class _UserManagementScreenState extends State<UserManagementScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _filterRole = 'All';
//   List<String> _roles = ['All', 'Admin', 'Manager', 'User', 'Gate Man'];

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
//             onPressed: (context) => _deleteUser(context, userId),
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

// void _deleteUser(BuildContext context, String userId) {
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
//                 _performDelete(context, userId);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _performDelete(BuildContext context, String userId) async {
//     // Store a reference to ScaffoldMessenger before the async gap
//     final scaffoldMessenger = ScaffoldMessenger.of(context);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     String resultMessage = '';
//     bool isSuccess = false;

//     try {
//       await authProvider.deleteUser(userId);
//       resultMessage = 'User deleted successfully';
//       isSuccess = true;
//     } catch (e) {
//       resultMessage = 'Error deleting user';
//       if (e is FirebaseException) {
//         resultMessage += ': ${e.message}';
//       }
//       print("Error deleting user: $e");
//     }

//     // Use a microtask to ensure this runs after the current build phase
//     Future.microtask(() {
//       if (mounted) {
//         setState(() {
//           // Trigger a rebuild of the widget tree
//         });
//         scaffoldMessenger.showSnackBar(
//           SnackBar(content: Text(resultMessage)),
//         );
//       }
//     });

//     // If deletion was successful, refresh the user list
//     if (isSuccess) {
//       await authProvider.refreshUserData();
//     }
//   }

//   // Future<void> _performDelete(BuildContext context, String userId) async {
//   //   try {
//   //     await Provider.of<AuthProvider>(context, listen: false)
//   //         .deleteUser(userId);
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text('User deleted successfully')),
//   //       );
//   //     }
//   //   } catch (e) {
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text('Error deleting user: $e')),
//   //       );
//   //     }
//   //   }
//   // }

//   void _handleUserOperationResult(dynamic result) async {
//     if (result == true) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('User operation successful')),
//       );
//     } else if (result is String) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $result')),
//       );
//     }
//     try {
//       await Provider.of<AuthProvider>(context, listen: false).refreshUserData();
//     } catch (e) {
//       print("Error refreshing admin data: $e");
//     }
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_user_bottom_sheet.dart';

// class UserManagementScreen extends StatefulWidget {
//   @override
//   _UserManagementScreenState createState() => _UserManagementScreenState();
// }

// class _UserManagementScreenState extends State<UserManagementScreen> {
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
//               child: StreamBuilder<QuerySnapshot>(
//                 stream:
//                     FirebaseFirestore.instance.collection('users').snapshots(),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return Center(child: CircularProgressIndicator());
//                   }
//                   if (snapshot.hasError) {
//                     return Center(child: Text('Error fetching users'));
//                   }
//                   final users = snapshot.data!.docs;
//                   return ListView.builder(
//                     itemCount: users.length,
//                     itemBuilder: (context, index) {
//                       final user = users[index];
//                       final userData = user.data() as Map<String, dynamic>;

//                       final userName = userData['name'] ?? 'Unnamed';
//                       final userEmail = userData['email'] ?? 'No Email';
//                       final userRole = userData['role'] ?? 'No Role';

//                       return Card(
//                         child: ListTile(
//                           title: Text(userName),
//                           subtitle: Text(userEmail),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editUser(context, user.id, userData);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   _deleteUser(context, user.id);
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
//                 onPressed: () => _addUser(context),
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
//       isScrollControlled: true,
//       builder: (context) => Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: EditUserBottomSheet(),
//       ),
//     ).then((result) async {
//       if (result == true) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('User created successfully')),
//         );
//       } else if (result is String) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $result')),
//         );
//       }

//       // Refresh the admin's data to ensure we're still logged in
//       try {
//         await Provider.of<AuthProvider>(context, listen: false)
//             .refreshUserData();
//       } catch (e) {
//         print("Error refreshing admin data: $e");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error refreshing admin data: $e')),
//         );
//       }
//     });
//   }

//   void _editUser(BuildContext context, String id, Map<String, dynamic> user) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserBottomSheet(
//         userId: id,
//         user: user,
//       ),
//     );
//   }

//   void _deleteUser(BuildContext context, String userId) {
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text("Confirm Delete"),
//           content: Text("Are you sure you want to delete this user?"),
//           actions: <Widget>[
//             TextButton(
//               child: Text("Cancel"),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//             ),
//             TextButton(
//               child: Text("Delete"),
//               onPressed: () {
//                 // Close the dialog first
//                 Navigator.of(dialogContext).pop();

//                 // Then perform the delete operation
//                 _performDelete(context, userId);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _performDelete(BuildContext context, String userId) async {
//     try {
//       print("Attempting to delete user with ID: $userId");
//       await Provider.of<AuthProvider>(context, listen: false)
//           .deleteUser(userId);

//       // Check if the widget is still in the tree before showing a SnackBar
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('User deleted successfully')),
//         );
//       }
//     } catch (e) {
//       print("Error in _performDelete: $e");
//       // Check if the widget is still in the tree before showing a SnackBar
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error deleting user: $e')),
//         );
//       }
//     }
//   }
// }
