import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../models/approved_request.dart';
import '../providers/approved_request_provider.dart';

class ManagerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manager Dashboard')),
      body: Consumer<ApprovedRequestProvider>(
        builder: (context, approvedRequestProvider, child) {
          return ListView.builder(
            itemCount: approvedRequestProvider.approvedRequests.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                    'Request from ${approvedRequestProvider.approvedRequests[index].userName}'),
                subtitle: Text(
                    'Items: ${approvedRequestProvider.approvedRequests[index].items.join(', ')}'),
                trailing: IconButton(
                  icon: Icon(Icons.done),
                  onPressed: () {
                    approvedRequestProvider.distributeItems(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Items distributed and OTP sent to ${approvedRequestProvider.approvedRequests[index].userName}')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Provider.of<ApprovedRequestProvider>(context, listen: false)
              .fetchApprovedRequests();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
