import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
// import '../providers/inventory_provider.dart';
// import '../providers/request_provider.dart';
import 'completed_requests_screen.dart';
import 'create_request_screen.dart';
// import 'edit_request_bottom_sheet.dart';
import 'edit_profile_screen.dart';
import 'pending_request_screen.dart'; // Assume you have an EditProfileScreen

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  // Map<String, int> _selectedItems = {};
  // String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      title: Text('Create New Request'),
                      leading: Icon(Icons.add_box),
                      onTap: () => _navigateToCreateRequest(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Pending Requests'),
                      leading: Icon(Icons.pending),
                      onTap: () => _navigateToPendingRequests(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Completed Requests'),
                      leading: Icon(Icons.check_circle),
                      onTap: () => _navigateToCompletedRequests(context),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: Text('Edit Profile'),
                      leading: Icon(Icons.person),
                      onTap: () => _navigateToEditProfile(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateRequestScreen()),
    );
  }

  void _navigateToPendingRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PendingRequestsScreen()),
    );
  }

  void _navigateToCompletedRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CompletedRequestsScreen()),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/auth_provider.dart';
// import '../providers/inventory_provider.dart';
// import '../providers/request_provider.dart';
// import 'edit_request_bottom_sheet.dart';

// class UserDashboard extends StatefulWidget {
//   @override
//   _UserDashboardState createState() => _UserDashboardState();
// }

// class _UserDashboardState extends State<UserDashboard>
//     with SingleTickerProviderStateMixin {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';
//   TabController? _tabController;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController?.dispose();
//     super.dispose();
//   }

