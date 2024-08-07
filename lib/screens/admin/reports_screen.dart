import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:async';

import '../../providers/inventory_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/inventory_item.dart';
import '../../models/request.dart';
import '../../models/stock_request.dart';
import '../../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedReportType = 'Inventory Report';
  DateTimeRange? _dateRange;
  bool _isLoading = false;
  String _errorMessage = '';
  final ReportService _reportService = ReportService();

  final List<String> _reportTypes = [
    'Inventory Report',
    'User Activity Report',
    'Request Status Report',
    'Stock Request Report',
    'Inventory Turnover Report',
    'Fulfillment Performance Report',
    'Item Usage Report',
    'Approval Process Analysis',
    'User Role Efficiency Report',
    'Location-based Analysis',
    'Audit Trail Report',
    'Financial Impact Report',
    'System Usage Report',
    'Compliance Report',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).primaryColor, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Reports',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 24),
                _buildReportTypeDropdown(),
                SizedBox(height: 16),
                _buildDateRangePicker(),
                SizedBox(height: 24),
                _buildGenerateButton(),
                SizedBox(height: 16),
                if (_isLoading) _buildLoadingIndicator(),
                if (_errorMessage.isNotEmpty) _buildErrorMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReportType,
          onChanged: (String? newValue) {
            setState(() {
              _selectedReportType = newValue!;
            });
          },
          items: _reportTypes.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down,
              color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date Range',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectDateRange,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateRange == null
                      ? 'Select dates'
                      : '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.calendar_today,
                    color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _generateReport,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Text('Generate Report', style: TextStyle(fontSize: 18)),
      ),
      style: ElevatedButton.styleFrom(
        primary: Theme.of(context).accentColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generating report...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _errorMessage,
        style: TextStyle(color: Colors.red.shade900),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Theme.of(context).primaryColor,
            accentColor: Theme.of(context).accentColor,
            colorScheme:
                ColorScheme.light(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_dateRange == null) {
      setState(() {
        _errorMessage = 'Please select a date range.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final pdf = pw.Document();

      switch (_selectedReportType) {
        case 'Inventory Report':
          await _generateInventoryReport(pdf);
          break;
        case 'User Activity Report':
          await _generateUserActivityReport(pdf);
          break;
        case 'Request Status Report':
          await _generateRequestStatusReport(pdf);
          break;
        case 'Stock Request Report':
          await _generateStockRequestReport(pdf);
          break;
        case 'Inventory Turnover Report':
          await _generateInventoryTurnoverReport(pdf);
          break;
        case 'Fulfillment Performance Report':
          await _generateFulfillmentPerformanceReport(pdf);
          break;
        case 'Item Usage Report':
          await _generateItemUsageReport(pdf);
          break;
        case 'Approval Process Analysis':
          await _generateApprovalProcessAnalysis(pdf);
          break;
        case 'User Role Efficiency Report':
          await _generateUserRoleEfficiencyReport(pdf);
          break;
        case 'Location-based Analysis':
          await _generateLocationBasedAnalysis(pdf);
          break;
        case 'Audit Trail Report':
          await _generateAuditTrailReport(pdf);
          break;
        case 'Financial Impact Report':
          await _generateFinancialImpactReport(pdf);
          break;
        case 'System Usage Report':
          await _generateSystemUsageReport(pdf);
          break;
        case 'Compliance Report':
          await _generateComplianceReport(pdf);
          break;
        default:
          throw Exception('Unsupported report type');
      }

      final output = await getTemporaryDirectory();
      final file = File(
          "${output.path}/${_selectedReportType.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf");
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated successfully')),
      );

      await OpenFile.open(file.path);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to generate report: $e';
      });
    }
  }

  Future<void> _generateInventoryReport(pw.Document pdf) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    await inventoryProvider.refreshItems();
    final inventoryItems = inventoryProvider.items;

    final chart = await _reportService.generateInventoryChart(inventoryItems);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Inventory Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
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
              data: inventoryItems
                  .map((item) => [
                        item.name,
                        item.category,
                        item.subcategory,
                        item.quantity.toString(),
                        item.unit,
                        item.threshold.toString(),
                        item.hashtag,
                      ])
                  .toList(),
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
                  .where((item) => item.quantity < item.threshold)
                  .map((item) => [
                        item.name,
                        item.quantity.toString(),
                        item.threshold.toString(),
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

  Future<void> _generateUserActivityReport(pw.Document pdf) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final users = await authProvider.getAllUsers();
    final userRequestCounts =
        await _reportService.getUserDailyRequestCounts(_dateRange!);

    final chart =
        await _reportService.generateUserActivityChart(userRequestCounts);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('User Activity Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Name',
                'Email',
                'Role',
                'Mobile',
                'Daily Request Count'
              ],
              data: users.map((user) {
                final dailyRequestCount = userRequestCounts[user.email] ?? 0;
                return [
                  user.displayName,
                  user.email,
                  user.role,
                  user.phoneNumber ?? 'N/A',
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
  }

  Future<void> _generateRequestStatusReport(pw.Document pdf) async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final requests = await requestProvider.getFilteredRequests(
      startDate: _dateRange!.start,
      endDate: _dateRange!.end,
    );

    final chart = await _reportService.generateRequestStatusChart(requests);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Request Status Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'ID',
                'Items',
                'Location',
                'Picker Name',
                'Status',
                'Date'
              ],
              data: requests
                  .map((request) => [
                        request.id,
                        request.items
                            .map((item) =>
                                '${item.quantity} ${item.unit} x ${item.name}')
                            .join(', '),
                        request.location,
                        request.pickerName,
                        request.status,
                        DateFormat('yyyy-MM-dd HH:mm')
                            .format(request.timestamp),
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateStockRequestReport(pw.Document pdf) async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final stockRequests =
        await requestProvider.getDetailedStockRequestReport(_dateRange!);

    final chart = await _reportService.generateStockRequestChart(stockRequests);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Stock Request Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
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
                        request.id,
                        request.createdBy,
                        request.status,
                        DateFormat('yyyy-MM-dd HH:mm')
                            .format(request.createdAt),
                        request.items
                            .map((item) => '${item.quantity} x ${item.name}')
                            .join(', '),
                        request.note,
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
                          child: pw.Text('Request Details: ${request.id}')),
                      pw.Paragraph(text: 'Status: ${request.status}'),
                      pw.Paragraph(
                          text:
                              'Created By: ${request.createdBy} on ${DateFormat('yyyy-MM-dd HH:mm').format(request.createdAt)}'),
                      pw.Paragraph(
                          text:
                              'Items: ${request.items.map((item) => '${item.quantity} x ${item.name}').join(', ')}'),
                      pw.Paragraph(text: 'Note: ${request.note}'),
                      if (request.status == 'approved')
                        pw.Paragraph(
                            text:
                                'Approved By: ${request.approvedBy} on ${DateFormat('yyyy-MM-dd HH:mm').format(request.approvedAt!)}'),
                      if (request.status == 'fulfilled')
                        pw.Paragraph(
                            text:
                                'Fulfilled By: ${request.fulfilledBy} on ${DateFormat('yyyy-MM-dd HH:mm').format(request.fulfilledAt!)}'),
                      if (request.status == 'rejected') ...[
                        pw.Paragraph(
                            text:
                                'Rejected By: ${request.rejectedBy} on ${DateFormat('yyyy-MM-dd HH:mm').format(request.rejectedAt!)}'),
                        pw.Paragraph(
                            text:
                                'Rejection Reason: ${request.rejectionReason}'),
                      ],
                      pw.SizedBox(height: 10),
                    ])
                .expand((element) => element)
                .toList(),
          ];
        },
      ),
    );
  }

  Future<void> _generateInventoryTurnoverReport(pw.Document pdf) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final turnoverData = await _reportService.calculateInventoryTurnover(
      inventoryProvider.items,
      _dateRange!.start,
      _dateRange!.end,
    );

    final chart =
        await _reportService.generateInventoryTurnoverChart(turnoverData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Inventory Turnover Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Item Name',
                'Beginning Inventory',
                'Ending Inventory',
                'COGS',
                'Turnover Ratio'
              ],
              data: turnoverData
                  .map((item) => [
                        item.name,
                        item.beginningInventory.toString(),
                        item.endingInventory.toString(),
                        item.cogs.toStringAsFixed(2),
                        item.turnoverRatio.toStringAsFixed(2),
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateFulfillmentPerformanceReport(pw.Document pdf) async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final fulfillmentData =
        await _reportService.calculateFulfillmentPerformance(
      await requestProvider.getFilteredRequests(
          startDate: _dateRange!.start, endDate: _dateRange!.end),
    );

    final chart = await _reportService
        .generateFulfillmentPerformanceChart(fulfillmentData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Fulfillment Performance Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                [
                  'Average Fulfillment Time',
                  '${fulfillmentData.averageFulfillmentTime.toStringAsFixed(2)} hours'
                ],
                [
                  'On-Time Fulfillment Rate',
                  '${(fulfillmentData.onTimeFulfillmentRate * 100).toStringAsFixed(2)}%'
                ],
                ['Total Requests', fulfillmentData.totalRequests.toString()],
                [
                  'Fulfilled Requests',
                  fulfillmentData.fulfilledRequests.toString()
                ],
                [
                  'Pending Requests',
                  fulfillmentData.pendingRequests.toString()
                ],
              ],
              cellStyle: pw.TextStyle(fontSize: 10),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateItemUsageReport(pw.Document pdf) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final usageData = await _reportService.calculateItemUsage(
      inventoryProvider.items,
      _dateRange!.start,
      _dateRange!.end,
    );

    final chart = await _reportService.generateItemUsageChart(usageData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Item Usage Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Item Name',
                'Total Usage',
                'Average Daily Usage',
                'Peak Usage Date',
                'Peak Usage Amount'
              ],
              data: usageData
                  .map((item) => [
                        item.name,
                        item.totalUsage.toString(),
                        item.averageDailyUsage.toStringAsFixed(2),
                        DateFormat('yyyy-MM-dd').format(item.peakUsageDate),
                        item.peakUsageAmount.toString(),
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateApprovalProcessAnalysis(pw.Document pdf) async {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final approvalData = await _reportService.analyzeApprovalProcess(
      await requestProvider.getFilteredRequests(
          startDate: _dateRange!.start, endDate: _dateRange!.end),
    );

    final chart =
        await _reportService.generateApprovalProcessChart(approvalData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Approval Process Analysis',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                [
                  'Average Approval Time',
                  '${approvalData.averageApprovalTime.toStringAsFixed(2)} hours'
                ],
                [
                  'Approval Rate',
                  '${(approvalData.approvalRate * 100).toStringAsFixed(2)}%'
                ],
                ['Total Requests', approvalData.totalRequests.toString()],
                ['Approved Requests', approvalData.approvedRequests.toString()],
                ['Rejected Requests', approvalData.rejectedRequests.toString()],
              ],
              cellStyle: pw.TextStyle(fontSize: 10),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Top Rejection Reasons')),
            pw.Table.fromTextArray(
              headers: ['Reason', 'Count'],
              data: approvalData.topRejectionReasons.entries
                  .map((entry) => [
                        entry.key,
                        entry.value.toString(),
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateUserRoleEfficiencyReport(pw.Document pdf) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    final users = await authProvider.getAllUsers();
    final requests = await requestProvider.getFilteredRequests(
        startDate: _dateRange!.start, endDate: _dateRange!.end);

    final efficiencyData =
        await _reportService.calculateUserRoleEfficiency(users, requests);

    final chart =
        await _reportService.generateUserRoleEfficiencyChart(efficiencyData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('User Role Efficiency Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            ...efficiencyData.keys
                .map((role) => [
                      pw.Header(level: 1, child: pw.Text('$role Efficiency')),
                      pw.Table.fromTextArray(
                        headers: ['Metric', 'Value'],
                        data: [
                          [
                            'Average Requests Processed',
                            efficiencyData[role]!
                                .averageRequestsProcessed
                                .toStringAsFixed(2)
                          ],
                          [
                            'Average Processing Time',
                            '${efficiencyData[role]!.averageProcessingTime.toStringAsFixed(2)} hours'
                          ],
                          [
                            'Approval Rate',
                            '${(efficiencyData[role]!.approvalRate * 100).toStringAsFixed(2)}%'
                          ],
                        ],
                        cellStyle: pw.TextStyle(fontSize: 10),
                        cellHeight: 30,
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.centerRight,
                        },
                      ),
                      pw.SizedBox(height: 10),
                    ])
                .expand((element) => element)
                .toList(),
          ];
        },
      ),
    );
  }

  Future<void> _generateLocationBasedAnalysis(pw.Document pdf) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    final locationData = await _reportService.analyzeLocationData(
      inventoryProvider.items,
      await requestProvider.getFilteredRequests(
          startDate: _dateRange!.start, endDate: _dateRange!.end),
    );

    final chart = await _reportService.generateLocationBasedChart(locationData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Location-based Analysis',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            ...locationData.keys
                .map((location) => [
                      pw.Header(level: 1, child: pw.Text('$location Analysis')),
                      pw.Table.fromTextArray(
                        headers: ['Metric', 'Value'],
                        data: [
                          [
                            'Total Inventory Items',
                            locationData[location]!
                                .totalInventoryItems
                                .toString()
                          ],
                          [
                            'Total Inventory Value',
                            '\$${locationData[location]!.totalInventoryValue.toStringAsFixed(2)}'
                          ],
                          [
                            'Total Requests',
                            locationData[location]!.totalRequests.toString()
                          ],
                          [
                            'Fulfillment Rate',
                            '${(locationData[location]!.fulfillmentRate * 100).toStringAsFixed(2)}%'
                          ],
                          [
                            'Average Fulfillment Time',
                            '${locationData[location]!.averageFulfillmentTime.toStringAsFixed(2)} hours'
                          ],
                        ],
                        cellStyle: pw.TextStyle(fontSize: 10),
                        cellHeight: 30,
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.centerRight,
                        },
                      ),
                      pw.SizedBox(height: 10),
                    ])
                .expand((element) => element)
                .toList(),
          ];
        },
      ),
    );
  }

  Future<void> _generateAuditTrailReport(pw.Document pdf) async {
    final auditData =
        await _reportService.getAuditTrail(_dateRange!.start, _dateRange!.end);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Audit Trail Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Timestamp', 'User', 'Action', 'Details'],
              data: auditData
                  .map((entry) => [
                        DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(entry.timestamp),
                        entry.user,
                        entry.action,
                        entry.details,
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateFinancialImpactReport(pw.Document pdf) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    final financialData = await _reportService.calculateFinancialImpact(
      inventoryProvider.items,
      await requestProvider.getFilteredRequests(
          startDate: _dateRange!.start, endDate: _dateRange!.end),
    );

    final chart =
        await _reportService.generateFinancialImpactChart(financialData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Financial Impact Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                [
                  'Total Inventory Value',
                  '\$${financialData.totalInventoryValue.toStringAsFixed(2)}'
                ],
                [
                  'Total Request Value',
                  '\$${financialData.totalRequestValue.toStringAsFixed(2)}'
                ],
                [
                  'Cost of Goods Sold',
                  '\$${financialData.costOfGoodsSold.toStringAsFixed(2)}'
                ],
                [
                  'Gross Profit',
                  '\$${financialData.grossProfit.toStringAsFixed(2)}'
                ],
                [
                  'Inventory Turnover Ratio',
                  financialData.inventoryTurnoverRatio.toStringAsFixed(2)
                ],
              ],
              cellStyle: pw.TextStyle(fontSize: 10),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Top 10 Most Valuable Items')),
            pw.Table.fromTextArray(
              headers: ['Item Name', 'Total Value'],
              data: financialData.topValueItems
                  .take(10)
                  .map((item) => [
                        item.name,
                        '\$${item.totalValue.toStringAsFixed(2)}',
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateSystemUsageReport(pw.Document pdf) async {
    final usageData = await _reportService.getSystemUsageData(
        _dateRange!.start, _dateRange!.end);

    final chart = await _reportService.generateSystemUsageChart(usageData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('System Usage Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Active Users', usageData.totalActiveUsers.toString()],
                [
                  'Average Daily Active Users',
                  usageData.averageDailyActiveUsers.toStringAsFixed(2)
                ],
                ['Total Sessions', usageData.totalSessions.toString()],
                [
                  'Average Session Duration',
                  '${usageData.averageSessionDuration.toStringAsFixed(2)} minutes'
                ],
                [
                  'Most Active Day',
                  DateFormat('yyyy-MM-dd').format(usageData.mostActiveDay)
                ],
                [
                  'Least Active Day',
                  DateFormat('yyyy-MM-dd').format(usageData.leastActiveDay)
                ],
              ],
              cellStyle: pw.TextStyle(fontSize: 10),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Most Used Features')),
            pw.Table.fromTextArray(
              headers: ['Feature', 'Usage Count'],
              data: usageData.mostUsedFeatures.entries
                  .map((entry) => [
                        entry.key,
                        entry.value.toString(),
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _generateComplianceReport(pw.Document pdf) async {
    final complianceData = await _reportService.analyzeCompliance(
        _dateRange!.start, _dateRange!.end);

    final chart = await _reportService.generateComplianceChart(complianceData);

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Compliance Report',
                    style: pw.TextStyle(fontSize: 24))),
            pw.SizedBox(height: 20),
            pw.Image(chart),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                [
                  'Overall Compliance Rate',
                  '${(complianceData.overallComplianceRate * 100).toStringAsFixed(2)}%'
                ],
                [
                  'Inventory Policy Compliance',
                  '${(complianceData.inventoryPolicyCompliance * 100).toStringAsFixed(2)}%'
                ],
                [
                  'Approval Process Compliance',
                  '${(complianceData.approvalProcessCompliance * 100).toStringAsFixed(2)}%'
                ],
                [
                  'User Access Compliance',
                  '${(complianceData.userAccessCompliance * 100).toStringAsFixed(2)}%'
                ],
                [
                  'Data Privacy Compliance',
                  '${(complianceData.dataPrivacyCompliance * 100).toStringAsFixed(2)}%'
                ],
              ],
              cellStyle: pw.TextStyle(fontSize: 10),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, child: pw.Text('Non-Compliance Incidents')),
            pw.Table.fromTextArray(
              headers: ['Date', 'Type', 'Description'],
              data: complianceData.nonComplianceIncidents
                  .map((incident) => [
                        DateFormat('yyyy-MM-dd').format(incident.date),
                        incident.type,
                        incident.description,
                      ])
                  .toList(),
              cellStyle: pw.TextStyle(fontSize: 8),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();

    switch (_selectedReportType) {
      case 'Inventory Report':
        await _exportInventoryToExcel(excel);
        break;
      case 'User Activity Report':
        await _exportUserActivityToExcel(excel);
        break;
      // Add cases for other report types
      default:
        throw Exception('Unsupported report type for Excel export');
    }

    final output = await getTemporaryDirectory();
    final file = File(
        "${output.path}/${_selectedReportType.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx");
    await file.writeAsBytes(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel report generated successfully')),
    );

    await OpenFile.open(file.path);
  }

  Future<void> _exportInventoryToExcel(Excel excel) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    await inventoryProvider.refreshItems();
    final inventoryItems = inventoryProvider.items;

    final sheet = excel['Inventory'];

    sheet.appendRow([
      'Name',
      'Category',
      'Subcategory',
      'Quantity',
      'Unit',
      'Threshold',
      'Hashtag'
    ]);

    for (var item in inventoryItems) {
      sheet.appendRow([
        item.name,
        item.category,
        item.subcategory,
        item.quantity,
        item.unit,
        item.threshold,
        item.hashtag,
      ]);
    }
  }

  Future<void> _exportUserActivityToExcel(Excel excel) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final users = await authProvider.getAllUsers();
    final userRequestCounts =
        await _reportService.getUserDailyRequestCounts(_dateRange!);

    final sheet = excel['User Activity'];

    sheet.appendRow(['Name', 'Email', 'Role', 'Mobile', 'Daily Request Count']);

    for (var user in users) {
      final dailyRequestCount = userRequestCounts[user.email] ?? 0;
      sheet.appendRow([
        user.displayName,
        user.email,
        user.role,
        user.phoneNumber ?? 'N/A',
        dailyRequestCount,
      ]);
    }
  }

  Future<void> _scheduleRecurringReport() async {
    // Implement the logic to schedule recurring reports
    // This could involve using a background service or cloud functions
    // For simplicity, we'll just show a dialog to demonstrate the concept
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Schedule Recurring Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select frequency:'),
              DropdownButton<String>(
                value: 'Weekly',
                onChanged: (String? newValue) {
                  // Implement the logic to save the selected frequency
                },
                items: <String>['Daily', 'Weekly', 'Monthly']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Schedule'),
              onPressed: () {
                // Implement the logic to schedule the report
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Recurring report scheduled')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportHistoryButton() {
    return ElevatedButton(
      onPressed: _showReportHistory,
      child: Text('View Report History'),
    );
  }

  Future<void> _showReportHistory() async {
    final reports = await _reportService.getReportHistory();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Report History'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return ListTile(
                  title: Text(report.name),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                      .format(report.generatedAt)),
                  trailing: IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () => _downloadReport(report),
                  ),
                );
              },
            ),
          ),
          actions: [
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

  Future<void> _downloadReport(Report report) async {
    // Implement the logic to download the report
    // This could involve fetching the report from a server or local storage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading report: ${report.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showReportHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Reports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildReportTypeDropdown(),
              SizedBox(height: 16),
              _buildDateRangePicker(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildGenerateButton()),
                  SizedBox(width: 8),
                  Expanded(child: _buildExportToExcelButton()),
                ],
              ),
              SizedBox(height: 16),
              _buildScheduleRecurringReportButton(),
              SizedBox(height: 16),
              _buildReportHistoryButton(),
              SizedBox(height: 16),
              if (_isLoading) _buildLoadingIndicator(),
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportToExcelButton() {
    return ElevatedButton(
      onPressed: _exportToExcel,
      child: Text('Export to Excel'),
      style: ElevatedButton.styleFrom(
        primary: Colors.green,
      ),
    );
  }

  Widget _buildScheduleRecurringReportButton() {
    return ElevatedButton(
      onPressed: _scheduleRecurringReport,
      child: Text('Schedule Recurring Report'),
      style: ElevatedButton.styleFrom(
        primary: Colors.orange,
      ),
    );
  }

  Future<void> _showReportPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final previewData = await _generateReportPreviewData();

      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Report Preview'),
            content: Container(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text('Report Type: $_selectedReportType'),
                  Text(
                      'Date Range: ${_dateRange?.start.toString()} - ${_dateRange?.end.toString()}'),
                  SizedBox(height: 16),
                  Text('Preview Data:'),
                  ...previewData.map((item) => Text('- $item')).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Generate Full Report'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _generateReport();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error generating report preview: $e';
      });
    }
  }

  Future<List<String>> _generateReportPreviewData() async {
    // This is a simplified version. In a real implementation, you'd generate actual preview data.
    switch (_selectedReportType) {
      case 'Inventory Report':
        return ['Total Items: 1000', 'Low Stock Items: 50', 'Categories: 10'];
      case 'User Activity Report':
        return [
          'Active Users: 100',
          'Total Requests: 500',
          'Average Requests per User: 5'
        ];
      case 'Request Status Report':
        return [
          'Pending Requests: 20',
          'Approved Requests: 50',
          'Fulfilled Requests: 30'
        ];
      // Add cases for other report types
      default:
        return ['Preview not available for this report type'];
    }
  }

  Widget _buildPreviewButton() {
    return ElevatedButton(
      onPressed: _showReportPreview,
      child: Text('Preview Report'),
      style: ElevatedButton.styleFrom(
        primary: Colors.blue,
      ),
    );
  }

  Future<void> _processReportInBackground() async {
    // This is a simplified example. In a real app, you'd use a proper background processing solution.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report generation started in the background')),
    );

    // Simulate background processing
    await Future.delayed(Duration(seconds: 5));

    // Notify user when complete
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Background report generation complete')),
    );
  }

  Widget _buildBackgroundProcessingButton() {
    return ElevatedButton(
      onPressed: _processReportInBackground,
      child: Text('Generate in Background'),
      style: ElevatedButton.styleFrom(
        primary: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showReportHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Reports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildReportTypeDropdown(),
              SizedBox(height: 16),
              _buildDateRangePicker(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildGenerateButton()),
                  SizedBox(width: 8),
                  Expanded(child: _buildExportToExcelButton()),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildScheduleRecurringReportButton()),
                  SizedBox(width: 8),
                  Expanded(child: _buildPreviewButton()),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildReportHistoryButton()),
                  SizedBox(width: 8),
                  Expanded(child: _buildBackgroundProcessingButton()),
                ],
              ),
              SizedBox(height: 16),
              if (_isLoading) _buildLoadingIndicator(),
              if (_errorMessage.isNotEmpty) _buildErrorMessage(),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportService {
  Future<pw.MemoryImage> generateInventoryChart(
      List<InventoryItem> items) async {
    // Implement chart generation logic here
    // This is a placeholder implementation
    return pw.MemoryImage((await generateDummyChart()).buffer.asUint8List());
  }

  Future<pw.MemoryImage> generateUserActivityChart(
      Map<String, int> userRequestCounts) async {
    // Implement chart generation logic here
    // This is a placeholder implementation
    return pw.MemoryImage((await generateDummyChart()).buffer.asUint8List());
  }

  Future<pw.MemoryImage> generateRequestStatusChart(
      List<Request> requests) async {
    // Implement chart generation logic here
    // This is a placeholder implementation
    return pw.MemoryImage((await generateDummyChart()).buffer.asUint8List());
  }

  Future<pw.MemoryImage> generateStockRequestChart(
      List<StockRequest> stockRequests) async {
    // Implement chart generation logic here
    // This is a placeholder implementation
    return pw.MemoryImage((await generateDummyChart()).buffer.asUint8List());
  }

  Future<Image> generateDummyChart() async {
    // This is a placeholder method to generate a dummy chart
    // In a real implementation, you'd use a charting library to create actual charts
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.blue;

    canvas.drawRect(Rect.fromLTWH(0, 0, 300, 200), paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 200);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return Image.memory(pngBytes!.buffer.asUint8List());
  }

  Future<Map<String, int>> getUserDailyRequestCounts(
      DateTimeRange dateRange) async {
    // Implement the logic to get user daily request counts
    // This is a placeholder implementation
    return {
      'user1@example.com': 5,
      'user2@example.com': 3,
      'user3@example.com': 7,
    };
  }

  Future<List<InventoryTurnoverData>> calculateInventoryTurnover(
    List<InventoryItem> items,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Implement inventory turnover calculation logic
    // This is a placeholder implementation
    return items
        .map((item) => InventoryTurnoverData(
              name: item.name,
              beginningInventory: item.quantity,
              endingInventory: item.quantity,
              cogs: 1000,
              turnoverRatio: 2.5,
            ))
        .toList();
  }

  Future<FulfillmentPerformanceData> calculateFulfillmentPerformance(
      List<Request> requests) async {
    // Implement fulfillment performance calculation logic
    // This is a placeholder implementation
    return FulfillmentPerformanceData(
      averageFulfillmentTime: 24,
      onTimeFulfillmentRate: 0.95,
      totalRequests: requests.length,
      fulfilledRequests: requests.where((r) => r.status == 'fulfilled').length,
      pendingRequests: requests.where((r) => r.status == 'pending').length,
    );
  }

  Future<List<ItemUsageData>> calculateItemUsage(
    List<InventoryItem> items,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Implement item usage calculation logic
    // This is a placeholder implementation
    return items
        .map((item) => ItemUsageData(
              name: item.name,
              totalUsage: 100,
              averageDailyUsage: 10,
              peakUsageDate: DateTime.now(),
              peakUsageAmount: 20,
            ))
        .toList();
  }

  Future<ApprovalProcessData> analyzeApprovalProcess(
      List<Request> requests) async {
    // Implement approval process analysis logic
    // This is a placeholder implementation
    return ApprovalProcessData(
      averageApprovalTime: 4,
      approvalRate: 0.8,
      totalRequests: requests.length,
      approvedRequests: requests.where((r) => r.status == 'approved').length,
      rejectedRequests: requests.where((r) => r.status == 'rejected').length,
      topRejectionReasons: {'Insufficient stock': 5, 'Invalid request': 3},
    );
  }

  Future<Map<String, UserRoleEfficiencyData>> calculateUserRoleEfficiency(
    List<UserModel> users,
    List<Request> requests,
  ) async {
    // Implement user role efficiency calculation logic
    // This is a placeholder implementation
    return {
      'Admin': UserRoleEfficiencyData(
        averageRequestsProcessed: 50,
        averageProcessingTime: 2,
        approvalRate: 0.9,
      ),
      'Manager': UserRoleEfficiencyData(
        averageRequestsProcessed: 30,
        averageProcessingTime: 3,
        approvalRate: 0.85,
      ),
    };
  }

  Future<Map<String, LocationData>> analyzeLocationData(
    List<InventoryItem> items,
    List<Request> requests,
  ) async {
    // Implement location-based analysis logic
    // This is a placeholder implementation
    return {
      'Warehouse A': LocationData(
        totalInventoryItems: 500,
        totalInventoryValue: 50000,
        totalRequests: 100,
        fulfillmentRate: 0.95,
        averageFulfillmentTime: 12,
      ),
      'Warehouse B': LocationData(
        totalInventoryItems: 300,
        totalInventoryValue: 30000,
        totalRequests: 80,
        fulfillmentRate: 0.9,
        averageFulfillmentTime: 14,
      ),
    };
  }

  Future<List<AuditEntry>> getAuditTrail(
      DateTime startDate, DateTime endDate) async {
    // Implement audit trail fetching logic
    // This is a placeholder implementation
    return [
      AuditEntry(
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        user: 'John Doe',
        action: 'Item Added',
        details: 'Added 100 units of Item A',
      ),
      AuditEntry(
        timestamp: DateTime.now().subtract(Duration(days: 2)),
        user: 'Jane Smith',
        action: 'Request Approved',
        details: 'Approved request #12345',
      ),
    ];
  }

  Future<FinancialImpactData> calculateFinancialImpact(
    List<InventoryItem> items,
    List<Request> requests,
  ) async {
    // Implement financial impact calculation logic
    // This is a placeholder implementation
    return FinancialImpactData(
      totalInventoryValue: 100000,
      totalRequestValue: 50000,
      costOfGoodsSold: 40000,
      grossProfit: 10000,
      inventoryTurnoverRatio: 2.5,
      topValueItems: items
          .map((item) =>
              ValueItem(name: item.name, totalValue: item.quantity * 10))
          .toList(),
    );
  }

  Future<SystemUsageData> getSystemUsageData(
      DateTime startDate, DateTime endDate) async {
    // Implement system usage data fetching logic
    // This is a placeholder implementation
    return SystemUsageData(
      totalActiveUsers: 100,
      averageDailyActiveUsers: 50,
      totalSessions: 1000,
      averageSessionDuration: 15,
      mostActiveDay: DateTime.now().subtract(Duration(days: 3)),
      leastActiveDay: DateTime.now().subtract(Duration(days: 7)),
      mostUsedFeatures: {
        'Inventory Management': 500,
        'Request Processing': 300
      },
    );
  }

  Future<ComplianceData> analyzeCompliance(
      DateTime startDate, DateTime endDate) async {
    // Implement compliance analysis logic
    // This is a placeholder implementation
    return ComplianceData(
      overallComplianceRate: 0.95,
      inventoryPolicyCompliance: 0.98,
      approvalProcessCompliance: 0.96,
      userAccessCompliance: 0.99,
      dataPrivacyCompliance: 0.97,
      nonComplianceIncidents: [
        NonComplianceIncident(
          date: DateTime.now().subtract(Duration(days: 10)),
          type: 'Inventory Policy',
          description: 'Item quantity adjusted without proper documentation',
        ),
      ],
    );
  }

  Future<List<Report>> getReportHistory() async {
    // Implement report history fetching logic
    // This is a placeholder implementation
    return [
      Report(
        name: 'Inventory Report',
        generatedAt: DateTime.now().subtract(Duration(days: 1)),
        filePath: '/path/to/report1.pdf',
      ),
      Report(
        name: 'User Activity Report',
        generatedAt: DateTime.now().subtract(Duration(days: 3)),
        filePath: '/path/to/report2.pdf',
      ),
    ];
  }
}

