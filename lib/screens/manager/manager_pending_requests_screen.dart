// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final managerRequests = requestProvider
//               .getRequestsByRole(currentUserRole!, currentUserEmail)
//               .where((request) {
//             return request['createdBy'] == currentUserEmail;
//           }).toList();

//           return ListView.builder(
//             itemCount: managerRequests.length,
//             itemBuilder: (context, index) {
//               final request = managerRequests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     if (request['createdBy'] == currentUserEmail ||
//                         currentUserRole == 'admin') {
//                       _showRequestOptions(
//                         context,
//                         request['id'], // Pass the request ID instead of index
//                         List<Map<String, dynamic>>.from(request['items']),
//                         request['location'] ?? 'Default Location',
//                         request['pickerName'] ?? '',
//                         request['pickerContact'] ?? '',
//                         request['note'] ?? '',
//                         request['createdBy'],
//                       );
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id, // Change index to id
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id, // Pass the request ID instead of index
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id,
//                           createdBy); // Pass the request ID instead of index
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id, // Change index to id
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id, // Pass the request ID instead of index
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id); // Use ID instead of index
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final managerRequests = requestProvider.requests.where((request) {
//             return request['status'] == 'pending' &&
//                 (request['createdBy'] == currentUserEmail ||
//                     request['role'] == 'user' ||
//                     currentUserRole == 'admin');
//           }).toList();

//           if (managerRequests.isEmpty) {
//             return Center(
//               child: Text('No pending requests found.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: managerRequests.length,
//             itemBuilder: (context, index) {
//               final request = managerRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     _showRequestOptions(
//                       context,
//                       request['id'],
//                       List<Map<String, dynamic>>.from(request['items']),
//                       request['location'] ?? 'Default Location',
//                       request['pickerName'] ?? '',
//                       request['pickerContact'] ?? '',
//                       request['note'] ?? '',
//                       request['createdBy'],
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id,
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id, createdBy);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_manager_request_bottom_sheet.dart';

class ManagerPendingRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;
    final currentUserRole = authProvider.role;

    if (currentUserEmail == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Pending Requests'),
        ),
        body: Center(
          child: Text('Error: Current user email is not available.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          final managerRequests = requestProvider.requests.where((request) {
            return request['status'] == 'pending';
          }).toList();

          if (managerRequests.isEmpty) {
            return Center(
              child: Text('No pending requests found.'),
            );
          }

          return ListView.builder(
            itemCount: managerRequests.length,
            itemBuilder: (context, index) {
              final request = managerRequests[index];
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}\n'
                    'Unique Code: ${request['uniqueCode']}',
                  ),
                  leading: Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                  onTap: () {
                    _showRequestOptions(
                      context,
                      request['id'],
                      List<Map<String, dynamic>>.from(request['items']),
                      request['location'] ?? 'Default Location',
                      request['pickerName'] ?? '',
                      request['pickerContact'] ?? '',
                      request['note'] ?? '',
                      request['createdBy'],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRequestOptions(
    BuildContext context,
    String id,
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
    String createdBy,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserRole = authProvider.role;
    final currentUserEmail = authProvider.currentUserEmail;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Request Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                ...items.map((item) => ListTile(
                      title: Text(
                          '${item['name']} x${item['quantity']} (${item['unit']})'),
                    )),
                SizedBox(height: 16),
                if (note.isNotEmpty) ...[
                  Text(
                    'Note:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(note),
                  SizedBox(height: 16),
                ],
                if (createdBy == currentUserEmail ||
                    currentUserRole == 'admin' ||
                    currentUserRole == 'manager') ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _editRequest(
                        context,
                        id,
                        items,
                        location,
                        pickerName,
                        pickerContact,
                        note,
                        createdBy,
                      );
                    },
                    child: Text('Edit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteRequest(context, id, createdBy);
                    },
                    child: Text('Delete Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  void _editRequest(
    BuildContext context,
    String id,
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
    String createdBy,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditManagerRequestBottomSheet(
        id: id,
        items: items,
        location: location,
        pickerName: pickerName,
        pickerContact: pickerContact,
        note: note,
        createdBy: createdBy,
      ),
    );
  }

  void _deleteRequest(BuildContext context, String id, String createdBy) {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    requestProvider.cancelRequest(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request deleted')),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final managerRequests = requestProvider.requests.where((request) {
//             return request['status'] == 'pending' &&
//                 (request['createdBy'] == currentUserEmail ||
//                     currentUserRole == 'admin' ||
//                     currentUserRole == 'manager' && request['role'] == 'user');
//           }).toList();

//           if (managerRequests.isEmpty) {
//             return Center(
//               child: Text('No pending requests found.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: managerRequests.length,
//             itemBuilder: (context, index) {
//               final request = managerRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     _showRequestOptions(
//                       context,
//                       request['id'],
//                       List<Map<String, dynamic>>.from(request['items']),
//                       request['location'] ?? 'Default Location',
//                       request['pickerName'] ?? '',
//                       request['pickerContact'] ?? '',
//                       request['note'] ?? '',
//                       request['createdBy'],
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id,
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id, createdBy);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final managerRequests = requestProvider.requests.where((request) {
//             return request['createdBy'] == currentUserEmail ||
//                 currentUserRole == 'admin' ||
//                 (currentUserRole == 'manager' && request['role'] == 'user');
//           }).toList();

//           if (managerRequests.isEmpty) {
//             return Center(
//               child: Text('No pending requests found.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: managerRequests.length,
//             itemBuilder: (context, index) {
//               final request = managerRequests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     _showRequestOptions(
//                       context,
//                       request['id'],
//                       List<Map<String, dynamic>>.from(request['items']),
//                       request['location'] ?? 'Default Location',
//                       request['pickerName'] ?? '',
//                       request['pickerContact'] ?? '',
//                       request['note'] ?? '',
//                       request['createdBy'],
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id,
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id, createdBy);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final managerRequests = requestProvider.requests.where((request) {
//             return request['createdBy'] == currentUserEmail ||
//                 currentUserRole == 'admin';
//           }).toList();

//           if (managerRequests.isEmpty) {
//             return Center(
//               child: Text('No pending requests found.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: managerRequests.length,
//             itemBuilder: (context, index) {
//               final request = managerRequests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     _showRequestOptions(
//                       context,
//                       request['id'],
//                       List<Map<String, dynamic>>.from(request['items']),
//                       request['location'] ?? 'Default Location',
//                       request['pickerName'] ?? '',
//                       request['pickerContact'] ?? '',
//                       request['note'] ?? '',
//                       request['createdBy'],
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id,
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id, createdBy);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final requests = requestProvider.getRequestsByRole(
//               currentUserRole!, currentUserEmail);
//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     if (request['createdBy'] == currentUserEmail ||
//                         currentUserRole == 'admin') {
//                       _showRequestOptions(
//                         context,
//                         request['id'], // Pass the request ID instead of index
//                         List<Map<String, dynamic>>.from(request['items']),
//                         request['location'] ?? 'Default Location',
//                         request['pickerName'] ?? '',
//                         request['pickerContact'] ?? '',
//                         request['note'] ?? '',
//                         request['createdBy'],
//                       );
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     String id, // Change index to id
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         id, // Pass the request ID instead of index
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, id,
//                           createdBy); // Pass the request ID instead of index
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     String id, // Change index to id
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => ManagerEditRequestBottomSheet(
//         id: id, // Pass the request ID instead of index
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(id); // Use ID instead of index
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;
//     final currentUserRole = authProvider.role;

//     if (currentUserEmail == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Pending Requests'),
//         ),
//         body: Center(
//           child: Text('Error: Current user email is not available.'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final requests = requestProvider.getRequestsByRole(
//               currentUserRole!, currentUserEmail);
//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     if (request['createdBy'] == currentUserEmail ||
//                         currentUserRole == 'admin') {
//                       _showRequestOptions(
//                         context,
//                         index,
//                         List<Map<String, dynamic>>.from(request['items']),
//                         request['location'] ?? 'Default Location',
//                         request['pickerName'] ?? '',
//                         request['pickerContact'] ?? '',
//                         request['note'] ?? '',
//                         request['createdBy'],
//                       );
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserRole = authProvider.role;
//     final currentUserEmail = authProvider.currentUserEmail;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 if (createdBy == currentUserEmail ||
//                     currentUserRole == 'admin') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         index,
//                         items,
//                         location,
//                         pickerName,
//                         pickerContact,
//                         note,
//                         createdBy,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, index, createdBy);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ]
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String createdBy,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => ManagerEditRequestBottomSheet(
//         index: index,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         createdBy: createdBy,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index, String createdBy) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     requestProvider.cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';
// // import 'manager_edit_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               final request = requestProvider.requests[index];
//               if (request['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () {
//                     if (request['createdBy'] == currentUserEmail) {
//                       _showRequestOptions(
//                         context,
//                         index,
//                         List<Map<String, dynamic>>.from(request['items']),
//                         request['location'] ?? 'Default Location',
//                         request['pickerName'] ?? '',
//                         request['pickerContact'] ?? '',
//                         request['note'] ?? '',
//                       );
//                     }
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _editRequest(
//                       context,
//                       index,
//                       items,
//                       location,
//                       pickerName,
//                       pickerContact,
//                       note,
//                     );
//                   },
//                   child: Text('Edit Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _deleteRequest(context, index);
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => ManagerEditRequestBottomSheet(
//         index: index,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';
// import '../../providers/auth_provider.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final currentUser =
//         Provider.of<AuthProvider>(context, listen: false).currentUser!.email;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final pendingRequests = requestProvider.requests
//               .where((request) => request['status'] == 'pending')
//               .toList();

//           return ListView.builder(
//             itemCount: pendingRequests.length,
//             itemBuilder: (context, index) {
//               final request = pendingRequests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () => _showRequestOptions(
//                     context,
//                     index,
//                     request,
//                     currentUser,
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     int index,
//     Map<String, dynamic> request,
//     String currentUser,
//   ) {
//     final isOwner = request['owner'] == currentUser;

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...request['items'].map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (request['note'].isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(request['note']),
//                   SizedBox(height: 16),
//                 ],
//                 if (isOwner) ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(
//                         context,
//                         index,
//                         request,
//                       );
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, index);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     int index,
//     Map<String, dynamic> request,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         index: index,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'],
//         pickerName: request['pickerName'],
//         pickerContact: request['pickerContact'],
//         note: request['note'],
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               if (requestProvider.requests[index]['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${requestProvider.requests[index]['location']}\n'
//                     'Picker: ${requestProvider.requests[index]['pickerName']}\n'
//                     'Contact: ${requestProvider.requests[index]['pickerContact']}\n'
//                     'Status: ${requestProvider.requests[index]['status']}\n'
//                     'Unique Code: ${requestProvider.requests[index]['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () => _showRequestOptions(
//                     context,
//                     index,
//                     List<Map<String, dynamic>>.from(
//                         requestProvider.requests[index]['items']),
//                     requestProvider.requests[index]['location'] ??
//                         'Default Location',
//                     requestProvider.requests[index]['pickerName'] ?? '',
//                     requestProvider.requests[index]['pickerContact'] ?? '',
//                     requestProvider.requests[index]['note'] ?? '',
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _editRequest(
//                       context,
//                       index,
//                       items,
//                       location,
//                       pickerName,
//                       pickerContact,
//                       note,
//                     );
//                   },
//                   child: Text('Edit Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _deleteRequest(context, index);
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         index: index,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_manager_request_bottom_sheet.dart';

// class ManagerPendingRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Pending Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               if (requestProvider.requests[index]['status'] != 'pending') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${requestProvider.requests[index]['location']}\n'
//                     'Picker: ${requestProvider.requests[index]['pickerName']}\n'
//                     'Contact: ${requestProvider.requests[index]['pickerContact']}\n'
//                     'Status: ${requestProvider.requests[index]['status']}\n'
//                     'Unique Code: ${requestProvider.requests[index]['uniqueCode']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () => _showRequestOptions(
//                     context,
//                     index,
//                     List<Map<String, dynamic>>.from(
//                         requestProvider.requests[index]['items']),
//                     requestProvider.requests[index]['location'] ??
//                         'Default Location',
//                     requestProvider.requests[index]['pickerName'] ?? '',
//                     requestProvider.requests[index]['pickerContact'] ?? '',
//                     requestProvider.requests[index]['note'] ?? '',
//                     requestProvider.requests[index]['status'],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _showRequestOptions(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String status,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Request Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 ...items.map((item) => ListTile(
//                       title: Text(
//                           '${item['name']} x${item['quantity']} (${item['unit']})'),
//                     )),
//                 SizedBox(height: 16),
//                 if (note.isNotEmpty) ...[
//                   Text(
//                     'Note:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text(note),
//                   SizedBox(height: 16),
//                 ],
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _editRequest(
//                       context,
//                       index,
//                       items,
//                       location,
//                       pickerName,
//                       pickerContact,
//                       note,
//                       status,
//                     );
//                   },
//                   child: Text('Edit Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor:
//                         status == 'pending' ? Colors.blue : Colors.grey,
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _deleteRequest(context, index);
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor:
//                         status == 'pending' ? Colors.red : Colors.grey,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _editRequest(
//     BuildContext context,
//     int index,
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//     String status,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         index: index,
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//         status: status,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     if (Provider.of<RequestProvider>(context, listen: false).requests[index]
//             ['status'] ==
//         'pending') {
//       Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request deleted')),
//       );
//     }
//   }
// }
