import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart' as app_auth;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  final storage =
      FlutterSecureStorage(); // Secure storage for saving credentials

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load saved credentials when screen is initialized
  }

  // Load saved email, password, and rememberMe state
  Future<void> _loadSavedCredentials() async {
    try {
      // Read saved values from secure storage
      final savedEmail = await storage.read(key: 'email');
      final savedPassword = await storage.read(key: 'password');
      final savedRememberMe = await storage.read(key: 'rememberMe');

      // If credentials are found and rememberMe is true, load them into the text fields
      if (savedEmail != null &&
          savedPassword != null &&
          savedRememberMe == 'true') {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.black),
        title: Text(
          'Login',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.grey),
            onPressed: _showHelpInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 60),
            Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please log in to your account',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 40),
            _buildTextField(
              controller: emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value!;
                    });
                  },
                ),
                Text('Remember me'),
              ],
            ),
            SizedBox(height: 30),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _login,
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
            SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable method for creating text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
    );
  }

  // Method to show help information
  void _showHelpInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Help Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Only verified users who are part of the inventory management system can log in.'),
              SizedBox(height: 16),
              Text('For any clarification, please email liffytech@gmail.com'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Handle login process
  Future<void> _login() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.login(emailController.text, passwordController.text);

      // Save credentials if "Remember me" is checked
      if (_rememberMe) {
        await _saveCredentials();
      } else {
        await _clearSavedCredentials();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      String errorMessage = _getErrorMessage(e);
      print("Login error: $errorMessage");
      _showSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Save credentials to secure storage
  Future<void> _saveCredentials() async {
    try {
      await storage.write(key: 'email', value: emailController.text);
      await storage.write(key: 'password', value: passwordController.text);
      await storage.write(key: 'rememberMe', value: _rememberMe.toString());
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  // Clear saved credentials
  Future<void> _clearSavedCredentials() async {
    try {
      await storage.delete(key: 'email');
      await storage.delete(key: 'password');
      await storage.write(key: 'rememberMe', value: 'false');
    } catch (e) {
      print('Error clearing credentials: $e');
    }
  }

  // Handle error messages
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        default:
          return 'An error occurred during login: ${error.message}';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  // Show a snack bar with the provided message
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Handle forgotten password
  Future<void> _forgotPassword() async {
    final email = emailController.text;
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.sendPasswordResetEmail(email);
      _showSnackBar(
          'If an account exists for $email, a password reset email has been sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-not-found':
          errorMessage =
              'If an account exists, a password reset email has been sent.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again later.';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('An unexpected error occurred. Please try again later.');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
