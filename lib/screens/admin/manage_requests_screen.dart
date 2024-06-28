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
//                   trailing: _buildActionButtons(
//                       context, requestProvider, request['id']),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, String requestId) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             final request = requestProvider.getRequestById(requestId);
//             if (request != null) {
//               _editRequest(context, requestId, request);
//             }
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../providers/request_provider.dart';
import 'edit_admin_request_bottom_sheet.dart';

class ManageRequestsScreen extends StatefulWidget {
  @override
  _ManageRequestsScreenState createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _filterLocation = 'All';
  DateTime _selectedDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  final List<String> _locations = [
    'All',
    'Location1',
    'Location2',
    'Location3'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _exportData(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            SizedBox(height: 16),
            _buildFilterRow(),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<RequestProvider>(
                builder: (context, requestProvider, child) {
                  final requests = requestProvider.requests.where((request) {
                    final requestDate = (request['timestamp'] as DateTime);
                    final matchesDate =
                        requestDate.year == _selectedDate.year &&
                            requestDate.month == _selectedDate.month &&
                            requestDate.day == _selectedDate.day;
                    final matchesSearch = request['pickerName']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                    final matchesFilter = _filterStatus == 'All' ||
                        request['status'] == _filterStatus.toLowerCase();
                    final matchesLocation = _filterLocation == 'All' ||
                        request['location'] == _filterLocation;
                    return matchesDate &&
                        matchesSearch &&
                        matchesFilter &&
                        matchesLocation;
                  }).toList();

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search by Picker Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(child: _buildFilterDropdown()),
        SizedBox(width: 16),
        Expanded(child: _buildLocationFilterDropdown()),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Filter by Status',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          onChanged: (newValue) {
            setState(() {
              _filterStatus = newValue!;
            });
          },
          items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationFilterDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Filter by Location',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterLocation,
          onChanged: (newValue) {
            setState(() {
              _filterLocation = newValue!;
            });
          },
          items: _locations.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate)
      setState(() {
        _selectedDate = picked;
      });
  }

  void _exportData(BuildContext context) async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final csvData =
        ListToCsvConverter().convert(requestProvider.requests.map((request) {
      return [
        request['id'],
        request['items']
            .map((item) =>
                '${item['quantity']} ${item['unit']} x ${item['name']}')
            .join(', '),
        request['location'],
        request['pickerName'],
        request['pickerContact'],
        request['status'],
        (request['timestamp'] as DateTime).toIso8601String(),
      ];
    }).toList());

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/requests_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csvData);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Data exported to $path')));
      OpenFile.open(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File saving not supported on this platform')));
    }
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


// import 'dart:io';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import 'package:csv/csv.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class ManageRequestsScreen extends StatefulWidget {
//   @override
//   _ManageRequestsScreenState createState() => _ManageRequestsScreenState();
// }

// class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
//   String _searchQuery = '';
//   String _filterStatus = 'All';
//   String _filterLocation = 'All';
//   DateTime _selectedDate = DateTime.now();
//   final ScrollController _scrollController = ScrollController();
//   final List<String> _locations = [
//     'All',
//     'Location1',
//     'Location2',
//     'Location3'
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.calendar_today),
//             onPressed: () => _selectDate(context),
//           ),
//           IconButton(
//             icon: Icon(Icons.download),
//             onPressed: () => _exportData(context),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildSearchBar(),
//             _buildFilterDropdown(),
//             _buildLocationFilterDropdown(),
//             SizedBox(height: 16),
//             Expanded(
//               child: Consumer<RequestProvider>(
//                 builder: (context, requestProvider, child) {
//                   final requests = requestProvider.requests.where((request) {
//                     final requestDate = (request['timestamp'] as DateTime);
//                     final matchesDate =
//                         requestDate.year == _selectedDate.year &&
//                             requestDate.month == _selectedDate.month &&
//                             requestDate.day == _selectedDate.day;
//                     final matchesSearch = request['pickerName']
//                         .toString()
//                         .toLowerCase()
//                         .contains(_searchQuery.toLowerCase());
//                     final matchesFilter = _filterStatus == 'All' ||
//                         request['status'] == _filterStatus.toLowerCase();
//                     final matchesLocation = _filterLocation == 'All' ||
//                         request['location'] == _filterLocation;
//                     return matchesDate &&
//                         matchesSearch &&
//                         matchesFilter &&
//                         matchesLocation;
//                   }).toList();