class InventoryTurnoverData {
  final String name;
  final int beginningInventory;
  final int endingInventory;
  final double cogs;
  final double turnoverRatio;

  InventoryTurnoverData({
    required this.name,
    required this.beginningInventory,
    required this.endingInventory,
    required this.cogs,
    required this.turnoverRatio,
  });
}

class FulfillmentPerformanceData {
  final double averageFulfillmentTime;
  final double onTimeFulfillmentRate;
  final int totalRequests;
  final int fulfilledRequests;
  final int pendingRequests;

  FulfillmentPerformanceData({
    required this.averageFulfillmentTime,
    required this.onTimeFulfillmentRate,
    required this.totalRequests,
    required this.fulfilledRequests,
    required this.pendingRequests,
  });
}

class ItemUsageData {
  final String name;
  final int totalUsage;
  final double averageDailyUsage;
  final DateTime peakUsageDate;
  final int peakUsageAmount;

  ItemUsageData({
    required this.name,
    required this.totalUsage,
    required this.averageDailyUsage,
    required this.peakUsageDate,
    required this.peakUsageAmount,
  });
}

class ApprovalProcessData {
  final double averageApprovalTime;
  final double approvalRate;
  final int totalRequests;
  final int approvedRequests;
  final int rejectedRequests;
  final Map<String, int> topRejectionReasons;

