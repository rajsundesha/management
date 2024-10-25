import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'package:flutter_slidable/flutter_slidable.dart';

class CompletedRequestsScreen extends StatefulWidget {
  @override
  _CompletedRequestsScreenState createState() =>
      _CompletedRequestsScreenState();
}

class _CompletedRequestsScreenState extends State<CompletedRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, yyyy h:mm a').format(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
    } else if (timestamp is String) {
      return timestamp; // It's already formatted
    }
    return 'Unknown date';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final userEmail = authProvider.currentUserEmail;
    final userRole = authProvider.role;

    if (userEmail == null || userRole == null) {
      print('Error: User information not available. Please log in again.');
      return Scaffold(
        body: Center(
          child: Text('Please log in to view completed requests.'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildSearchBar(),
          ),
          _buildCompletedRequestsList(requestProvider, userEmail, userRole),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Completed Requests'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.green.shade400, Colors.green.shade800],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by picker name or contact',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade200,
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade600),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCompletedRequestsList(
      RequestProvider requestProvider, String userEmail, String userRole) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream:
          requestProvider.getRecentFulfilledRequestsStream(userEmail, userRole),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print('Error fetching completed requests: ${snapshot.error}');
          return SliverFillRemaining(
            child: Center(child: Text('Unable to load completed requests.')),
          );
        }

        final completedRequests = snapshot.data ?? [];
        final filteredRequests = completedRequests
            .where((request) =>
                _searchQuery.isEmpty ||
                (request['pickerName'] as String?)
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ==
                    true ||
                (request['pickerContact'] as String?)
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ==
                    true)
            .toList();

        if (filteredRequests.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No completed requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'in the last 7 days',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final request = filteredRequests[index];
              return _buildRequestCard(request);
            },
            childCount: filteredRequests.length,
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String formattedDate = _formatDate(request['fulfilledAt']);

    return Slidable(
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showRequestDetails(request),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.info,
            label: 'Details',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          title: Text(
            request['pickerName'] ?? 'Unknown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text('Location: ${request['location'] ?? 'Unknown'}'),
              Text('Contact: ${request['pickerContact'] ?? 'Unknown'}'),
              Text('Completed On: $formattedDate'),
              Text('Items: ${(request['items'] as List?)?.length ?? 0} items'),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white),
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _showRequestDetails(request),
        ),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Request Details',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildDetailItem(
                        'Picker', request['pickerName'] ?? 'Unknown'),
                    _buildDetailItem(
                        'Location', request['location'] ?? 'Unknown'),
                    _buildDetailItem(
                        'Contact', request['pickerContact'] ?? 'Unknown'),
                    _buildDetailItem('Status', request['status'] ?? 'Unknown'),
                    _buildDetailItem(
                        'Unique Code', request['uniqueCode'] ?? 'Unknown'),
                    _buildDetailItem(
                        'Completed On', _formatDate(request['fulfilledAt'])),
                    SizedBox(height: 16),
                    Text(
                      'Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...(request['items'] as List<dynamic>? ?? [])
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                  '${item['quantity'] ?? 0} ${item['unit'] ?? 'pcs'} of ${item['name'] ?? 'Unknown Item'}'),
                            )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
