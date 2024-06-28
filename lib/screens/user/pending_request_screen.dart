// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class PendingRequestsScreen extends StatelessWidget {
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
//       builder: (context) => EditUserRequestBottomSheet(
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
// import 'edit_user_request_bottom_sheet.dart';

// class PendingRequestsScreen extends StatelessWidget {
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
//                     'Status: ${requestProvider.requests[index]['status']}',
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
//                     backgroundColor: Colors.blue, // Consistent button color
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _deleteRequest(context, index);
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red, // Consistent button color
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
//       builder: (context) => EditUserRequestBottomSheet(
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_user_request_bottom_sheet.dart';

class PendingRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          final userRequests = requestProvider.requests.where((request) {
            return request['createdBy'] == currentUserEmail;
          }).toList();

          return ListView.builder(
            itemCount: userRequests.length,
            itemBuilder: (context, index) {
              final request = userRequests[index];
              if (request['status'] != 'pending') {
                return Container();
              }
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${request['items'].map((item) => '${item['quantity']} x ${item['name']} (${item['unit']})').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}',
                  ),
                  leading: Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                  onTap: () => _showRequestOptions(
                    context,
                    request['id'], // Use request ID
                    List<Map<String, dynamic>>.from(request['items']),
                    request['location'] ?? 'Default Location',
                    request['pickerName'] ?? '',
                    request['pickerContact'] ?? '',
                    request['note'] ?? '',
                  ),
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
    String id, // Use request ID
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
  ) {
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editRequest(
                      context,
                      id, // Use request ID
                      items,
                      location,
                      pickerName,
                      pickerContact,
                      note,
                    );
                  },
                  child: Text('Edit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Consistent button color
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteRequest(context, id); // Use request ID
                  },
                  child: Text('Delete Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Consistent button color
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editRequest(
    BuildContext context,
    String id, // Use request ID
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditUserRequestBottomSheet(
        id: id, // Use request ID
        items: items,
        location: location,
        pickerName: pickerName,
        pickerContact: pickerContact,
        note: note,
      ),
    );
  }

  void _deleteRequest(BuildContext context, String id) {
    Provider.of<RequestProvider>(context, listen: false)
        .cancelRequest(id); // Use ID instead of index
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request deleted')),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_user_request_bottom_sheet.dart';

// class PendingRequestsScreen extends StatelessWidget {
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
//                     'Status: ${request['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.hourglass_empty,
//                     color: Colors.orange,
//                   ),
//                   onTap: () => _showRequestOptions(
//                     context,
//                     request['id'], // Use request ID
//                     List<Map<String, dynamic>>.from(request['items']),
//                     request['location'] ?? 'Default Location',
//                     request['pickerName'] ?? '',
//                     request['pickerContact'] ?? '',
//                     request['note'] ?? '',
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
//     String id, // Use request ID
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
//                       id, // Use request ID
//                       items,
//                       location,
//                       pickerName,
//                       pickerContact,
//                       note,
//                     );
//                   },
//                   child: Text('Edit Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue, // Consistent button color
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _deleteRequest(context, id); // Use request ID
//                   },
//                   child: Text('Delete Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red, // Consistent button color
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
//     String id, // Use request ID
//     List<Map<String, dynamic>> items,
//     String location,
//     String pickerName,
//     String pickerContact,
//     String note,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditUserRequestBottomSheet(
//         id: id, // Use request ID
//         items: items,
//         location: location,
//         pickerName: pickerName,
//         pickerContact: pickerContact,
//         note: note,
//       ),
//     );
//   }

//   void _deleteRequest(BuildContext context, String id) {
//     Provider.of<RequestProvider>(context, listen: false)
//         .cancelRequest(id); // Use ID instead of index
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }
// }
