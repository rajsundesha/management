import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import 'edit_admin_request_bottom_sheet.dart';

class ManageRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          return ListView.builder(
            itemCount: requestProvider.requests.length,
            itemBuilder: (context, index) {
              final request = requestProvider.requests[index];
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}',
                  ),
                  leading: Icon(
                    Icons.request_page,
                    color: request['status'] == 'pending'
                        ? Colors.orange
                        : Colors.green,
                  ),
                  trailing: _buildActionButtons(
                      context, requestProvider, request['id']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, RequestProvider requestProvider, String requestId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.check, color: Colors.green),
          onPressed: () {
            requestProvider.updateRequestStatus(requestId, 'approved');
          },
        ),
        IconButton(
          icon: Icon(Icons.close, color: Colors.red),
          onPressed: () {
            requestProvider.updateRequestStatus(requestId, 'rejected');
          },
        ),
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: () {
            final request = requestProvider.getRequestById(requestId);
            if (request != null) {
              _editRequest(context, requestId, request);
            }
          },
        ),
      ],
    );
  }

  void _editRequest(
      BuildContext context, String requestId, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditAdminRequestBottomSheet(
        id: requestId,
        items: List<Map<String, dynamic>>.from(request['items']),
        location: request['location'] ?? 'Default Location',
        pickerName: request['pickerName'] ?? '',
        pickerContact: request['pickerContact'] ?? '',
        note: request['note'] ?? '',
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class ManageRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               final request = requestProvider.requests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.request_page,
//                     color: request['status'] == 'pending'
//                         ? Colors.orange
//                         : Colors.green,
//                   ),
//                   trailing:
//                       _buildActionButtons(context, requestProvider, index),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, int index) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             _editRequest(context, index, requestProvider.requests[index]);
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, int index, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         index: index,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class ManageRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               final request = requestProvider.requests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.request_page,
//                     color: request['status'] == 'pending'
//                         ? Colors.orange
//                         : Colors.green,
//                   ),
//                   trailing:
//                       _buildActionButtons(context, requestProvider, index),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, int index) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             _editRequest(context, index, requestProvider.requests[index]);
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, int index, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         index: index,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }
// }


// // import 'package:dhavla_road_project/screens/user/edit_user_request_bottom_sheet.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';
// // import 'edit_request_bottom_sheet.dart';

// class ManageRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               final request = requestProvider.requests[index];
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.request_page,
//                     color: request['status'] == 'pending'
//                         ? Colors.orange
//                         : Colors.green,
//                   ),
//                   trailing:
//                       _buildActionButtons(context, requestProvider, index),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, int index) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(index, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             _editRequest(context, index, requestProvider.requests[index]);
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, int index, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         index: index,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }
// }