  ApprovalProcessData({
    required this.averageApprovalTime,
    required this.approvalRate,
    required this.totalRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
    required this.topRejectionReasons,
  });
}

class UserRoleEfficiencyData {
  final double averageRequestsProcessed;
  final double averageProcessingTime;
  final double approvalRate;

  UserRoleEfficiencyData({
    required this.averageRequestsProcessed,
    required this.averageProcessingTime,
    required this.approvalRate,
  });
}

class LocationData {
  final int totalInventoryItems;
  final double totalInventoryValue;
  final int totalRequests;
  final double fulfillmentRate;
  final double averageFulfillmentTime;

  LocationData({
    required this.totalInventoryItems,
    required this.totalInventoryValue,
    required this.totalRequests,
    required this.fulfillmentRate,
    required this.averageFulfillmentTime,
  });
}

class AuditEntry {
  final DateTime timestamp;
  final String user;
  final String action;
  final String details;

  AuditEntry({
    required this.timestamp,
    required this.user,
    required this.action,
    required this.details,
  });
}

class FinancialImpactData {
  final double totalInventoryValue;
  final double totalRequestValue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double inventoryTurnoverRatio;
  final List<ValueItem> topValueItems;

  FinancialImpactData({
    required this.totalInventoryValue,
    required this.totalRequestValue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.inventoryTurnoverRatio,
    required this.topValueItems,
  });
}

