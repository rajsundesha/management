import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String _selectedRole = 'User'; // Default role

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
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
              items: <String>['User', 'Admin', 'Manager'].map((String value) {
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
            ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false)
                    .login(_selectedRole);
                if (_selectedRole == 'User') {
                  Navigator.pushNamed(context, '/user_dashboard');
                } else if (_selectedRole == 'Admin') {
                  Navigator.pushNamed(context, '/admin_dashboard');
                } else if (_selectedRole == 'Manager') {
                  Navigator.pushNamed(context, '/manager_dashboard');
                }
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
