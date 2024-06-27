import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class ManagerCompletedRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Completed Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          final completedRequests = requestProvider.requests
              .where((request) => request['status'] == 'fulfilled')
              .toList();
          return ListView.builder(
            itemCount: completedRequests.length,
            itemBuilder: (context, index) {
              final request = completedRequests[index];
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
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
