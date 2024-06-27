import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import '../../providers/inventory_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/user_provider.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedReportType = 'Inventory Report';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Reports',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedReportType,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedReportType = newValue!;
                });
              },
              items: <String>[
                'Inventory Report',
                'User Activity Report',
                'Request Status Report'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                _dateRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                setState(() {});
              },
              child: Text('Select Date Range'),
            ),
            SizedBox(height: 16),
            if (_dateRange != null)
              Text(
                'Selected Range: ${_dateRange!.start.toLocal()} - ${_dateRange!.end.toLocal()}',
                style: TextStyle(fontSize: 16),
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _generateReport(context);
              },
              child: Text('Generate Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(BuildContext context) async {
    final pdf = pw.Document();

    switch (_selectedReportType) {
      case 'Inventory Report':
        final inventoryItems =
            Provider.of<InventoryProvider>(context, listen: false).items;
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Inventory Report',
                    style:
                        pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['Name', 'Category', 'Unit'],
                  data: inventoryItems
                      .map((item) =>
                          [item['name'], item['category'], item['unit']])
                      .toList(),
                ),
              ],
            );
          },
        ));
        break;

      case 'User Activity Report':
        final users = Provider.of<UserProvider>(context, listen: false).users;
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('User Activity Report',
                    style:
                        pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['Name', 'Email', 'Role'],
                  data: users
                      .map(
                          (user) => [user['name'], user['email'], user['role']])
                      .toList(),
                ),
              ],
            );
          },
        ));
        break;

      case 'Request Status Report':
        final requests =
            Provider.of<RequestProvider>(context, listen: false).requests;
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Request Status Report',
                    style:
                        pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [
                    'Items',
                    'Location',
                    'Picker Name',
                    'Picker Contact',
                    'Status',
                    'Unique Code'
                  ],
                  data: requests
                      .map((request) => [
                            request['items']
                                .map((item) =>
                                    '${item['quantity']} ${item['unit']} x ${item['name']}')
                                .join(', '),
                            request['location'],
                            request['pickerName'],
                            request['pickerContact'],
                            request['status'],
                            request['uniqueCode']
                          ])
                      .toList(),
                ),
              ],
            );
          },
        ));
        break;
    }

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/report.pdf");
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated and saved as report.pdf')),
      );

      // Open the PDF file
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import 'dart:io';

// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/user_provider.dart';

// class ReportsScreen extends StatefulWidget {
//   @override
//   _ReportsScreenState createState() => _ReportsScreenState();
// }

// class _ReportsScreenState extends State<ReportsScreen> {
//   String _selectedReportType = 'Inventory Report';
//   DateTimeRange? _dateRange;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Reports'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Generate Reports',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             DropdownButton<String>(
//               value: _selectedReportType,
//               onChanged: (String? newValue) {
//                 setState(() {
//                   _selectedReportType = newValue!;
//                 });
//               },
//               items: <String>[
//                 'Inventory Report',
//                 'User Activity Report',
//                 'Request Status Report'
//               ].map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () async {
//                 _dateRange = await showDateRangePicker(
//                   context: context,
//                   firstDate: DateTime(2020),
//                   lastDate: DateTime.now(),
//                 );
//                 setState(() {});
//               },
//               child: Text('Select Date Range'),
//             ),
//             SizedBox(height: 16),
//             if (_dateRange != null)
//               Text(
//                 'Selected Range: ${_dateRange!.start.toLocal()} - ${_dateRange!.end.toLocal()}',
//                 style: TextStyle(fontSize: 16),
//               ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 _generateReport(context);
//               },
//               child: Text('Generate Report'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _generateReport(BuildContext context) async {
//     final pdf = pw.Document();

