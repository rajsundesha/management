import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class GenericRequestListScreen extends StatefulWidget {
  final String title;
  final String status;
  final Color headerColor;

  const GenericRequestListScreen({
    Key? key,
    required this.title,
    required this.status,
    required this.headerColor,
  }) : super(key: key);

  @override
  _GenericRequestListScreenState createState() =>
      _GenericRequestListScreenState();
}

class _GenericRequestListScreenState extends State<GenericRequestListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;
    final userRole = authProvider.role;

    if (currentUserEmail == null || userRole == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Text('User information not available. Please log in again.'),
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
          _buildRequestList(requestProvider, currentUserEmail, userRole),
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
        title: Text(widget.title),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [widget.headerColor.withOpacity(0.8), widget.headerColor],
            ),
          ),
          child: Center(
            child: Icon(
              _getIconForStatus(widget.status),
              size: 80,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'partially_fulfilled':
        return Icons.hourglass_bottom;
      case 'fulfilled':
        return Icons.done_all;
      default:
        return Icons.list;
    }
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

  Widget _buildRequestList(RequestProvider requestProvider,
      String currentUserEmail, String userRole) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: requestProvider.getRequestsStream(
          currentUserEmail, userRole, widget.status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final requests = snapshot.data ?? [];
        final filteredRequests = requests.where((request) {
          final String pickerName = request['pickerName'] ?? '';
          final String pickerContact = request['pickerContact'] ?? '';
          return pickerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              pickerContact.contains(_searchQuery);
        }).toList();

        if (filteredRequests.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text('No ${widget.status} requests found.'),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildRequestCard(context, filteredRequests[index]),
            childCount: filteredRequests.length,
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    return Slidable(
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showRequestDetails(context, request),
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
          title: Text(
            request['pickerName'] ?? 'Unknown Picker',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: ${request['location']}'),
              Text('Items: ${_formatItems(request['items'])}'),
              Text('Status: ${request['status']}'),
            ],
          ),
          trailing: Text(_formatDate(request['timestamp'])),
          onTap: () => _showRequestDetails(context, request),
        ),
      ),
    );
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
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
                  Text('Request Details',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Picker: ${request['pickerName']}'),
                  Text('Contact: ${request['pickerContact']}'),
                  Text('Location: ${request['location']}'),
                  Text('Status: ${request['status']}'),
                  Text('Created: ${_formatDate(request['timestamp'])}'),
                  SizedBox(height: 16),
                  Text('Items:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ..._buildItemsList(request['items']),
                  if (request['note'] != null &&
                      request['note'].isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text('Note:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(request['note']),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildItemsList(List<dynamic> items) {
    return items.map((item) {
      if (item['isPipe'] == true) {
        return ListTile(
          title: Text(item['name']),
          subtitle: Text('${item['pcs']} pcs, ${item['meters']} meters'),
        );
      } else {
        return ListTile(
          title: Text(item['name']),
          subtitle: Text('${item['quantity']} ${item['unit']}'),
        );
      }
    }).toList();
  }

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

  String _formatItems(List<dynamic> items) {
    return items.map((item) {
      if (item['isPipe'] == true) {
        return '${item['name']}: ${item['pcs']} pcs, ${item['meters']} m';
      } else {
        return '${item['name']}: ${item['quantity']} ${item['unit']}';
      }
    }).join(', ');
  }
}
