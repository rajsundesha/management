import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class CompletedRequestsScreen extends StatefulWidget {
  @override
  _CompletedRequestsScreenState createState() =>
      _CompletedRequestsScreenState();
}

class _CompletedRequestsScreenState extends State<CompletedRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildSearchBar(),
          ),
          _buildCompletedRequestsList(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Completed Requests'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.green.shade400, Colors.green.shade800],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by picker name or contact',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade200,
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade600),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCompletedRequestsList() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, child) {
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(Duration(days: 7));
        final completedRequests = requestProvider.requests
            .where((request) =>
                request['status'] == 'fulfilled' &&
                (request['timestamp'] as DateTime).isAfter(sevenDaysAgo) &&
                (_searchQuery.isEmpty ||
                    request['pickerName']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    request['pickerContact']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())))
            .toList();

        if (completedRequests.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No completed requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'in the last 7 days',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final request = completedRequests[index];
              return _buildRequestCard(request);
            },
            childCount: completedRequests.length,
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final DateTime timestamp = request['timestamp'] as DateTime;
    final String formattedDate =
        DateFormat('dd/MM/yyyy hh:mm a').format(timestamp);

    return Slidable(
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showRequestDetails(request),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.info,
            label: 'Details',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          title: Text(
            request['pickerName'],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text('Location: ${request['location']}'),
              Text('Contact: ${request['pickerContact']}'),
              Text('Completed On: $formattedDate'),
              Text('Items: ${request['items'].length} items'),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white),
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _showRequestDetails(request),
        ),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Request Details',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildDetailItem('Picker', request['pickerName']),
                    _buildDetailItem('Location', request['location']),
                    _buildDetailItem('Contact', request['pickerContact']),
                    _buildDetailItem('Status', request['status']),
                    _buildDetailItem('Unique Code', request['uniqueCode']),
                    _buildDetailItem(
                        'Completed On',
                        DateFormat('dd/MM/yyyy hh:mm a')
                            .format(request['timestamp'])),
                    SizedBox(height: 16),
                    Text(
                      'Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...(request['items'] as List<dynamic>)
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                  '${item['quantity']} ${item['unit']} of ${item['name']}'),
                            )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';

// class CompletedRequestsScreen extends StatefulWidget {
//   @override
//   _CompletedRequestsScreenState createState() =>
//       _CompletedRequestsScreenState();
// }

// class _CompletedRequestsScreenState extends State<CompletedRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Completed Requests'),
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
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final now = DateTime.now();
//           final sevenDaysAgo = now.subtract(Duration(days: 7));
//           final completedRequests = requestProvider.requests
//               .where((request) =>
//                   request['status'] == 'fulfilled' &&
//                   (request['timestamp'] as DateTime).isAfter(sevenDaysAgo) &&
//                   (_searchQuery.isEmpty ||
//                       request['pickerName']
//                           .toString()
//                           .toLowerCase()
//                           .contains(_searchQuery.toLowerCase()) ||
//                       request['pickerContact']
//                           .toString()
//                           .toLowerCase()
//                           .contains(_searchQuery.toLowerCase())))
//               .toList();

//           if (completedRequests.isEmpty) {
//             return Center(
//               child: Text('No completed requests in the last 7 days.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: completedRequests.length,
//             itemBuilder: (context, index) {
//               final request = completedRequests[index];
//               final items = request['items'];
//               final itemCount = items.length;

//               final DateTime timestamp = request['timestamp'] as DateTime;
//               final String formattedDate =
//                   DateFormat('dd/MM/yyyy hh:mm a').format(timestamp);

//               return Card(
//                 child: ExpansionTile(
//                   title: Text('Picker: ${request['pickerName']}'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Completed On: $formattedDate\n'
//                     'Items: $itemCount items',
//                   ),
//                   leading: Icon(
//                     Icons.check_circle,
//                     color: Colors.green,
//                   ),
//                   children: items.map<Widget>((item) {
//                     return ListTile(
//                       title: Text(
//                           '${item['quantity']} ${item['unit']} of ${item['name']}'),
//                     );
//                   }).toList(),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';

// class CompletedRequestsScreen extends StatefulWidget {
//   @override
//   _CompletedRequestsScreenState createState() =>
//       _CompletedRequestsScreenState();
// }

// class _CompletedRequestsScreenState extends State<CompletedRequestsScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Completed Requests'),
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
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           final now = DateTime.now();
//           final sevenDaysAgo = now.subtract(Duration(days: 7));
//           final completedRequests = requestProvider.requests
//               .where((request) =>
//                   request['status'] == 'fulfilled' &&
//                   (request['timestamp'] as DateTime).isAfter(sevenDaysAgo) &&
//                   (_searchQuery.isEmpty ||
//                       request['pickerName']
//                           .toString()
//                           .toLowerCase()
//                           .contains(_searchQuery.toLowerCase()) ||
//                       request['pickerContact']
//                           .toString()
//                           .toLowerCase()
//                           .contains(_searchQuery.toLowerCase())))
//               .toList();

//           if (completedRequests.isEmpty) {
//             return Center(
//               child: Text('No completed requests in the last 7 days.'),
//             );
//           }

//           return ListView.builder(
//             itemCount: completedRequests.length,
//             itemBuilder: (context, index) {
//               final request = completedRequests[index];
//               final items = request['items'];
//               final itemCount = items.length;

//               final DateTime timestamp = request['timestamp'] as DateTime;
//               final String formattedDate =
//                   DateFormat('dd/MM/yyyy hh:mm a').format(timestamp);

//               return Card(
//                 child: ExpansionTile(
//                   title: Text('Items: $itemCount items'),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}\n'
//                     'Unique Code: ${request['uniqueCode']}\n'
//                     'Completed On: $formattedDate',
//                   ),
//                   leading: Icon(
//                     Icons.check_circle,
//                     color: Colors.green,
//                   ),
//                   children: items.map<Widget>((item) {
//                     return ListTile(
//                       title: Text(
//                           '${item['quantity']} ${item['unit']} of ${item['name']}'),
//                     );
//                   }).toList(),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
// }


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
//               if (requestProvider.requests[index]['status'] != 'fulfilled') {
//                 return Container();
//               }
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} ${item['unit']} of ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${requestProvider.requests[index]['location']}\n'
//                     'Picker: ${requestProvider.requests[index]['pickerName']}\n'
//                     'Contact: ${requestProvider.requests[index]['pickerContact']}\n'
//                     'Status: ${requestProvider.requests[index]['status']}\n'
//                     'Unique Code: ${requestProvider.requests[index]['uniqueCode']}',
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