class ValueItem {
  final String name;
  final double totalValue;

  ValueItem({
    required this.name,
    required this.totalValue,
  });
}

class SystemUsageData {
  final int totalActiveUsers;
  final double averageDailyActiveUsers;
  final int totalSessions;
  final double averageSessionDuration;
  final DateTime mostActiveDay;
  final DateTime leastActiveDay;
  final Map<String, int> mostUsedFeatures;

  SystemUsageData({
    required this.totalActiveUsers,
    required this.averageDailyActiveUsers,
    required this.totalSessions,
    required this.averageSessionDuration,
    required this.mostActiveDay,
    required this.leastActiveDay,
    required this.mostUsedFeatures,
  });
}

class ComplianceData {
  final double overallComplianceRate;
  final double inventoryPolicyCompliance;
  final double approvalProcessCompliance;
  final double userAccessCompliance;
  final double dataPrivacyCompliance;
  final List<NonComplianceIncident> nonComplianceIncidents;

  ComplianceData({
    required this.overallComplianceRate,
    required this.inventoryPolicyCompliance,
    required this.approvalProcessCompliance,
    required this.userAccessCompliance,
    required this.dataPrivacyCompliance,
    required this.nonComplianceIncidents,
  });
}

class NonComplianceIncident {
  final DateTime date;
  final String type;
  final String description;

