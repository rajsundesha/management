import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class CompletedRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Completed Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          return ListView.builder(
            itemCount: requestProvider.requests.length,
            itemBuilder: (context, index) {
              if (requestProvider.requests[index]['status'] != 'fulfilled') {
                return Container();
              }
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} ${item['unit']} of ${item['name']}').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${requestProvider.requests[index]['location']}\n'
                    'Picker: ${requestProvider.requests[index]['pickerName']}\n'
                    'Contact: ${requestProvider.requests[index]['pickerContact']}\n'
                    'Status: ${requestProvider.requests[index]['status']}\n'
                    'Unique Code: ${requestProvider.requests[index]['uniqueCode']}',
                  ),
                  leading: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';

// class CompletedRequestsScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Completed Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               if (requestProvider.requests[index]['status'] != 'approved') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} ${item['unit']} of ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Status: ${requestProvider.requests[index]['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.check_circle,
//                     color: Colors.green,
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
