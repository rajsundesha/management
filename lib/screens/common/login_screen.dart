import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String _selectedRole = 'User';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedRole,
              items: <String>['User', 'Admin', 'Manager', 'Gate Man']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue!;
                });
              },
            ),
            SizedBox(height: 20),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                  ),
            SizedBox(height: 20),
            TextButton(
              onPressed: _isLoading ? null : _forgotPassword,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Forgot Password'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text('Don\'t have an account? Sign up here.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.login(emailController.text, passwordController.text);

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
        case 'invalid-credential':
          return 'The supplied auth credential is malformed or has expired.';
        case 'email-not-verified':
          return 'Please check your email and verify your account before logging in.';
        default:
          return 'An error occurred during login: ${error.message}';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

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

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Email Verification Required'),
          content: Text(
              'Please check your email and verify your account before logging in.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
        case 'inconsistent-user-data':
          errorMessage =
              'There was an issue with your account. Please contact support.';
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

  void _showSignUpOption() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Account Not Found'),
          content: Text('Would you like to create a new account?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Sign Up'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/signup');
              },
            ),
          ],
        );
      },
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Account Issue'),
          content: Text(
              'There was an issue with your account. Please contact our support team for assistance.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

  // Future<void> _forgotPassword() async {
  //   final email = emailController.text;
  //   if (email.isNotEmpty) {
  //     try {
  //       await Provider.of<app_auth.AuthProvider>(context, listen: false)
  //           .sendPasswordResetEmail(email);
  //       _showSnackBar('Password reset email sent. Please check your inbox.');
  //     } catch (e) {
  //       _showSnackBar('Error sending password reset email: ${e.toString()}');
  //     }
  //   } else {
  //     _showSnackBar('Please enter your email address');
  //   }
  // }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart' as app_auth;
// import 'package:firebase_auth/firebase_auth.dart';

// class LoginScreen extends StatefulWidget {
//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   String _selectedRole = 'User';
//   bool _isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login')),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: <Widget>[
//             TextField(
//               controller: emailController,
//               decoration: InputDecoration(labelText: 'Email'),
//               keyboardType: TextInputType.emailAddress,
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: passwordController,
//               decoration: InputDecoration(labelText: 'Password'),
//               obscureText: true,
//             ),
//             SizedBox(height: 20),
//             DropdownButton<String>(
//               isExpanded: true,
//               value: _selectedRole,
//               items: <String>['User', 'Admin', 'Manager', 'Gate Man']
//                   .map((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//               onChanged: (String? newValue) {
//                 setState(() {
//                   _selectedRole = newValue!;
//                 });
//               },
//             ),
//             SizedBox(height: 20),
//             _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : ElevatedButton(
//                     onPressed: _login,
//                     child: Text('Login'),
//                   ),
//             SizedBox(height: 20),
//             TextButton(
//               child: Text('Forgot Password'),
//               onPressed: _forgotPassword,
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.pushNamed(context, '/signup');
//               },
//               child: Text('Don\'t have an account? Sign up here.'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Future<void> _login() async {
//   //   if (!mounted) return;

//   //   setState(() => _isLoading = true);

//   //   try {
//   //     User? user =
//   //         await Provider.of<app_auth.AuthProvider>(context, listen: false)
//   //             .login(emailController.text, passwordController.text);

//   //     if (!mounted) return;

//   //     if (user != null) {
//   //       if (user.emailVerified) {
//   //         _showSnackBar('Login successful!');
//   //         Navigator.of(context).pushReplacementNamed('/');
//   //       } else {
//   //         await user.sendEmailVerification();
//   //         _showVerificationDialog();
//   //       }
//   //     } else {
//   //       _showSnackBar('Login failed. Please try again.');
//   //     }
//   //   } catch (e) {
//   //     if (!mounted) return;
//   //     String errorMessage = _getErrorMessage(e);
//   //     _showSnackBar(errorMessage);
//   //   } finally {
//   //     if (mounted) {
//   //       setState(() => _isLoading = false);
//   //     }
//   //   }
//   // }

//   // String _getErrorMessage(dynamic error) {
//   //   if (error is FirebaseAuthException) {
//   //     switch (error.code) {
//   //       case 'invalid-email':
//   //         return 'The email address is not valid.';
//   //       case 'user-disabled':
//   //         return 'This user account has been disabled.';
//   //       case 'user-not-found':
//   //         return 'No user found with this email address.';
//   //       case 'wrong-password':
//   //         return 'Incorrect password. Please try again.';
//   //       case 'invalid-credential':
//   //         return 'The supplied auth credential is malformed or has expired.';
//   //       default:
//   //         return 'An error occurred during login. Please try again. (${error.code})';
//   //     }
//   //   }
//   //   return 'An unexpected error occurred. Please try again.';
//   // }

//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           duration: Duration(seconds: 3),
//         ),
//       );
//     }
//   }

//   // void _showVerificationDialog() {
//   //   showDialog(
//   //     context: context,
//   //     builder: (BuildContext context) {
//   //       return AlertDialog(
//   //         title: Text('Email Verification Required'),
//   //         content: Text(
//   //             'Please check your email and verify your account before logging in.'),
//   //         actions: <Widget>[
//   //           TextButton(
//   //             child: Text('OK'),
//   //             onPressed: () {
//   //               Navigator.of(context).pop();
//   //             },
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }
//   void _checkAuthStatus() {
//     final authProvider =
//         Provider.of<app_auth.AuthProvider>(context, listen: false);
//     if (authProvider.user != null && !authProvider.isEmailVerified) {
//       _showVerificationDialog();
//     }
//   }

