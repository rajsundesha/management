import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;
import 'package:firebase_messaging/firebase_messaging.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  bool _isLoading = false;
  bool _isDeletingAccount = false;
  bool _hasDeletionRequest = false;
  String _deletionRequestStatus = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _mobileController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadUserData(),
        _checkDeletionRequest(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Failed to load user data. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = userData['name'] ?? user.displayName ?? '';
            _emailController.text = user.email ?? '';
            _mobileController.text = userData['mobile'] ?? '';
          });

          if (fcmToken != null && fcmToken != userData['fcmToken']) {
            await _updateFCMToken(user.uid, fcmToken);
          }
        }
      } catch (e) {
        print("Error loading user data: $e");
        rethrow;
      }
    }
  }

  Future<void> _updateFCMToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  Future<void> _cancelAccountDeletionRequest() async {
    setState(() => _isDeletingAccount = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      final requestSnapshot = await FirebaseFirestore.instance
          .collection('deletion_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestSnapshot.docs.isEmpty) {
        // No pending deletion request found, update the UI
        setState(() {
          _hasDeletionRequest = false;
          _deletionRequestStatus = '';
        });
        _showSuccessSnackBar(
            'No pending deletion request found. Your account is safe.');
        return;
      }

      final requestId = requestSnapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('deletion_requests')
          .doc(requestId)
          .delete();

      setState(() {
        _hasDeletionRequest = false;
        _deletionRequestStatus = '';
      });
      _showSuccessSnackBar('Account deletion request canceled successfully.');
    } catch (e) {
      print('Error canceling account deletion request: $e');
      _showErrorSnackBar('Error canceling request: ${e.toString()}');
    } finally {
      setState(() => _isDeletingAccount = false);
    }
  }