//     switch (_selectedReportType) {
//       case 'Inventory Report':
//         final inventoryItems =
//             Provider.of<InventoryProvider>(context, listen: false).items;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Inventory Report',
//                     style:
//                         pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Category', 'Unit'],
//                   data: inventoryItems
//                       .map((item) =>
//                           [item['name'], item['category'], item['unit']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'User Activity Report':
//         final users = Provider.of<UserProvider>(context, listen: false).users;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('User Activity Report',
//                     style:
//                         pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Email', 'Role'],
//                   data: users
//                       .map(
//                           (user) => [user['name'], user['email'], user['role']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'Request Status Report':
//         final requests =
//             Provider.of<RequestProvider>(context, listen: false).requests;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Request Status Report',
//                     style:
//                         pw.TextStyle(fontSize: 24, font: pw.Font.helvetica())),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: [
//                     'Items',
//                     'Location',
//                     'Picker Name',
//                     'Picker Contact',
//                     'Status'
//                   ],
//                   data: requests
//                       .map((request) => [
//                             request['items']
//                                 .map((item) =>
//                                     '${item['quantity']} ${item['unit']} x ${item['name']}')
//                                 .join(', '),
//                             request['location'],
//                             request['pickerName'],
//                             request['pickerContact'],
//                             request['status']
//                           ])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;
//     }

//     try {
//       final output = await getTemporaryDirectory();
//       final file = File("${output.path}/report.pdf");
//       await file.writeAsBytes(await pdf.save());

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Report generated and saved as report.pdf')),
//       );

//       // Open the PDF file
//       await OpenFile.open(file.path);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to generate report: $e')),
//       );
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import 'dart:io';

// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/user_provider.dart';
// import 'package:google_fonts/google_fonts.dart';


// class ReportsScreen extends StatefulWidget {
//   @override
//   _ReportsScreenState createState() => _ReportsScreenState();
// }

// class _ReportsScreenState extends State<ReportsScreen> {
//   String _selectedReportType = 'Inventory Report';
//   DateTimeRange? _dateRange;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Reports'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Generate Reports',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             DropdownButton<String>(
//               value: _selectedReportType,
//               onChanged: (String? newValue) {
//                 setState(() {
//                   _selectedReportType = newValue!;
//                 });
//               },
//               items: <String>[
//                 'Inventory Report',
//                 'User Activity Report',
//                 'Request Status Report'
//               ].map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () async {
//                 _dateRange = await showDateRangePicker(
//                   context: context,
//                   firstDate: DateTime(2020),
//                   lastDate: DateTime.now(),
//                 );
//                 setState(() {});
//               },
//               child: Text('Select Date Range'),
//             ),
//             SizedBox(height: 16),
//             if (_dateRange != null)
//               Text(
//                 'Selected Range: ${_dateRange!.start.toLocal()} - ${_dateRange!.end.toLocal()}',
//                 style: TextStyle(fontSize: 16),
//               ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 _generateReport(context);
//               },
//               child: Text('Generate Report'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _generateReport(BuildContext context) async {
//     final pdf = pw.Document();

//     final ttf = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
//     final font = pw.Font.ttf(ttf);

//     switch (_selectedReportType) {
//       case 'Inventory Report':
//         final inventoryItems =
//             Provider.of<InventoryProvider>(context, listen: false).items;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Inventory Report',
//                     style: pw.TextStyle(fontSize: 24, font: font)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Category', 'Unit'],
//                   data: inventoryItems
//                       .map((item) =>
//                           [item['name'], item['category'], item['unit']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'User Activity Report':
//         final users = Provider.of<UserProvider>(context, listen: false).users;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('User Activity Report',
//                     style: pw.TextStyle(fontSize: 24, font: font)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Email', 'Role'],
//                   data: users
//                       .map(
//                           (user) => [user['name'], user['email'], user['role']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'Request Status Report':
//         final requests =
//             Provider.of<RequestProvider>(context, listen: false).requests;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Request Status Report',
//                     style: pw.TextStyle(fontSize: 24, font: font)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: [
//                     'Items',
//                     'Location',
//                     'Picker Name',
//                     'Picker Contact',
//                     'Status'
//                   ],
//                   data: requests
//                       .map((request) => [
//                             request['items']
//                                 .map((item) =>
//                                     '${item['quantity']} ${item['unit']} x ${item['name']}')
//                                 .join(', '),
//                             request['location'],
//                             request['pickerName'],
//                             request['pickerContact'],
//                             request['status']
//                           ])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;
//     }