  NonComplianceIncident({
    required this.date,
    required this.type,
    required this.description,
  });
}

class Report {
  final String name;
  final DateTime generatedAt;
  final String filePath;

  Report({
    required this.name,
    required this.generatedAt,
    required this.filePath,
  });
}

// Add this method to the ReportsScreen class to handle report downloading
Future<void> _downloadReport(Report report) async {
  try {
    final file = File(report.filePath);
    if (await file.exists()) {
      final output = await getExternalStorageDirectory();
      final downloadPath =
          '${output!.path}/${report.name}_${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.pdf';
      await file.copy(downloadPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Report downloaded successfully: $downloadPath')),
      );

      await OpenFile.open(downloadPath);
    } else {
      throw Exception('Report file not found');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error downloading report: $e')),
    );
  }
}

// Add this method to handle background report generation
Future<void> _generateReportInBackground() async {
  final reportService = ReportService();

  // Show a notification that background processing has started
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Background report generation started')),
  );

  try {
    // Perform the report generation in a separate isolate
    final result = await compute(_backgroundReportGeneration, {
      'reportType': _selectedReportType,
      'startDate': _dateRange!.start,
      'endDate': _dateRange!.end,
    });

    // Save the generated report
    final output = await getExternalStorageDirectory();
    final filePath =
        '${output!.path}/${_selectedReportType.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.pdf';
    await File(filePath).writeAsBytes(result);

    // Show a notification that the report is ready
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Background report generation complete'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => OpenFile.open(filePath),
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error generating report in background: $e')),
    );
  }
}

