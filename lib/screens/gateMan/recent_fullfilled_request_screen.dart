import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';

class RecentFulfilledRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recent Fulfilled Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              Provider.of<RequestProvider>(context, listen: false)
                  .refreshFulfilledRequests();
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: Provider.of<RequestProvider>(context, listen: false)
            .refreshFulfilledRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          return Consumer<RequestProvider>(
            builder: (context, requestProvider, _) {
              final requests = requestProvider.fulfilledRequests;
              if (requests.isEmpty) {
                return _buildEmptyWidget(context, requestProvider);
              }
              return _buildRequestList(context, requests);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyWidget(
      BuildContext context, RequestProvider requestProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('No recent fulfilled requests found',
              style: TextStyle(fontSize: 18)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => requestProvider.refreshFulfilledRequests(),
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(
      BuildContext context, List<Map<String, dynamic>> requests) {
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(context, request);
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          'Request ID: ${request['id']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
            SizedBox(height: 4),
            Text('Picker: ${request['pickerName']}'),
            SizedBox(height: 4),
            Text('Items: ${_formatItems(request['items'])}'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () => _showRequestDetails(context, request),
      ),
    );
  }

  void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Request Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('ID', request['id']),
                _buildDetailRow('Status', request['status']),
                _buildDetailRow(
                    'Approved At', _formatTimestamp(request['approvedAt'])),
                _buildDetailRow(
                    'Fulfilled At', _formatTimestamp(request['fulfilledAt'])),
                _buildDetailRow('Location', request['location']),
                _buildDetailRow('Picker Name', request['pickerName']),
                _buildDetailRow('Picker Contact', request['pickerContact']),
                _buildDetailRow('Note', request['note']),
                SizedBox(height: 16),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...request['items']
                    .map<Widget>((item) => Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Text('${item['quantity']} x ${item['name']}'),
                        ))
                    .toList(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child:
                Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
    }
    return timestamp.toString();
  }

  String _formatItems(List<dynamic>? items) {
    if (items == null || items.isEmpty) return 'No items';
    return items
        .map((item) => '${item['quantity']} x ${item['name']}')
        .join(', ');
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';

// class RecentFulfilledRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Recent Fulfilled Requests'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () {
//               Provider.of<RequestProvider>(context, listen: false)
//                   .refreshFulfilledRequests();
//             },
//           ),
//         ],
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, _) {
//           return StreamBuilder<List<Map<String, dynamic>>>(
//             stream: requestProvider.getRecentFulfilledRequestsStream(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               }
//               if (snapshot.hasError) {
//                 return _buildErrorWidget(
//                     context, snapshot.error.toString(), requestProvider);
//               }
//               final requests = snapshot.data ?? [];
//               if (requests.isEmpty) {
//                 return _buildEmptyWidget(context, requestProvider);
//               }
//               return _buildRequestList(context, requests);
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildErrorWidget(
//       BuildContext context, String error, RequestProvider requestProvider) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, size: 60, color: Colors.red),
//           SizedBox(height: 16),
//           Text('Error: $error', style: TextStyle(fontSize: 18)),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () => requestProvider.refreshFulfilledRequests(),
//             child: Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyWidget(
//       BuildContext context, RequestProvider requestProvider) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.inbox, size: 60, color: Colors.grey),
//           SizedBox(height: 16),
//           Text('No recent fulfilled requests found',
//               style: TextStyle(fontSize: 18)),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () => requestProvider.refreshFulfilledRequests(),
//             child: Text('Refresh'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRequestList(
//       BuildContext context, List<Map<String, dynamic>> requests) {
//     return ListView.builder(
//       itemCount: requests.length,
//       itemBuilder: (context, index) {
//         final request = requests[index];
//         return _buildRequestCard(context, request);
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       elevation: 4,
//       child: ListTile(
//         contentPadding: EdgeInsets.all(16),
//         title: Text(
//           'Request ID: ${request['id']}',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SizedBox(height: 8),
//             Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             SizedBox(height: 4),
//             Text('Picker: ${request['pickerName']}'),
//             SizedBox(height: 4),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: Icon(Icons.arrow_forward_ios),
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 _buildDetailRow('ID', request['id']),
//                 _buildDetailRow('Status', request['status']),
//                 _buildDetailRow(
//                     'Approved At', _formatTimestamp(request['approvedAt'])),
//                 _buildDetailRow(
//                     'Fulfilled At', _formatTimestamp(request['fulfilledAt'])),
//                 _buildDetailRow('Location', request['location']),
//                 _buildDetailRow('Picker Name', request['pickerName']),
//                 _buildDetailRow('Picker Contact', request['pickerContact']),
//                 _buildDetailRow('Note', request['note']),
//                 SizedBox(height: 16),
//                 Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16, top: 8),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child:
//                 Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   String _formatTimestamp(dynamic timestamp) {
//     if (timestamp == null) return 'N/A';
//     if (timestamp is Timestamp) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//     }
//     if (timestamp is DateTime) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//     }
//     return timestamp.toString();
//   }

//   String _formatItems(List<dynamic>? items) {
//     if (items == null || items.isEmpty) return 'No items';
//     return items
//         .map((item) => '${item['quantity']} x ${item['name']}')
//         .join(', ');
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';

// class RecentFulfilledRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Recent Fulfilled Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, _) {
//           return StreamBuilder<List<Map<String, dynamic>>>(
//             stream: requestProvider.getRecentFulfilledRequestsStream(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               }
//               if (snapshot.hasError) {
//                 print("Error in stream: ${snapshot.error}");
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('Error: ${snapshot.error}'),
//                       ElevatedButton(
//                         onPressed: () {
//                           // Manually trigger a refresh
//                           requestProvider.refreshFulfilledRequests();
//                         },
//                         child: Text('Retry'),
//                       ),
//                     ],
//                   ),
//                 );
//               }
//               final requests = snapshot.data ?? [];
//               print("Fetched ${requests.length} fulfilled requests");
//               if (requests.isEmpty) {
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No recent fulfilled requests found.'),
//                       ElevatedButton(
//                         onPressed: () {
//                           // Manually trigger a refresh
//                           requestProvider.refreshFulfilledRequests();
//                         },
//                         child: Text('Refresh'),
//                       ),
//                     ],
//                   ),
//                 );
//               }
//               return ListView.builder(
//                 itemCount: requests.length,
//                 itemBuilder: (context, index) {
//                   final request = requests[index];
//                   return _buildRequestCard(context, request);
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ListTile(
//         title: Text('Request ID: ${request['id']}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 Text(
//                     'Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16.0),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   String _formatTimestamp(dynamic timestamp) {
//     if (timestamp == null) return 'N/A';
//     if (timestamp is Timestamp) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//     }
//     if (timestamp is DateTime) {
//       return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//     }
//     return timestamp.toString();
//   }

//   String _formatItems(List<dynamic>? items) {
//     if (items == null || items.isEmpty) return 'No items';
//     return items
//         .map((item) => '${item['quantity']} x ${item['name']}')
//         .join(', ');
//   }
// }