//     try {
//       final output = await getTemporaryDirectory();
//       final file = File("${output.path}/report.pdf");
//       await file.writeAsBytes(await pdf.save());

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Report generated and saved as report.pdf')),
//       );

//       // Open the PDF file
//       await OpenFile.open(file.path);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to generate report: $e')),
//       );
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import 'dart:io';

// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/user_provider.dart';

// class ReportsScreen extends StatefulWidget {
//   @override
//   _ReportsScreenState createState() => _ReportsScreenState();
// }

// class _ReportsScreenState extends State<ReportsScreen> {
//   String _selectedReportType = 'Inventory Report';
//   DateTimeRange? _dateRange;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Reports'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Generate Reports',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             DropdownButton<String>(
//               value: _selectedReportType,
//               onChanged: (String? newValue) {
//                 setState(() {
//                   _selectedReportType = newValue!;
//                 });
//               },
//               items: <String>[
//                 'Inventory Report',
//                 'User Activity Report',
//                 'Request Status Report'
//               ].map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () async {
//                 _dateRange = await showDateRangePicker(
//                   context: context,
//                   firstDate: DateTime(2020),
//                   lastDate: DateTime.now(),
//                 );
//                 setState(() {});
//               },
//               child: Text('Select Date Range'),
//             ),
//             SizedBox(height: 16),
//             if (_dateRange != null)
//               Text(
//                 'Selected Range: ${_dateRange!.start.toLocal()} - ${_dateRange!.end.toLocal()}',
//                 style: TextStyle(fontSize: 16),
//               ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () {
//                 _generateReport(context);
//               },
//               child: Text('Generate Report'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _generateReport(BuildContext context) async {
//     final pdf = pw.Document();

//     switch (_selectedReportType) {
//       case 'Inventory Report':
//         final inventoryItems =
//             Provider.of<InventoryProvider>(context, listen: false).items;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Inventory Report', style: pw.TextStyle(fontSize: 24)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Category', 'Unit'],
//                   data: inventoryItems
//                       .map((item) =>
//                           [item['name'], item['category'], item['unit']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'User Activity Report':
//         final users = Provider.of<UserProvider>(context, listen: false).users;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('User Activity Report',
//                     style: pw.TextStyle(fontSize: 24)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ['Name', 'Email', 'Role'],
//                   data: users
//                       .map(
//                           (user) => [user['name'], user['email'], user['role']])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'Request Status Report':
//         final requests =
//             Provider.of<RequestProvider>(context, listen: false).requests;
//         pdf.addPage(pw.Page(
//           build: (pw.Context context) {
//             return pw.Column(
//               children: [
//                 pw.Text('Request Status Report',
//                     style: pw.TextStyle(fontSize: 24)),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: [
//                     'Items',
//                     'Location',
//                     'Picker Name',
//                     'Picker Contact',
//                     'Status'
//                   ],
//                   data: requests
//                       .map((request) => [
//                             request['items']
//                                 .map((item) =>
//                                     '${item['quantity']} ${item['unit']} x ${item['name']}')
//                                 .join(', '),
//                             request['location'],
//                             request['pickerName'],
//                             request['pickerContact'],
//                             request['status']
//                           ])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;
//     }

//     try {
//       final output = await getTemporaryDirectory();
//       final file = File("${output.path}/report.pdf");
//       await file.writeAsBytes(await pdf.save());

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Report generated and saved as report.pdf')),
//       );

//       // Open the PDF file
//       await OpenFile.open(file.path);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to generate report: $e')),
//       );
//     }
//   }
// }

