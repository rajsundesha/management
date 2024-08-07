import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ManagerStockRequestScreen extends StatefulWidget {
  @override
  _ManagerStockRequestScreenState createState() =>
      _ManagerStockRequestScreenState();
}

class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
  final Map<String, Map<String, dynamic>> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Stock Request'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _viewNonFulfilledRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(child: _buildInventoryList()),
          _buildSelectedItemsList(),
          _buildNoteField(),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search Items',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        List<String> categories = ['All', ...inventoryProvider.getCategories()];
        return DropdownButton<String>(
          value: _selectedCategory,
          items: categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedCategory = newValue);
            }
          },
        );
      },
    );
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        List<Map<String, dynamic>> filteredItems = inventoryProvider.items
            .where((item) =>
                (_selectedCategory == 'All' ||
                    item['category'] == _selectedCategory) &&
                item['name']
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
            .toList();

        return ListView.builder(
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return ListTile(
              title: Text(item['name']),
              subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
              trailing: _buildQuantityControls(item),
            );
          },
        );
      },
    );
  }

  Widget _buildQuantityControls(Map<String, dynamic> item) {
    String itemId = item['id'];
    int quantity = _selectedItems[itemId]?['quantity'] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed:
              quantity > 0 ? () => _updateQuantity(item, quantity - 1) : null,
        ),
        Text('$quantity'),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () => _updateQuantity(item, quantity + 1),
        ),
      ],
    );
  }

  void _updateQuantity(Map<String, dynamic> item, int newQuantity) {
    setState(() {
      String itemId = item['id'];
      if (newQuantity > 0) {
        _selectedItems[itemId] = {
          'id': itemId,
          'name': item['name'],
          'quantity': newQuantity,
          'unit': item['unit'],
        };
      } else {
        _selectedItems.remove(itemId);
      }
    });
  }

  Widget _buildSelectedItemsList() {
    return Container(
      height: 150,
      child: ListView.builder(
        itemCount: _selectedItems.length,
        itemBuilder: (context, index) {
          String itemId = _selectedItems.keys.elementAt(index);
          Map<String, dynamic> item = _selectedItems[itemId]!;
          return ListTile(
            title:
                Text('${item['name']} x ${item['quantity']} ${item['unit']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showEditItemDialog(item),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _updateQuantity(item, 0),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    TextEditingController quantityController =
        TextEditingController(text: item['quantity'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item['name']}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              int newQuantity = int.tryParse(quantityController.text) ?? 0;
              _updateQuantity(item, newQuantity);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _noteController,
        decoration: InputDecoration(
          labelText: 'Note',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      child: Text('Submit Stock Request'),
      onPressed: _submitStockRequest,
    );
  }

  void _submitStockRequest() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    List<Map<String, dynamic>> items = _selectedItems.values.toList();

    try {
      await requestProvider.addStockRequest(
        items: items,
        note: _noteController.text,
        createdBy: authProvider.currentUserEmail!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock request submitted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit stock request: $e')),
      );
    }
  }

  void _viewNonFulfilledRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => NonFulfilledStockRequestsScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

class NonFulfilledStockRequestsScreen extends StatefulWidget {
  @override
  _NonFulfilledStockRequestsScreenState createState() =>
      _NonFulfilledStockRequestsScreenState();
}

class _NonFulfilledStockRequestsScreenState
    extends State<NonFulfilledStockRequestsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Non-Fulfilled Stock Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showDateFilterDialog,
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, _) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: requestProvider.getNonFulfilledStockRequests(
                startDate: _startDate, endDate: _endDate),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No non-fulfilled stock requests'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final request = snapshot.data![index];
                    return ListTile(
                      title: Text('Request ID: ${request['id']}'),
                      subtitle:
                          Text('Created: ${_formatDate(request['createdAt'])}'),
                      trailing: Text('Status: ${request['status']}'),
                      onTap: () => _showRequestDetails(context, request),
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showDateFilterDialog() async {
    DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (dateRange != null) {
      setState(() {
        _startDate = dateRange.start;
        _endDate = dateRange.end;
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('MM/dd/yyyy').format(date.toDate());
    }
    return 'N/A';
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime is Timestamp) {
      return DateFormat('MM/dd/yyyy hh:mm a').format(dateTime.toDate());
    }
    return 'N/A';
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${request['id']}'),
              Text('Created by: ${request['createdBy']}'),
              Text('Current Status: ${request['status']}'),
              SizedBox(height: 10),
              Text('Timeline:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Created: ${_formatDateTime(request['createdAt'])}'),
              if (request['approvedAt'] != null)
                Text('Approved: ${_formatDateTime(request['approvedAt'])}'),
              if (request['partiallyFulfilledAt'] != null)
                Text(
                    'Partially Fulfilled: ${_formatDateTime(request['partiallyFulfilledAt'])}'),
              if (request['fulfilledAt'] != null)
                Text('Fulfilled: ${_formatDateTime(request['fulfilledAt'])}'),
              SizedBox(height: 10),
              Text('Note: ${request['note'] ?? 'No note'}'),
              SizedBox(height: 10),
              Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (request['items'] != null)
                ...request['items'].map((item) => Text(
                    '- ${item['name']}: ${item['quantity']} ${item['unit']}')),
              if (request['items'] == null) Text('No items found'),
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
// class NonFulfilledStockRequestsScreen extends StatefulWidget {
//   @override
//   _NonFulfilledStockRequestsScreenState createState() =>
//       _NonFulfilledStockRequestsScreenState();
// }

// class _NonFulfilledStockRequestsScreenState
//     extends State<NonFulfilledStockRequestsScreen> {
//   DateTime? _startDate;
//   DateTime? _endDate;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Non-Fulfilled Stock Requests'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: _showDateFilterDialog,
//           ),
//         ],
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, _) {
//           return FutureBuilder<List<Map<String, dynamic>>>(
//             future: requestProvider.getNonFulfilledStockRequests(
//                 startDate: _startDate, endDate: _endDate),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               } else if (snapshot.hasError) {
//                 return Center(child: Text('Error: ${snapshot.error}'));
//               } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 return Center(child: Text('No non-fulfilled stock requests'));
//               } else {
//                 return ListView.builder(
//                   itemCount: snapshot.data!.length,
//                   itemBuilder: (context, index) {
//                     final request = snapshot.data![index];
//                     return ListTile(
//                       title: Text('Request ID: ${request['id']}'),
//                       subtitle:
//                           Text('Created: ${_formatDate(request['createdAt'])}'),
//                       trailing: Text('Status: ${request['status']}'),
//                       onTap: () => _showRequestDetails(context, request),
//                     );
//                   },
//                 );
//               }
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showDateFilterDialog() async {
//     DateTimeRange? dateRange = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       initialDateRange: _startDate != null && _endDate != null
//           ? DateTimeRange(start: _startDate!, end: _endDate!)
//           : null,
//     );

//     if (dateRange != null) {
//       setState(() {
//         _startDate = dateRange.start;
//         _endDate = dateRange.end;
//       });
//     }
//   }

//   String _formatDate(dynamic date) {
//     if (date is Timestamp) {
//       return date.toDate().toString().split(' ')[0];
//     }
//     return 'N/A';
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('ID: ${request['id']}'),
//               Text('Created by: ${request['createdBy']}'),
//               Text('Status: ${request['status']}'),
//               Text('Created At: ${_formatDate(request['createdAt'])}'),
//               Text('Note: ${request['note'] ?? 'No note'}'),
//               SizedBox(height: 10),
//               Text('Items:'),
//               if (request['items'] != null)
//                 ...request['items'].map((item) => Text(
//                     '- ${item['name']}: ${item['quantity']} ${item['unit']}')),
//               if (request['items'] == null) Text('No items found'),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             child: Text('Close'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           if (request['status'] == 'pending')
//             ElevatedButton(
//               child: Text('Approve'),
//               onPressed: () =>
//                   _updateRequestStatus(context, request['id'], 'approved'),
//             ),
//           if (request['status'] != 'fulfilled')
//             ElevatedButton(
//               child: Text('Mark as Fulfilled'),
//               onPressed: () =>
//                   _updateRequestStatus(context, request['id'], 'fulfilled'),
//             ),
//         ],
//       ),
//     );
//   }

//   void _updateRequestStatus(
//       BuildContext context, String requestId, String newStatus) async {
//     try {
//       await Provider.of<RequestProvider>(context, listen: false)
//           .updateStockRequestStatus(
//         requestId,
//         newStatus,
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail!,
//       );
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request status updated successfully')),
//       );
//       setState(() {}); // Refresh the list
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update request status: $e')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class ManagerStockRequestScreen extends StatefulWidget {
//   @override
//   _ManagerStockRequestScreenState createState() =>
//       _ManagerStockRequestScreenState();
// }

// class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _noteController = TextEditingController();
//   String _selectedCategory = 'All';

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Stock Request'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.history),
//             onPressed: _viewPendingRequests,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           _buildCategoryFilter(),
//           Expanded(child: _buildInventoryList()),
//           _buildSelectedItemsList(),
//           _buildNoteField(),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         controller: _searchController,
//         decoration: InputDecoration(
//           labelText: 'Search Items',
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(Icons.search),
//         ),
//         onChanged: (_) => setState(() {}),
//       ),
//     );
//   }

//   Widget _buildCategoryFilter() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<String> categories = ['All', ...inventoryProvider.getCategories()];
//         return DropdownButton<String>(
//           value: _selectedCategory,
//           items: categories.map((String category) {
//             return DropdownMenuItem<String>(
//               value: category,
//               child: Text(category),
//             );
//           }).toList(),
//           onChanged: (String? newValue) {
//             if (newValue != null) {
//               setState(() => _selectedCategory = newValue);
//             }
//           },
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             final item = filteredItems[index];
//             return ListTile(
//               title: Text(item['name']),
//               subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
//               trailing: _buildQuantityControls(item),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     String itemId = item['id'];
//     int quantity = _selectedItems[itemId]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed:
//               quantity > 0 ? () => _updateQuantity(item, quantity - 1) : null,
//         ),
//         Text('$quantity'),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () => _updateQuantity(item, quantity + 1),
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(Map<String, dynamic> item, int newQuantity) {
//     setState(() {
//       String itemId = item['id'];
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'id': itemId,
//           'name': item['name'],
//           'quantity': newQuantity,
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 150,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemId = _selectedItems.keys.elementAt(index);
//           Map<String, dynamic> item = _selectedItems[itemId]!;
//           return ListTile(
//             title:
//                 Text('${item['name']} x ${item['quantity']} ${item['unit']}'),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.edit),
//                   onPressed: () => _showEditItemDialog(item),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.delete),
//                   onPressed: () => _updateQuantity(item, 0),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   void _showEditItemDialog(Map<String, dynamic> item) {
//     TextEditingController quantityController =
//         TextEditingController(text: item['quantity'].toString());
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit ${item['name']}'),
//         content: TextField(
//           controller: quantityController,
//           keyboardType: TextInputType.number,
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             child: Text('Cancel'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           ElevatedButton(
//             child: Text('Save'),
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               _updateQuantity(item, newQuantity);
//               Navigator.of(context).pop();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNoteField() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         controller: _noteController,
//         decoration: InputDecoration(
//           labelText: 'Note',
//           border: OutlineInputBorder(),
//         ),
//         maxLines: 3,
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return ElevatedButton(
//       child: Text('Submit Stock Request'),
//       onPressed: _submitStockRequest,
//     );
//   }

//   void _submitStockRequest() async {
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please select at least one item')),
//       );
//       return;
//     }

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     List<Map<String, dynamic>> items = _selectedItems.values.toList();

//     try {
//       await requestProvider.addStockRequest(
//         items: items,
//         note: _noteController.text,
//         createdBy: authProvider.currentUserEmail!,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request submitted successfully')),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to submit stock request: $e')),
//       );
//     }
//   }

//   void _viewPendingRequests() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => PendingStockRequestsScreen()),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// class PendingStockRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Stock Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, _) {
//           return FutureBuilder<List<Map<String, dynamic>>>(
//             future: requestProvider.getPendingStockRequests(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               } else if (snapshot.hasError) {
//                 print(
//                     "Error in FutureBuilder: ${snapshot.error}"); // Debug print
//                 return Center(child: Text('Error: ${snapshot.error}'));
//               } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 print("No data or empty data"); // Debug print
//                 return Center(child: Text('No pending stock requests'));
//               } else {
//                 print(
//                     "Displaying ${snapshot.data!.length} requests"); // Debug print
//                 return ListView.builder(
//                   itemCount: snapshot.data!.length,
//                   itemBuilder: (context, index) {
//                     final request = snapshot.data![index];
//                     print(
//                         "Building item for request: ${request['id']}"); // Debug print
//                     return ListTile(
//                       title: Text('Request ID: ${request['id']}'),
//                       subtitle: Text('Created by: ${request['createdBy']}'),
//                       trailing: Text('Status: ${request['status']}'),
//                       onTap: () => _showRequestDetails(context, request),
//                     );
//                   },
//                 );
//               }
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('ID: ${request['id']}'),
//               Text('Created by: ${request['createdBy']}'),
//               Text('Status: ${request['status']}'),
//               Text('Note: ${request['note'] ?? 'No note'}'),
//               SizedBox(height: 10),
//               Text('Items:'),
//               if (request['items'] != null)
//                 ...request['items'].map((item) => Text(
//                     '- ${item['name']}: ${item['quantity']} ${item['unit']}')),
//               if (request['items'] == null) Text('No items found'),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             child: Text('Close'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class ManagerStockRequestScreen extends StatefulWidget {
//   @override
//   _ManagerStockRequestScreenState createState() =>
//       _ManagerStockRequestScreenState();
// }

// class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
//   Map<String, Map<String, dynamic>> _selectedItems = {};
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   TextEditingController _noteController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Stock Request'),
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           _buildCategoryFilter(),
//           Expanded(child: _buildInventoryList()),
//           _buildSelectedItemsList(),
//           _buildNoteField(),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         decoration: InputDecoration(
//           labelText: 'Search Items',
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(Icons.search),
//         ),
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryFilter() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<String> categories = ['All', ...inventoryProvider.getCategories()];
//         return DropdownButton<String>(
//           value: _selectedCategory,
//           items: categories.map((String category) {
//             return DropdownMenuItem<String>(
//               value: category,
//               child: Text(category),
//             );
//           }).toList(),
//           onChanged: (String? newValue) {
//             setState(() {
//               _selectedCategory = newValue!;
//             });
//           },
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             final item = filteredItems[index];
//             return ListTile(
//               title: Text(item['name']),
//               subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
//               trailing: _buildQuantityControls(item),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     String itemId = item['id'];
//     int quantity = _selectedItems[itemId]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed:
//               quantity > 0 ? () => _updateQuantity(item, quantity - 1) : null,
//         ),
//         Text('$quantity'),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () => _updateQuantity(item, quantity + 1),
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(Map<String, dynamic> item, int newQuantity) {
//     setState(() {
//       String itemId = item['id'];
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'id': itemId,
//           'name': item['name'],
//           'quantity': newQuantity,
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 100,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemId = _selectedItems.keys.elementAt(index);
//           Map<String, dynamic> item = _selectedItems[itemId]!;
//           return ListTile(
//             title:
//                 Text('${item['name']} x ${item['quantity']} ${item['unit']}'),
//             trailing: IconButton(
//               icon: Icon(Icons.delete),
//               onPressed: () => _updateQuantity(item, 0),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildNoteField() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         controller: _noteController,
//         decoration: InputDecoration(
//           labelText: 'Note',
//           border: OutlineInputBorder(),
//         ),
//         maxLines: 3,
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return ElevatedButton(
//       child: Text('Submit Stock Request'),
//       onPressed: _submitStockRequest,
//     );
//   }

//   void _submitStockRequest() async {
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please select at least one item')),
//       );
//       return;
//     }

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     List<Map<String, dynamic>> items = _selectedItems.values.toList();

//     try {
//       await requestProvider.addStockRequest(
//         items: items,
//         note: _noteController.text,
//         createdBy: authProvider.currentUserEmail!,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request submitted successfully')),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to submit stock request: $e')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class ManagerStockRequestScreen extends StatefulWidget {
//   @override
//   _ManagerStockRequestScreenState createState() =>
//       _ManagerStockRequestScreenState();
// }

// class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   TextEditingController _noteController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Stock Request'),
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           _buildCategoryFilter(),
//           Expanded(child: _buildInventoryList()),
//           _buildSelectedItemsList(),
//           _buildNoteField(),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         decoration: InputDecoration(
//           labelText: 'Search Items',
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(Icons.search),
//         ),
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryFilter() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<String> categories = ['All', ...inventoryProvider.getCategories()];
//         return DropdownButton<String>(
//           value: _selectedCategory,
//           items: categories.map((String category) {
//             return DropdownMenuItem<String>(
//               value: category,
//               child: Text(category),
//             );
//           }).toList(),
//           onChanged: (String? newValue) {
//             setState(() {
//               _selectedCategory = newValue!;
//             });
//           },
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             final item = filteredItems[index];
//             return ListTile(
//               title: Text(item['name']),
//               subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
//               trailing: _buildQuantityControls(item),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['name']] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['name'], quantity - 1)
//               : null,
//         ),
//         Text('$quantity'),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () => _updateQuantity(item['name'], quantity + 1),
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(String itemName, int newQuantity) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemName] = newQuantity;
//       } else {
//         _selectedItems.remove(itemName);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 100,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return ListTile(
//             title: Text('$itemName x $quantity'),
//             trailing: IconButton(
//               icon: Icon(Icons.delete),
//               onPressed: () => _updateQuantity(itemName, 0),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildNoteField() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         controller: _noteController,
//         decoration: InputDecoration(
//           labelText: 'Note',
//           border: OutlineInputBorder(),
//         ),
//         maxLines: 3,
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return ElevatedButton(
//       child: Text('Submit Stock Request'),
//       onPressed: _submitStockRequest,
//     );
//   }

//   void _submitStockRequest() async {
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please select at least one item')),
//       );
//       return;
//     }

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     List<Map<String, dynamic>> items = _selectedItems.entries
//         .map((entry) => {
//               'name': entry.key,
//               'quantity': entry.value,
//             })
//         .toList();

//     try {
//       await requestProvider.addStockRequest(
//         items: items,
//         note: _noteController.text,
//         createdBy: authProvider.currentUserEmail!,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request submitted successfully')),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to submit stock request: $e')),
//       );
//     }
//   }
// }
