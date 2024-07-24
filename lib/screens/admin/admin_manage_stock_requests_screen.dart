import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';

class AdminManageStockRequestsScreen extends StatefulWidget {
  @override
  _AdminManageStockRequestsScreenState createState() =>
      _AdminManageStockRequestsScreenState();
}

class _AdminManageStockRequestsScreenState
    extends State<AdminManageStockRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Stock Requests'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<RequestProvider>(context, listen: false)
            .getStockRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(child: Text('No stock requests available'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return GestureDetector(
                onTap: () => _showRequestDetails(request),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock Request by ${request['createdBy']}',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Status: ${request['status']}',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        _buildActionButtons(request),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> request) {
    switch (request['status']) {
      case 'pending':
        return SizedBox(
          width: 96, // Ensure the width is within acceptable limits
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check, color: Colors.green),
                onPressed: () =>
                    _updateRequestStatus(request['id'], 'approved'),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: () => _showRejectDialog(request['id']),
              ),
            ],
          ),
        );
      case 'approved':
        return IconButton(
          icon: Icon(Icons.done_all, color: Colors.blue),
          onPressed: () => _updateRequestStatus(request['id'], 'fulfilled'),
        );
      default:
        return Container(); // Return an empty container for other statuses
    }
  }

  void _updateRequestStatus(String id, String status) {
    final adminEmail =
        Provider.of<AuthProvider>(context, listen: false).currentUserEmail;
    if (adminEmail != null) {
      Provider.of<RequestProvider>(context, listen: false)
          .updateStockRequestStatus(id, status, adminEmail);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin email not available')),
      );
    }
  }

  void _showRejectDialog(String id) {
    final _reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Request'),
        content: TextField(
          controller: _reasonController,
          decoration: InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Reject'),
            onPressed: () {
              if (_reasonController.text.isNotEmpty) {
                final adminEmail =
                    Provider.of<AuthProvider>(context, listen: false)
                        .currentUserEmail;
                if (adminEmail != null) {
                  Provider.of<RequestProvider>(context, listen: false)
                      .updateStockRequestStatus(id, 'rejected', adminEmail,
                          rejectionReason: _reasonController.text);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Admin email not available')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Please provide a reason for rejection')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stock Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Created by: ${request['createdBy']}'),
              Text('Status: ${request['status']}'),
              Text('Items:'),
              ...(request['items'] as List<dynamic>)
                  .map(
                    (item) => Text('- ${item['name']}: ${item['quantity']}'),
                  )
                  .toList(),
              SizedBox(height: 10),
              Text('Note: ${request['note']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

