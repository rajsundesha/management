import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class AdminManageStockRequestsScreen extends StatefulWidget {
  @override
  _AdminManageStockRequestsScreenState createState() =>
      _AdminManageStockRequestsScreenState();
}

class _AdminManageStockRequestsScreenState
    extends State<AdminManageStockRequestsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Pending',
    'Approved',
    'Partially Fulfilled',
    'Fulfilled',
    'Rejected'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Stock Requests'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
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
                final filteredRequests = _selectedFilter == 'All'
                    ? requests
                    : requests
                        .where((r) =>
                            r['status'].toLowerCase() ==
                            _selectedFilter.toLowerCase().replaceAll(' ', '_'))
                        .toList();
                if (filteredRequests.isEmpty) {
                  return Center(child: Text('No stock requests available'));
                }
                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return _buildRequestCard(request);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: _selectedFilter == filter,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          'Request by ${request['createdBy'] ?? 'Unknown'}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${_formatStatus(request['status'])}',
          style: TextStyle(color: _getStatusColor(request['status'])),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created at: ${_formatDate(request['createdAt'])}'),
                if (request['approvedAt'] != null)
                  Text('Approved at: ${_formatDate(request['approvedAt'])}'),
                if (request['fulfilledAt'] != null)
                  Text('Fulfilled at: ${_formatDate(request['fulfilledAt'])}'),
                if (request['rejectedAt'] != null)
                  Text('Rejected at: ${_formatDate(request['rejectedAt'])}'),
                if (request['rejectionReason'] != null)
                  Text('Rejection Reason: ${request['rejectionReason']}'),
                SizedBox(height: 8),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._buildItemsList(request['items'] ?? []),
                SizedBox(height: 8),
                Text('Note: ${request['note'] ?? 'No note provided'}'),
                SizedBox(height: 16),
                _buildActionButtons(request),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemsList(List<dynamic> items) {
    return items.map((item) {
      final name = item['name'] ?? 'Unknown Item';
      final isPipe = item['isPipe'] ?? false;
      String details;
      if (isPipe) {
        final pcs = item['pcs'] ?? 0;
        final meters = item['meters'] ?? 0.0;
        details =
            '${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
      } else {
        final quantity = item['quantity'] ?? 0;
        final unit = item['unit'] ?? 'pcs';
        details = '$quantity $unit';
      }
      return Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Text('• $name: $details'),
      );
    }).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'partially_fulfilled':
        return Colors.blue;
      case 'fulfilled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    return status.split('_').map((word) => word.capitalize()).join(' ');
  }

  Widget _buildActionButtons(Map<String, dynamic> request) {
    List<Widget> buttons = [
      ElevatedButton.icon(
        icon: Icon(Icons.share),
        label: Text('Share'),
        onPressed: () => shareRequestDetails(request),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    ];

    switch (request['status']?.toLowerCase()) {
      case 'pending':
        buttons.addAll([
          ElevatedButton.icon(
            icon: Icon(Icons.check),
            label: Text('Approve'),
            onPressed: () => _updateRequestStatus(request['id'], 'approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.close),
            label: Text('Reject'),
            onPressed: () => _showRejectDialog(request['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ]);
        break;
      case 'rejected':
        buttons.add(
          ElevatedButton.icon(
            icon: Icon(Icons.check),
            label: Text('Approve'),
            onPressed: () => _updateRequestStatus(request['id'], 'approved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
        break;
      case 'approved':
      case 'partially_fulfilled':
      case 'fulfilled':
        buttons.add(
          ElevatedButton.icon(
            icon: Icon(Icons.close),
            label: Text('Reject'),
            onPressed: () => _showRejectDialog(request['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
        break;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceEvenly,
      children: buttons,
    );
  }

  void shareRequestDetails(Map<String, dynamic> request) {
    String shareText = '''
Status: ${_formatStatus(request['status'])}
Created by: ${request['createdBy'] ?? 'N/A'}
Created at: ${_formatDate(request['createdAt'])}
${request['approvedAt'] != null ? 'Approved at: ${_formatDate(request['approvedAt'])}\n' : ''}
${request['fulfilledAt'] != null ? 'Fulfilled at: ${_formatDate(request['fulfilledAt'])}\n' : ''}
${request['rejectedAt'] != null ? 'Rejected at: ${_formatDate(request['rejectedAt'])}\n' : ''}
${request['rejectionReason'] != null ? 'Rejection Reason: ${request['rejectionReason']}\n' : ''}
Items: ${_formatItems(request['items'] ?? [])}
Note: ${request['note'] ?? 'N/A'}
  ''';

    Share.share(shareText, subject: 'Stock Request Details');
  }

  String _formatItems(List<dynamic> items) {
    return items.map((item) {
      final name = item['name'] ?? 'Unknown Item';
      final isPipe = item['isPipe'] ?? false;
      if (isPipe) {
        final pcs = item['pcs'] ?? 0;
        final meters = item['meters'] ?? 0.0;
        return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
      } else {
        final quantity = item['quantity'] ?? 0;
        final unit = item['unit'] ?? 'pcs';
        return '$quantity x $name ($unit)';
      }
    }).join(', ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not available';
    if (date is DateTime) {
      return DateFormat('yyyy-MM-dd hh:mm a').format(date);
    }
    if (date is int) {
      return DateFormat('yyyy-MM-dd hh:mm a')
          .format(DateTime.fromMillisecondsSinceEpoch(date));
    }
    if (date is Timestamp) {
      return DateFormat('yyyy-MM-dd hh:mm a').format(date.toDate());
    }
    return 'Invalid date format';
  }

  void _updateRequestStatus(String id, String status) {
    final adminEmail =
        Provider.of<AuthProvider>(context, listen: false).currentUserEmail;
    if (adminEmail != null) {
      Provider.of<RequestProvider>(context, listen: false)
          .updateStockRequestStatus(id, status, adminEmail)
          .then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request status updated successfully')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating request status: $error')),
        );
      });
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
                          rejectionReason: _reasonController.text)
                      .then((_) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Request rejected successfully')),
                    );
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error rejecting request: $error')),
                    );
                  });
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
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
