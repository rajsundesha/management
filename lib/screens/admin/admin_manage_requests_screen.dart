import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
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
  List<Map<String, String>> _creators = [];
  Map<String, Map<String, String>> _userCache = {};

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

  // Future<void> _fetchCreators() async {
  //   try {
  //     QuerySnapshot userSnapshot =
  //         await FirebaseFirestore.instance.collection('users').get();
  //     _creators = userSnapshot.docs.map((doc) {
  //       Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
  //       String userId = doc.id;
  //       String name = userData['name'] ?? 'Unknown';
  //       String email = userData['email'] ?? 'No Email';
  //       _userCache[userId] = {'name': name, 'email': email};
  //       return {'id': userId, 'name': name, 'email': email};
  //     }).toList();
  //     setState(() {});
  //   } catch (e) {
  //     print("Error fetching creators: $e");
  //   }
  // }

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
                      [
                        'All',
                        'Pending',
                        'Approved',
                        'Partially Fulfilled',
                        'Fulfilled',
                        'Rejected'
                      ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search by name or email",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      // This will trigger a rebuild of the dialog
                    });
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _creators.length + 1,
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
                      Map<String, String> creator = _creators[index - 1];
                      return ListTile(
                        title: Text(creator['name'] ?? 'Unknown'),
                        subtitle: Text(creator['email'] ?? 'No Email'),
                        onTap: () {
                          setState(() {
                            _searchController.text =
                                creator['name'] ?? creator['email'] ?? '';
                          });
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            _dateRange = filters['dateRange'] as DateTimeRange?;
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
    final statusColor = _getStatusColor(request['status'] as String);
    final userId = request['createdBy'] as String;

    return FutureBuilder<Map<String, String>>(
      future: _getUserInfo(userId),
      builder: (context, snapshot) {
        final userInfo =
            snapshot.data ?? {'name': 'Loading...', 'email': 'Loading...'};
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ExpansionTile(
            title: Text('Request by: ${userInfo['name']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${userInfo['email']}'),
                Text('Status: ${_capitalize(request['status'] as String)}',
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold)),
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
                    _buildInfoRow('Picker', request['pickerName'] as String?),
                    _buildInfoRow('Location', request['location'] as String?),
                    _buildInfoRow(
                        'Contact', request['pickerContact'] as String?),
                    _buildInfoRow('Items',
                        _formatItems(request['items'] as List<dynamic>)),
                    _buildInfoRow('Note', request['note'] as String?),
                    _buildInfoRow(
                        'Unique Code', request['uniqueCode'] as String?),
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
      },
    );
  }

  Future<void> _fetchCreators() async {
    try {
      QuerySnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      _creators = userSnapshot.docs.map((doc) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        String userId = doc.id;
        String name = userData['name'] as String? ?? 'Unknown';
        String email = userData['email'] as String? ?? 'No Email';
        _userCache[userId] = {'name': name, 'email': email};
        return {'id': userId, 'name': name, 'email': email};
      }).toList();
      setState(() {});
    } catch (e) {
      print("Error fetching creators: $e");
    }
  }

  Future<Map<String, String>> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userInfo = {
          'name': userData['name'] as String? ?? 'Unknown User',
          'email': userData['email'] as String? ?? 'No Email'
        };
        _userCache[userId] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print("Error fetching user info: $e");
    }

    return {'name': 'Unknown User', 'email': 'No Email'};
  }

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

    if (request['status'] == 'pending' || request['status'] == 'rejected') {
      buttons.add(_buildActionButton(
          Icons.check,
          'Approve',
          Colors.green,
          () => _updateRequestStatus(
              requestProvider, request['id'] as String, 'approved')));
    }

    if (request['status'] == 'pending') {
      buttons.add(_buildActionButton(
          Icons.close,
          'Reject',
          Colors.red,
          () => _updateRequestStatus(
              requestProvider, request['id'] as String, 'rejected')));
    }

    if (request['status'] == 'approved' ||
        request['status'] == 'partially_fulfilled') {
      buttons.add(_buildActionButton(
          Icons.check_circle,
          'Fulfill',
          Colors.blue,
          () => _showCodeDialog(
              context, requestProvider, request['id'] as String)));
    }

    buttons.add(_buildActionButton(Icons.edit, 'Edit', Colors.orange,
        () => _editRequest(context, request['id'] as String, request)));
    buttons.add(_buildActionButton(
        Icons.delete,
        'Delete',
        Colors.red,
        () => _deleteRequest(
            context, request['id'] as String, inventoryProvider)));

    return buttons;
  }
  // List<Widget> _buildActionButtons(
  //     BuildContext context, Map<String, dynamic> request) {
  //   final requestProvider =
  //       Provider.of<RequestProvider>(context, listen: false);
  //   final inventoryProvider =
  //       Provider.of<InventoryProvider>(context, listen: false);
  //   List<Widget> buttons = [];

  //   if (request['status'] == 'pending') {
  //     buttons.add(_buildActionButton(
  //         Icons.check,
  //         'Approve',
  //         Colors.green,
  //         () => _updateRequestStatus(
  //             requestProvider, request['id'] as String, 'approved')));
  //     buttons.add(_buildActionButton(
  //         Icons.close,
  //         'Reject',
  //         Colors.red,
  //         () => _updateRequestStatus(
  //             requestProvider, request['id'] as String, 'rejected')));
  //   } else if (request['status'] == 'approved' ||
  //       request['status'] == 'partially_fulfilled') {
  //     buttons.add(_buildActionButton(
  //         Icons.check_circle,
  //         'Fulfill',
  //         Colors.blue,
  //         () => _showCodeDialog(
  //             context, requestProvider, request['id'] as String)));
  //   }

  //   buttons.add(_buildActionButton(Icons.edit, 'Edit', Colors.orange,
  //       () => _editRequest(context, request['id'] as String, request)));
  //   buttons.add(_buildActionButton(
  //       Icons.delete,
  //       'Delete',
  //       Colors.red,
  //       () => _deleteRequest(
  //           context, request['id'] as String, inventoryProvider)));

  //   return buttons;
  // }

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
      final request = await requestProvider.getRequestById(requestId);
      if (request == null) {
        throw CustomException('Request not found');
      }

      final currentStatus = request['status'] as String;
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      // Function to update inventory
      Future<void> updateInventory(double factor) async {
        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(request['items']);
        for (var item in items) {
          bool isPipe = item['isPipe'] == true;
          double pipeLength = (item['pipeLength'] as num?)?.toDouble() ?? 1.0;

          double quantity;
          if (isPipe) {
            double meters = (item['meters'] as num).toDouble();
            quantity =
                meters / pipeLength; // Convert meters to quantity (pieces)
          } else {
            quantity = (item['quantity'] as num).toDouble();
          }

          // Get the current inventory impact of this item
          double currentImpact =
              (item['currentInventoryImpact'] as num?)?.toDouble() ?? 0.0;

          // Calculate the difference to apply
          double difference = (quantity * factor) - currentImpact;

          if (difference.abs() > 0.001) {
            // Use a small threshold for floating-point comparison
            if (isPipe) {
              await inventoryProvider.updateInventoryQuantity(
                  item['id'], difference * pipeLength,
                  unit: 'meters');
            } else {
              await inventoryProvider.updateInventoryQuantity(
                  item['id'], difference);
            }

            // Update the current inventory impact
            item['currentInventoryImpact'] = quantity * factor;

            if (isPipe) {
              item['metersFulfilled'] = quantity * pipeLength * factor.abs();
              item['metersPending'] =
                  quantity * pipeLength * (1 - factor.abs());
              item['pcsFulfilled'] = quantity * factor.abs();
              item['pcsPending'] = quantity * (1 - factor.abs());
            } else {
              item['quantityFulfilled'] = quantity * factor.abs();
              item['quantityPending'] = quantity * (1 - factor.abs());
            }
          }
        }
        // Update the items in the request
        await requestProvider.updateRequestItems(requestId, items);
      }

      // Determine how to update inventory based on status change
      double inventoryFactor = 0;
      String dialogTitle = '';
      String dialogContent = '';

      if (newStatus == 'rejected' && currentStatus != 'rejected') {
        inventoryFactor = 1; // Add back to inventory
        dialogTitle = 'Confirm Rejection';
        dialogContent =
            'Are you sure you want to reject this request? This will return the items to inventory.';
      } else if (newStatus == 'approved' && currentStatus == 'rejected') {
        inventoryFactor = -1; // Remove from inventory
        dialogTitle = 'Confirm Approval';
        dialogContent =
            'Are you sure you want to approve this previously rejected request? This will deduct the items from inventory again.';
      } else if (newStatus == 'approved' && currentStatus == 'pending') {
        inventoryFactor = -1; // Remove from inventory
        dialogTitle = 'Confirm Approval';
        dialogContent =
            'Are you sure you want to approve this request? This will deduct the items from inventory.';
      }

      if (inventoryFactor != 0) {
        bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: Text(dialogContent),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text(inventoryFactor > 0 ? 'Reject' : 'Approve'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
        if (confirm != true) return;

        await updateInventory(inventoryFactor);
      }

      // Update the request status
      await requestProvider.updateRequestStatus(requestId, newStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request status updated to $newStatus')),
      );
    } catch (e) {
      print("Error in _updateRequestStatus: $e");
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
                  Navigator.of(context).pop();
                  _showItemConfirmationDialog(context, request);
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

  void _showItemConfirmationDialog(
      BuildContext context, Map<String, dynamic> request) {
    List<Map<String, dynamic>> items =
        List<Map<String, dynamic>>.from(request['items'] as List);
    List<TextEditingController> controllers =
        List.generate(items.length, (index) => TextEditingController());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Items',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: List.generate(items.length, (index) {
                double requiredQuantity =
                    (items[index]['quantity'] as num).toDouble();
                double remainingQuantity =
                    (items[index]['remainingQuantity'] as num?)?.toDouble() ??
                        requiredQuantity;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[index]['name'] as String,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Required: $requiredQuantity ${items[index]['unit']}'),
                    Text(
                        'Remaining: $remainingQuantity ${items[index]['unit']}'),
                    TextField(
                      controller: controllers[index],
                      decoration:
                          InputDecoration(labelText: 'Received Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                  ],
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Confirm'),
              onPressed: () => _confirmItemsFulfillment(
                  context, request['id'] as String, items, controllers),
            ),
          ],
        );
      },
    );
  }

  void _confirmItemsFulfillment(
      BuildContext context,
      String requestId,
      List<Map<String, dynamic>> items,
      List<TextEditingController> controllers) {
    List<Map<String, dynamic>> updatedItems = [];
    bool isFullyFulfilled = true;

    for (int i = 0; i < items.length; i++) {
      double receivedQuantity = double.tryParse(controllers[i].text) ?? 0;
      double remainingQuantity =
          (items[i]['remainingQuantity'] as num?)?.toDouble() ??
              (items[i]['quantity'] as num).toDouble();

      if (receivedQuantity > remainingQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid quantity for ${items[i]['name']}')),
        );
        return;
      }

      updatedItems.add({
        ...items[i],
        'receivedQuantity': receivedQuantity,
        'remainingQuantity': remainingQuantity - receivedQuantity,
      });

      if (remainingQuantity - receivedQuantity > 0) {
        isFullyFulfilled = false;
      }
    }

    String newStatus = isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';

    Provider.of<RequestProvider>(context, listen: false)
        .updateRequestFulfillment(
      requestId,
      updatedItems,
      newStatus,
    )
        .then((_) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request updated successfully')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request: $error')),
      );
    });
  }

  void _editRequest(
      BuildContext context, String requestId, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditAdminRequestBottomSheet(
        id: requestId,
        items: List<Map<String, dynamic>>.from(request['items'] as List),
        location: request['location'] as String? ?? 'Default Location',
        pickerName: request['pickerName'] as String? ?? '',
        pickerContact: request['pickerContact'] as String? ?? '',
        note: request['note'] as String? ?? '',
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context, String requestId,
      InventoryProvider inventoryProvider) async {
    // Get the RequestProvider before showing the dialog
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false)),
          ElevatedButton(
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    // Check if the context is still valid
    if (!context.mounted) return;

    if (confirmed == true) {
      try {
        await requestProvider.deleteRequest(requestId, inventoryProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request deleted successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting request: $e')));
        }
      }
    }
  }

  // Future<void> _deleteRequest(BuildContext context, String requestId,
  //     InventoryProvider inventoryProvider) async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Confirm Delete'),
  //       content: Text('Are you sure you want to delete this request?'),
  //       actions: [
  //         TextButton(
  //             child: Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(false)),
  //         ElevatedButton(
  //           child: Text('Delete'),
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           onPressed: () => Navigator.of(context).pop(true),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed == true) {
  //     try {
  //       await Provider.of<RequestProvider>(context, listen: false)
  //           .deleteRequest(requestId, inventoryProvider);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Request deleted successfully')));
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Error deleting request: $e')));
  //     }
  //   }
  // }

  String _capitalize(String text) =>
      text.isNotEmpty ? '${text[0].toUpperCase()}${text.substring(1)}' : '';

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'partially_fulfilled':
        return Colors.cyan;
      case 'fulfilled':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void shareRequestDetails(Map<String, dynamic> request) {
    String shareText = '''
Request Details:
Created by: ${request['createdByName']}
Date: ${DateFormat('yyyy-MM-dd HH:mm').format(request['timestamp'] as DateTime)}
Location: ${request['location']}
Picker: ${request['pickerName']}
Contact: ${request['pickerContact']}
Items: ${_formatItems(request['items'] as List<dynamic>)}
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
            items: [
              'All',
              'Pending',
              'Approved',
              'Partially Fulfilled',
              'Fulfilled',
              'Rejected'
            ]
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