// Update the _checkDeletionRequest method to set _hasDeletionRequest to false when there's no request
  Future<void> _checkDeletionRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final request = await FirebaseFirestore.instance
            .collection('deletion_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isNotEqualTo: 'completed')
            .get();

        setState(() {
          _hasDeletionRequest = request.docs.isNotEmpty;
          _deletionRequestStatus =
              request.docs.isNotEmpty ? request.docs.first['status'] : '';
        });
      } catch (e) {
        print('Error checking deletion request: $e');
        _showErrorSnackBar('Error checking deletion request status');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isInitialized
          ? SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(_nameController, 'Name', Icons.person),
                        SizedBox(height: 16),
                        _buildTextField(_emailController, 'Email', Icons.email),
                        SizedBox(height: 16),
                        _buildTextField(
                            _mobileController, 'Mobile Number', Icons.phone),
                        SizedBox(height: 16),
                        _buildPasswordField(
                            _currentPasswordController, 'Current Password'),
                        SizedBox(height: 16),
                        _buildPasswordField(
                            _newPasswordController, 'New Password (optional)'),
                        SizedBox(height: 8),
                        _buildForgotPasswordButton(),
                        SizedBox(height: 24),
                        _buildUpdateButton(),
                        SizedBox(height: 24),
                        if (_hasDeletionRequest) ...[
                          _buildDeletionRequestStatus(),
                          SizedBox(height: 16),
                          _buildCancelDeletionRequestButton(),
                        ] else
                          _buildDeleteAccountButton(),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     resizeToAvoidBottomInset: false,
  //     body: SafeArea(
  //       child: _isInitialized
  //           ? CustomScrollView(
  //               slivers: [
  //                 _buildSliverAppBar(),
  //                 SliverToBoxAdapter(child: _buildBody()),
  //               ],
  //             )
  //           : Center(child: CircularProgressIndicator()),
  //     ),
  //   );
  // }

  // Widget _buildSliverAppBar() {
  //   return SliverAppBar(
  //     expandedHeight: 200.0,
  //     floating: false,
  //     pinned: true,
  //     flexibleSpace: FlexibleSpaceBar(
  //       title: Text('Edit Profile'),
  //       background: Container(
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             begin: Alignment.topCenter,
  //             end: Alignment.bottomCenter,
  //             colors: [Colors.blue.shade700, Colors.blue.shade900],
  //           ),
  //         ),
  //         child: Center(
  //           child: CircleAvatar(
  //             radius: 50,
  //             backgroundColor: Colors.white,
  //             child: Icon(Icons.person, size: 50, color: Colors.blue.shade700),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildBody() {
  //   return SingleChildScrollView(
  //     child: Padding(
  //       padding: EdgeInsets.all(16.0),
  //       child: Form(
  //         key: _formKey,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.stretch,
  //           children: [
  //             _buildTextField(_nameController, 'Name', Icons.person),
  //             SizedBox(height: 16),
  //             _buildTextField(_emailController, 'Email', Icons.email),
  //             SizedBox(height: 16),
  //             _buildTextField(_mobileController, 'Mobile Number', Icons.phone),
  //             SizedBox(height: 16),
  //             _buildPasswordField(
  //                 _currentPasswordController, 'Current Password'),
  //             SizedBox(height: 16),
  //             _buildPasswordField(
  //                 _newPasswordController, 'New Password (optional)'),
  //             SizedBox(height: 8),
  //             _buildForgotPasswordButton(),
  //             SizedBox(height: 24),
  //             _buildUpdateButton(),
  //             SizedBox(height: 24),
  //             if (_hasDeletionRequest) ...[
  //               _buildDeletionRequestStatus(),
  //               SizedBox(height: 16),
  //               _buildCancelDeletionRequestButton(),
  //             ] else
  //               _buildDeleteAccountButton(),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      obscureText: true,
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _sendPasswordResetEmail,
        child: Text('Forgot Password?'),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updateProfile,
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : Text('Update Profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return ElevatedButton(
      onPressed: _isDeletingAccount ? null : _requestAccountDeletion,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _isDeletingAccount
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : Text('Request Account Deletion'),
    );
  }

  Widget _buildCancelDeletionRequestButton() {
    return ElevatedButton(
      onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _isDeletingAccount
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : Text('Cancel Account Deletion Request'),
    );
  }

  Widget _buildDeletionRequestStatus() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Account Deletion Request Status: $_deletionRequestStatus',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          if (_deletionRequestStatus == 'rejected') ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resendAccountDeletionRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Resend Deletion Request'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final authProvider =
              Provider.of<app_auth.AuthProvider>(context, listen: false);
          authProvider.updateUserNameLocally(_nameController.text);

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() as Map<String, dynamic>;

          Map<String, dynamic> updates = {};
          if (_nameController.text != userData['name']) {
            updates['name'] = _nameController.text;
            await user.updateProfile(displayName: _nameController.text);
          }
          if (_mobileController.text != userData['mobile']) {
            updates['mobile'] = _mobileController.text;
          }

          if (updates.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update(updates);
          }

          if (_emailController.text != user.email) {
            await _updateEmail(user);
          }

          if (_newPasswordController.text.isNotEmpty) {
            await _updatePassword(user);
          }

          _showSuccessSnackBar('Profile updated successfully');
          await authProvider.refreshUserData();
          Navigator.of(context).pop();
        } else {
          throw Exception('User not found');
        }
      } catch (e) {
        _showErrorSnackBar('Error updating profile: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _updateEmail(User user) async {
    if (_emailController.text != user.email) {
      try {
        await user.verifyBeforeUpdateEmail(_emailController.text);
        _showSuccessSnackBar(
            'Verification email sent. Please verify to update your email.');
      } catch (e) {
        print('Error updating email: $e');
        rethrow;
      }
    }
  }

  Future<void> _updatePassword(User user) async {
    if (_currentPasswordController.text.isNotEmpty) {
      try {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);
      } catch (e) {
        print('Error updating password: $e');
        rethrow;
      }
    } else {
      throw Exception('Current password is required to update password');
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text);
      _showSuccessSnackBar(
          'Password reset email sent to ${_emailController.text}. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          _showErrorSnackBar('The email address is not valid.');
          break;
        case 'user-not-found':
          _showErrorSnackBar('No user found for that email.');
          break;
        default:
          _showErrorSnackBar(
              'Error sending password reset email: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackBar(
          'An unexpected error occurred. Please try again later.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestAccountDeletion() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
            'Are you sure you want to request account deletion? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Confirm')),
        ],
      ),
    );
    if (result == true) {
      setState(() => _isDeletingAccount = true);
      try {
        final authProvider =
            Provider.of<app_auth.AuthProvider>(context, listen: false);
        await authProvider.requestAccountDeletion();
        _showSuccessSnackBar(
            'Account deletion request sent. You will be notified when it\'s processed.');
        await _checkDeletionRequest();
      } catch (e) {
        print('Error requesting account deletion: $e');
        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            _showErrorSnackBar(
                'You do not have permission to perform this action. Please contact support.');
          } else {
            _showErrorSnackBar(
                'Error requesting account deletion: ${e.message}');
          }
        } else {
          _showErrorSnackBar(
              'An unexpected error occurred. Please try again later.');
        }
      } finally {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<void> _resendAccountDeletionRequest() async {
    setState(() => _isDeletingAccount = true);
    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.requestAccountDeletion();
      _showSuccessSnackBar(
          'Account deletion request resent. You will be notified when it\'s processed.');
      await _checkDeletionRequest();
    } catch (e) {
      print('Error resending account deletion request: $e');
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          _showErrorSnackBar(
              'You do not have permission to perform this action. Please contact support.');
        } else {
          _showErrorSnackBar(
              'Error resending account deletion request: ${e.message}');
        }
      } else {
        _showErrorSnackBar(
            'An unexpected error occurred. Please try again later.');
      }
    } finally {
      setState(() => _isDeletingAccount = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;
// import 'package:firebase_messaging/firebase_messaging.dart';

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _initializeData();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeData() async {
//     setState(() => _isLoading = true);
//     try {
//       await Future.wait([
//         _loadUserData(),
//         _checkDeletionRequest(),
//       ]);
//     } catch (e) {
//       _showErrorSnackBar('Failed to load user data. Please try again.');
//     } finally {
//       setState(() {
//         _isLoading = false;
//         _isInitialized = true;
//       });
//     }
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final futures = await Future.wait([
//           FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
//           FirebaseMessaging.instance.getToken(),
//         ]);

//         final DocumentSnapshot doc = futures[0] as DocumentSnapshot;
//         final String? fcmToken = futures[1] as String?;

//         if (doc.exists) {
//           final Map<String, dynamic> userData =
//               doc.data() as Map<String, dynamic>;
//           setState(() {
//             _nameController.text = userData['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData['mobile'] ?? '';
//           });

//           if (fcmToken != null && fcmToken != userData['fcmToken']) {
//             await _updateFCMToken(user.uid, fcmToken);
//           }
//         }
//       } catch (e) {
//         print("Error loading user data: $e");
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updateFCMToken(String uid, String token) async {
//     try {
//       await FirebaseFirestore.instance.collection('users').doc(uid).update({
//         'fcmToken': token,
//       });
//     } catch (e) {
//       print('Error updating FCM token: $e');
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         setState(() {
//           _hasDeletionRequest = request.docs.isNotEmpty;
//           _deletionRequestStatus =
//               request.docs.isNotEmpty ? request.docs.first['status'] : '';
//         });
//       } catch (e) {
//         print('Error checking deletion request: $e');
//         rethrow;
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       body: SafeArea(
//         child: _isInitialized
//             ? CustomScrollView(
//                 slivers: [
//                   _buildSliverAppBar(),
//                   SliverToBoxAdapter(child: _buildBody()),
//                 ],
//               )
//             : Center(child: CircularProgressIndicator()),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: Text('Edit Profile'),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Colors.blue.shade700, Colors.blue.shade900],
//             ),
//           ),
//           child: Center(
//             child: CircleAvatar(
//               radius: 50,
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, size: 50, color: Colors.blue.shade700),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBody() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(_nameController, 'Name', Icons.person),
//               SizedBox(height: 16),
//               _buildTextField(_emailController, 'Email', Icons.email),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number', Icons.phone),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 8),
//               _buildForgotPasswordButton(),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               if (_hasDeletionRequest) ...[
//                 _buildDeletionRequestStatus(),
//                 SizedBox(height: 16),
//                 _buildCancelDeletionRequestButton(),
//               ] else
//                 _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, IconData icon) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(Icons.lock),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       obscureText: true,
//     );
//   }

//   Widget _buildForgotPasswordButton() {
//     return Align(
//       alignment: Alignment.centerRight,
//       child: TextButton(
//         onPressed: _sendPasswordResetEmail,
//         child: Text('Forgot Password?'),
//       ),
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Update Profile'),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.blue.shade700,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Widget _buildDeletionRequestStatus() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red.shade100,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.warning, color: Colors.red),
//               SizedBox(width: 16),
//               Expanded(
//                 child: Text(
//                   'Account Deletion Request Status: $_deletionRequestStatus',
//                   style: TextStyle(color: Colors.red),
//                 ),
//               ),
//             ],
//           ),
//           if (_deletionRequestStatus == 'rejected') ...[
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _resendAccountDeletionRequest,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 padding: EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10)),
//               ),
//               child: Text('Resend Deletion Request'),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           authProvider.updateUserNameLocally(_nameController.text);

//           List<Future> updateOperations = [];

//           DocumentSnapshot userDoc = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .get();
//           Map<String, dynamic> userData =
//               userDoc.data() as Map<String, dynamic>;

//           Map<String, dynamic> updates = {};
//           if (_nameController.text != userData['name']) {
//             updates['name'] = _nameController.text;
//             updateOperations
//                 .add(user.updateProfile(displayName: _nameController.text));
//           }
//           if (_mobileController.text != userData['mobile']) {
//             updates['mobile'] = _mobileController.text;
//           }

//           if (updates.isNotEmpty) {
//             updateOperations.add(FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .update(updates));
//           }

//           if (_emailController.text != user.email) {
//             updateOperations.add(_updateEmail(user));
//           }

//           if (_newPasswordController.text.isNotEmpty) {
//             updateOperations.add(_updatePassword(user));
//           }

//           await Future.wait(updateOperations);

//           _showSuccessSnackBar('Profile updated successfully');
//           await authProvider.refreshUserData();
//           Navigator.of(context).pop();
//         } else {
//           throw Exception('User not found');
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       try {
//         await user.verifyBeforeUpdateEmail(_emailController.text);
//         _showSuccessSnackBar(
//             'Verification email sent. Please verify to update your email.');
//       } catch (e) {
//         print('Error updating email: $e');
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_currentPasswordController.text.isNotEmpty) {
//       try {
//         AuthCredential credential = EmailAuthProvider.credential(
//           email: user.email!,
//           password: _currentPasswordController.text,
//         );
//         await user.reauthenticateWithCredential(credential);
//         await user.updatePassword(_newPasswordController.text);
//       } catch (e) {
//         print('Error updating password: $e');
//         rethrow;
//       }
//     } else {
//       throw Exception('Current password is required to update password');
//     }
//   }

//   Future<void> _sendPasswordResetEmail() async {
//     try {
//       await FirebaseAuth.instance
//           .sendPasswordResetEmail(email: _emailController.text);
//       _showSuccessSnackBar(
//           'Password reset email sent. Please check your inbox.');
//     } catch (e) {
//       _showErrorSnackBar('Error sending password reset email: ${e.toString()}');
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text('Cancel')),
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: Text('Confirm')),
//         ],
//       ),
//     );
//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         await _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     setState(() => _isDeletingAccount = true);
//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         _showSuccessSnackBar('Account deletion request canceled.');
//         await _checkDeletionRequest();
//       } else {
//         _showErrorSnackBar('No pending deletion request found.');
//       }
//     } catch (e) {
//       print('Error canceling account deletion request: $e');
//       _showErrorSnackBar(
//           'Error canceling account deletion request: ${e.toString()}');
//     } finally {
//       setState(() => _isDeletingAccount = false);
//     }
//   }

//   Future<void> _resendAccountDeletionRequest() async {
//     setState(() => _isDeletingAccount = true);
//     try {
//       final authProvider =
//           Provider.of<app_auth.AuthProvider>(context, listen: false);
//       await authProvider.requestAccountDeletion();
//       _showSuccessSnackBar(
//           'Account deletion request resent. You will be notified when it\'s processed.');
//       await _checkDeletionRequest();
//     } catch (e) {
//       print('Error resending account deletion request: $e');
//       if (e is FirebaseException) {
//         if (e.code == 'permission-denied') {
//           _showErrorSnackBar(
//               'You do not have permission to perform this action. Please contact support.');
//         } else {
//           _showErrorSnackBar(
//               'Error resending account deletion request: ${e.message}');
//         }
//       } else {
//         _showErrorSnackBar(
//             'An unexpected error occurred. Please try again later.');
//       }
//     } finally {
//       setState(() => _isDeletingAccount = false);
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).removeCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//         margin: EdgeInsets.only(
//           bottom: MediaQuery.of(context).size.height * 0.8,
//           left: 16,
//           right: 16,
//         ),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).removeCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         margin: EdgeInsets.only(
//           bottom: MediaQuery.of(context).size.height * 0.8,
//           left: 16,
//           right: 16,
//         ),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }
// }
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;
// import 'package:firebase_messaging/firebase_messaging.dart';

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _initializeData();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeData() async {
//     setState(() => _isLoading = true);
//     try {
//       await Future.wait([
//         _loadUserData(),
//         _checkDeletionRequest(),
//       ]);
//     } catch (e) {
//       _showErrorSnackBar('Failed to load user data. Please try again.');
//     } finally {
//       setState(() {
//         _isLoading = false;
//         _isInitialized = true;
//       });
//     }
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final futures = await Future.wait([
//           FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
//           FirebaseMessaging.instance.getToken(),
//         ]);

//         final DocumentSnapshot doc = futures[0] as DocumentSnapshot;
//         final String? fcmToken = futures[1] as String?;

//         if (doc.exists) {
//           final Map<String, dynamic> userData =
//               doc.data() as Map<String, dynamic>;
//           setState(() {
//             _nameController.text = userData['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData['mobile'] ?? '';
//           });

//           // Update FCM token if it's new or different
//           if (fcmToken != null && fcmToken != userData['fcmToken']) {
//             await _updateFCMToken(user.uid, fcmToken);
//           }
//         }
//       } catch (e) {
//         print("Error loading user data: $e");
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updateFCMToken(String uid, String token) async {
//     try {
//       await FirebaseFirestore.instance.collection('users').doc(uid).update({
//         'fcmToken': token,
//       });
//       print('FCM Token updated in Firestore successfully');
//     } catch (e) {
//       print('Error updating FCM token: $e');
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         setState(() {
//           _hasDeletionRequest = request.docs.isNotEmpty;
//           _deletionRequestStatus =
//               request.docs.isNotEmpty ? request.docs.first['status'] : '';
//         });
//       } catch (e) {
//         print('Error checking deletion request: $e');
//         rethrow;
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isInitialized
//           ? SafeArea(child: _buildBody())
//           : Center(child: CircularProgressIndicator()),
//     );
//   }

//   Widget _buildBody() {
//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(child: _buildHeader()),
//         SliverPadding(
//           padding: EdgeInsets.all(16.0),
//           sliver: SliverToBoxAdapter(
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   _buildTextField(_nameController, 'Name', Icons.person),
//                   SizedBox(height: 16),
//                   _buildTextField(_emailController, 'Email', Icons.email),
//                   SizedBox(height: 16),
//                   _buildTextField(
//                       _mobileController, 'Mobile Number', Icons.phone),
//                   SizedBox(height: 16),
//                   _buildPasswordField(
//                       _currentPasswordController, 'Current Password'),
//                   SizedBox(height: 16),
//                   _buildPasswordField(
//                       _newPasswordController, 'New Password (optional)'),
//                   SizedBox(height: 24),
//                   _buildUpdateButton(),
//                   SizedBox(height: 24),
//                   if (_hasDeletionRequest) ...[
//                     _buildDeletionRequestStatus(),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                   ] else
//                     _buildDeleteAccountButton(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 24),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Center(
//         child: Column(
//           children: [
//             CircleAvatar(
//               radius: 50,
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, size: 50, color: Colors.blue.shade700),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Edit Your Profile',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, IconData icon) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(Icons.lock),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Update Profile'),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Color.fromARGB(255, 95, 169, 243),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: const Color.fromARGB(255, 239, 94, 83),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Widget _buildDeletionRequestStatus() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red.shade100,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.warning, color: Colors.red),
//               SizedBox(width: 16),
//               Expanded(
//                 child: Text(
//                   'Account Deletion Request Status: $_deletionRequestStatus',
//                   style: TextStyle(color: Colors.red),
//                 ),
//               ),
//             ],
//           ),
//           if (_deletionRequestStatus == 'rejected') ...[
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _resendAccountDeletionRequest,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 padding: EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10)),
//               ),
//               child: Text('Resend Deletion Request'),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);

//           // Update local state immediately for responsive UI
//           authProvider.updateUserNameLocally(_nameController.text);

//           // Prepare update operations
//           List<Future> updateOperations = [];

//           // Check if name or mobile number has changed
//           DocumentSnapshot userDoc = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .get();
//           Map<String, dynamic> userData =
//               userDoc.data() as Map<String, dynamic>;

//           Map<String, dynamic> updates = {};
//           if (_nameController.text != userData['name']) {
//             updates['name'] = _nameController.text;
//             updateOperations
//                 .add(user.updateProfile(displayName: _nameController.text));
//           }
//           if (_mobileController.text != userData['mobile']) {
//             updates['mobile'] = _mobileController.text;
//           }

//           // Only update Firestore if there are changes
//           if (updates.isNotEmpty) {
//             updateOperations.add(FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .update(updates));
//           }

//           // Check if email needs to be updated
//           if (_emailController.text != user.email) {
//             updateOperations.add(_updateEmail(user));
//           }

//           // Check if password needs to be updated
//           if (_newPasswordController.text.isNotEmpty) {
//             updateOperations.add(_updatePassword(user));
//           }

//           // Execute all update operations concurrently
//           await Future.wait(updateOperations);

//           _showSuccessSnackBar('Profile updated successfully');

//           // Refresh user data after updating
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         } else {
//           throw Exception('User not found');
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       try {
//         await user.verifyBeforeUpdateEmail(_emailController.text);
//         _showSuccessSnackBar(
//             'Verification email sent. Please verify to update your email.');
//       } catch (e) {
//         print('Error updating email: $e');
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_currentPasswordController.text.isNotEmpty) {
//       try {
//         AuthCredential credential = EmailAuthProvider.credential(
//           email: user.email!,
//           password: _currentPasswordController.text,
//         );
//         await user.reauthenticateWithCredential(credential);
//         await user.updatePassword(_newPasswordController.text);
//       } catch (e) {
//         print('Error updating password: $e');
//         rethrow;
//       }
//     } else {
//       throw Exception('Current password is required to update password');
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text('Cancel')),
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: Text('Confirm')),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         await _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     setState(() => _isDeletingAccount = true);
//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         _showSuccessSnackBar('Account deletion request canceled.');
//         await _checkDeletionRequest();
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     } finally {
//       setState(() => _isDeletingAccount = false);
//     }
//   }

//   Future<void> _resendAccountDeletionRequest() async {
//     setState(() => _isDeletingAccount = true);
//     try {
//       final authProvider =
//           Provider.of<app_auth.AuthProvider>(context, listen: false);
//       await authProvider.requestAccountDeletion();
//       _showSuccessSnackBar(
//           'Account deletion request resent. You will be notified when it\'s processed.');
//       await _checkDeletionRequest();
//     } catch (e) {
//       print('Error resending account deletion request: $e');
//       if (e is FirebaseException) {
//         if (e.code == 'permission-denied') {
//           _showErrorSnackBar(
//               'You do not have permission to perform this action. Please contact support.');
//         } else {
//           _showErrorSnackBar(
//               'Error resending account deletion request: ${e.message}');
//         }
//       } else {
//         _showErrorSnackBar(
//             'An unexpected error occurred. Please try again later.');
//       }
//     } finally {
//       setState(() => _isDeletingAccount = false);
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;
// import 'package:firebase_messaging/firebase_messaging.dart';

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _initializeData();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _initializeData() async {
//     setState(() => _isLoading = true);
//     try {
//       await Future.wait([
//         _loadUserData(),
//         _checkDeletionRequest(),
//       ]);
//     } catch (e) {
//       _showErrorSnackBar('Failed to load user data. Please try again.');
//     } finally {
//       setState(() {
//         _isLoading = false;
//         _isInitialized = true;
//       });
//     }
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final futures = await Future.wait([
//           FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
//           FirebaseMessaging.instance.getToken(),
//         ]);

//         final DocumentSnapshot doc = futures[0] as DocumentSnapshot;
//         final String? fcmToken = futures[1] as String?;

//         if (doc.exists) {
//           final Map<String, dynamic> userData =
//               doc.data() as Map<String, dynamic>;
//           setState(() {
//             _nameController.text = userData['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData['mobile'] ?? '';
//           });

//           // Update FCM token if it's new or different
//           if (fcmToken != null && fcmToken != userData['fcmToken']) {
//             await _updateFCMToken(user.uid, fcmToken);
//           }
//         }
//       } catch (e) {
//         print("Error loading user data: $e");
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updateFCMToken(String uid, String token) async {
//     try {
//       await FirebaseFirestore.instance.collection('users').doc(uid).update({
//         'fcmToken': token,
//       });
//       print('FCM Token updated in Firestore successfully');
//     } catch (e) {
//       print('Error updating FCM token: $e');
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         setState(() {
//           _hasDeletionRequest = request.docs.isNotEmpty;
//           _deletionRequestStatus =
//               request.docs.isNotEmpty ? request.docs.first['status'] : '';
//         });
//       } catch (e) {
//         print('Error checking deletion request: $e');
//         rethrow;
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isInitialized
//           ? SafeArea(child: _buildBody())
//           : Center(child: CircularProgressIndicator()),
//     );
//   }

//   Widget _buildBody() {
//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(child: _buildHeader()),
//         SliverPadding(
//           padding: EdgeInsets.all(16.0),
//           sliver: SliverToBoxAdapter(
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   _buildTextField(_nameController, 'Name', Icons.person),
//                   SizedBox(height: 16),
//                   _buildTextField(_emailController, 'Email', Icons.email),
//                   SizedBox(height: 16),
//                   _buildTextField(
//                       _mobileController, 'Mobile Number', Icons.phone),
//                   SizedBox(height: 16),
//                   _buildPasswordField(
//                       _currentPasswordController, 'Current Password'),
//                   SizedBox(height: 16),
//                   _buildPasswordField(
//                       _newPasswordController, 'New Password (optional)'),
//                   SizedBox(height: 24),
//                   _buildUpdateButton(),
//                   SizedBox(height: 24),
//                   if (_hasDeletionRequest) ...[
//                     _buildDeletionRequestStatus(),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                   ] else
//                     _buildDeleteAccountButton(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 24),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Center(
//         child: Column(
//           children: [
//             CircleAvatar(
//               radius: 50,
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, size: 50, color: Colors.blue.shade700),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Edit Your Profile',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, IconData icon) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(Icons.lock),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Update Profile'),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Color.fromARGB(255, 95, 169, 243),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: const Color.fromARGB(255, 239, 94, 83),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   strokeWidth: 2))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Widget _buildDeletionRequestStatus() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red.shade100,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.warning, color: Colors.red),
//           SizedBox(width: 16),
//           Expanded(
//             child: Text(
//               'Account Deletion Request Status: $_deletionRequestStatus',
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Future<void> _updateProfile() async {
//   //   if (_formKey.currentState!.validate()) {
//   //     setState(() => _isLoading = true);
//   //     try {
//   //       final user = FirebaseAuth.instance.currentUser;
//   //       if (user != null) {
//   //         final authProvider =
//   //             Provider.of<app_auth.AuthProvider>(context, listen: false);

//   //         // Update local state immediately
//   //         authProvider.updateUserNameLocally(_nameController.text);

//   //         // Perform updates concurrently
//   //         await Future.wait([
//   //           _updateUserData(user),
//   //           _updateEmail(user),
//   //           if (_newPasswordController.text.isNotEmpty) _updatePassword(user),
//   //         ]);

//   //         _showSuccessSnackBar('Profile updated successfully');

//   //         // Refresh user data after updating
//   //         await authProvider.refreshUserData();

//   //         Navigator.of(context).pop();
//   //       } else {
//   //         throw Exception('User not found');
//   //       }
//   //     } catch (e) {
//   //       _showErrorSnackBar('Error updating profile: ${e.toString()}');
//   //     } finally {
//   //       if (mounted) {
//   //         setState(() => _isLoading = false);
//   //       }
//   //     }
//   //   }
//   // }
//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);

//           // Update local state immediately for responsive UI
//           authProvider.updateUserNameLocally(_nameController.text);

//           // Prepare update operations
//           List<Future> updateOperations = [];

//           // Check if name or mobile number has changed
//           DocumentSnapshot userDoc = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .get();
//           Map<String, dynamic> userData =
//               userDoc.data() as Map<String, dynamic>;

//           Map<String, dynamic> updates = {};
//           if (_nameController.text != userData['name']) {
//             updates['name'] = _nameController.text;
//             updateOperations
//                 .add(user.updateProfile(displayName: _nameController.text));
//           }
//           if (_mobileController.text != userData['mobile']) {
//             updates['mobile'] = _mobileController.text;
//           }

//           // Only update Firestore if there are changes
//           if (updates.isNotEmpty) {
//             updateOperations.add(FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .update(updates));
//           }

//           // Check if email needs to be updated
//           if (_emailController.text != user.email) {
//             updateOperations.add(_updateEmail(user));
//           }

//           // Check if password needs to be updated
//           if (_newPasswordController.text.isNotEmpty) {
//             updateOperations.add(_updatePassword(user));
//           }

//           // Execute all update operations concurrently
//           await Future.wait(updateOperations);

//           _showSuccessSnackBar('Profile updated successfully');

//           // Refresh user data after updating
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         } else {
//           throw Exception('User not found');
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .update({
//         'name': _nameController.text,
//         'mobile': _mobileController.text,
//       });
//       await user.updateProfile(displayName: _nameController.text);
//     } catch (e) {
//       print('Error updating user data: $e');
//       rethrow;
//     }
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       try {
//         await user.verifyBeforeUpdateEmail(_emailController.text);
//         _showSuccessSnackBar(
//             'Verification email sent. Please verify to update your email.');
//       } catch (e) {
//         print('Error updating email: $e');
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_currentPasswordController.text.isNotEmpty) {
//       try {
//         AuthCredential credential = EmailAuthProvider.credential(
//           email: user.email!,
//           password: _currentPasswordController.text,
//         );
//         await user.reauthenticateWithCredential(credential);
//         await user.updatePassword(_newPasswordController.text);
//       } catch (e) {
//         print('Error updating password: $e');
//         rethrow;
//       }
//     } else {
//       throw Exception('Current password is required to update password');
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text('Cancel')),
//           TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: Text('Confirm')),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         _showSuccessSnackBar('Account deletion request canceled.');
//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//     _checkDeletionRequest();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         if (request.docs.isNotEmpty) {
//           setState(() {
//             _hasDeletionRequest = true;
//             _deletionRequestStatus = request.docs.first['status'];
//           });
//         } else {
//           setState(() {
//             _hasDeletionRequest = false;
//             _deletionRequestStatus = '';
//           });
//         }
//       } catch (e) {
//         print('Error checking deletion request: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: SafeArea(
//         child: CustomScrollView(
//           slivers: [
//             SliverToBoxAdapter(child: _buildHeader()),
//             SliverPadding(
//               padding: EdgeInsets.all(16.0),
//               sliver: SliverToBoxAdapter(
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       _buildTextField(_nameController, 'Name', Icons.person),
//                       SizedBox(height: 16),
//                       _buildTextField(_emailController, 'Email', Icons.email),
//                       SizedBox(height: 16),
//                       _buildTextField(
//                           _mobileController, 'Mobile Number', Icons.phone),
//                       SizedBox(height: 16),
//                       _buildPasswordField(
//                           _currentPasswordController, 'Current Password'),
//                       SizedBox(height: 16),
//                       _buildPasswordField(
//                           _newPasswordController, 'New Password (optional)'),
//                       SizedBox(height: 24),
//                       _buildUpdateButton(),
//                       SizedBox(height: 24),
//                       if (_hasDeletionRequest) ...[
//                         _buildDeletionRequestStatus(),
//                         SizedBox(height: 16),
//                         _buildCancelDeletionRequestButton(),
//                       ] else
//                         _buildDeleteAccountButton(),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 24),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Center(
//         child: Column(
//           children: [
//             CircleAvatar(
//               radius: 50,
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, size: 50, color: Colors.blue.shade700),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Edit Your Profile',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, IconData icon) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(Icons.lock),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//       ),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Update Profile'),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Color.fromARGB(255, 95, 169, 243),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: const Color.fromARGB(255, 239, 94, 83),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//       child: _isDeletingAccount
//           ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 strokeWidth: 2,
//               ),
//             )
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Widget _buildDeletionRequestStatus() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red.shade100,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.warning, color: Colors.red),
//           SizedBox(width: 16),
//           Expanded(
//             child: Text(
//               'Account Deletion Request Status: $_deletionRequestStatus',
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);

//           // Update local state immediately
//           authProvider.updateUserNameLocally(_nameController.text);

//           // Perform updates concurrently
//           await Future.wait([
//             _updateUserData(user),
//             _updateEmail(user),
//             if (_newPasswordController.text.isNotEmpty) _updatePassword(user),
//           ]);

//           _showSuccessSnackBar('Profile updated successfully');

//           // Refresh user data after updating
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         } else {
//           throw Exception('User not found');
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .update({
//         'name': _nameController.text,
//         'mobile': _mobileController.text,
//       });
//       await user.updateProfile(displayName: _nameController.text);
//     } catch (e) {
//       print('Error updating user data: $e');
//       rethrow;
//     }
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       try {
//         await user.verifyBeforeUpdateEmail(_emailController.text);
//         _showSuccessSnackBar(
//             'Verification email sent. Please verify to update your email.');
//       } catch (e) {
//         print('Error updating email: $e');
//         rethrow;
//       }
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_currentPasswordController.text.isNotEmpty) {
//       try {
//         AuthCredential credential = EmailAuthProvider.credential(
//           email: user.email!,
//           password: _currentPasswordController.text,
//         );
//         await user.reauthenticateWithCredential(credential);
//         await user.updatePassword(_newPasswordController.text);
//       } catch (e) {
//         print('Error updating password: $e');
//         rethrow;
//       }
//     } else {
//       throw Exception('Current password is required to update password');
//     }
//   }
//   // Future<void> _updateProfile() async {
//   //   if (_formKey.currentState!.validate()) {
//   //     setState(() => _isLoading = true);
//   //     try {
//   //       final user = FirebaseAuth.instance.currentUser;
//   //       if (user != null) {
//   //         final authProvider =
//   //             Provider.of<app_auth.AuthProvider>(context, listen: false);

//   //         // Update local state immediately for responsive UI
//   //         authProvider.updateUserNameLocally(_nameController.text);

//   //         // Prepare all update operations
//   //         List<Future> updateOperations = [
//   //           _updateUserData(user),
//   //           _updateEmail(user),
//   //         ];

//   //         // Only add password update if a new password is provided
//   //         if (_newPasswordController.text.isNotEmpty) {
//   //           updateOperations.add(_updatePassword(user));
//   //         }

//   //         // Execute all update operations concurrently
//   //         await Future.wait(updateOperations);

//   //         // Refresh user data after updating
//   //         await authProvider.refreshUserData();

//   //         _showSuccessSnackBar('Profile updated successfully');
//   //         Navigator.of(context).pop();
//   //       } else {
//   //         throw Exception('User not found');
//   //       }
//   //     } catch (e) {
//   //       _showErrorSnackBar('Error updating profile: ${e.toString()}');
//   //     } finally {
//   //       if (mounted) {
//   //         setState(() => _isLoading = false);
//   //       }
//   //     }
//   //   }
//   // }

//   // Future<void> _updateUserData(User user) async {
//   //   try {
//   //     await FirebaseFirestore.instance
//   //         .collection('users')
//   //         .doc(user.uid)
//   //         .update({
//   //       'name': _nameController.text,
//   //       'mobile': _mobileController.text,
//   //     });
//   //     await user.updateProfile(displayName: _nameController.text);
//   //   } catch (e) {
//   //     print('Error updating user data: $e');
//   //     rethrow;
//   //   }
//   // }

//   // Future<void> _updateEmail(User user) async {
//   //   if (_emailController.text != user.email) {
//   //     try {
//   //       await user.verifyBeforeUpdateEmail(_emailController.text);
//   //       _showSuccessSnackBar(
//   //           'Verification email sent. Please verify to update your email.');
//   //     } catch (e) {
//   //       print('Error updating email: $e');
//   //       rethrow;
//   //     }
//   //   }
//   // }

//   // Future<void> _updatePassword(User user) async {
//   //   if (_currentPasswordController.text.isNotEmpty) {
//   //     try {
//   //       AuthCredential credential = EmailAuthProvider.credential(
//   //         email: user.email!,
//   //         password: _currentPasswordController.text,
//   //       );
//   //       await user.reauthenticateWithCredential(credential);
//   //       await user.updatePassword(_newPasswordController.text);
//   //     } catch (e) {
//   //       print('Error updating password: $e');
//   //       rethrow;
//   //     }
//   //   } else {
//   //     throw Exception('Current password is required to update password');
//   //   }
//   // }
//   // Future<void> _updateUserData(User user) async {
//   //   await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//   //     'name': _nameController.text,
//   //     'mobile': _mobileController.text,
//   //     'email': _emailController.text,
//   //   });

//   //   await user.updateProfile(displayName: _nameController.text);
//   // }

//   // Future<void> _updateEmail(User user) async {
//   //   if (_emailController.text != user.email) {
//   //     await user.verifyBeforeUpdateEmail(_emailController.text);
//   //     _showSuccessSnackBar(
//   //         'Verification email sent. Please verify to update your email.');
//   //   }
//   // }

//   // Future<void> _updatePassword(User user) async {
//   //   if (_newPasswordController.text.isNotEmpty) {
//   //     if (_currentPasswordController.text.isNotEmpty) {
//   //       try {
//   //         AuthCredential credential = EmailAuthProvider.credential(
//   //           email: user.email!,
//   //           password: _currentPasswordController.text,
//   //         );
//   //         await user.reauthenticateWithCredential(credential);
//   //         await user.updatePassword(_newPasswordController.text);
//   //       } catch (e) {
//   //         throw Exception('Current password is incorrect');
//   //       }
//   //     } else {
//   //       _showErrorSnackBar(
//   //           'To change your password, please use the "Forgot Password" feature on the login screen.');
//   //     }
//   //   }
//   // }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         _showSuccessSnackBar('Account deletion request canceled.');
//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//     _checkDeletionRequest();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         if (request.docs.isNotEmpty) {
//           setState(() {
//             _hasDeletionRequest = true;
//             _deletionRequestStatus = request.docs.first['status'];
//           });
//         } else {
//           setState(() {
//             _hasDeletionRequest = false;
//             _deletionRequestStatus = '';
//           });
//         }
//       } catch (e) {
//         print('Error checking deletion request: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(
//                   _nameController, 'Name', 'Please enter your name'),
//               SizedBox(height: 16),
//               _buildTextField(
//                   _emailController, 'Email', 'Please enter your email'),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number',
//                   'Please enter your mobile number'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               if (_hasDeletionRequest)
//                 Column(
//                   children: [
//                     Text(
//                       'Account Deletion Request Status: $_deletionRequestStatus',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                     SizedBox(height: 24),
//                   ],
//                 ),
//               if (!_hasDeletionRequest) _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, String errorText) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       validator: (value) => value!.isEmpty ? errorText : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading ? CircularProgressIndicator() : Text('Update Profile'),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           await _updateUserData(user);
//           await _updateEmail(user);
//           await _updatePassword(user);

//           _showSuccessSnackBar('Profile updated successfully');

//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//       'name': _nameController.text,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//     });

//     await user.updateProfile(displayName: _nameController.text);
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       await user.verifyBeforeUpdateEmail(_emailController.text);
//       _showSuccessSnackBar(
//           'Verification email sent. Please verify to update your email.');
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_newPasswordController.text.isNotEmpty) {
//       if (_currentPasswordController.text.isNotEmpty) {
//         try {
//           AuthCredential credential = EmailAuthProvider.credential(
//             email: user.email!,
//             password: _currentPasswordController.text,
//           );
//           await user.reauthenticateWithCredential(credential);
//           await user.updatePassword(_newPasswordController.text);
//         } catch (e) {
//           throw Exception('Current password is incorrect');
//         }
//       } else {
//         _showErrorSnackBar(
//             'To change your password, please use the "Forgot Password" feature on the login screen.');
//       }
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         _showSuccessSnackBar('Account deletion request canceled.');
//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red));
//   }
// }


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//     _checkDeletionRequest();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         if (request.docs.isNotEmpty) {
//           setState(() {
//             _hasDeletionRequest = true;
//             _deletionRequestStatus = request.docs.first['status'];
//           });
//         } else {
//           setState(() {
//             _hasDeletionRequest = false;
//             _deletionRequestStatus = '';
//           });
//         }
//       } catch (e) {
//         print('Error checking deletion request: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(
//                   _nameController, 'Name', 'Please enter your name'),
//               SizedBox(height: 16),
//               _buildTextField(
//                   _emailController, 'Email', 'Please enter your email'),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number',
//                   'Please enter your mobile number'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               if (_hasDeletionRequest)
//                 Column(
//                   children: [
//                     Text(
//                       'Account Deletion Request Status: $_deletionRequestStatus',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                     SizedBox(height: 24),
//                   ],
//                 ),
//               if (!_hasDeletionRequest) _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, String errorText) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       validator: (value) => value!.isEmpty ? errorText : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading ? CircularProgressIndicator() : Text('Update Profile'),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           await _updateUserData(user);
//           await _updateEmail(user);
//           await _updatePassword(user);

//           _showSuccessSnackBar('Profile updated successfully');

//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//       'name': _nameController.text,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//     });

//     await user.updateProfile(displayName: _nameController.text);
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       await user.verifyBeforeUpdateEmail(_emailController.text);
//       _showSuccessSnackBar(
//           'Verification email sent. Please verify to update your email.');
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_newPasswordController.text.isNotEmpty) {
//       if (_currentPasswordController.text.isNotEmpty) {
//         try {
//           AuthCredential credential = EmailAuthProvider.credential(
//             email: user.email!,
//             password: _currentPasswordController.text,
//           );
//           await user.reauthenticateWithCredential(credential);
//           await user.updatePassword(_newPasswordController.text);
//         } catch (e) {
//           throw Exception('Current password is incorrect');
//         }
//       } else {
//         _showErrorSnackBar(
//             'To change your password, please use the "Forgot Password" feature on the login screen.');
//       }
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         await _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         HttpsCallable callable =
//             FirebaseFunctions.instance.httpsCallable('cancelDeletionRequest');
//         final response = await callable.call({'requestId': requestId});

//         _showSuccessSnackBar(response.data['message']);
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .delete();

//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red));
//   }
// }


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//     _checkDeletionRequest();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         if (request.docs.isNotEmpty) {
//           setState(() {
//             _hasDeletionRequest = true;
//             _deletionRequestStatus = request.docs.first['status'];
//           });
//         }
//       } catch (e) {
//         print('Error checking deletion request: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(
//                   _nameController, 'Name', 'Please enter your name'),
//               SizedBox(height: 16),
//               _buildTextField(
//                   _emailController, 'Email', 'Please enter your email'),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number',
//                   'Please enter your mobile number'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               if (_hasDeletionRequest)
//                 Column(
//                   children: [
//                     Text(
//                       'Account Deletion Request Status: $_deletionRequestStatus',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                     SizedBox(height: 24),
//                   ],
//                 ),
//               _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, String errorText) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       validator: (value) => value!.isEmpty ? errorText : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading ? CircularProgressIndicator() : Text('Update Profile'),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           await _updateUserData(user);
//           await _updateEmail(user);
//           await _updatePassword(user);

//           _showSuccessSnackBar('Profile updated successfully');

//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//       'name': _nameController.text,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//     });

//     await user.updateProfile(displayName: _nameController.text);
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       await user.verifyBeforeUpdateEmail(_emailController.text);
//       _showSuccessSnackBar(
//           'Verification email sent. Please verify to update your email.');
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_newPasswordController.text.isNotEmpty) {
//       if (_currentPasswordController.text.isNotEmpty) {
//         try {
//           AuthCredential credential = EmailAuthProvider.credential(
//             email: user.email!,
//             password: _currentPasswordController.text,
//           );
//           await user.reauthenticateWithCredential(credential);
//           await user.updatePassword(_newPasswordController.text);
//         } catch (e) {
//           throw Exception('Current password is incorrect');
//         }
//       } else {
//         _showErrorSnackBar(
//             'To change your password, please use the "Forgot Password" feature on the login screen.');
//       }
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .update({'status': 'canceled'});

//         _showSuccessSnackBar('Account deletion request canceled.');
//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red));
//   }
// }


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;
//   bool _hasDeletionRequest = false;
//   String _deletionRequestStatus = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//     _checkDeletionRequest();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   Future<void> _checkDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final request = await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .where('userId', isEqualTo: user.uid)
//             .where('status', isNotEqualTo: 'completed')
//             .get();

//         if (request.docs.isNotEmpty) {
//           setState(() {
//             _hasDeletionRequest = true;
//             _deletionRequestStatus = request.docs.first['status'];
//           });
//         }
//       } catch (e) {
//         print('Error checking deletion request: $e');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(
//                   _nameController, 'Name', 'Please enter your name'),
//               SizedBox(height: 16),
//               _buildTextField(
//                   _emailController, 'Email', 'Please enter your email'),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number',
//                   'Please enter your mobile number'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               if (_hasDeletionRequest)
//                 Column(
//                   children: [
//                     Text(
//                       'Account Deletion Request Status: $_deletionRequestStatus',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                     SizedBox(height: 16),
//                     _buildCancelDeletionRequestButton(),
//                     SizedBox(height: 24),
//                   ],
//                 ),
//               _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, String errorText) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       validator: (value) => value!.isEmpty ? errorText : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading ? CircularProgressIndicator() : Text('Update Profile'),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount || _hasDeletionRequest
//           ? null
//           : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Widget _buildCancelDeletionRequestButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _cancelAccountDeletionRequest,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.orange,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Cancel Account Deletion Request'),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           await _updateUserData(user);
//           await _updateEmail(user);
//           await _updatePassword(user);

//           _showSuccessSnackBar('Profile updated successfully');

//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//       'name': _nameController.text,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//     });

//     await user.updateProfile(displayName: _nameController.text);
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       await user.verifyBeforeUpdateEmail(_emailController.text);
//       _showSuccessSnackBar(
//           'Verification email sent. Please verify to update your email.');
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_newPasswordController.text.isNotEmpty) {
//       if (_currentPasswordController.text.isNotEmpty) {
//         try {
//           AuthCredential credential = EmailAuthProvider.credential(
//             email: user.email!,
//             password: _currentPasswordController.text,
//           );
//           await user.reauthenticateWithCredential(credential);
//           await user.updatePassword(_newPasswordController.text);
//         } catch (e) {
//           throw Exception('Current password is incorrect');
//         }
//       } else {
//         _showErrorSnackBar(
//             'To change your password, please use the "Forgot Password" feature on the login screen.');
//       }
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//         _checkDeletionRequest();
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   Future<void> _cancelAccountDeletionRequest() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User must be logged in to cancel the request.');
//       return;
//     }

//     try {
//       final requestSnapshot = await FirebaseFirestore.instance
//           .collection('deletion_requests')
//           .where('userId', isEqualTo: user.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();

//       if (requestSnapshot.docs.isNotEmpty) {
//         final requestId = requestSnapshot.docs.first.id;
//         await FirebaseFirestore.instance
//             .collection('deletion_requests')
//             .doc(requestId)
//             .update({'status': 'canceled'});

//         _showSuccessSnackBar('Account deletion request canceled.');
//         setState(() {
//           _hasDeletionRequest = false;
//           _deletionRequestStatus = '';
//         });
//       }
//     } catch (e) {
//       _showErrorSnackBar('Error canceling account deletion request: $e');
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red));
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;
//   bool _isDeletingAccount = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data. Please try again.');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildTextField(
//                   _nameController, 'Name', 'Please enter your name'),
//               SizedBox(height: 16),
//               _buildTextField(
//                   _emailController, 'Email', 'Please enter your email'),
//               SizedBox(height: 16),
//               _buildTextField(_mobileController, 'Mobile Number',
//                   'Please enter your mobile number'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _currentPasswordController, 'Current Password'),
//               SizedBox(height: 16),
//               _buildPasswordField(
//                   _newPasswordController, 'New Password (optional)'),
//               SizedBox(height: 24),
//               _buildUpdateButton(),
//               SizedBox(height: 24),
//               _buildDeleteAccountButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(
//       TextEditingController controller, String label, String errorText) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       validator: (value) => value!.isEmpty ? errorText : null,
//     );
//   }

//   Widget _buildPasswordField(TextEditingController controller, String label) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(labelText: label),
//       obscureText: true,
//     );
//   }

//   Widget _buildUpdateButton() {
//     return ElevatedButton(
//       onPressed: _isLoading ? null : _updateProfile,
//       child: _isLoading ? CircularProgressIndicator() : Text('Update Profile'),
//     );
//   }

//   Widget _buildDeleteAccountButton() {
//     return ElevatedButton(
//       onPressed: _isDeletingAccount ? null : _requestAccountDeletion,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.red,
//       ),
//       child: _isDeletingAccount
//           ? CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
//           : Text('Request Account Deletion'),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           await _updateUserData(user);
//           await _updateEmail(user);
//           await _updatePassword(user);

//           _showSuccessSnackBar('Profile updated successfully');

//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Error updating profile: ${e.toString()}');
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateUserData(User user) async {
//     await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//       'name': _nameController.text,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//     });

//     await user.updateProfile(displayName: _nameController.text);
//   }

//   Future<void> _updateEmail(User user) async {
//     if (_emailController.text != user.email) {
//       await user.verifyBeforeUpdateEmail(_emailController.text);
//       _showSuccessSnackBar(
//           'Verification email sent. Please verify to update your email.');
//     }
//   }

//   Future<void> _updatePassword(User user) async {
//     if (_newPasswordController.text.isNotEmpty) {
//       if (_currentPasswordController.text.isNotEmpty) {
//         try {
//           AuthCredential credential = EmailAuthProvider.credential(
//             email: user.email!,
//             password: _currentPasswordController.text,
//           );
//           await user.reauthenticateWithCredential(credential);
//           await user.updatePassword(_newPasswordController.text);
//         } catch (e) {
//           throw Exception('Current password is incorrect');
//         }
//       } else {
//         _showErrorSnackBar(
//             'To change your password, please use the "Forgot Password" feature on the login screen.');
//       }
//     }
//   }

//   Future<void> _requestAccountDeletion() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Delete Account'),
//         content: Text(
//             'Are you sure you want to request account deletion? This action cannot be undone.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Confirm'),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() => _isDeletingAccount = true);
//       try {
//         final authProvider =
//             Provider.of<app_auth.AuthProvider>(context, listen: false);
//         await authProvider.requestAccountDeletion();
//         _showSuccessSnackBar(
//             'Account deletion request sent. You will be notified when it\'s processed.');
//       } catch (e) {
//         print('Error requesting account deletion: $e');
//         if (e is FirebaseException) {
//           if (e.code == 'permission-denied') {
//             _showErrorSnackBar(
//                 'You do not have permission to perform this action. Please contact support.');
//           } else {
//             _showErrorSnackBar(
//                 'Error requesting account deletion: ${e.message}');
//           }
//         } else {
//           _showErrorSnackBar(
//               'An unexpected error occurred. Please try again later.');
//         }
//       } finally {
//         setState(() => _isDeletingAccount = false);
//       }
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(message), backgroundColor: Colors.red));
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _emailController;
//   late TextEditingController _mobileController;
//   late TextEditingController _currentPasswordController;
//   late TextEditingController _newPasswordController;
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _emailController = TextEditingController();
//     _mobileController = TextEditingController();
//     _currentPasswordController = TextEditingController();
//     _newPasswordController = TextEditingController();
//     _loadUserData();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (mounted) {
//           setState(() {
//             _nameController.text =
//                 userData.data()?['name'] ?? user.displayName ?? '';
//             _emailController.text = user.email ?? '';
//             _mobileController.text = userData.data()?['mobile'] ?? '';
//           });
//         }
//       } catch (e) {
//         print('Error loading user data: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Failed to load user data. Please try again.')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your name' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _emailController,
//                 decoration: InputDecoration(labelText: 'Email'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your email' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _mobileController,
//                 decoration: InputDecoration(labelText: 'Mobile Number'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your mobile number' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _currentPasswordController,
//                 decoration: InputDecoration(labelText: 'Current Password'),
//                 obscureText: true,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _newPasswordController,
//                 decoration:
//                     InputDecoration(labelText: 'New Password (optional)'),
//                 obscureText: true,
//               ),
//               SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _updateProfile,
//                 child: _isLoading
//                     ? CircularProgressIndicator()
//                     : Text('Update Profile'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           // Update name, mobile, and email in Firestore
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .update({
//             'name': _nameController.text,
//             'mobile': _mobileController.text,
//             'email': _emailController.text,
//           });

//           // Update the user's display name in Firebase Auth
//           await user.updateProfile(displayName: _nameController.text);

//           // Update email if changed
//           if (_emailController.text != user.email) {
//             await user.verifyBeforeUpdateEmail(_emailController.text);
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                   content: Text(
//                       'Verification email sent. Please verify to update your email.')),
//             );
//           }

//           // Update password if provided
//           if (_newPasswordController.text.isNotEmpty) {
//             if (_currentPasswordController.text.isNotEmpty) {
//               // If current password is provided, use it for reauthentication
//               try {
//                 AuthCredential credential = EmailAuthProvider.credential(
//                   email: user.email!,
//                   password: _currentPasswordController.text,
//                 );
//                 await user.reauthenticateWithCredential(credential);
//                 await user.updatePassword(_newPasswordController.text);
//               } catch (e) {
//                 throw Exception('Current password is incorrect');
//               }
//             } else {
//               // If current password is not provided, show a message about resetting password
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                     content: Text(
//                         'To change your password, please use the "Forgot Password" feature on the login screen.')),
//               );
//             }
//           }

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Profile updated successfully')),
//           );

//           // Refresh user data in AuthProvider
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error updating profile: ${e.toString()}')),
//         );
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

// class EditProfileScreen extends StatefulWidget {
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _mobileController = TextEditingController();
//   final _currentPasswordController = TextEditingController();
//   final _newPasswordController = TextEditingController();
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }

//   void _loadUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       try {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         setState(() {
//           _nameController.text =
//               userData.data()?['name'] ?? user.displayName ?? '';
//           _emailController.text = user.email ?? '';
//           _mobileController.text = userData.data()?['mobile'] ?? '';
//         });
//       } catch (e) {
//         print('Error loading user data: $e');
//         // Handle the error, maybe show a snackbar to the user
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Failed to load user data. Please try again.')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Profile'),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your name' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _emailController,
//                 decoration: InputDecoration(labelText: 'Email'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your email' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _mobileController,
//                 decoration: InputDecoration(labelText: 'Mobile Number'),
//                 validator: (value) =>
//                     value!.isEmpty ? 'Please enter your mobile number' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _currentPasswordController,
//                 decoration: InputDecoration(labelText: 'Current Password'),
//                 obscureText: true,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 controller: _newPasswordController,
//                 decoration:
//                     InputDecoration(labelText: 'New Password (optional)'),
//                 obscureText: true,
//               ),
//               SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: _isLoading ? null : _updateProfile,
//                 child: _isLoading
//                     ? CircularProgressIndicator()
//                     : Text('Update Profile'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

// void _updateProfile() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           // Update name, mobile, and email in Firestore
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .update({
//             'name': _nameController.text,
//             'mobile': _mobileController.text,
//             'email': _emailController.text,
//           });

//           // Update the user's display name in Firebase Auth
//           await user.updateProfile(displayName: _nameController.text);

//           // Update email if changed
//           if (_emailController.text != user.email) {
//             await user.verifyBeforeUpdateEmail(_emailController.text);
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                   content: Text(
//                       'Verification email sent. Please verify to update your email.')),
//             );
//           }

//           // Update password if provided
//           if (_newPasswordController.text.isNotEmpty) {
//             if (_currentPasswordController.text.isNotEmpty) {
//               // If current password is provided, use it for reauthentication
//               try {
//                 AuthCredential credential = EmailAuthProvider.credential(
//                   email: user.email!,
//                   password: _currentPasswordController.text,
//                 );
//                 await user.reauthenticateWithCredential(credential);
//                 await user.updatePassword(_newPasswordController.text);
//               } catch (e) {
//                 throw Exception('Current password is incorrect');
//               }
//             } else {
//               // If current password is not provided, show a message about resetting password
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                     content: Text(
//                         'To change your password, please use the "Forgot Password" feature on the login screen.')),
//               );
//             }
//           }

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Profile updated successfully')),
//           );

//           // Refresh user data in AuthProvider
//           final authProvider =
//               Provider.of<app_auth.AuthProvider>(context, listen: false);
//           await authProvider.refreshUserData();

//           Navigator.of(context).pop();
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error updating profile: ${e.toString()}')),
//         );
//       } finally {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _mobileController.dispose();
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     super.dispose();
//   }
// }
