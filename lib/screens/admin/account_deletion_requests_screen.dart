import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhavla_road_project/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AccountDeletionRequestsScreen extends StatefulWidget {
  @override
  _AccountDeletionRequestsScreenState createState() =>
      _AccountDeletionRequestsScreenState();
}

class _AccountDeletionRequestsScreenState
    extends State<AccountDeletionRequestsScreen> {
  late AuthProvider authProvider;
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortAscending = true;
  String _statusFilter = 'All';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Deletion Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deletion_requests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No account deletion requests'));
                }

                var requests = snapshot.data!.docs;
                requests = _filterAndSortRequests(requests);

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var request = requests[index];
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by email...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildRequestCard(QueryDocumentSnapshot request) {
    Map<String, dynamic>? data = request.data() as Map<String, dynamic>?;
    String status = data?['status'] ?? 'pending';
    Color statusColor = _getStatusColor(status);

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(
          data?['email'] ?? 'No email provided',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Requested: ${_formatDate(data?['requestDate'])}',
        ),
        trailing: Chip(
          label: Text(status.capitalize()),
          backgroundColor: statusColor.withOpacity(0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == 'approved' &&
                    data?.containsKey('approvedAt') == true)
                  Text('Approved at: ${_formatDate(data?['approvedAt'])}'),
                if (status == 'rejected' &&
                    data?.containsKey('rejectedAt') == true)
                  Text('Rejected at: ${_formatDate(data?['rejectedAt'])}'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (status != 'approved')
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () => _processRequest(request.id, true),
                      ),
                    if (status != 'rejected')
                      ElevatedButton.icon(
                        icon: Icon(Icons.close),
                        label: Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _processRequest(request.id, false),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _processRequest(String userId, bool approved) async {
    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .processAccountDeletionRequest(userId, approved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved
              ? 'Account deletion request approved'
              : 'Account deletion request rejected'),
          backgroundColor: approved ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sort by'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Date'),
                leading: Radio<String>(
                  value: 'date',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text('Email'),
                leading: Radio<String>(
                  value: 'email',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(_sortAscending ? 'Ascending' : 'Descending'),
              onPressed: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                  Navigator.pop(context);
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter by Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('All'),
                leading: Radio<String>(
                  value: 'All',
                  groupValue: _statusFilter,
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text('Pending'),
                leading: Radio<String>(
                  value: 'pending',
                  groupValue: _statusFilter,
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text('Approved'),
                leading: Radio<String>(
                  value: 'approved',
                  groupValue: _statusFilter,
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text('Rejected'),
                leading: Radio<String>(
                  value: 'rejected',
                  groupValue: _statusFilter,
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterAndSortRequests(
      List<QueryDocumentSnapshot> requests) {
    // Filter by status
    if (_statusFilter != 'All') {
      requests = requests
          .where((request) => request['status'] == _statusFilter)
          .toList();
    }

    // Filter by search query
    requests = requests.where((request) {
      return (request['email'] ?? '')
          .toString()
          .toLowerCase()
          .contains(_searchQuery);
    }).toList();

    // Sort
    requests.sort((a, b) {
      if (_sortBy == 'date') {
        return _sortAscending
            ? _getDate(a['requestDate']).compareTo(_getDate(b['requestDate']))
            : _getDate(b['requestDate']).compareTo(_getDate(a['requestDate']));
      } else {
        return _sortAscending
            ? (a['email'] ?? '')
                .toString()
                .compareTo((b['email'] ?? '').toString())
            : (b['email'] ?? '')
                .toString()
                .compareTo((a['email'] ?? '').toString());
      }
    });

    return requests;
  }

  DateTime _getDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is DateTime) {
      return date;
    } else {
      return DateTime.now(); // fallback
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date not available';
    if (date is Timestamp) {
      return DateFormat('MMM d, yyyy HH:mm').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('MMM d, yyyy HH:mm').format(date);
    }
    return 'Invalid date format';
  }
  // String _formatDate(dynamic date) {
  //   DateTime dateTime = _getDate(date);
  //   return DateFormat('MMM d, yyyy HH:mm').format(dateTime);
  // }

// void _processRequest(String requestId, String newStatus) async {
//     try {
//       await authProvider.updateAccountDeletionRequestStatus(
//           requestId, newStatus);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Request status updated to ${newStatus.capitalize()}'),
//           backgroundColor: _getStatusColor(newStatus),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error processing request: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
