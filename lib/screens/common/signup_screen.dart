import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String _selectedRole = 'User'; // Default role
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SignUp')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
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
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      try {
                        await Provider.of<AuthProvider>(context, listen: false)
                            .createUser(emailController.text,
                                passwordController.text, _selectedRole);
                        Navigator.pushReplacementNamed(context, '/');
                      } catch (e) {
                        setState(() {
                          _errorMessage = e.toString();
                          _isLoading = false;
                        });
                        print("Error during registration: $e");
                      }
                    },
                    child: Text('SignUp'),
                  ),
            if (_errorMessage != null) ...[
              SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