//   Future<void> _login() async {
//     if (!mounted) return;

//     setState(() => _isLoading = true);

//     try {
//       final authProvider =
//           Provider.of<app_auth.AuthProvider>(context, listen: false);
//       await authProvider.login(emailController.text, passwordController.text);

//       if (!mounted) return;

//       if (authProvider.isEmailVerified) {
//         Navigator.of(context).pushReplacementNamed('/');
//       } else {
//         _showVerificationDialog();
//       }
//     } catch (e) {
//       if (!mounted) return;
//       String errorMessage = _getErrorMessage(e);
//       print("Login error: $errorMessage");
//       if (e is FirebaseAuthException && e.code == 'email-not-verified') {
//         _showVerificationDialog();
//       } else {
//         _showSnackBar(errorMessage);
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   String _getErrorMessage(dynamic error) {
//     if (error is FirebaseAuthException) {
//       switch (error.code) {
//         case 'invalid-email':
//           return 'The email address is not valid.';
//         case 'user-disabled':
//           return 'This user account has been disabled.';
//         case 'user-not-found':
//           return 'No user found with this email address.';
//         case 'wrong-password':
//           return 'Incorrect password. Please try again.';
//         case 'invalid-credential':
//           return 'The supplied auth credential is malformed or has expired.';
//         case 'email-not-verified':
//           return 'Please check your email and verify your account before logging in.';
//         default:
//           return 'An error occurred during login: ${error.message}';
//       }
//     }
//     return 'An unexpected error occurred. Please try again.';
//   }

//   // Future<void> _login() async {
//   //   if (!mounted) return;

//   //   setState(() => _isLoading = true);

//   //   try {
//   //     final authProvider =
//   //         Provider.of<app_auth.AuthProvider>(context, listen: false);
//   //     await authProvider.login(emailController.text, passwordController.text);

//   //     if (!mounted) return;

//   //     if (authProvider.isEmailVerified) {
//   //       Navigator.of(context).pushReplacementNamed('/');
//   //     } else {
//   //       _showVerificationDialog();
//   //     }
//   //   } catch (e) {
//   //     if (!mounted) return;
//   //     String errorMessage = _getErrorMessage(e);
//   //     if (e is FirebaseAuthException && e.code == 'email-not-verified') {
//   //       _showVerificationDialog();
//   //     } else {
//   //       _showSnackBar(errorMessage);
//   //     }
//   //   } finally {
//   //     if (mounted) {
//   //       setState(() => _isLoading = false);
//   //     }
//   //   }
//   // }

//   // String _getErrorMessage(dynamic error) {
//   //   if (error is FirebaseAuthException) {
//   //     switch (error.code) {
//   //       case 'invalid-email':
//   //         return 'The email address is not valid.';
//   //       case 'user-disabled':
//   //         return 'This user account has been disabled.';
//   //       case 'user-not-found':
//   //         return 'No user found with this email address.';
//   //       case 'wrong-password':
//   //         return 'Incorrect password. Please try again.';
//   //       case 'invalid-credential':
//   //         return 'The supplied auth credential is malformed or has expired.';
//   //       case 'email-not-verified':
//   //         return 'Please check your email and verify your account before logging in.';
//   //       default:
//   //         return 'An error occurred during login. Please try again. (${error.code})';
//   //     }
//   //   }
//   //   return 'An unexpected error occurred. Please try again.';
//   // }

//   void _showVerificationDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Email Verification Required'),
//           content: Text(
//               'Please check your email and verify your account before logging in.'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('OK'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _forgotPassword() async {
//     final email = emailController.text;
//     if (email.isNotEmpty) {
//       try {
//         await Provider.of<app_auth.AuthProvider>(context, listen: false)
//             .sendPasswordResetEmail(email);
//         _showSnackBar('Password reset email sent. Please check your inbox.');
//       } catch (e) {
//         _showSnackBar('Error sending password reset email: ${e.toString()}');
//       }
//     } else {
//       _showSnackBar('Please enter your email address');
//     }
//   }
// }