//   void _showRequestOptions(BuildContext context, int index,
//       List<Map<String, dynamic>> items, String status) {
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
//                 ...items
//                     .map((item) => ListTile(
//                           title: Text('${item['name']} x${item['quantity']}'),
//                         ))
//                     .toList(),
//                 SizedBox(height: 16),
//                 if (status == 'pending') ...[
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _editRequest(context, index, items);
//                     },
//                     child: Text('Edit Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue, // Consistent button color
//                     ),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       _deleteRequest(context, index);
//                     },
//                     child: Text('Delete Request'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red, // Consistent button color
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
//       BuildContext context, int index, List<Map<String, dynamic>> items) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditRequestBottomSheet(index: index, items: items),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Dashboard'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: () {
//               Provider.of<AuthProvider>(context, listen: false).logout();
//               Navigator.pushReplacementNamed(context, '/');
//             },
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: [
//             Tab(text: 'New Request'),
//             Tab(text: 'Pending Requests'),
//             Tab(text: 'Completed Requests'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildNewRequestTab(context),
//           _buildRequestList(context, 'pending'),
//           _buildRequestList(context, 'completed'),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//         },
//         child: Icon(Icons.refresh),
//       ),
//     );
//   }

//   Widget _buildNewRequestTab(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: <Widget>[
//           TextField(
//             decoration: InputDecoration(
//               labelText: 'Search',
//               border: OutlineInputBorder(),
//               prefixIcon: Icon(Icons.search),
//             ),
//             onChanged: (value) {
//               setState(() {
//                 _searchQuery = value;
//               });
//             },
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Inventory List',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 8),
//           Expanded(
//             child: Consumer<InventoryProvider>(
//               builder: (context, inventoryProvider, child) {
//                 List<String> filteredItems = inventoryProvider.items
//                     .where((item) =>
//                         item.toLowerCase().contains(_searchQuery.toLowerCase()))
//                     .toList();
//                 return ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     String item = filteredItems[index];
//                     return Card(
//                       child: ListTile(
//                         title: Text(item),
//                         trailing: _selectedItems.containsKey(item)
//                             ? Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   IconButton(
//                                     icon: Icon(Icons.remove),
//                                     onPressed: () {
//                                       setState(() {
//                                         if (_selectedItems[item] == 1) {
//                                           _selectedItems.remove(item);
//                                         } else {
//                                           _selectedItems[item] =
//                                               _selectedItems[item]! - 1;
//                                         }
//                                       });
//                                     },
//                                   ),
//                                   Text('${_selectedItems[item]}'),
//                                   IconButton(
//                                     icon: Icon(Icons.add),
//                                     onPressed: () {
//                                       setState(() {
//                                         _selectedItems[item] =
//                                             _selectedItems[item]! + 1;
//                                       });
//                                     },
//                                   ),
//                                 ],
//                               )
//                             : IconButton(
//                                 icon: Icon(Icons.add),
//                                 onPressed: () {
//                                   setState(() {
//                                     _selectedItems[item] = 1;
//                                   });
//                                 },
//                               ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Selected Items',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 8),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _selectedItems.length,
//               itemBuilder: (context, index) {
//                 String item = _selectedItems.keys.elementAt(index);
//                 int quantity = _selectedItems[item]!;
//                 return Card(
//                   child: ListTile(
//                     title: Text('$item x$quantity'),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.remove),
//                           onPressed: () {
//                             setState(() {
//                               if (_selectedItems[item] == 1) {
//                                 _selectedItems.remove(item);
//                               } else {
//                                 _selectedItems[item] =
//                                     _selectedItems[item]! - 1;
//                               }
//                             });
//                           },
//                         ),
//                         Container(
//                           width: 40,
//                           child: TextField(
//                             keyboardType: TextInputType.number,
//                             onChanged: (value) {
//                               setState(() {
//                                 _selectedItems[item] = int.tryParse(value) ?? 1;
//                               });
//                             },
//                             decoration: InputDecoration(
//                               contentPadding: EdgeInsets.symmetric(
//                                   vertical: 8, horizontal: 8),
//                               isDense: true,
//                               border: OutlineInputBorder(),
//                             ),
//                             controller: TextEditingController()
//                               ..text = quantity.toString(),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add),
//                           onPressed: () {
//                             setState(() {
//                               _selectedItems[item] = _selectedItems[item]! + 1;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.remove_circle, color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               _selectedItems.remove(item);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           SizedBox(height: 16),
//           Center(
//             child: ElevatedButton(
//               onPressed: _selectedItems.isEmpty
//                   ? null
//                   : () {
//                       List<Map<String, dynamic>> requestItems =
//                           _selectedItems.entries
//                               .map((entry) => {
//                                     'name': entry.key,
//                                     'quantity': entry.value,
//                                   })
//                               .toList();
//                       Provider.of<RequestProvider>(context, listen: false)
//                           .addRequest(requestItems);
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                               'Request added for ${_selectedItems.entries.map((e) => '${e.value} x ${e.key}').join(', ')}'),
//                         ),
//                       );
//                       setState(() {
//                         _selectedItems.clear();
//                       });
//                     },
//               child: Text('Send Request'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     _selectedItems.isEmpty ? Colors.grey : Colors.blue,
//                 padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRequestList(BuildContext context, String statusFilter) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, child) {
//         List<Map<String, dynamic>> filteredRequests = requestProvider.requests
//             .where((request) =>
//                 request['status'] == statusFilter ||
//                 (statusFilter == 'completed' &&
//                     request['status'] != 'pending' &&
//                     DateTime.now().difference(request['timestamp']).inDays < 1))
//             .toList();
//         return ListView.builder(
//           itemCount: filteredRequests.length,
//           itemBuilder: (context, index) {
//             return Card(
//               child: ListTile(
//                 title: Text(
//                   'Items: ${filteredRequests[index]['items'].map((item) => '${item['quantity']} x ${item['name']}').join(', ')}',
//                 ),
//                 subtitle: Text(
//                   'Status: ${filteredRequests[index]['status']}',
//                 ),
//                 leading: Icon(
//                   filteredRequests[index]['status'] == 'approved'
//                       ? Icons.check_circle
//                       : filteredRequests[index]['status'] == 'rejected'
//                           ? Icons.cancel
//                           : Icons.hourglass_empty,
//                   color: filteredRequests[index]['status'] == 'approved'
//                       ? Colors.green
//                       : filteredRequests[index]['status'] == 'rejected'
//                           ? Colors.red
//                           : Colors.orange,
//                 ),
//                 onTap: () => _showRequestOptions(
//                     context,
//                     index,
//                     List<Map<String, dynamic>>.from(
//                         filteredRequests[index]['items']),
//                     filteredRequests[index]['status']),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/auth_provider.dart';
// import '../providers/inventory_provider.dart';
// import '../providers/request_provider.dart';
// import 'edit_request_bottom_sheet.dart';

// class UserDashboard extends StatefulWidget {
//   @override
//   _UserDashboardState createState() => _UserDashboardState();
// }

// class _UserDashboardState extends State<UserDashboard> {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';

//   void _showRequestOptions(
//       BuildContext context, int index, List<Map<String, dynamic>> items) {
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
//                 ...items
//                     .map((item) => ListTile(
//                           title: Text('${item['name']} x${item['quantity']}'),
//                         ))
//                     .toList(),
//                 SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _editRequest(context, index, items);
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
//       BuildContext context, int index, List<Map<String, dynamic>> items) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditRequestBottomSheet(index: index, items: items),
//     );
//   }

