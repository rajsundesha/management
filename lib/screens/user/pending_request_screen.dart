import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import 'edit_user_request_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart'; // Import the share_plus package

class UserPendingRequestsScreen extends StatefulWidget {
  @override
  _UserPendingRequestsScreenState createState() =>
      _UserPendingRequestsScreenState();
}

class _UserPendingRequestsScreenState extends State<UserPendingRequestsScreen> {
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
        appBar: AppBar(title: Text('Pending Requests')),
        body: Center(
          child: Text('User information not available. Please log in again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Requests'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildRequestList(requestProvider, currentUserEmail),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by picker name or contact',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          prefixIcon: Icon(Icons.search, color: Colors.white),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ),
        style: TextStyle(color: Colors.white),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildRequestList(
      RequestProvider requestProvider, String currentUserEmail) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print("Error fetching pending requests: ${snapshot.error}");
          return Center(
            child: Text(
                'Error: Unable to fetch requests. Please try again later.'),
          );
        }

        final pendingRequests = (snapshot.data ?? []).where((request) {
          final String pickerName = request['pickerName'] ?? '';
          final String pickerContact = request['pickerContact'] ?? '';
          return pickerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              pickerContact.contains(_searchQuery);
        }).toList();

        if (pendingRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Your pending requests will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: pendingRequests.length,
          itemBuilder: (context, index) {
            final request = pendingRequests[index];
            return _buildRequestCard(context, request);
          },
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
            onPressed: (_) => _editRequest(context, request),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => _deleteRequest(context, request['id']),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
          SlidableAction(
            onPressed: (_) =>
                _shareRequest(context, request), // Add sharing option
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.share,
            label: 'Share',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () => _showRequestDetails(context, request),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      request['pickerName'] ?? 'Unknown Picker',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(request['timestamp']),
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Location: ${request['location']}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                SizedBox(height: 8),
                Text(
                  'Items: ${_formatItems(request['items'])}',
                  style: TextStyle(color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${request['status']}',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Code: ${request['uniqueCode']}',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Picker: ${request['pickerName']}'),
              Text('Contact: ${request['pickerContact']}'),
              Text('Location: ${request['location']}'),
              Text('Status: ${request['status']}'),
              Text('Unique Code: ${request['uniqueCode']}'),
              Text('Created: ${_formatDate(request['timestamp'])}'),
              SizedBox(height: 16),
              Text(
                'Items:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...(request['items'] as List<dynamic>).map((item) {
                final isPipe = item['isPipe'] ?? false;
                final name = item['name'] ?? 'Unknown Item';
                if (isPipe) {
                  final pieces = item['pcs'] ?? 0;
                  final length = item['meters'] ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '$name - ${pieces > 0 ? '$pieces pcs' : ''}${pieces > 0 && length > 0 ? ', ' : ''}${length > 0 ? '$length m' : ''}',
                    ),
                  );
                } else {
                  final quantity = item['quantity'] ?? 0;
                  final unit = item['unit'] ?? 'pcs';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('$name x $quantity ($unit)'),
                  );
                }
              }).toList(),
              if (request['note'] != null && request['note'].isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Note:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(request['note']),
              ],
              SizedBox(height: 24),
              // Fixed Row with Expanded widgets to prevent overflow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editRequest(context, request);
                      },
                      child: Text('Edit Request'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                    ),
                  ),
                  SizedBox(width: 10), // Add spacing between buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _deleteRequest(context, request['id']);
                      },
                      child: Text('Delete Request'),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                  SizedBox(width: 10), // Add spacing between buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _shareRequest(context, request);
                      },
                      child: Text('Share Request'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to share request details
  void _shareRequest(BuildContext context, Map<String, dynamic> request) {
    final String shareContent = _formatShareContent(request);
    Share.share(shareContent);
  }

  // Method to format share content
  String _formatShareContent(Map<String, dynamic> request) {
    final itemsDescription = _formatItems(request['items']);
    return '''
Request Details:
Picker: ${request['pickerName']}
Contact: ${request['pickerContact']}
Location: ${request['location']}
Status: ${request['status']}
Unique Code: ${request['uniqueCode']}
Items: $itemsDescription
Note: ${request['note'] ?? 'N/A'}
Created: ${_formatDate(request['timestamp'])}
''';
  }

  void _editRequest(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditUserRequestBottomSheet(
        id: request['id'],
        items: List<Map<String, dynamic>>.from(request['items']),
        location: request['location'],
        pickerName: request['pickerName'],
        pickerContact: request['pickerContact'],
        note: request['note'],
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context, String requestId) async {
    try {
      // Obtain the InventoryProvider instance
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      await Provider.of<RequestProvider>(context, listen: false).deleteRequest(
          requestId,
          inventoryProvider); // Pass both requestId and inventoryProvider

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request deleted successfully')),
      );
    } catch (e) {
      print("Error deleting request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting request: $e')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate(); // Convert Timestamp to DateTime
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } else if (timestamp is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
    }
    return 'Unknown date';
  }

  String _formatItems(List<dynamic> items) {
    return items.map((item) {
      final isPipe = item['isPipe'] ?? false;
      final name = item['name'] ?? 'Unknown Item';
      if (isPipe) {
        final pcs = item['pcs'] ?? 0;
        final meters = item['meters'] ?? 0.0;
        return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
      } else {
        final quantity = item['quantity'] ?? 0;
        final unit = item['unit'] ?? 'pcs';
        return '$name x $quantity ($unit)';
      }
    }).join(', ');
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:share_plus/share_plus.dart'; // Import the share_plus package

// class UserPendingRequestsScreen extends StatefulWidget {
//   @override
//   _UserPendingRequestsScreenState createState() =>
//       _UserPendingRequestsScreenState();
// }

// class _UserPendingRequestsScreenState extends State<UserPendingRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//           child: Text('User information not available. Please log in again.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           Expanded(
//             child: _buildRequestList(requestProvider, currentUserEmail),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: TextField(
//         controller: _searchController,
//         decoration: InputDecoration(
//           hintText: 'Search by picker name or contact',
//           hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//           filled: true,
//           fillColor: Colors.white.withOpacity(0.2),
//           prefixIcon: Icon(Icons.search, color: Colors.white),
//           suffixIcon: IconButton(
//             icon: Icon(Icons.clear, color: Colors.white),
//             onPressed: () {
//               _searchController.clear();
//               setState(() {
//                 _searchQuery = '';
//               });
//             },
//           ),
//         ),
//         style: TextStyle(color: Colors.white),
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildRequestList(
//       RequestProvider requestProvider, String currentUserEmail) {
//     return StreamBuilder<List<Map<String, dynamic>>>(
//       stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }

//         if (snapshot.hasError) {
//           print("Error fetching pending requests: ${snapshot.error}");
//           return Center(
//             child: Text(
//                 'Error: Unable to fetch requests. Please try again later.'),
//           );
//         }

//         final pendingRequests = (snapshot.data ?? []).where((request) {
//           final String pickerName = request['pickerName'] ?? '';
//           final String pickerContact = request['pickerContact'] ?? '';
//           return pickerName
//                   .toLowerCase()
//                   .contains(_searchQuery.toLowerCase()) ||
//               pickerContact.contains(_searchQuery);
//         }).toList();

//         if (pendingRequests.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
//                 SizedBox(height: 16),
//                 Text(
//                   'No pending requests',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Your pending requests will appear here',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               ],
//             ),
//           );
//         }

//         return ListView.builder(
//           itemCount: pendingRequests.length,
//           itemBuilder: (context, index) {
//             final request = pendingRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Slidable(
//       endActionPane: ActionPane(
//         motion: ScrollMotion(),
//         children: [
//           SlidableAction(
//             onPressed: (_) => _editRequest(context, request),
//             backgroundColor: Colors.blue,
//             foregroundColor: Colors.white,
//             icon: Icons.edit,
//             label: 'Edit',
//           ),
//           SlidableAction(
//             onPressed: (_) => _deleteRequest(context, request['id']),
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//             icon: Icons.delete,
//             label: 'Delete',
//           ),
//           SlidableAction(
//             onPressed: (_) =>
//                 _shareRequest(context, request), // Add sharing option
//             backgroundColor: Colors.green,
//             foregroundColor: Colors.white,
//             icon: Icons.share,
//             label: 'Share',
//           ),
//         ],
//       ),
//       child: Card(
//         elevation: 2,
//         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: InkWell(
//           onTap: () => _showRequestDetails(context, request),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       request['pickerName'] ?? 'Unknown Picker',
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       _formatDate(request['timestamp']),
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Location: ${request['location']}',
//                   style: TextStyle(color: Colors.grey.shade700),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Items: ${_formatItems(request['items'])}',
//                   style: TextStyle(color: Colors.grey.shade700),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Status: ${request['status']}',
//                       style: TextStyle(
//                           color: Colors.orange, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       'Code: ${request['uniqueCode']}',
//                       style: TextStyle(
//                           color: Colors.blue.shade700,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (BuildContext bc) {
//         return Container(
//           padding: EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Request Details',
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 16),
//               Text('Picker: ${request['pickerName']}'),
//               Text('Contact: ${request['pickerContact']}'),
//               Text('Location: ${request['location']}'),
//               Text('Status: ${request['status']}'),
//               Text('Unique Code: ${request['uniqueCode']}'),
//               Text('Created: ${_formatDate(request['timestamp'])}'),
//               SizedBox(height: 16),
//               Text(
//                 'Items:',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               ...(request['items'] as List<dynamic>).map((item) {
//                 final isPipe = item['isPipe'] ?? false;
//                 final name = item['name'] ?? 'Unknown Item';
//                 if (isPipe) {
//                   final pieces = item['pcs'] ?? 0;
//                   final length = item['meters'] ?? 0.0;
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Text(
//                       '$name - ${pieces > 0 ? '$pieces pcs' : ''}${pieces > 0 && length > 0 ? ', ' : ''}${length > 0 ? '$length m' : ''}',
//                     ),
//                   );
//                 } else {
//                   final quantity = item['quantity'] ?? 0;
//                   final unit = item['unit'] ?? 'pcs';
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Text('$name x $quantity ($unit)'),
//                   );
//                 }
//               }).toList(),
//               if (request['note'] != null && request['note'].isNotEmpty) ...[
//                 SizedBox(height: 16),
//                 Text(
//                   'Note:',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Text(request['note']),
//               ],
//               SizedBox(height: 24),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                   ),
//                   ElevatedButton(
//                     onPressed: () async {
//                       Navigator.of(context).pop();
//                       await _deleteRequest(context, request['id']);
//                     },
//                     child: Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _shareRequest(context, request);
//                     },
//                     child: Text('Share Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // Method to share request details
//   void _shareRequest(BuildContext context, Map<String, dynamic> request) {
//     final String shareContent = _formatShareContent(request);
//     Share.share(shareContent);
//   }

//   // Method to format share content
//   String _formatShareContent(Map<String, dynamic> request) {
//     final itemsDescription = _formatItems(request['items']);
//     return '''
// Request Details:
// Picker: ${request['pickerName']}
// Contact: ${request['pickerContact']}
// Location: ${request['location']}
// Status: ${request['status']}
// Unique Code: ${request['uniqueCode']}
// Items: $itemsDescription
// Note: ${request['note'] ?? 'N/A'}
// Created: ${_formatDate(request['timestamp'])}
// ''';
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'],
//         pickerName: request['pickerName'],
//         pickerContact: request['pickerContact'],
//         note: request['note'],
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String requestId) async {
//     try {
//       // Obtain the InventoryProvider instance
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       await Provider.of<RequestProvider>(context, listen: false).deleteRequest(
//           requestId,
//           inventoryProvider); // Pass both requestId and inventoryProvider

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

//   String _formatDate(dynamic timestamp) {
//     if (timestamp is Timestamp) {
//       DateTime dateTime = timestamp.toDate(); // Convert Timestamp to DateTime
//       return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
//     } else if (timestamp is DateTime) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//     }
//     return 'Unknown date';
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final isPipe = item['isPipe'] ?? false;
//       final name = item['name'] ?? 'Unknown Item';
//       if (isPipe) {
//         final pcs = item['pcs'] ?? 0;
//         final meters = item['meters'] ?? 0.0;
//         return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
//       } else {
//         final quantity = item['quantity'] ?? 0;
//         final unit = item['unit'] ?? 'pcs';
//         return '$name x $quantity ($unit)';
//       }
//     }).join(', ');
//   }
// }

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class UserPendingRequestsScreen extends StatefulWidget {
//   @override
//   _UserPendingRequestsScreenState createState() =>
//       _UserPendingRequestsScreenState();
// }

// class _UserPendingRequestsScreenState extends State<UserPendingRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//           child: Text('User information not available. Please log in again.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           Expanded(
//             child: _buildRequestList(requestProvider, currentUserEmail),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: TextField(
//         controller: _searchController,
//         decoration: InputDecoration(
//           hintText: 'Search by picker name or contact',
//           hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: BorderSide.none,
//           ),
//           filled: true,
//           fillColor: Colors.white.withOpacity(0.2),
//           prefixIcon: Icon(Icons.search, color: Colors.white),
//           suffixIcon: IconButton(
//             icon: Icon(Icons.clear, color: Colors.white),
//             onPressed: () {
//               _searchController.clear();
//               setState(() {
//                 _searchQuery = '';
//               });
//             },
//           ),
//         ),
//         style: TextStyle(color: Colors.white),
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildRequestList(
//       RequestProvider requestProvider, String currentUserEmail) {
//     return StreamBuilder<List<Map<String, dynamic>>>(
//       stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }

//         if (snapshot.hasError) {
//           print("Error fetching pending requests: ${snapshot.error}");
//           return Center(
//             child: Text(
//                 'Error: Unable to fetch requests. Please try again later.'),
//           );
//         }

//         final pendingRequests = (snapshot.data ?? []).where((request) {
//           final String pickerName = request['pickerName'] ?? '';
//           final String pickerContact = request['pickerContact'] ?? '';
//           return pickerName
//                   .toLowerCase()
//                   .contains(_searchQuery.toLowerCase()) ||
//               pickerContact.contains(_searchQuery);
//         }).toList();

//         if (pendingRequests.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
//                 SizedBox(height: 16),
//                 Text(
//                   'No pending requests',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Your pending requests will appear here',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               ],
//             ),
//           );
//         }

//         return ListView.builder(
//           itemCount: pendingRequests.length,
//           itemBuilder: (context, index) {
//             final request = pendingRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Slidable(
//       endActionPane: ActionPane(
//         motion: ScrollMotion(),
//         children: [
//           SlidableAction(
//             onPressed: (_) => _editRequest(context, request),
//             backgroundColor: Colors.blue,
//             foregroundColor: Colors.white,
//             icon: Icons.edit,
//             label: 'Edit',
//           ),
//           SlidableAction(
//             onPressed: (_) => _deleteRequest(context, request['id']),
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//             icon: Icons.delete,
//             label: 'Delete',
//           ),
//         ],
//       ),
//       child: Card(
//         elevation: 2,
//         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: InkWell(
//           onTap: () => _showRequestDetails(context, request),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       request['pickerName'] ?? 'Unknown Picker',
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       _formatDate(request['timestamp']),
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Location: ${request['location']}',
//                   style: TextStyle(color: Colors.grey.shade700),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Items: ${_formatItems(request['items'])}',
//                   style: TextStyle(color: Colors.grey.shade700),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Status: ${request['status']}',
//                       style: TextStyle(
//                           color: Colors.orange, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       'Code: ${request['uniqueCode']}',
//                       style: TextStyle(
//                           color: Colors.blue.shade700,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (BuildContext bc) {
//         return Container(
//           padding: EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Request Details',
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 16),
//               Text('Picker: ${request['pickerName']}'),
//               Text('Contact: ${request['pickerContact']}'),
//               Text('Location: ${request['location']}'),
//               Text('Status: ${request['status']}'),
//               Text('Unique Code: ${request['uniqueCode']}'),
//               Text('Created: ${_formatDate(request['timestamp'])}'),
//               SizedBox(height: 16),
//               Text(
//                 'Items:',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               ...(request['items'] as List<dynamic>).map((item) {
//                 final isPipe = item['isPipe'] ?? false;
//                 final name = item['name'] ?? 'Unknown Item';
//                 if (isPipe) {
//                   final pieces = item['pcs'] ?? 0;
//                   final length = item['meters'] ?? 0.0;
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Text(
//                       '$name - ${pieces > 0 ? '$pieces pcs' : ''}${pieces > 0 && length > 0 ? ', ' : ''}${length > 0 ? '$length m' : ''}',
//                     ),
//                   );
//                 } else {
//                   final quantity = item['quantity'] ?? 0;
//                   final unit = item['unit'] ?? 'pcs';
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Text('$name x $quantity ($unit)'),
//                   );
//                 }
//               }).toList(),
//               if (request['note'] != null && request['note'].isNotEmpty) ...[
//                 SizedBox(height: 16),
//                 Text(
//                   'Note:',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Text(request['note']),
//               ],
//               SizedBox(height: 24),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                   ),
//                   ElevatedButton(
//                     onPressed: () async {
//                       Navigator.of(context).pop();
//                       await _deleteRequest(context, request['id']);
//                     },
//                     child: Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'],
//         pickerName: request['pickerName'],
//         pickerContact: request['pickerContact'],
//         note: request['note'],
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String requestId) async {
//     try {
//       // Obtain the InventoryProvider instance
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       await Provider.of<RequestProvider>(context, listen: false).deleteRequest(
//           requestId,
//           inventoryProvider); // Pass both requestId and inventoryProvider

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


//   String _formatDate(dynamic timestamp) {
//     if (timestamp is Timestamp) {
//       DateTime dateTime = timestamp.toDate(); // Convert Timestamp to DateTime
//       return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
//     } else if (timestamp is DateTime) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//     }
//     return 'Unknown date';
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final isPipe = item['isPipe'] ?? false;
//       final name = item['name'] ?? 'Unknown Item';
//       if (isPipe) {
//         final pcs = item['pcs'] ?? 0;
//         final meters = item['meters'] ?? 0.0;
//         return '$name - ${pcs > 0 ? '$pcs pcs' : ''}${pcs > 0 && meters > 0 ? ', ' : ''}${meters > 0 ? '$meters m' : ''}';
//       } else {
//         final quantity = item['quantity'] ?? 0;
//         final unit = item['unit'] ?? 'pcs';
//         return '$name x $quantity ($unit)';
//       }
//     }).join(', ');
//   }
// }

// void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (BuildContext bc) {
//       return Container(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Request Details',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Text('Picker: ${request['pickerName']}'),
//             Text('Contact: ${request['pickerContact']}'),
//             Text('Location: ${request['location']}'),
//             Text('Status: ${request['status']}'),
//             Text('Unique Code: ${request['uniqueCode']}'),
//             Text('Created: ${_formatDate(request['timestamp'])}'),
//             SizedBox(height: 16),
//             Text(
//               'Items:',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             ...(request['items'] as List<dynamic>).map((item) {
//               final isPipe = item['isPipe'] ?? false;
//               final name = item['name'] ?? 'Unknown Item';
//               if (isPipe) {
//                 final pieces = item['pcs'] ?? 0;
//                 final length = item['meters'] ?? 0.0;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Text(
//                     '$name - ${pieces > 0 ? '$pieces pcs' : ''}${pieces > 0 && length > 0 ? ', ' : ''}${length > 0 ? '$length m' : ''}',
//                   ),
//                 );
//               } else {
//                 final quantity = item['quantity'] ?? 0;
//                 final unit = item['unit'] ?? 'pcs';
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Text('$name x $quantity ($unit)'),
//                 );
//               }
//             }).toList(),
//             if (request['note'] != null && request['note'].isNotEmpty) ...[
//               SizedBox(height: 16),
//               Text(
//                 'Note:',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               Text(request['note']),
//             ],
//             SizedBox(height: 24),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _editRequest(context, request);
//                   },
//                   child: Text('Edit Request'),
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     Navigator.of(context).pop();
//                     await _deleteRequest(context, request['id']);
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

// // String _formatItems(List<dynamic> items) {
// //   return items.map((item) {
// //     final quantity = item['quantity'] ?? 0;
// //     final name = item['name'] ?? 'Unknown Item';
// //     final unit = item['unit'] ?? 'pcs';
// //     return '$quantity x $name ($unit)';
// //   }).join(', ');
// // }
// String _formatItems(List<dynamic> items) {
//   return items.map((item) {
//     final name = item['name'] ?? 'Unknown Item';
//     final isPipe = item['isPipe'] ?? false;
//     if (isPipe) {
//       // Handle pipe items
//       final pieces = item['pcs'] ?? 0;
//       final length = item['meters'] ?? 0.0;
//       return '$name - ${pieces > 0 ? '$pieces pcs' : ''}${pieces > 0 && length > 0 ? ', ' : ''}${length > 0 ? '$length m' : ''}';
//     } else {
//       // Handle regular items
//       final quantity = item['quantity'] ?? 0;
//       final unit = item['unit'] ?? 'pcs';
//       return '$name x $quantity ($unit)';
//     }
//   }).join(', ');
// }

// String _formatDate(DateTime date) {
//   final DateFormat formatter = DateFormat('MM/dd/yyyy hh:mm a');
//   return formatter.format(date);
// }

// void _editRequest(BuildContext context, Map<String, dynamic> request) {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (context) => Padding(
//       padding:
//           EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
//       child: EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     ),
//   );
// }

// Future<void> _deleteRequest(BuildContext context, String id) async {
//   bool confirmDelete = await showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       return AlertDialog(
//         title: Text('Confirm Delete'),
//         content: Text('Are you sure you want to delete this request?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: Text('Delete'),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//           ),
//         ],
//       );
//     },
//   );

//   if (confirmDelete == true) {
//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);

//       await requestProvider.cancelRequest(id, inventoryProvider);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';
// import 'package:intl/intl.dart';

// class UserPendingRequestsScreen extends StatefulWidget {
//   @override
//   _UserPendingRequestsScreenState createState() =>
//       _UserPendingRequestsScreenState();
// }

// class _UserPendingRequestsScreenState extends State<UserPendingRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//           child: Text('User information not available. Please log in again.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//         bottom: PreferredSize(
//           preferredSize: Size.fromHeight(kToolbarHeight),
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search by picker name or contact number',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.search),
//                 suffixIcon: IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     _searchController.clear();
//                     setState(() {
//                       _searchQuery = '';
//                     });
//                   },
//                 ),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//           ),
//         ),
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//               child: Text(
//                   'Error: Unable to fetch requests. Please try again later.'),
//             );
//           }

//           final pendingRequests = (snapshot.data ?? []).where((request) {
//             final String pickerName = request['pickerName'] ?? '';
//             final String pickerContact = request['pickerContact'] ?? '';
//             return pickerName
//                     .toLowerCase()
//                     .contains(_searchQuery.toLowerCase()) ||
//                 pickerContact.contains(_searchQuery);
//           }).toList();

//           if (pendingRequests.isEmpty) {
//             return Center(child: Text('No pending requests.'));
//           }

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(request['pickerName'] ?? 'Unknown Picker'),
//                   subtitle: Text(
//                     'Items: ${_formatItems(request['items'])}\n'
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Created: ${_formatDate(request['timestamp'])}',
//                   ),
//                   leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//                   onTap: () => _showRequestOptions(context, request),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }

//   String _formatDate(DateTime date) {
//     final DateFormat formatter = DateFormat('MM/dd/yyyy hh:mm a');
//     return formatter.format(date);
//   }

//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext bc) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setState) {
//             return Container(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'Request Details',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 16),
//                   ...(request['items'] as List<dynamic>).map((item) => ListTile(
//                         title: Text(
//                             '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                       )),
//                   SizedBox(height: 16),
//                   if (request['note'] != null &&
//                       request['note'].isNotEmpty) ...[
//                     Text('Note:',
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                     Text(request['note']),
//                     SizedBox(height: 16),
//                   ],
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () async {
//                       setState(() {
//                         request['isDeleting'] = true;
//                       });
//                       await _deleteRequest(context, request['id']);
//                       Navigator.of(context).pop();
//                     },
//                     child: request['isDeleting'] == true
//                         ? CircularProgressIndicator(color: Colors.white)
//                         : Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String id) async {
//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);

//       await requestProvider.cancelRequest(id, inventoryProvider);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class UserPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//           child: Text('User information not available. Please log in again.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//               child: Text(
//                   'Error: Unable to fetch requests. Please try again later.'),
//             );
//           }

//           final pendingRequests = snapshot.data ?? [];
//           print("Fetched ${pendingRequests.length} pending requests for user");

//           if (pendingRequests.isEmpty) {
//             return Center(child: Text('No pending requests.'));
//           }

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text('Items: ${_formatItems(request['items'])}'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Created: ${_formatDate(request['timestamp'])}',
//                   ),
//                   leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//                   onTap: () => _showRequestOptions(context, request),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
//   }

//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext bc) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setState) {
//             return Container(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'Request Details',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 16),
//                   ...(request['items'] as List<dynamic>).map((item) => ListTile(
//                         title: Text(
//                             '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                       )),
//                   SizedBox(height: 16),
//                   if (request['note'] != null &&
//                       request['note'].isNotEmpty) ...[
//                     Text('Note:',
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                     Text(request['note']),
//                     SizedBox(height: 16),
//                   ],
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () async {
//                       setState(() {
//                         request['isDeleting'] = true;
//                       });
//                       await _deleteRequest(context, request['id']);
//                       Navigator.of(context).pop();
//                     },
//                     child: request['isDeleting'] == true
//                         ? CircularProgressIndicator(color: Colors.white)
//                         : Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String id) async {
//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);

//       await requestProvider.cancelRequest(id, inventoryProvider);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class UserPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//             child:
//                 Text('User information not available. Please log in again.')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//                 child: Text(
//                     'Error: Unable to fetch requests. Please try again later.'));
//           }

//           final pendingRequests = snapshot.data ?? [];
//           print("Fetched ${pendingRequests.length} pending requests for user");

//           if (pendingRequests.isEmpty) {
//             return Center(child: Text('No pending requests.'));
//           }

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text('Items: ${_formatItems(request['items'])}'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Created: ${_formatDate(request['timestamp'])}',
//                   ),
//                   leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//                   onTap: () => _showRequestOptions(context, request),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
//   }

//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext bc) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setState) {
//             return Container(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     'Request Details',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 16),
//                   ...(request['items'] as List<dynamic>).map((item) => ListTile(
//                         title: Text(
//                             '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                       )),
//                   SizedBox(height: 16),
//                   if (request['note'] != null &&
//                       request['note'].isNotEmpty) ...[
//                     Text(
//                       'Note:',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     Text(request['note']),
//                     SizedBox(height: 16),
//                   ],
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () async {
//                       setState(() {
//                         // This setState is for the StatefulBuilder
//                         request['isDeleting'] = true;
//                       });
//                       await _deleteRequest(context, request['id']);
//                       Navigator.of(context).pop();
//                     },
//                     child: request['isDeleting'] == true
//                         ? CircularProgressIndicator(color: Colors.white)
//                         : Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String id) async {
//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);

//       await requestProvider.cancelRequest(id, inventoryProvider);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class UserPendingRequestsScreen extends StatefulWidget {
//   @override
//   _UserPendingRequestsScreenState createState() =>
//       _UserPendingRequestsScreenState();
// }

// class _UserPendingRequestsScreenState extends State<UserPendingRequestsScreen> {
//   bool _isDeleting = false;

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//             child:
//                 Text('User information not available. Please log in again.')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//                 child: Text(
//                     'Error: Unable to fetch requests. Please try again later.'));
//           }

//           final pendingRequests = snapshot.data ?? [];
//           print("Fetched ${pendingRequests.length} pending requests for user");

//           if (pendingRequests.isEmpty) {
//             return Center(child: Text('No pending requests.'));
//           }

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text('Items: ${_formatItems(request['items'])}'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Created: ${_formatDate(request['timestamp'])}',
//                   ),
//                   leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//                   onTap: () => _showRequestOptions(context, request),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
//   }

//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Request Details',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 16),
//               ...(request['items'] as List<dynamic>).map((item) => ListTile(
//                     title: Text(
//                         '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                   )),
//               SizedBox(height: 16),
//               if (request['note'] != null && request['note'].isNotEmpty) ...[
//                 Text(
//                   'Note:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 Text(request['note']),
//                 SizedBox(height: 16),
//               ],
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _editRequest(context, request);
//                 },
//                 child: Text('Edit Request'),
//               ),
//               ElevatedButton(
//                 onPressed: _isDeleting
//                     ? null
//                     : () {
//                         Navigator.of(context).pop();
//                         _deleteRequest(context, request['id']);
//                       },
//                 child: Text('Delete Request'),
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   Future<void> _deleteRequest(BuildContext context, String id) async {
//     setState(() {
//       _isDeleting = true;
//     });

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);

//       await requestProvider.cancelRequest(id, inventoryProvider);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Request deleted successfully')),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error deleting request: $e')),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isDeleting = false;
//         });
//       }
//     }
//   }
// }

// import 'package:dhavla_road_project/providers/inventory_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class UserPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     print("Current user email in UserPendingRequestsScreen: $currentUserEmail");
//     final userRole = authProvider.role;

//     if (currentUserEmail == null || userRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//             child:
//                 Text('User information not available. Please log in again.')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//                 child: Text(
//                     'Error: Unable to fetch requests. Please try again later.'));
//           }

//           final pendingRequests = snapshot.data ?? [];
//           print("Fetched ${pendingRequests.length} pending requests for user");

//           if (pendingRequests.isEmpty) {
//             return Center(child: Text('No pending requests.'));
//           }

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text('Items: ${_formatItems(request['items'])}'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Created: ${_formatDate(request['timestamp'])}',
//                   ),
//                   leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//                   onTap: () => _showRequestOptions(context, request),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }

//   String _formatDate(DateTime date) {
//     return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
//   }

//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Request Details',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 16),
//               ...(request['items'] as List<dynamic>).map((item) => ListTile(
//                     title: Text(
//                         '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                   )),
//               SizedBox(height: 16),
//               if (request['note'] != null && request['note'].isNotEmpty) ...[
//                 Text(
//                   'Note:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 Text(request['note']),
//                 SizedBox(height: 16),
//               ],
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _editRequest(context, request);
//                 },
//                 child: Text('Edit Request'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   _deleteRequest(context, request['id']);
//                 },
//                 child: Text('Delete Request'),
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

// //   Future<void> _deleteRequest(BuildContext context, String id) async {
// //     setState(() {
// //       _isDeleting = true;
// //     });

// //     try {
// //       final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
// //       final requestProvider = Provider.of<RequestProvider>(context, listen: false);

// //       await requestProvider.cancelRequest(id, inventoryProvider);

// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Request deleted successfully')),
// //         );
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Error deleting request: $e')),
// //         );
// //       }
// //     } finally {
// //       if (mounted) {
// //         setState(() {
// //           _isDeleting = false;
// //         });
// //       }
// //     }
// //   }
// // }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id) async {
//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false)
//           .cancelRequest(id, inventoryProvider);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting request: $e')),
//       );
//     }
//   }
// }
