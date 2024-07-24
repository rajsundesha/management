import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import 'edit_manager_request_bottom_sheet.dart';

class ManagerPendingRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;
    final currentUserRole = authProvider.role;

    print("Current user email: $currentUserEmail, role: $currentUserRole");

    if (currentUserEmail == null || currentUserRole == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Pending Requests')),
        body: Center(
            child:
                Text('User information not available. Please log in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Pending Requests')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<RequestProvider>(context, listen: false)
            .getUserPendingRequestsStream(currentUserEmail, currentUserRole),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error fetching pending requests: ${snapshot.error}");
            return Center(
                child:
                    Text('Error fetching pending requests. Please try again.'));
          }

          final requests = snapshot.data ?? [];
          print("Fetched ${requests.length} pending requests");

          if (requests.isEmpty) {
            return Center(child: Text('No pending requests found.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(context, request, currentUserEmail);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request,
      String currentUserEmail) {
    final timestamp = request['timestamp'];
    final DateTime dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : (timestamp is DateTime ? timestamp : DateTime.now());
    final formattedDate = DateFormat.yMMMd().add_jm().format(dateTime);

    return Card(
      child: ListTile(
        title: Text(
          'Items: ${_formatItems(request['items'])}',
        ),
        subtitle: Text(
          'Location: ${request['location'] ?? 'N/A'}\n'
          'Picker: ${request['pickerName'] ?? 'N/A'}\n'
          'Contact: ${request['pickerContact'] ?? 'N/A'}\n'
          'Status: ${request['status'] ?? 'N/A'}\n'
          'Unique Code: ${request['uniqueCode'] ?? 'N/A'}\n'
          'Date: $formattedDate\n'
          'Created by: ${request['createdByEmail'] ?? 'N/A'}',
        ),
        leading: Icon(Icons.hourglass_empty, color: Colors.orange),
        onTap: () => _showRequestOptions(context, request, currentUserEmail),
      ),
    );
  }

  String _formatItems(List<dynamic> items) {
    return items.map((item) {
      final quantity = item['quantity'] ?? 0;
      final name = item['name'] ?? 'Unknown Item';
      final unit = item['unit'] ?? 'pcs';
      return '$quantity x $name ($unit)';
    }).join(', ');
  }

  void _showRequestOptions(BuildContext context, Map<String, dynamic> request,
      String currentUserEmail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, controller) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: ListView(
                    controller: controller,
                    children: [
                      Text('Request Details',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      ...(request['items'] as List? ?? [])
                          .map((item) => ListTile(
                                title: Text(
                                    '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
                              )),
                      SizedBox(height: 16),
                      if (request['note'] != null &&
                          request['note'].isNotEmpty) ...[
                        Text('Note:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(request['note']),
                        SizedBox(height: 16),
                      ],
                      if (request['createdByEmail'] == currentUserEmail) ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _editRequest(context, request);
                          },
                          child: Text('Edit Request'),
                        ),
                        ElevatedButton(
                          onPressed: request['isDeleting'] == true
                              ? null
                              : () async {
                                  setState(() {
                                    request['isDeleting'] = true;
                                  });
                                  await _deleteRequest(context, request['id']);
                                  Navigator.of(context).pop();
                                },
                          child: request['isDeleting'] == true
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Delete Request'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _editRequest(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EditManagerRequestBottomSheet(
          id: request['id'],
          items: List<Map<String, dynamic>>.from(request['items'] ?? []),
          location: request['location'] ?? '',
          pickerName: request['pickerName'] ?? '',
          pickerContact: request['pickerContact'] ?? '',
          note: request['note'] ?? '',
          createdByEmail: request['createdByEmail'] ?? '',
        ),
      ),
    );
  }

  Future<void> _deleteRequest(BuildContext context, String id) async {
    try {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      final requestProvider =
          Provider.of<RequestProvider>(context, listen: false);

      await requestProvider.cancelRequest(id, inventoryProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting request: $e')),
      );
    }
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:dhavla_road_project/providers/inventory_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     print("Current user email: $currentUserEmail, role: $currentUserRole");

//     if (currentUserEmail == null || currentUserRole == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text('Pending Requests')),
//         body: Center(
//             child:
//                 Text('User information not available. Please log in again.')),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(title: Text('Pending Requests')),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: Provider.of<RequestProvider>(context, listen: false)
//             .getUserPendingRequestsStream(currentUserEmail, currentUserRole),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             print("Error fetching pending requests: ${snapshot.error}");
//             return Center(
//                 child:
//                     Text('Error fetching pending requests. Please try again.'));
//           }

//           final requests = snapshot.data ?? [];
//           print("Fetched ${requests.length} pending requests");

//           if (requests.isEmpty) {
//             return Center(child: Text('No pending requests found.'));
//           }

//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               return _buildRequestCard(context, request, currentUserEmail);
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request,
//       String currentUserEmail) {
//     final timestamp = request['timestamp'];
//     final DateTime dateTime = timestamp is Timestamp
//         ? timestamp.toDate()
//         : (timestamp is DateTime ? timestamp : DateTime.now());
//     final formattedDate = DateFormat.yMMMd().add_jm().format(dateTime);

//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${_formatItems(request['items'])}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location'] ?? 'N/A'}\n'
//           'Picker: ${request['pickerName'] ?? 'N/A'}\n'
//           'Contact: ${request['pickerContact'] ?? 'N/A'}\n'
//           'Status: ${request['status'] ?? 'N/A'}\n'
//           'Unique Code: ${request['uniqueCode'] ?? 'N/A'}\n'
//           'Date: $formattedDate\n'
//           'Created by: ${request['createdByEmail'] ?? 'N/A'}',
//         ),
//         leading: Icon(Icons.hourglass_empty, color: Colors.orange),
//         onTap: () => _showRequestOptions(context, request, currentUserEmail),
//       ),
//     );
//   }

//  String _formatItems(List<dynamic> items) {
//     return items.map((item) {
//       final quantity = item['quantity'] ?? 0;
//       final name = item['name'] ?? 'Unknown Item';
//       final unit = item['unit'] ?? 'pcs';
//       return '$quantity x $name ($unit)';
//     }).join(', ');
//   }


//   void _showRequestOptions(BuildContext context, Map<String, dynamic> request,
//       String currentUserEmail) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text('Request Details',
//                     style:
//                         TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                 SizedBox(height: 16),
//                 ...(request['items'] as List? ?? []).map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (request['note'] != null && request['note'].isNotEmpty) ...[
//                   Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text(request['note']),
//                   SizedBox(height: 16),
//                 ],
//                 if (request['createdByEmail'] == currentUserEmail) ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, request);
//                     },
//                     child: Text('Edit Request'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, request['id']);
//                     },
//                     child: Text('Delete Request'),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(BuildContext context, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: request['id'],
//         items: List<Map<String, dynamic>>.from(request['items'] ?? []),
//         location: request['location'] ?? '',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//         createdByEmail: request['createdByEmail'] ?? '',
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
