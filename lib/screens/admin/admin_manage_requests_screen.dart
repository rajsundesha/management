import 'dart:async';
import 'package:dhavla_road_project/providers/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_admin_request_bottom_sheet.dart';

class AdminManageRequestsScreen extends StatefulWidget {
  @override
  _AdminManageRequestsScreenState createState() =>
      _AdminManageRequestsScreenState();
}

class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';
  String _filterLocation = 'All';
  DateTimeRange? _dateRange;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  List<String> _creators = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRequests();
      Provider.of<LocationProvider>(context, listen: false).fetchLocations();
      _fetchCreators();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreRequests();
    }
  }

  Future<void> _fetchCreators() async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    _creators = await requestProvider.getUniqueCreators();
    setState(() {});
  }

  Future<void> _initializeRequests() async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.currentUserEmail;
    final userRole = await authProvider.getUserRole();

    if (userEmail != null && userRole != null) {
      await requestProvider.refreshRequests(userEmail, userRole);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: User not authenticated or role not found')),
      );
    }
  }

  Future<void> _loadMoreRequests() async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.currentUserEmail;
    final userRole = await authProvider.getUserRole();

    if (userEmail != null && userRole != null) {
      await requestProvider.loadMoreRequests(userEmail, userRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<RequestProvider>(
              builder: (context, requestProvider, child) {
                if (requestProvider.isLoading &&
                    requestProvider.requests.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                } else if (requestProvider.requests.isEmpty) {
                  return Center(child: Text('No requests found'));
                } else {
                  return _buildRequestList(requestProvider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void shareRequestDetails(Map<String, dynamic> request) {
    String shareText = '''
Request Details:
Created by: ${request['createdByName']}
Date: ${DateFormat('yyyy-MM-dd HH:mm').format(request['timestamp'])}
Location: ${request['location']}
Picker: ${request['pickerName']}
Contact: ${request['pickerContact']}
Items: ${_formatItems(request['items'])}
Note: ${request['note']}
  ''';

    Share.share(shareText, subject: 'Request Details');
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

  Widget _buildFilterBar() {
    final locationProvider = Provider.of<LocationProvider>(context);
    List<String> locations = ['All', ...locationProvider.locations];

    return Container(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showCreatorList(),
            child: AbsorbPointer(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Creator',
                  suffixIcon: IconButton(
                    icon: Icon(_searchController.text.isEmpty
                        ? Icons.search
                        : Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildDropdown(
                      'Status',
                      _filterStatus,
                      ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected'],
                      (value) => setState(() => _filterStatus = value))),
              SizedBox(width: 8),
              Expanded(
                  child: _buildDropdown('Location', _filterLocation, locations,
                      (value) => setState(() => _filterLocation = value))),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon:
                      Icon(_dateRange == null ? Icons.date_range : Icons.clear),
                  label: Text(_dateRange == null
                      ? 'Select Date Range'
                      : 'Clear Date Range'),
                  onPressed: () => _selectDateRange(),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.filter_list),
                label: Text('Advanced Filters'),
                onPressed: () => _showAdvancedFilters(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreatorList() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Creator"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount:
                  _creators.length + 1, // +1 for the "Clear Selection" option
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return ListTile(
                    title: Text("Clear Selection",
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                      });
                      Navigator.of(context).pop();
                    },
                  );
                }
                return ListTile(
                  title: Text(_creators[index - 1]),
                  onTap: () {
                    setState(() {
                      _searchController.text = _creators[index - 1];
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {});
    });
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (newValue) => onChanged(newValue!),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    } else if (_dateRange != null) {
      setState(() => _dateRange = null);
    }
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AdvancedFiltersBottomSheet(
        onApply: (filters) {
          setState(() {
            _filterStatus = filters['status'] ?? _filterStatus;
            _filterLocation = filters['location'] ?? _filterLocation;
            _dateRange = filters['dateRange'];
          });
        },
      ),
    );
  }

  Widget _buildRequestList(RequestProvider requestProvider) {
    final filteredRequests = requestProvider.getFilteredRequests(
      searchQuery: _searchController.text,
      status: _filterStatus,
      location: _filterLocation,
      dateRange: _dateRange,
    );

    return ListView.builder(
      controller: _scrollController,
      itemCount: filteredRequests.length + 1,
      itemBuilder: (context, index) {
        if (index < filteredRequests.length) {
          return _buildRequestCard(filteredRequests[index]);
        } else if (requestProvider.hasMore) {
          _loadMoreRequests();
          return Center(child: CircularProgressIndicator());
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestDate = request['timestamp'] as DateTime;
    final statusColor = _getStatusColor(request['status']);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        title:
            Text('Request by: ${request['createdByName'] ?? 'Unknown User'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${_capitalize(request['status'])}',
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            Text(
                'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(requestDate)}'),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(Icons.assignment, color: Colors.white),
        ),
        trailing: IconButton(
          icon: Icon(Icons.share),
          onPressed: () => shareRequestDetails(request),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Picker', request['pickerName']),
                _buildInfoRow('Location', request['location']),
                _buildInfoRow('Contact', request['pickerContact']),
                _buildInfoRow('Items', _formatItems(request['items'])),
                _buildInfoRow('Note', request['note']),
                _buildInfoRow('Unique Code', request['uniqueCode']),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildActionButtons(context, request),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Widget _buildRequestCard(Map<String, dynamic> request) {
  //   final requestDate = request['timestamp'] as DateTime;
  //   final statusColor = _getStatusColor(request['status']);

  //   return Card(
  //     margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  //     child: ExpansionTile(
  //       title:
  //           Text('Request by: ${request['createdByName'] ?? 'Unknown User'}'),
  //       subtitle: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('Status: ${_capitalize(request['status'])}',
  //               style:
  //                   TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
  //           Text(
  //               'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(requestDate)}'),
  //         ],
  //       ),
  //       leading: CircleAvatar(
  //         backgroundColor: statusColor,
  //         child: Icon(Icons.assignment, color: Colors.white),
  //       ),
  //       children: [
  //         Padding(
  //           padding: EdgeInsets.all(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               _buildInfoRow('Picker', request['pickerName']),
  //               _buildInfoRow('Location', request['location']),
  //               _buildInfoRow('Contact', request['pickerContact']),
  //               _buildInfoRow('Items', _formatItems(request['items'])),
  //               _buildInfoRow('Note', request['note']),
  //               _buildInfoRow('Unique Code', request['uniqueCode']),
  //               SizedBox(height: 16),
  //               Wrap(
  //                 spacing: 8,
  //                 runSpacing: 8,
  //                 children: _buildActionButtons(context, request),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child:
                Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
      BuildContext context, Map<String, dynamic> request) {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    List<Widget> buttons = [];

    if (request['status'] == 'pending') {
      buttons.add(_buildActionButton(
          Icons.check,
          'Approve',
          Colors.green,
          () => _updateRequestStatus(
              requestProvider, request['id'], 'approved')));
      buttons.add(_buildActionButton(
          Icons.close,
          'Reject',
          Colors.red,
          () => _updateRequestStatus(
              requestProvider, request['id'], 'rejected')));
    } else if (request['status'] == 'approved') {
      buttons.add(_buildActionButton(Icons.check_circle, 'Fulfill', Colors.blue,
          () => _showCodeDialog(context, requestProvider, request['id'])));
    }

    buttons.add(_buildActionButton(Icons.edit, 'Edit', Colors.orange,
        () => _editRequest(context, request['id'], request)));
    buttons.add(_buildActionButton(Icons.delete, 'Delete', Colors.red,
        () => _deleteRequest(context, request['id'], inventoryProvider)));

    return buttons;
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _updateRequestStatus(RequestProvider requestProvider,
      String requestId, String newStatus) async {
    try {
      await requestProvider.updateRequestStatus(requestId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request status: $e')),
      );
    }
  }

  void _showCodeDialog(
      BuildContext context, RequestProvider requestProvider, String requestId) {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Unique Code'),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(hintText: 'Unique Code'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Submit'),
            onPressed: () async {
              try {
                final request = await requestProvider.getRequestById(requestId);
                if (request != null &&
                    codeController.text == request['uniqueCode']) {
                  await requestProvider.updateRequestStatus(
                      requestId, 'fulfilled');
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request fulfilled successfully')),
                  );
                } else {
                  throw Exception('Invalid code');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _editRequest(
      BuildContext context, String requestId, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditAdminRequestBottomSheet(
        id: requestId,
        items: List<Map<String, dynamic>>.from(request['items'] ?? []),
        location: request['location'] ?? 'Default Location',
        pickerName: request['pickerName'] ?? '',
        pickerContact: request['pickerContact'] ?? '',
        note: request['note'] ?? '',
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context, String requestId,
      InventoryProvider inventoryProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false)),
          ElevatedButton(
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<RequestProvider>(context, listen: false)
            .deleteRequest(requestId, inventoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request deleted successfully')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting request: $e')));
      }
    }
  }

  String _capitalize(String text) =>
      text.isNotEmpty ? '${text[0].toUpperCase()}${text.substring(1)}' : '';

  // String _formatItems(List<dynamic> items) {
  //   return items.map((item) {
  //     final name = item['name'] ?? 'Unknown Item';
  //     final isPipe = item['isPipe'] ?? false;
  //     if (isPipe) {
  //       final pcs = item['pcs'] ?? 0;
  //       final meters = item['meters'] ?? 0.0;
  //       return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
  //     } else {
  //       final quantity = item['quantity'] ?? 0;
  //       final unit = item['unit'] ?? 'pcs';
  //       return '$quantity x $name ($unit)';
  //     }
  //   }).join(', ');
  // }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'fulfilled':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class AdvancedFiltersBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onApply;

  AdvancedFiltersBottomSheet({required this.onApply});

  @override
  _AdvancedFiltersBottomSheetState createState() =>
      _AdvancedFiltersBottomSheetState();
}

class _AdvancedFiltersBottomSheetState
    extends State<AdvancedFiltersBottomSheet> {
  String _selectedStatus = 'All';
  String _selectedLocation = 'All';
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    List<String> locations = ['All', ...locationProvider.locations];

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Advanced Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Status'),
            value: _selectedStatus,
            items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
                .map((status) =>
                    DropdownMenuItem(value: status, child: Text(status)))
                .toList(),
            onChanged: (value) => setState(() => _selectedStatus = value!),
          ),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Location'),
            value: _selectedLocation,
            items: locations
                .map((location) =>
                    DropdownMenuItem(value: location, child: Text(location)))
                .toList(),
            onChanged: (value) => setState(() => _selectedLocation = value!),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            child: Text(_selectedDateRange == null
                ? 'Select Date Range'
                : 'Clear Date Range'),
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _selectedDateRange,
              );
              setState(() => _selectedDateRange = picked ?? _selectedDateRange);
            },
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Date Range: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          SizedBox(height: 24),
          ElevatedButton(
            child: Text('Apply Filters'),
            onPressed: () {
              widget.onApply({
                'status': _selectedStatus,
                'location': _selectedLocation,
                'dateRange': _selectedDateRange,
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class AdminManageRequestsScreen extends StatefulWidget {
//   @override
//   _AdminManageRequestsScreenState createState() => _AdminManageRequestsScreenState();
// }

// class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _filterStatus = 'All';
//   String _filterLocation = 'All';
//   DateTimeRange? _dateRange;
//   final List<String> _locations = ['All', 'Location1', 'Location2', 'Location3'];
//   final ScrollController _scrollController = ScrollController();
//   bool _isLoadingMore = false;

//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(_onScroll);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initializeRequests();
//     });
//   }

//   @override
//   void dispose() {
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _onScroll() {
//     if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
//       _loadMoreRequests();
//     }
//   }

//   Future<void> _initializeRequests() async {
//     final requestProvider = Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final userEmail = authProvider.currentUserEmail;
//     final userRole = await authProvider.getUserRole();

//     if (userEmail != null && userRole != null) {
//       await requestProvider.refreshRequests(userEmail, userRole);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: User not authenticated')),
//       );
//     }
//   }

//   Future<void> _loadMoreRequests() async {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final userEmail = authProvider.currentUserEmail;
//     final userRole = await authProvider.getUserRole();

//     if (userEmail != null && userRole != null) {
//       await requestProvider.loadMoreRequests(userEmail, userRole);
//     }
//   }
//   // Future<void> _loadMoreRequests() async {
//   //   if (!_isLoadingMore) {
//   //     setState(() {
//   //       _isLoadingMore = true;
//   //     });
//   //     final requestProvider = Provider.of<RequestProvider>(context, listen: false);
//   //     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//   //     final userEmail = authProvider.currentUserEmail;
//   //     final userRole = await authProvider.getUserRole();

//   //     if (userEmail != null && userRole != null) {
//   //       await requestProvider.loadMoreRequests(userEmail, userRole);
//   //     }
//   //     setState(() {
//   //       _isLoadingMore = false;
//   //     });
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _initializeRequests,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildFilterBar(),
//           Expanded(
//             child: Consumer<RequestProvider>(
//               builder: (context, requestProvider, child) {
//                 if (requestProvider.isLoading && requestProvider.requests.isEmpty) {
//                   return Center(child: CircularProgressIndicator());
//                 } else if (requestProvider.requests.isEmpty) {
//                   return Center(child: Text('No requests found'));
//                 } else {
//                   return _buildRequestList(requestProvider);
//                 }
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterBar() {
//     return Container(
//       padding: EdgeInsets.all(8),
//       child: Column(
//         children: [
//           TextField(
//             controller: _searchController,
//             decoration: InputDecoration(
//               labelText: 'Search by Creator',
//               suffixIcon: Icon(Icons.search),
//             ),
//             onChanged: (value) => setState(() {}),
//           ),
//           SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(child: _buildDropdown('Status', _filterStatus, ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected'], (value) => setState(() => _filterStatus = value))),
//               SizedBox(width: 8),
//               Expanded(child: _buildDropdown('Location', _filterLocation, _locations, (value) => setState(() => _filterLocation = value))),
//             ],
//           ),
//           SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   icon: Icon(_dateRange == null ? Icons.date_range : Icons.clear),
//                   label: Text(_dateRange == null ? 'Select Date Range' : 'Clear Date Range'),
//                   onPressed: () => _selectDateRange(),
//                 ),
//               ),
//               SizedBox(width: 8),
//               ElevatedButton.icon(
//                 icon: Icon(Icons.filter_list),
//                 label: Text('Advanced Filters'),
//                 onPressed: () => _showAdvancedFilters(),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDropdown(String label, String value, List<String> items, Function(String) onChanged) {
//     return DropdownButtonFormField<String>(
//       decoration: InputDecoration(labelText: label),
//       value: value,
//       items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
//       onChanged: (newValue) => onChanged(newValue!),
//     );
//   }

//   Future<void> _selectDateRange() async {
//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       initialDateRange: _dateRange,
//     );
//     if (picked != null) {
//       setState(() => _dateRange = picked);
//     } else if (_dateRange != null) {
//       setState(() => _dateRange = null);
//     }
//   }

//   void _showAdvancedFilters() {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => AdvancedFiltersBottomSheet(
//         onApply: (filters) {
//           setState(() {
//             // Update filter state based on advanced filters
//             _filterStatus = filters['status'] ?? _filterStatus;
//             _filterLocation = filters['location'] ?? _filterLocation;
//             _dateRange = filters['dateRange'];
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildRequestList(RequestProvider requestProvider) {
//     final filteredRequests = requestProvider.getFilteredRequests(
//       searchQuery: _searchController.text,
//       status: _filterStatus,
//       location: _filterLocation,
//       dateRange: _dateRange,
//     );

//     return ListView.builder(
//       controller: _scrollController,
//       itemCount: filteredRequests.length + 1,
//       itemBuilder: (context, index) {
//         if (index < filteredRequests.length) {
//           return _buildRequestCard(filteredRequests[index]);
//         } else if (requestProvider.hasMore) {
//           _loadMoreRequests();
//           return Center(child: CircularProgressIndicator());
//         } else {
//           return SizedBox.shrink();
//         }
//       },
//     );
//   }

//   // Widget _buildRequestList(RequestProvider requestProvider) {
//   //   final filteredRequests = requestProvider.getFilteredRequests(
//   //     searchQuery: _searchController.text,
//   //     status: _filterStatus,
//   //     location: _filterLocation,
//   //     dateRange: _dateRange,
//   //   );

//   //   return ListView.builder(
//   //     controller: _scrollController,
//   //     itemCount: filteredRequests.length + 1,
//   //     itemBuilder: (context, index) {
//   //       if (index < filteredRequests.length) {
//   //         return _buildRequestCard(filteredRequests[index]);
//   //       } else if (index == filteredRequests.length && _isLoadingMore) {
//   //         return Center(child: CircularProgressIndicator());
//   //       } else {
//   //         return SizedBox.shrink();
//   //       }
//   //     },
//   //   );
//   // }

//   Widget _buildRequestCard(Map<String, dynamic> request) {
//     final requestDate = request['timestamp'] as DateTime;
//     final statusColor = _getStatusColor(request['status']);

//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ExpansionTile(
//         title: Text('Request by: ${request['createdByName'] ?? 'Unknown User'}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Status: ${_capitalize(request['status'])}',
//                 style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
//             Text('Created: ${DateFormat('yyyy-MM-dd HH:mm').format(requestDate)}'),
//           ],
//         ),
//         leading: CircleAvatar(
//           backgroundColor: statusColor,
//           child: Icon(Icons.assignment, color: Colors.white),
//         ),
//         children: [
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildInfoRow('Picker', request['pickerName']),
//                 _buildInfoRow('Location', request['location']),
//                 _buildInfoRow('Contact', request['pickerContact']),
//                 _buildInfoRow('Items', _formatItems(request['items'])),
//                 _buildInfoRow('Note', request['note']),
//                 _buildInfoRow('Unique Code', request['uniqueCode']),
//                 SizedBox(height: 16),
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: _buildActionButtons(context, request),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String? value) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
//           ),
//           Expanded(child: Text(value ?? 'N/A')),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildActionButtons(BuildContext context, Map<String, dynamic> request) {
//     final requestProvider = Provider.of<RequestProvider>(context, listen: false);
//     final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
//     List<Widget> buttons = [];

//     if (request['status'] == 'pending') {
//       buttons.add(_buildActionButton(Icons.check, 'Approve', Colors.green, () => _updateRequestStatus(requestProvider, request['id'], 'approved')));
//       buttons.add(_buildActionButton(Icons.close, 'Reject', Colors.red, () => _updateRequestStatus(requestProvider, request['id'], 'rejected')));
//     } else if (request['status'] == 'approved') {
//       buttons.add(_buildActionButton(Icons.check_circle, 'Fulfill', Colors.blue, () => _showCodeDialog(context, requestProvider, request['id'])));
//     }

//     buttons.add(_buildActionButton(Icons.edit, 'Edit', Colors.orange, () => _editRequest(context, request['id'], request)));
//     buttons.add(_buildActionButton(Icons.delete, 'Delete', Colors.red, () => _deleteRequest(context, request['id'], inventoryProvider)));

//     return buttons;
//   }

//   Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
//     return ElevatedButton.icon(
//       icon: Icon(icon, color: Colors.white, size: 18),
//       label: Text(label, style: TextStyle(fontSize: 12)),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       ),
//       onPressed: onPressed,
//     );
//   }

//   Future<void> _updateRequestStatus(RequestProvider requestProvider, String requestId, String newStatus) async {
//     try {
//       await requestProvider.updateRequestStatus(requestId, newStatus);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request status updated to $newStatus')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request status: $e')),
//       );
//     }
//   }

//   void _showCodeDialog(BuildContext context, RequestProvider requestProvider, String requestId) {
//     final TextEditingController codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Unique Code'),
//         content: TextField(
//           controller: codeController,
//           decoration: InputDecoration(hintText: 'Unique Code'),
//         ),
//         actions: [
//           TextButton(
//             child: Text('Cancel'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           ElevatedButton(
//             child: Text('Submit'),
//             onPressed: () async {
//               try {
//                 final request = await requestProvider.getRequestById(requestId);
//                 if (request != null && codeController.text == request['uniqueCode']) {
//                   await requestProvider.updateRequestStatus(requestId, 'fulfilled');
//                   Navigator.of(context).pop();
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Request fulfilled successfully')),
//                   );
//                 } else {
//                   throw Exception('Invalid code');
//                 }
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Error: ${e.toString()}')),
//                 );
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _editRequest(BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
//         items: List<Map<String, dynamic>>.from(request['items'] ?? []),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String requestId, InventoryProvider inventoryProvider) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Confirm Delete'),
//         content: Text('Are you sure you want to delete this request?'),
//         actions: [
//           TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
//           ElevatedButton(
//             child: Text('Delete'),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.of(context).pop(true),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       try {
//         await Provider.of<RequestProvider>(context, listen: false).deleteRequest(requestId, inventoryProvider);
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request deleted successfully')));
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting request: $e')));
//       }
//     }
//   }

//   String _capitalize(String text) => text.isNotEmpty ? '${text[0].toUpperCase()}${text.substring(1)}' : '';
// String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final name = item['name'] ?? 'Unknown Item';
//       final isPipe = item['isPipe'] ?? false;
//       if (isPipe) {
//         final pcs = item['pcs'] ?? 0;
//         final meters = item['meters'] ?? 0.0;
//         return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
//       } else {
//         final quantity = item['quantity'] ?? 0;
//         final unit = item['unit'] ?? 'pcs';
//         return '$quantity x $name ($unit)';
//       }
//     }).join(', ');
//   }

//   Color _getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'pending':
//         return Colors.orange;
//       case 'approved':
//         return Colors.blue;
//       case 'fulfilled':
//         return Colors.green;
//       case 'rejected':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
// }

// class AdvancedFiltersBottomSheet extends StatefulWidget {
//   final Function(Map<String, dynamic>) onApply;

//   AdvancedFiltersBottomSheet({required this.onApply});

//   @override
//   _AdvancedFiltersBottomSheetState createState() =>
//       _AdvancedFiltersBottomSheetState();
// }

// class _AdvancedFiltersBottomSheetState
//     extends State<AdvancedFiltersBottomSheet> {
//   String _selectedStatus = 'All';
//   String _selectedLocation = 'All';
//   DateTimeRange? _selectedDateRange;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Advanced Filters',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           SizedBox(height: 16),
//           DropdownButtonFormField<String>(
//             decoration: InputDecoration(labelText: 'Status'),
//             value: _selectedStatus,
//             items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
//                 .map((status) =>
//                     DropdownMenuItem(value: status, child: Text(status)))
//                 .toList(),
//             onChanged: (value) => setState(() => _selectedStatus = value!),
//           ),
//           SizedBox(height: 8),
//           DropdownButtonFormField<String>(
//             decoration: InputDecoration(labelText: 'Location'),
//             value: _selectedLocation,
//             items: ['All', 'Location1', 'Location2', 'Location3']
//                 .map((location) =>
//                     DropdownMenuItem(value: location, child: Text(location)))
//                 .toList(),
//             onChanged: (value) => setState(() => _selectedLocation = value!),
//           ),
//           SizedBox(height: 16),
//           ElevatedButton(
//             child: Text(_selectedDateRange == null
//                 ? 'Select Date Range'
//                 : 'Clear Date Range'),
//             onPressed: () async {
//               final DateTimeRange? picked = await showDateRangePicker(
//                 context: context,
//                 firstDate: DateTime(2020),
//                 lastDate: DateTime.now(),
//                 initialDateRange: _selectedDateRange,
//               );
//               setState(() => _selectedDateRange = picked ?? _selectedDateRange);
//             },
//           ),
//           if (_selectedDateRange != null)
//             Padding(
//               padding: const EdgeInsets.only(top: 8.0),
//               child: Text(
//                 'Date Range: ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//             ),
//           SizedBox(height: 24),
//           ElevatedButton(
//             child: Text('Apply Filters'),
//             onPressed: () {
//               widget.onApply({
//                 'status': _selectedStatus,
//                 'location': _selectedLocation,
//                 'dateRange': _selectedDateRange,
//               });
//               Navigator.pop(context);
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart'; // Added import for InventoryProvider
// import 'edit_admin_request_bottom_sheet.dart';

// class AdminManageRequestsScreen extends StatefulWidget {
//   @override
//   _AdminManageRequestsScreenState createState() =>
//       _AdminManageRequestsScreenState();
// }

// class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
//   String _searchQuery = '';
//   String _filterStatus = 'All';
//   String _filterLocation = 'All';
//   DateTimeRange? _dateRange;
//   final List<String> _locations = [
//     'All',
//     'Location1',
//     'Location2',
//     'Location3'
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildSearchBar(),
//             SizedBox(height: 16),
//             _buildFilterRow(),
//             SizedBox(height: 16),
//             Expanded(
//               child: StreamBuilder<List<Map<String, dynamic>>>(
//                 stream: Provider.of<RequestProvider>(context, listen: false)
//                     .getRequestsStream('admin@example.com', 'Admin', 'All'),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return Center(child: CircularProgressIndicator());
//                   }
//                   if (snapshot.hasError) {
//                     return Center(child: Text('Error: ${snapshot.error}'));
//                   }
//                   final allRequests = snapshot.data ?? [];
//                   print("Total unfiltered requests: ${allRequests.length}");

//                   final requests = allRequests.where((request) {
//                     final requestDate = request['timestamp'] is Timestamp
//                         ? request['timestamp']
//                             .toDate() // Convert Timestamp to DateTime
//                         : null;
//                     final matchesDate = _dateRange == null ||
//                         (requestDate != null &&
//                             requestDate.isAfter(_dateRange!.start) &&
//                             requestDate.isBefore(
//                                 _dateRange!.end.add(Duration(days: 1))));
//                     final matchesSearch = (request['createdBy'] as String?)
//                             ?.toLowerCase()
//                             .contains(_searchQuery.toLowerCase()) ??
//                         false;
//                     final matchesFilter = _filterStatus == 'All' ||
//                             (request['status'] as String?)!
//                                 .toLowerCase()
//                                 .contains(_filterStatus.toLowerCase()) ??
//                         false;
//                     final matchesLocation = _filterLocation == 'All' ||
//                         request['location'] == _filterLocation;

//                     final matchesAll = matchesDate &&
//                         matchesSearch &&
//                         matchesFilter &&
//                         matchesLocation;
//                     print(
//                         "Request ${request['id']} matches filters: $matchesAll");
//                     return matchesAll;
//                   }).toList();
//                   print("Filtered requests: ${requests.length}");

//                   if (requests.isEmpty) {
//                     return Center(child: Text('No requests found.'));
//                   }

//                   return ListView.builder(
//                     itemCount: requests.length,
//                     itemBuilder: (context, index) {
//                       final request = requests[index];
//                       final requestDate = request['timestamp'] is Timestamp
//                           ? request['timestamp']
//                               .toDate() // Convert Timestamp to DateTime
//                           : null;

//                       return Card(
//                         child: ExpansionTile(
//                           title: Text(
//                             'Request by: ${request['createdByName'] ?? request['createdByEmail'] ?? 'Unknown User'}',
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold, fontSize: 16),
//                           ),
//                           subtitle: Text(
//                             'Created on: ${requestDate != null ? DateFormat('yyyy-MM-dd').format(requestDate) : 'N/A'} at ${requestDate != null ? DateFormat('hh:mm a').format(requestDate) : 'N/A'}\n'
//                             'Status: ${_capitalize((request['status'] ?? 'N/A').toString())}',
//                           ),
//                           leading: Icon(
//                             Icons.request_page,
//                             color: request['status'] == 'pending'
//                                 ? Colors.orange
//                                 : request['status'] == 'approved'
//                                     ? Colors.blue
//                                     : request['status'] == 'fulfilled'
//                                         ? Colors.green
//                                         : Colors.red,
//                           ),
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   _buildInfoRow('Picker:',
//                                       request['pickerName'] ?? 'N/A'),
//                                   _buildInfoRow('Location:',
//                                       request['location'] ?? 'N/A'),
//                                   _buildInfoRow('Contact:',
//                                       request['pickerContact'] ?? 'N/A'),
//                                   _buildInfoRow(
//                                       'Items:',
//                                       (request['items'] as List<dynamic>?)
//                                               ?.map((item) => _formatItem(item))
//                                               .join(', ') ??
//                                           'No items'),
//                                   _buildInfoRow(
//                                       'Note:', request['note'] ?? 'N/A'),
//                                   _buildInfoRow('Unique Code:',
//                                       request['uniqueCode'] ?? 'N/A'),
//                                   SizedBox(height: 16),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.end,
//                                     children:
//                                         _buildActionButtons(context, request),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search by Creator',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildFilterRow() {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(child: _buildFilterDropdown()),
//             SizedBox(width: 16),
//             Expanded(child: _buildLocationFilterDropdown()),
//           ],
//         ),
//         SizedBox(height: 16),
//         Row(
//           children: [
//             Expanded(
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final selectedRange = await showDateRangePicker(
//                     context: context,
//                     firstDate: DateTime(2020),
//                     lastDate: DateTime.now(),
//                   );
//                   if (selectedRange != null) {
//                     setState(() {
//                       _dateRange = DateTimeRange(
//                         start: DateTime(selectedRange.start.year,
//                             selectedRange.start.month, selectedRange.start.day),
//                         end: DateTime(
//                             selectedRange.end.year,
//                             selectedRange.end.month,
//                             selectedRange.end.day,
//                             23,
//                             59,
//                             59),
//                       );
//                     });
//                   }
//                 },
//                 child: Text('Select Date Range'),
//               ),
//             ),
//             if (_dateRange != null)
//               IconButton(
//                 icon: Icon(Icons.clear),
//                 onPressed: () {
//                   setState(() {
//                     _dateRange = null;
//                   });
//                 },
//               ),
//           ],
//         ),
//         if (_dateRange != null)
//           Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Text(
//               'Selected Range: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
//               style: TextStyle(fontSize: 16),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildFilterDropdown() {
//     return InputDecorator(
//       decoration: InputDecoration(
//         labelText: 'Filter by Status',
//         border: OutlineInputBorder(),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: _filterStatus,
//           onChanged: (newValue) {
//             setState(() {
//               _filterStatus = newValue!;
//             });
//           },
//           items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
//               .map<DropdownMenuItem<String>>((String value) {
//             return DropdownMenuItem<String>(
//               value: value,
//               child: Text(_capitalize(value)),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildLocationFilterDropdown() {
//     return InputDecorator(
//       decoration: InputDecoration(
//         labelText: 'Filter by Location',
//         border: OutlineInputBorder(),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: _filterLocation,
//           onChanged: (newValue) {
//             setState(() {
//               _filterLocation = newValue!;
//             });
//           },
//           items: _locations.map<DropdownMenuItem<String>>((String value) {
//             return DropdownMenuItem<String>(
//               value: value,
//               child: Text(value),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: Row(
//         children: [
//           Text(
//             '$label ',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildActionButtons(
//       BuildContext context, Map<String, dynamic> request) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     List<Widget> buttons = [];

//     if (request['status'] == 'pending') {
//       buttons.add(_buildActionButton(
//         Icons.check,
//         'Approve',
//         Colors.green,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'approved');
//         },
//       ));
//       buttons.add(SizedBox(width: 8));
//       buttons.add(_buildActionButton(
//         Icons.close,
//         'Reject',
//         Colors.red,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'rejected');
//         },
//       ));
//     } else if (request['status'] == 'approved') {
//       buttons.add(_buildActionButton(
//         Icons.check_circle,
//         'Fulfill',
//         Colors.blue,
//         () {
//           _showCodeDialog(context, requestProvider, request['id']);
//         },
//       ));
//       buttons.add(SizedBox(width: 8));
//       buttons.add(_buildActionButton(
//         Icons.close,
//         'Reject',
//         Colors.red,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'rejected');
//         },
//       ));
//     } else if (request['status'] == 'rejected') {
//       buttons.add(_buildActionButton(
//         Icons.check,
//         'Approve',
//         Colors.green,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'approved');
//         },
//       ));
//     }

//     buttons.add(SizedBox(width: 8));
//     buttons.add(_buildActionButton(
//       Icons.edit,
//       'Edit',
//       Colors.blue,
//       () {
//         _editRequest(context, request['id'], request);
//       },
//     ));

//     buttons.add(SizedBox(width: 8));
//     buttons.add(_buildActionButton(
//       Icons.delete,
//       'Delete',
//       Colors.red,
//       () async {
//         await _deleteRequest(context, request['id'],
//             inventoryProvider); // Pass inventoryProvider
//       },
//     ));

//     return buttons;
//   }

//   void _showCodeDialog(
//       BuildContext context, RequestProvider requestProvider, String requestId) {
//     TextEditingController codeController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Enter Unique Code'),
//           content: TextField(
//             controller: codeController,
//             decoration: InputDecoration(hintText: 'Unique Code'),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 final request = await requestProvider.getRequestById(requestId);
//                 if (request != null &&
//                     codeController.text == request['uniqueCode']) {
//                   await requestProvider.updateRequestStatus(
//                       requestId, 'fulfilled');
//                   Navigator.of(context).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Invalid code!')),
//                   );
//                 }
//               },
//               child: Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildActionButton(
//       IconData icon, String label, Color color, VoidCallback onPressed) {
//     return Flexible(
//       child: ElevatedButton.icon(
//         icon: Icon(icon, color: Colors.white),
//         label: Text(label),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//         ),
//         onPressed: onPressed,
//       ),
//     );
//   }

//   void _editRequest(
//       BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
//         items: List<Map<String, dynamic>>.from(request['items'] ?? []),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String requestId,
//       InventoryProvider inventoryProvider) async {
//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .deleteRequest(requestId, inventoryProvider); // Correct arguments
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       print("Error deleting request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }

//   String _capitalize(String text) {
//     return text.isNotEmpty
//         ? '${text[0].toUpperCase()}${text.substring(1)}'
//         : '';
//   }

//   // New method to format individual items with pieces and meters
//   String _formatItem(Map<String, dynamic> item) {
//     final name = item['name'] ?? 'Unknown Item';
//     final isPipe = item['isPipe'] ?? false;
//     if (isPipe) {
//       final pcs = item['pcs'] ?? 0;
//       final meters = item['meters'] ?? 0.0;
//       return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
//     } else {
//       final quantity = item['quantity'] ?? 0;
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class AdminManageRequestsScreen extends StatefulWidget {
//   @override
//   _AdminManageRequestsScreenState createState() =>
//       _AdminManageRequestsScreenState();
// }

// class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
//   String _searchQuery = '';
//   String _filterStatus = 'All';
//   String _filterLocation = 'All';
//   DateTimeRange? _dateRange;
//   final List<String> _locations = [
//     'All',
//     'Location1',
//     'Location2',
//     'Location3'
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildSearchBar(),
//             SizedBox(height: 16),
//             _buildFilterRow(),
//             SizedBox(height: 16),
//             Expanded(
//               child: StreamBuilder<List<Map<String, dynamic>>>(
//                 stream: Provider.of<RequestProvider>(context, listen: false)
//                     .getRequestsStream('admin@example.com', 'Admin', 'All'),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return Center(child: CircularProgressIndicator());
//                   }
//                   if (snapshot.hasError) {
//                     return Center(child: Text('Error: ${snapshot.error}'));
//                   }
//                   final allRequests = snapshot.data ?? [];
//                   print("Total unfiltered requests: ${allRequests.length}");

//                   final requests = allRequests.where((request) {
//                     final requestDate = request['timestamp'] as DateTime?;
//                     final matchesDate = _dateRange == null ||
//                         (requestDate != null &&
//                             requestDate.isAfter(_dateRange!.start) &&
//                             requestDate.isBefore(
//                                 _dateRange!.end.add(Duration(days: 1))));
//                     final matchesSearch = (request['createdBy'] as String?)
//                             ?.toLowerCase()
//                             .contains(_searchQuery.toLowerCase()) ??
//                         false;
//                     final matchesFilter = _filterStatus == 'All' ||
//                             (request['status'] as String?)!
//                                 .toLowerCase()
//                                 .contains(_filterStatus.toLowerCase()) ??
//                         false;
//                     final matchesLocation = _filterLocation == 'All' ||
//                         request['location'] == _filterLocation;

//                     final matchesAll = matchesDate &&
//                         matchesSearch &&
//                         matchesFilter &&
//                         matchesLocation;
//                     print(
//                         "Request ${request['id']} matches filters: $matchesAll");
//                     return matchesAll;
//                   }).toList();
//                   print("Filtered requests: ${requests.length}");

//                   if (requests.isEmpty) {
//                     return Center(child: Text('No requests found.'));
//                   }

//                   return ListView.builder(
//                     itemCount: requests.length,
//                     itemBuilder: (context, index) {
//                       final request = requests[index];
//                       final requestDate = request['timestamp'] as DateTime?;

//                       // return Card(
//                       //   child: ExpansionTile(
//                       //     title: Text(
//                       //       'Request by: ${request['createdBy'] ?? 'N/A'}',
//                       //       style: TextStyle(
//                       //           fontWeight: FontWeight.bold, fontSize: 16),
//                       //     ),
//                       //     subtitle: Text(
//                       //       'Created on: ${requestDate != null ? DateFormat('yyyy-MM-dd').format(requestDate) : 'N/A'} at ${requestDate != null ? DateFormat('hh:mm a').format(requestDate) : 'N/A'}\n'
//                       //       'Status: ${_capitalize((request['status'] ?? 'N/A').toString())}',
//                       //     ),
//                       return Card(
//                         child: ExpansionTile(
//                           title: Text(
//                             'Request by: ${request['createdByName'] ?? request['createdByEmail'] ?? 'Unknown User'}',
//                             // request['name'] != null &&
//                             //         request['name'].isNotEmpty
//                             //     ? request['name']
//                             //     : 'Request #${index + 1}',
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold, fontSize: 16),
//                           ),
//                           subtitle: Text(
//                             // 'Created by: ${request['createdBy'] ?? 'N/A'}\n'
//                             'Created on: ${requestDate != null ? DateFormat('yyyy-MM-dd').format(requestDate) : 'N/A'} at ${requestDate != null ? DateFormat('hh:mm a').format(requestDate) : 'N/A'}\n'
//                             'Status: ${_capitalize((request['status'] ?? 'N/A').toString())}',
//                           ),
//                           leading: Icon(
//                             Icons.request_page,
//                             color: request['status'] == 'pending'
//                                 ? Colors.orange
//                                 : request['status'] == 'approved'
//                                     ? Colors.blue
//                                     : request['status'] == 'fulfilled'
//                                         ? Colors.green
//                                         : Colors.red,
//                           ),
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   _buildInfoRow('Picker:',
//                                       request['pickerName'] ?? 'N/A'),
//                                   _buildInfoRow('Location:',
//                                       request['location'] ?? 'N/A'),
//                                   _buildInfoRow('Contact:',
//                                       request['pickerContact'] ?? 'N/A'),
//                                   _buildInfoRow(
//                                       'Items:',
//                                       (request['items'] as List<dynamic>?)
//                                               ?.map((item) =>
//                                                   '${item['quantity']} ${item['unit']} x ${item['name']}')
//                                               .join(', ') ??
//                                           'No items'),
//                                   _buildInfoRow(
//                                       'Note:', request['note'] ?? 'N/A'),
//                                   // _buildInfoRow(
//                                   //     'Created By:', request['createdBy']),
//                                   _buildInfoRow('Unique Code:',
//                                       request['uniqueCode'] ?? 'N/A'),
//                                   SizedBox(height: 16),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.end,
//                                     children:
//                                         _buildActionButtons(context, request),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search by Creator',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildFilterRow() {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(child: _buildFilterDropdown()),
//             SizedBox(width: 16),
//             Expanded(child: _buildLocationFilterDropdown()),
//           ],
//         ),
//         SizedBox(height: 16),
//         Row(
//           children: [
//             Expanded(
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final selectedRange = await showDateRangePicker(
//                     context: context,
//                     firstDate: DateTime(2020),
//                     lastDate: DateTime.now(),
//                   );
//                   if (selectedRange != null) {
//                     setState(() {
//                       _dateRange = DateTimeRange(
//                         start: DateTime(selectedRange.start.year,
//                             selectedRange.start.month, selectedRange.start.day),
//                         end: DateTime(
//                             selectedRange.end.year,
//                             selectedRange.end.month,
//                             selectedRange.end.day,
//                             23,
//                             59,
//                             59),
//                       );
//                     });
//                   }
//                 },
//                 child: Text('Select Date Range'),
//               ),
//             ),
//             if (_dateRange != null)
//               IconButton(
//                 icon: Icon(Icons.clear),
//                 onPressed: () {
//                   setState(() {
//                     _dateRange = null;
//                   });
//                 },
//               ),
//           ],
//         ),
//         if (_dateRange != null)
//           Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Text(
//               'Selected Range: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
//               style: TextStyle(fontSize: 16),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildFilterDropdown() {
//     return InputDecorator(
//       decoration: InputDecoration(
//         labelText: 'Filter by Status',
//         border: OutlineInputBorder(),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: _filterStatus,
//           onChanged: (newValue) {
//             setState(() {
//               _filterStatus = newValue!;
//             });
//           },
//           items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
//               .map<DropdownMenuItem<String>>((String value) {
//             return DropdownMenuItem<String>(
//               value: value,
//               child: Text(_capitalize(value)),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildLocationFilterDropdown() {
//     return InputDecorator(
//       decoration: InputDecoration(
//         labelText: 'Filter by Location',
//         border: OutlineInputBorder(),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: _filterLocation,
//           onChanged: (newValue) {
//             setState(() {
//               _filterLocation = newValue!;
//             });
//           },
//           items: _locations.map<DropdownMenuItem<String>>((String value) {
//             return DropdownMenuItem<String>(
//               value: value,
//               child: Text(value),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: Row(
//         children: [
//           Text(
//             '$label ',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildActionButtons(
//       BuildContext context, Map<String, dynamic> request) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     List<Widget> buttons = [];

//     if (request['status'] == 'pending') {
//       buttons.add(_buildActionButton(
//         Icons.check,
//         'Approve',
//         Colors.green,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'approved');
//         },
//       ));
//       buttons.add(SizedBox(width: 8));
//       buttons.add(_buildActionButton(
//         Icons.close,
//         'Reject',
//         Colors.red,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'rejected');
//         },
//       ));
//     } else if (request['status'] == 'approved') {
//       buttons.add(_buildActionButton(
//         Icons.check_circle,
//         'Fulfill',
//         Colors.blue,
//         () {
//           _showCodeDialog(context, requestProvider, request['id']);
//         },
//       ));
//       buttons.add(SizedBox(width: 8));
//       buttons.add(_buildActionButton(
//         Icons.close,
//         'Reject',
//         Colors.red,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'rejected');
//         },
//       ));
//     } else if (request['status'] == 'rejected') {
//       buttons.add(_buildActionButton(
//         Icons.check,
//         'Approve',
//         Colors.green,
//         () {
//           requestProvider.updateRequestStatus(request['id'], 'approved');
//         },
//       ));
//     }

//     buttons.add(SizedBox(width: 8));
//     buttons.add(_buildActionButton(
//       Icons.edit,
//       'Edit',
//       Colors.blue,
//       () {
//         _editRequest(context, request['id'], request);
//       },
//     ));

//     return buttons;
//   }


//   void _showCodeDialog(
//       BuildContext context, RequestProvider requestProvider, String requestId) {
//     TextEditingController codeController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Enter Unique Code'),
//           content: TextField(
//             controller: codeController,
//             decoration: InputDecoration(hintText: 'Unique Code'),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 final request = await requestProvider.getRequestById(requestId);
//                 if (request != null &&
//                     codeController.text == request['uniqueCode']) {
//                   await requestProvider.updateRequestStatus(
//                       requestId, 'fulfilled');
//                   Navigator.of(context).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Invalid code!')),
//                   );
//                 }
//               },
//               child: Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   //     },
//   //   );
//   // }

//   Widget _buildActionButton(
//       IconData icon, String label, Color color, VoidCallback onPressed) {
//     return Flexible(
//       child: ElevatedButton.icon(
//         icon: Icon(icon, color: Colors.white),
//         label: Text(label),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//         ),
//         onPressed: onPressed,
//       ),
//     );
//   }

//   void _editRequest(
//       BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
//         items: List<Map<String, dynamic>>.from(request['items'] ?? []),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   String _capitalize(String text) {
//     return text.isNotEmpty
//         ? '${text[0].toUpperCase()}${text.substring(1)}'
//         : '';
//   }
// }