// This function runs in a separate isolate
Future<Uint8List> _backgroundReportGeneration(
    Map<String, dynamic> params) async {
  final reportType = params['reportType'] as String;
  final startDate = params['startDate'] as DateTime;
  final endDate = params['endDate'] as DateTime;

  final reportService = ReportService();
  final pdf = pw.Document();

  switch (reportType) {
    case 'Inventory Report':
      // Generate inventory report
      break;
    case 'User Activity Report':
      // Generate user activity report
      break;
    // Add cases for other report types
  }

  return pdf.save();
}

// Add this method to schedule recurring reports
Future<void> _scheduleRecurringReport() async {
  final selectedFrequency = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Select Report Frequency'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'Daily');
              },
              child: Text('Daily'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'Weekly');
              },
              child: Text('Weekly'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'Monthly');
              },
              child: Text('Monthly'),
            ),
          ],
        );
      });

  if (selectedFrequency != null) {
    // Here you would typically save this configuration to a database or shared preferences
    // and set up a background task to generate the report at the specified frequency
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Scheduled $selectedFrequency recurring report for $_selectedReportType')),
    );
  }
}

// Don't forget to update the build method to include the new buttons:
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Reports'),
      actions: [
        IconButton(
          icon: Icon(Icons.history),
          onPressed: _showReportHistory,
        ),
      ],
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Reports',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildReportTypeDropdown(),
            SizedBox(height: 16),
            _buildDateRangePicker(),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildGenerateButton()),
                SizedBox(width: 8),
                Expanded(child: _buildExportToExcelButton()),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildScheduleRecurringReportButton()),
                SizedBox(width: 8),
                Expanded(child: _buildPreviewButton()),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReportHistoryButton()),
                SizedBox(width: 8),
                Expanded(child: _buildBackgroundProcessingButton()),
              ],
            ),
            SizedBox(height: 16),
            if (_isLoading) _buildLoadingIndicator(),
            if (_errorMessage.isNotEmpty) _buildErrorMessage(),
          ],
        ),
      ),
    ),
  );
}



// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import 'dart:io';

// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';

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
//                 'Request Status Report',
//                 'Stock Request Report', // Added new report type
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
//       // case 'Inventory Report':
//       // final inventoryItems =
//       //     Provider.of<InventoryProvider>(context, listen: false).items;
//       case 'Inventory Report':
//         final inventoryProvider =
//             Provider.of<InventoryProvider>(context, listen: false);

//         if (inventoryProvider.isLoading) {
//           // Show loading indicator if items are being fetched
//           await showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertDialog(
//                 content: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 16),
//                     Text("Loading inventory items..."),
//                   ],
//                 ),
//               );
//             },
//           );
//         }

//         if (inventoryProvider.items.isEmpty) {
//           // If items are still empty, try fetching again
//           await inventoryProvider.refreshItems();
//         }

//         final inventoryItems = inventoryProvider.items;
//         print(
//             "Generating Inventory Report. Items count: ${inventoryItems.length}");

//         if (inventoryItems.isEmpty) {
//           pdf.addPage(
//             pw.Page(
//               build: (pw.Context context) {
//                 return pw.Center(
//                   child: pw.Text(
//                       'No inventory items found. Please check your database connection.',
//                       style: pw.TextStyle(fontSize: 18)),
//                 );
//               },
//             ),
//           );
//         } else {
//           final inventoryProvider =
//               Provider.of<InventoryProvider>(context, listen: false);
//           final inventoryItems = inventoryProvider.items;
//           print(
//               "Generating Inventory Report. Items count: ${inventoryItems.length}");

//           if (inventoryItems.isEmpty) {
//             pdf.addPage(
//               pw.Page(
//                 build: (pw.Context context) {
//                   return pw.Center(
//                     child: pw.Text('No inventory items found',
//                         style: pw.TextStyle(fontSize: 24)),
//                   );
//                 },
//               ),
//             );
//           } else {
//             pdf.addPage(
//               pw.MultiPage(
//                 build: (pw.Context context) {
//                   return [
//                     pw.Header(
//                         level: 0,
//                         child: pw.Text('Inventory Report',
//                             style: pw.TextStyle(fontSize: 24))),
//                     pw.SizedBox(height: 20),
//                     pw.Table.fromTextArray(
//                       headers: [
//                         'Name',
//                         'Category',
//                         'Subcategory',
//                         'Quantity',
//                         'Unit',
//                         'Threshold',
//                         'Hashtag'
//                       ],
//                       data: inventoryItems.map((item) {
//                         print("Processing item: $item"); // Debug print
//                         return [
//                           item['name']?.toString() ?? '',
//                           item['category']?.toString() ?? '',
//                           item['subcategory']?.toString() ?? '',
//                           item['quantity']?.toString() ?? '',
//                           item['unit']?.toString() ?? '',
//                           item['threshold']?.toString() ?? '',
//                           item['hashtag']?.toString() ?? '',
//                         ];
//                       }).toList(),
//                       cellStyle: pw.TextStyle(fontSize: 8),
//                       cellHeight: 30,
//                       cellAlignments: {
//                         0: pw.Alignment.centerLeft,
//                         1: pw.Alignment.centerLeft,
//                         2: pw.Alignment.centerLeft,
//                         3: pw.Alignment.centerRight,
//                         4: pw.Alignment.centerLeft,
//                         5: pw.Alignment.centerRight,
//                         6: pw.Alignment.centerLeft,
//                       },
//                     ),
//                     pw.SizedBox(height: 20),
//                     pw.Header(level: 1, child: pw.Text('Low Stock Items')),
//                     pw.Table.fromTextArray(
//                       headers: ['Name', 'Current Quantity', 'Threshold'],
//                       data: inventoryItems
//                           .where((item) =>
//                               (item['quantity'] ?? 0) <
//                               (item['threshold'] ?? 0))
//                           .map((item) => [
//                                 item['name'] ?? '',
//                                 item['quantity']?.toString() ?? '',
//                                 item['threshold']?.toString() ?? '',
//                               ])
//                           .toList(),
//                       cellStyle: pw.TextStyle(fontSize: 8),
//                       cellHeight: 30,
//                       cellAlignments: {
//                         0: pw.Alignment.centerLeft,
//                         1: pw.Alignment.centerRight,
//                         2: pw.Alignment.centerRight,
//                       },
//                     ),
//                   ];
//                 },
//               ),
//             );
//           }
//         }
//         break;