//                   return ListView.builder(
//                     controller: _scrollController,
//                     itemCount: requests.length,
//                     itemBuilder: (context, index) {
//                       final request = requests[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text(
//                             'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                           ),
//                           subtitle: Text(
//                             'Location: ${request['location']}\n'
//                             'Picker: ${request['pickerName']}\n'
//                             'Contact: ${request['pickerContact']}\n'
//                             'Status: ${request['status']}',
//                           ),
//                           leading: Icon(
//                             Icons.request_page,
//                             color: request['status'] == 'pending'
//                                 ? Colors.orange
//                                 : Colors.green,
//                           ),
//                           trailing: _buildActionButtons(
//                               context, requestProvider, request['id']),
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
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search by Picker Name',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildFilterDropdown() {
//     return DropdownButton<String>(
//       value: _filterStatus,
//       onChanged: (newValue) {
//         setState(() {
//           _filterStatus = newValue!;
//         });
//       },
//       items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
//           .map<DropdownMenuItem<String>>((String value) {
//         return DropdownMenuItem<String>(
//           value: value,
//           child: Text(value),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildLocationFilterDropdown() {
//     return DropdownButton<String>(
//       value: _filterLocation,
//       onChanged: (newValue) {
//         setState(() {
//           _filterLocation = newValue!;
//         });
//       },
//       items: _locations.map<DropdownMenuItem<String>>((String value) {
//         return DropdownMenuItem<String>(
//           value: value,
//           child: Text(value),
//         );
//       }).toList(),
//     );
//   }

//   void _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate)
//       setState(() {
//         _selectedDate = picked;
//       });
//   }

//   void _exportData(BuildContext context) async {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final csvData =
//         ListToCsvConverter().convert(requestProvider.requests.map((request) {
//       return [
//         request['id'],
//         request['items']
//             .map((item) =>
//                 '${item['quantity']} ${item['unit']} x ${item['name']}')
//             .join(', '),
//         request['location'],
//         request['pickerName'],
//         request['pickerContact'],
//         request['status'],
//         (request['timestamp'] as DateTime).toIso8601String(),
//       ];
//     }).toList());

//     if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
//       final directory = await getApplicationDocumentsDirectory();
//       final path =
//           '${directory.path}/requests_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
//       final file = File(path);
//       await file.writeAsString(csvData);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Data exported to $path')));
//       OpenFile.open(path);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('File saving not supported on this platform')));
//     }
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, String requestId) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             final request = requestProvider.getRequestById(requestId);
//             if (request != null) {
//               _editRequest(context, requestId, request);
//             }
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
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
// import 'package:intl/intl.dart';
// import 'package:csv/csv.dart';
// import 'package:file_picker/file_picker.dart';
// import 'dart:io';
// import '../../providers/request_provider.dart';
// import 'edit_admin_request_bottom_sheet.dart';

// class ManageRequestsScreen extends StatefulWidget {
//   @override
//   _ManageRequestsScreenState createState() => _ManageRequestsScreenState();
// }

