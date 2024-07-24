
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class ManagerCompletedRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;
    final currentUserRole = authProvider.role;

    return Scaffold(
      appBar: AppBar(
        title: Text('Completed Requests'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<RequestProvider>(context, listen: false)
            .getRequestsStream(
                currentUserEmail!, currentUserRole!, 'fulfilled'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final completedRequests = snapshot.data ?? [];
          return ListView.builder(
            itemCount: completedRequests.length,
            itemBuilder: (context, index) {
              final request = completedRequests[index];
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${(request['items'] as List).map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}\n'
                    'Unique Code: ${request['uniqueCode']}',
                  ),
                  leading: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