//       case 'User Activity Report':
//         final users =
//             await FirebaseFirestore.instance.collection('users').get();
//         final userRequestCounts = await _getUserDailyRequestCounts();

//         pdf.addPage(
//           pw.MultiPage(
//             build: (pw.Context context) {
//               return [
//                 pw.Header(
//                     level: 0,
//                     child: pw.Text('User Activity Report',
//                         style: pw.TextStyle(fontSize: 24))),
//                 pw.SizedBox(height: 20),
//                 pw.Table.fromTextArray(
//                   headers: [
//                     'Name',
//                     'Email',
//                     'Role',
//                     'Mobile',
//                     'Daily Request Count'
//                   ],
//                   data: users.docs.map((user) {
//                     final userData = user.data();
//                     final userEmail = userData['email'] ?? 'N/A';
//                     final dailyRequestCount = userRequestCounts[userEmail] ?? 0;
//                     return [
//                       userData['name'] ?? 'N/A',
//                       userEmail,
//                       userData['role'] ?? 'N/A',
//                       userData['mobile'] ?? 'N/A',
//                       dailyRequestCount.toString(),
//                     ];
//                   }).toList(),
//                   cellStyle: pw.TextStyle(fontSize: 8),
//                   cellHeight: 30,
//                   cellAlignments: {
//                     0: pw.Alignment.centerLeft,
//                     1: pw.Alignment.centerLeft,
//                     2: pw.Alignment.centerLeft,
//                     3: pw.Alignment.centerLeft,
//                     4: pw.Alignment.centerRight,
//                   },
//                 ),
//               ];
//             },
//           ),
//         );
//         break;

//       case 'Request Status Report':
//         final requests = Provider.of<RequestProvider>(context, listen: false)
//             .requests
//             .where((request) {
//           if (_dateRange == null) return true;
//           final requestDate = request['timestamp'];
//           return requestDate.isAfter(_dateRange!.start) &&
//               requestDate.isBefore(_dateRange!.end);
//         }).toList();
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
//                     'Status',
//                     'Unique Code',
//                     'Date'
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
//                             request['status'],
//                             request['uniqueCode'],
//                             request['timestamp'].toString()
//                           ])
//                       .toList(),
//                 ),
//               ],
//             );
//           },
//         ));
//         break;

//       case 'Stock Request Report':
//         final stockRequests =
//             await Provider.of<RequestProvider>(context, listen: false)
//                 .getDetailedStockRequestReport(_dateRange);

//         pdf.addPage(
//           pw.MultiPage(
//             build: (pw.Context context) {
//               return [
//                 pw.Header(
//                     level: 0,
//                     child: pw.Text('Detailed Stock Request Report',
//                         style: pw.TextStyle(
//                             fontSize: 18, fontWeight: pw.FontWeight.bold))),
//                 pw.SizedBox(height: 20),
//                 pw.Table.fromTextArray(
//                   headers: [
//                     'ID',
//                     'Created By',
//                     'Status',
//                     'Created At',
//                     'Items',
//                     'Note'
//                   ],
//                   data: stockRequests
//                       .map((request) => [
//                             request['id'],
//                             request['createdBy'],
//                             request['status'],
//                             request['createdAt'],
//                             request['items'],
//                             request['note'],
//                           ])
//                       .toList(),
//                   cellStyle: pw.TextStyle(fontSize: 8),
//                   cellHeight: 30,
//                   cellAlignments: {
//                     0: pw.Alignment.centerLeft,
//                     1: pw.Alignment.centerLeft,
//                     2: pw.Alignment.center,
//                     3: pw.Alignment.center,
//                     4: pw.Alignment.centerLeft,
//                     5: pw.Alignment.centerLeft,
//                   },
//                 ),
//                 pw.SizedBox(height: 20),
//                 ...stockRequests
//                     .map((request) => [
//                           pw.Header(
//                               level: 1,
//                               child:
//                                   pw.Text('Request Details: ${request['id']}')),
//                           pw.Paragraph(text: 'Status: ${request['status']}'),
//                           pw.Paragraph(
//                               text:
//                                   'Created By: ${request['createdBy']} on ${request['createdAt']}'),
//                           pw.Paragraph(text: 'Items: ${request['items']}'),
//                           pw.Paragraph(text: 'Note: ${request['note']}'),
//                           if (request['status'] == 'approved')
//                             pw.Paragraph(
//                                 text:
//                                     'Approved By: ${request['approvedBy']} on ${request['approvedAt']}'),
//                           if (request['status'] == 'fulfilled')
//                             pw.Paragraph(
//                                 text:
//                                     'Fulfilled By: ${request['fulfilledBy']} on ${request['fulfilledAt']}'),
//                           if (request['status'] == 'rejected') ...[
//                             pw.Paragraph(
//                                 text:
//                                     'Rejected By: ${request['rejectedBy']} on ${request['rejectedAt']}'),
//                             pw.Paragraph(
//                                 text:
//                                     'Rejection Reason: ${request['rejectionReason']}'),
//                           ],
//                           pw.SizedBox(height: 10),
//                         ])
//                     .expand((element) => element)
//                     .toList(),
//               ];
//             },
//           ),
//         );
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

//   Future<Map<String, int>> _getUserDailyRequestCounts() async {
//     final now = DateTime.now();
//     final startOfDay = DateTime(now.year, now.month, now.day);
//     final endOfDay = startOfDay.add(Duration(days: 1));

//     final querySnapshot = await FirebaseFirestore.instance
//         .collection('requests')
//         .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
//         .where('timestamp', isLessThan: endOfDay)
//         .get();

//     final Map<String, int> userRequestCounts = {};

//     for (var doc in querySnapshot.docs) {
//       final data = doc.data();
//       final userEmail = data['createdByEmail'] as String?;
//       if (userEmail != null) {
//         userRequestCounts[userEmail] = (userRequestCounts[userEmail] ?? 0) + 1;
//       }
//     }

//     return userRequestCounts;
//   }
// }
