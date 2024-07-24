import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import 'edit_user_request_bottom_sheet.dart';

class UserPendingRequestsScreen extends StatelessWidget {
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
            child:
                Text('User information not available. Please log in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Requests'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: requestProvider.getUserPendingRequestsStream(currentUserEmail),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error fetching pending requests: ${snapshot.error}");
            return Center(
                child: Text(
                    'Error: Unable to fetch requests. Please try again later.'));
          }

          final pendingRequests = snapshot.data ?? [];
          print("Fetched ${pendingRequests.length} pending requests for user");

          if (pendingRequests.isEmpty) {
            return Center(child: Text('No pending requests.'));
          }

          return ListView.builder(
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final request = pendingRequests[index];
              return Card(
                child: ListTile(
                  title: Text('Items: ${_formatItems(request['items'])}'),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}\n'
                    'Unique Code: ${request['uniqueCode']}\n'
                    'Created: ${_formatDate(request['timestamp'])}',
                  ),
                  leading: Icon(Icons.hourglass_empty, color: Colors.orange),
                  onTap: () => _showRequestOptions(context, request),
                ),
              );
            },
          );
        },
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  void _showRequestOptions(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Request Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  ...(request['items'] as List<dynamic>).map((item) => ListTile(
                        title: Text(
                            '${item['name']} x${item['quantity']} (${item['unit'] ?? 'pcs'})'),
                      )),
                  SizedBox(height: 16),
                  if (request['note'] != null &&
                      request['note'].isNotEmpty) ...[
                    Text(
                      'Note:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(request['note']),
                    SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _editRequest(context, request);
                    },
                    child: Text('Edit Request'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        // This setState is for the StatefulBuilder
                        request['isDeleting'] = true;
                      });
                      await _deleteRequest(context, request['id']);
                      Navigator.of(context).pop();
                    },
                    child: request['isDeleting'] == true
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Delete Request'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editRequest(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditUserRequestBottomSheet(
        id: request['id'],
        items: List<Map<String, dynamic>>.from(request['items']),
        location: request['location'] ?? '',
        pickerName: request['pickerName'] ?? '',
        pickerContact: request['pickerContact'] ?? '',
        note: request['note'] ?? '',
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
