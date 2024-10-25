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