// class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
//   String _searchQuery = '';
//   String _filterStatus = 'All';
//   String _filterLocation = 'All';
//   DateTime _selectedDate = DateTime.now();
//   final ScrollController _scrollController = ScrollController();
//   final List<String> _locations = [
//     'All',
//     'Location1',
//     'Location2',
//     'Location3'
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.calendar_today),
//             onPressed: () => _selectDate(context),
//           ),
//           IconButton(
//             icon: Icon(Icons.download),
//             onPressed: () => _exportData(context),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildSearchBar(),
//             _buildFilterDropdown(),
//             _buildLocationFilterDropdown(),
//             SizedBox(height: 16),
//             Expanded(
//               child: Consumer<RequestProvider>(
//                 builder: (context, requestProvider, child) {
//                   final requests = requestProvider.requests.where((request) {
//                     final requestDate = (request['timestamp'] as DateTime);
//                     final matchesDate =
//                         requestDate.year == _selectedDate.year &&
//                             requestDate.month == _selectedDate.month &&
//                             requestDate.day == _selectedDate.day;
//                     final matchesSearch = request['pickerName']
//                         .toString()
//                         .toLowerCase()
//                         .contains(_searchQuery.toLowerCase());
//                     final matchesFilter = _filterStatus == 'All' ||
//                         request['status'] == _filterStatus.toLowerCase();
//                     final matchesLocation = _filterLocation == 'All' ||
//                         request['location'] == _filterLocation;
//                     return matchesDate &&
//                         matchesSearch &&
//                         matchesFilter &&
//                         matchesLocation;
//                   }).toList();

//                   return ListView.builder(
//                     controller: _scrollController,
//                     itemCount: requests.length,
//                     itemBuilder: (context, index) {
//                       final request = requests[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text(
//                             'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                           ),
//                           subtitle: Text(
//                             'Location: ${request['location']}\n'
//                             'Picker: ${request['pickerName']}\n'
//                             'Contact: ${request['pickerContact']}\n'
//                             'Status: ${request['status']}',
//                           ),
//                           leading: Icon(
//                             Icons.request_page,
//                             color: request['status'] == 'pending'
//                                 ? Colors.orange
//                                 : Colors.green,
//                           ),
//                           trailing: _buildActionButtons(
//                               context, requestProvider, request['id']),
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
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search by Picker Name',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildFilterDropdown() {
//     return DropdownButton<String>(
//       value: _filterStatus,
//       onChanged: (newValue) {
//         setState(() {
//           _filterStatus = newValue!;
//         });
//       },
//       items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
//           .map<DropdownMenuItem<String>>((String value) {
//         return DropdownMenuItem<String>(
//           value: value,
//           child: Text(value),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildLocationFilterDropdown() {
//     return DropdownButton<String>(
//       value: _filterLocation,
//       onChanged: (newValue) {
//         setState(() {
//           _filterLocation = newValue!;
//         });
//       },
//       items: _locations.map<DropdownMenuItem<String>>((String value) {
//         return DropdownMenuItem<String>(
//           value: value,
//           child: Text(value),
//         );
//       }).toList(),
//     );
//   }

//   void _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != _selectedDate)
//       setState(() {
//         _selectedDate = picked;
//       });
//   }

//   void _exportData(BuildContext context) async {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final csvData =
//         ListToCsvConverter().convert(requestProvider.requests.map((request) {
//       return [
//         request['id'],
//         request['items']
//             .map((item) =>
//                 '${item['quantity']} ${item['unit']} x ${item['name']}')
//             .join(', '),
//         request['location'],
//         request['pickerName'],
//         request['pickerContact'],
//         request['status'],
//         (request['timestamp'] as DateTime).toIso8601String(),
//       ];
//     }).toList());

//     final result = await FilePicker.platform.saveFile(
//       dialogTitle: 'Please select an output file:',
//       fileName: 'requests_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
//     );

//     if (result != null) {
//       final file = File(result);
//       await file.writeAsString(csvData);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Data exported to $result')));
//     }
//   }

//   Widget _buildActionButtons(
//       BuildContext context, RequestProvider requestProvider, String requestId) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.check, color: Colors.green),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'approved');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.close, color: Colors.red),
//           onPressed: () {
//             requestProvider.updateRequestStatus(requestId, 'rejected');
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.edit, color: Colors.blue),
//           onPressed: () {
//             final request = requestProvider.getRequestById(requestId);
//             if (request != null) {
//               _editRequest(context, requestId, request);
//             }
//           },
//         ),
//       ],
//     );
//   }

//   void _editRequest(
//       BuildContext context, String requestId, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditAdminRequestBottomSheet(
//         id: requestId,
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