//   void _deleteRequest(BuildContext context, int index) {
//     Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Request deleted')),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('User Dashboard'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: () {
//               Provider.of<AuthProvider>(context, listen: false).logout();
//               Navigator.pushReplacementNamed(context, '/');
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             TextField(
//               decoration: InputDecoration(
//                 labelText: 'Search',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.search),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Inventory List',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Expanded(
//               child: Consumer<InventoryProvider>(
//                 builder: (context, inventoryProvider, child) {
//                   List<String> filteredItems = inventoryProvider.items
//                       .where((item) => item
//                           .toLowerCase()
//                           .contains(_searchQuery.toLowerCase()))
//                       .toList();
//                   return ListView.builder(
//                     itemCount: filteredItems.length,
//                     itemBuilder: (context, index) {
//                       String item = filteredItems[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text(item),
//                           trailing: _selectedItems.containsKey(item)
//                               ? Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     IconButton(
//                                       icon: Icon(Icons.remove),
//                                       onPressed: () {
//                                         setState(() {
//                                           if (_selectedItems[item] == 1) {
//                                             _selectedItems.remove(item);
//                                           } else {
//                                             _selectedItems[item] =
//                                                 _selectedItems[item]! - 1;
//                                           }
//                                         });
//                                       },
//                                     ),
//                                     Text('${_selectedItems[item]}'),
//                                     IconButton(
//                                       icon: Icon(Icons.add),
//                                       onPressed: () {
//                                         setState(() {
//                                           _selectedItems[item] =
//                                               _selectedItems[item]! + 1;
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 )
//                               : IconButton(
//                                   icon: Icon(Icons.add),
//                                   onPressed: () {
//                                     setState(() {
//                                       _selectedItems[item] = 1;
//                                     });
//                                   },
//                                 ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Selected Items',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _selectedItems.length,
//                 itemBuilder: (context, index) {
//                   String item = _selectedItems.keys.elementAt(index);
//                   int quantity = _selectedItems[item]!;
//                   return Card(
//                     child: ListTile(
//                       title: Text('$item x$quantity'),
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(
//                             icon: Icon(Icons.remove),
//                             onPressed: () {
//                               setState(() {
//                                 if (_selectedItems[item] == 1) {
//                                   _selectedItems.remove(item);
//                                 } else {
//                                   _selectedItems[item] =
//                                       _selectedItems[item]! - 1;
//                                 }
//                               });
//                             },
//                           ),
//                           Container(
//                             width: 40,
//                             child: TextField(
//                               keyboardType: TextInputType.number,
//                               onChanged: (value) {
//                                 setState(() {
//                                   _selectedItems[item] =
//                                       int.tryParse(value) ?? 1;
//                                 });
//                               },
//                               decoration: InputDecoration(
//                                 contentPadding: EdgeInsets.symmetric(
//                                     vertical: 8, horizontal: 8),
//                                 isDense: true,
//                                 border: OutlineInputBorder(),
//                               ),
//                               controller: TextEditingController()
//                                 ..text = quantity.toString(),
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.add),
//                             onPressed: () {
//                               setState(() {
//                                 _selectedItems[item] =
//                                     _selectedItems[item]! + 1;
//                               });
//                             },
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.remove_circle, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 _selectedItems.remove(item);
//                               });
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: _selectedItems.isEmpty
//                     ? null
//                     : () {
//                         List<Map<String, dynamic>> requestItems =
//                             _selectedItems.entries
//                                 .map((entry) => {
//                                       'name': entry.key,
//                                       'quantity': entry.value,
//                                     })
//                                 .toList();
//                         Provider.of<RequestProvider>(context, listen: false)
//                             .addRequest(requestItems);
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text(
//                                 'Request added for ${_selectedItems.entries.map((e) => '${e.value} x ${e.key}').join(', ')}'),
//                           ),
//                         );
//                         setState(() {
//                           _selectedItems.clear();
//                         });
//                       },
//                 child: Text('Send Request'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       _selectedItems.isEmpty ? Colors.grey : Colors.blue,
//                   padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                 ),
//               ),
//             ),
//             SizedBox(height: 16),
//             Divider(),
//             SizedBox(height: 16),
//             Text(
//               'Request Status',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Expanded(
//               child: Consumer<RequestProvider>(
//                 builder: (context, requestProvider, child) {
//                   return ListView.builder(
//                     itemCount: requestProvider.requests.length,
//                     itemBuilder: (context, index) {
//                       return Card(
//                         child: ListTile(
//                           title: Text(
//                             'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} x ${item['name']}').join(', ')}',
//                           ),
//                           subtitle: Text(
//                             'Status: ${requestProvider.requests[index]['status']}',
//                           ),
//                           leading: Icon(
//                             requestProvider.requests[index]['status'] ==
//                                     'approved'
//                                 ? Icons.check_circle
//                                 : requestProvider.requests[index]['status'] ==
//                                         'rejected'
//                                     ? Icons.cancel
//                                     : Icons.hourglass_empty,
//                             color: requestProvider.requests[index]['status'] ==
//                                     'approved'
//                                 ? Colors.green
//                                 : requestProvider.requests[index]['status'] ==
//                                         'rejected'
//                                     ? Colors.red
//                                     : Colors.orange,
//                           ),
//                           onTap: () => _showRequestOptions(
//                               context,
//                               index,
//                               List<Map<String, dynamic>>.from(
//                                   requestProvider.requests[index]['items'])),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//         },
//         child: Icon(Icons.refresh),
//       ),
//     );
//   }
// }
