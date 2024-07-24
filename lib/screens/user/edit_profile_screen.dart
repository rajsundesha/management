import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/auth_provider.dart' as app_auth;

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          _nameController.text =
              userData.data()?['name'] ?? user.displayName ?? '';
          _emailController.text = user.email ?? '';
          _mobileController.text = userData.data()?['mobile'] ?? '';
        });
      } catch (e) {
        print('Error loading user data: $e');
        // Handle the error, maybe show a snackbar to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load user data. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your email' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: InputDecoration(labelText: 'Mobile Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your mobile number' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration:
                    InputDecoration(labelText: 'New Password (optional)'),
                obscureText: true,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Update Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Update name, mobile, and email in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'name': _nameController.text,
            'mobile': _mobileController.text,
            'email': _emailController.text,
          });

          // Update the user's display name in Firebase Auth
          await user.updateProfile(displayName: _nameController.text);

          // Update email if changed
          if (_emailController.text != user.email) {
            await user.verifyBeforeUpdateEmail(_emailController.text);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Verification email sent. Please verify to update your email.')),
            );
          }

          // Update password if provided
          if (_newPasswordController.text.isNotEmpty) {
            if (_currentPasswordController.text.isNotEmpty) {
              // If current password is provided, use it for reauthentication
              try {
                AuthCredential credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: _currentPasswordController.text,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(_newPasswordController.text);
              } catch (e) {
                throw Exception('Current password is incorrect');
              }
            } else {
              // If current password is not provided, show a message about resetting password
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'To change your password, please use the "Forgot Password" feature on the login screen.')),
              );
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile updated successfully')),
          );

          // Refresh user data in AuthProvider
          final authProvider =
              Provider.of<app_auth.AuthProvider>(context, listen: false);
          await authProvider.refreshUserData();

          Navigator.of(context).pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
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
}
