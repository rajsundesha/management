import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

import '../../providers/inventory_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';

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
                'Request Status Report',
                'Stock Request Report', // Added new report type
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
      // case 'Inventory Report':
      // final inventoryItems =
      //     Provider.of<InventoryProvider>(context, listen: false).items;
      case 'Inventory Report':
        final inventoryProvider =
            Provider.of<InventoryProvider>(context, listen: false);

        if (inventoryProvider.isLoading) {
          // Show loading indicator if items are being fetched
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Loading inventory items..."),
                  ],
                ),
              );
            },
          );
        }

        if (inventoryProvider.items.isEmpty) {
          // If items are still empty, try fetching again
          await inventoryProvider.refreshItems();
        }

        final inventoryItems = inventoryProvider.items;
        print(
            "Generating Inventory Report. Items count: ${inventoryItems.length}");

        if (inventoryItems.isEmpty) {
          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Text(
                      'No inventory items found. Please check your database connection.',
                      style: pw.TextStyle(fontSize: 18)),
                );
              },
            ),
          );
        } else {
          final inventoryProvider =
              Provider.of<InventoryProvider>(context, listen: false);
          final inventoryItems = inventoryProvider.items;
          print(
              "Generating Inventory Report. Items count: ${inventoryItems.length}");

          if (inventoryItems.isEmpty) {
            pdf.addPage(
              pw.Page(
                build: (pw.Context context) {
                  return pw.Center(
                    child: pw.Text('No inventory items found',
                        style: pw.TextStyle(fontSize: 24)),
                  );
                },
              ),
            );
          } else {
            pdf.addPage(
              pw.MultiPage(
                build: (pw.Context context) {
                  return [
                    pw.Header(
                        level: 0,
                        child: pw.Text('Inventory Report',
                            style: pw.TextStyle(fontSize: 24))),
                    pw.SizedBox(height: 20),
                    pw.Table.fromTextArray(
                      headers: [
                        'Name',
                        'Category',
                        'Subcategory',
                        'Quantity',
                        'Unit',
                        'Threshold',
                        'Hashtag'
                      ],
                      data: inventoryItems.map((item) {
                        print("Processing item: $item"); // Debug print
                        return [
                          item['name']?.toString() ?? '',
                          item['category']?.toString() ?? '',
                          item['subcategory']?.toString() ?? '',
                          item['quantity']?.toString() ?? '',
                          item['unit']?.toString() ?? '',
                          item['threshold']?.toString() ?? '',
                          item['hashtag']?.toString() ?? '',
                        ];
                      }).toList(),
                      cellStyle: pw.TextStyle(fontSize: 8),
                      cellHeight: 30,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.centerLeft,
                        3: pw.Alignment.centerRight,
                        4: pw.Alignment.centerLeft,
                        5: pw.Alignment.centerRight,
                        6: pw.Alignment.centerLeft,
                      },
                    ),
                    pw.SizedBox(height: 20),
                    pw.Header(level: 1, child: pw.Text('Low Stock Items')),
                    pw.Table.fromTextArray(
                      headers: ['Name', 'Current Quantity', 'Threshold'],
                      data: inventoryItems
                          .where((item) =>
                              (item['quantity'] ?? 0) <
                              (item['threshold'] ?? 0))
                          .map((item) => [
                                item['name'] ?? '',
                                item['quantity']?.toString() ?? '',
                                item['threshold']?.toString() ?? '',
                              ])
                          .toList(),
                      cellStyle: pw.TextStyle(fontSize: 8),
                      cellHeight: 30,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerRight,
                        2: pw.Alignment.centerRight,
                      },
                    ),
                  ];
                },
              ),
            );
          }
        }
        break;

      case 'User Activity Report':
        final users =
            await FirebaseFirestore.instance.collection('users').get();
        final userRequestCounts = await _getUserDailyRequestCounts();

        pdf.addPage(
          pw.MultiPage(
            build: (pw.Context context) {
              return [
                pw.Header(
                    level: 0,
                    child: pw.Text('User Activity Report',
                        style: pw.TextStyle(fontSize: 24))),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: [
                    'Name',
                    'Email',
                    'Role',
                    'Mobile',
                    'Daily Request Count'
                  ],
                  data: users.docs.map((user) {
                    final userData = user.data();
                    final userEmail = userData['email'] ?? 'N/A';
                    final dailyRequestCount = userRequestCounts[userEmail] ?? 0;
                    return [
                      userData['name'] ?? 'N/A',
                      userEmail,
                      userData['role'] ?? 'N/A',
                      userData['mobile'] ?? 'N/A',
                      dailyRequestCount.toString(),
                    ];
                  }).toList(),
                  cellStyle: pw.TextStyle(fontSize: 8),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                  },
                ),
              ];
            },
          ),
        );
        break;

      case 'Request Status Report':
        final requests = Provider.of<RequestProvider>(context, listen: false)
            .requests
            .where((request) {
          if (_dateRange == null) return true;
          final requestDate = request['timestamp'];
          return requestDate.isAfter(_dateRange!.start) &&
              requestDate.isBefore(_dateRange!.end);
        }).toList();
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Request Status Report',
                    style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [
                    'Items',
                    'Location',
                    'Picker Name',
                    'Picker Contact',
                    'Status',
                    'Unique Code',
                    'Date'
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
                            request['uniqueCode'],
                            request['timestamp'].toString()
                          ])
                      .toList(),
                ),
              ],
            );
          },
        ));
        break;

      case 'Stock Request Report':
        final stockRequests =
            await Provider.of<RequestProvider>(context, listen: false)
                .getDetailedStockRequestReport(_dateRange);

        pdf.addPage(
          pw.MultiPage(
            build: (pw.Context context) {
              return [
                pw.Header(
                    level: 0,
                    child: pw.Text('Detailed Stock Request Report',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: [
                    'ID',
                    'Created By',
                    'Status',
                    'Created At',
                    'Items',
                    'Note'
                  ],
                  data: stockRequests
                      .map((request) => [
                            request['id'],
                            request['createdBy'],
                            request['status'],
                            request['createdAt'],
                            request['items'],
                            request['note'],
                          ])
                      .toList(),
                  cellStyle: pw.TextStyle(fontSize: 8),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                  },
                ),
                pw.SizedBox(height: 20),
                ...stockRequests
                    .map((request) => [
                          pw.Header(
                              level: 1,
                              child:
                                  pw.Text('Request Details: ${request['id']}')),
                          pw.Paragraph(text: 'Status: ${request['status']}'),
                          pw.Paragraph(
                              text:
                                  'Created By: ${request['createdBy']} on ${request['createdAt']}'),
                          pw.Paragraph(text: 'Items: ${request['items']}'),
                          pw.Paragraph(text: 'Note: ${request['note']}'),
                          if (request['status'] == 'approved')
                            pw.Paragraph(
                                text:
                                    'Approved By: ${request['approvedBy']} on ${request['approvedAt']}'),
                          if (request['status'] == 'fulfilled')
                            pw.Paragraph(
                                text:
                                    'Fulfilled By: ${request['fulfilledBy']} on ${request['fulfilledAt']}'),
                          if (request['status'] == 'rejected') ...[
                            pw.Paragraph(
                                text:
                                    'Rejected By: ${request['rejectedBy']} on ${request['rejectedAt']}'),
                            pw.Paragraph(
                                text:
                                    'Rejection Reason: ${request['rejectionReason']}'),
                          ],
                          pw.SizedBox(height: 10),
                        ])
                    .expand((element) => element)
                    .toList(),
              ];
            },
          ),
        );
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

  Future<Map<String, int>> _getUserDailyRequestCounts() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();

    final Map<String, int> userRequestCounts = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final userEmail = data['createdByEmail'] as String?;
      if (userEmail != null) {
        userRequestCounts[userEmail] = (userRequestCounts[userEmail] ?? 0) + 1;
      }
    }

    return userRequestCounts;
  }
}
