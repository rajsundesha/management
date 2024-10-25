// import 'dart:nativewrappers/_internal/vm/lib/async_patch.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class OverviewTab extends StatefulWidget {
  @override
  _OverviewTabState createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            SizedBox(height: 24),
            _buildDateSelector(),
            SizedBox(height: 24),
            _buildStatisticsSection(),
            SizedBox(height: 24),
            _buildChartSection(),
            SizedBox(height: 24),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Gate Man',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
          Icon(Icons.account_circle, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton(
          onPressed: () => _selectDate(context),
          child: Text('Change Date'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildStatisticsSection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<Map<String, int>>(
          stream: requestProvider.getDashboardStats(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final stats = snapshot.data ?? {};
            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Total Requests', stats['total'] ?? 0,
                    Icons.list_alt, Colors.blue),
                _buildStatCard('Pending', stats['pending'] ?? 0,
                    Icons.hourglass_empty, Colors.red),
                _buildStatCard('Approved', stats['approved'] ?? 0,
                    Icons.check_circle, Colors.green),
                _buildStatCard('Fulfilled', stats['fulfilled'] ?? 0,
                    Icons.done_all, Colors.orange),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<Map<String, int>>(
          stream: requestProvider.getDashboardStats(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final stats = snapshot.data ?? {};
            return Container(
              height: 260,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Status Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: Colors.green,
                            value: (stats['approved'] ?? 0).toDouble(),
                            title: 'Approved',
                            radius: 100,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          PieChartSectionData(
                            color: Colors.orange,
                            value: (stats['fulfilled'] ?? 0).toDouble(),
                            title: 'Fulfilled',
                            radius: 100,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          PieChartSectionData(
                            color: Colors.red,
                            value: (stats['pending'] ?? 0).toDouble(),
                            title: 'Pending',
                            radius: 100,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestProvider.getRecentActivityStream(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final recentActivity = snapshot.data ?? [];
            return Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (recentActivity.isEmpty) Text('No recent activity'),
                  if (recentActivity.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: recentActivity.length,
                      itemBuilder: (context, index) {
                        final activity = recentActivity[index];
                        return ListTile(
                          leading: _getStatusIcon(activity['status']),
                          title: Text(
                              '${activity['type']} Request #${activity['id']}'),
                          subtitle: Text('Status: ${activity['status']}'),
                          trailing: Text(DateFormat('HH:mm')
                              .format(activity['timestamp'].toDate())),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icon(Icons.check_circle, color: Colors.green);
      case 'fulfilled':
        return Icon(Icons.done_all, color: Colors.orange);
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.red);
      default:
        return Icon(Icons.info, color: Colors.grey);
    }
  }
}

// approved_requests_tab.dart

class ApprovedRequestsTab extends StatefulWidget {
  @override
  _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
}

class _ApprovedRequestsTabState extends State<ApprovedRequestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSearchBar(),
        ),
        Expanded(
          child: _buildApprovedRequestsList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Requests by Picker Name or Contact',
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

  Widget _buildApprovedRequestsList() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestProvider.getApprovedRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            List<Map<String, dynamic>> approvedRequests = snapshot.data ?? [];

            // Apply search filter
            approvedRequests = approvedRequests.where((request) {
              String pickerName =
                  request['pickerName']?.toString().toLowerCase() ?? '';
              String pickerContact = request['pickerContact']?.toString() ?? '';
              String query = _searchQuery.toLowerCase();

              return pickerName.contains(query) ||
                  pickerContact.contains(query);
            }).toList();

            if (approvedRequests.isEmpty) {
              return Center(child: Text('No approved requests found.'));
            }

            return ListView.builder(
              itemCount: approvedRequests.length,
              itemBuilder: (context, index) {
                final request = approvedRequests[index];
                return _buildApprovedRequestCard(context, request);
              },
            );
          },
        );
      },
    );
  }

  // Widget _buildApprovedRequestCard(
  //     BuildContext context, Map<String, dynamic> request) {
  //   return Card(
  //     elevation: 2,
  //     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     child: ListTile(
  //       title: Text(
  //         'Items: ${_formatItems(request['items'])}',
  //         style: TextStyle(fontWeight: FontWeight.bold),
  //       ),
  //       subtitle: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           SizedBox(height: 8),
  //           Text('Location: ${request['location'] ?? 'N/A'}'),
  //           Text('Picker: ${request['pickerName'] ?? 'N/A'}'),
  //           Text('Contact: ${request['pickerContact'] ?? 'N/A'}'),
  //           Text('Status: ${request['status'] ?? 'N/A'}',
  //               style: TextStyle(color: _getStatusColor(request['status']))),
  //           if (request['status'] == 'partially_fulfilled')
  //             Padding(
  //               padding: const EdgeInsets.only(top: 8.0),
  //               child: LinearProgressIndicator(
  //                 value: _calculateFulfillmentProgress(request),
  //                 backgroundColor: Colors.grey[300],
  //                 color: Colors.blue,
  //               ),
  //             ),
  //         ],
  //       ),
  //       isThreeLine: true,
  //       leading: Icon(Icons.request_page, color: Colors.green),
  //       trailing: IconButton(
  //         icon: Icon(Icons.verified, color: Colors.blue),
  //         onPressed: () =>
  //             _verifyCodeDialog(context, request['uniqueCode'], request),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildApprovedRequestCard(
      BuildContext context, Map<String, dynamic> request) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          'Items: ${_formatItems(request['items'])}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text('Location: ${request['location'] ?? 'N/A'}'),
            Text('Picker: ${request['pickerName'] ?? 'N/A'}'),
            Text('Contact: ${request['pickerContact'] ?? 'N/A'}'),
            Text('Status: ${request['status'] ?? 'N/A'}',
                style: TextStyle(color: _getStatusColor(request['status']))),
            Text('Unique Code: ${request['uniqueCode'] ?? 'N/A'}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (request['status'] == 'partially_fulfilled')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  value: _calculateFulfillmentProgress(request),
                  backgroundColor: Colors.grey[300],
                  color: Colors.blue,
                ),
              ),
          ],
        ),
        isThreeLine: true,
        leading: Icon(Icons.request_page, color: Colors.green),
        trailing: IconButton(
          icon: Icon(Icons.verified, color: Colors.blue),
          onPressed: () =>
              _verifyCodeDialog(context, request['uniqueCode'], request),
        ),
      ),
    );
  }

  void _verifyCodeDialog(
      BuildContext context, String? uniqueCode, Map<String, dynamic> request) {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Unique Code'),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(hintText: 'Enter unique code'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Verify'),
            onPressed: () {
              if (codeController.text.trim() == uniqueCode) {
                Navigator.of(context).pop();
                _showItemConfirmationDialog(context, request);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid code. Please try again.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showItemConfirmationDialog(
      BuildContext context, Map<String, dynamic> request) {
    List<Map<String, dynamic>> items =
        List<Map<String, dynamic>>.from(request['items'] ?? []);
    List<TextEditingController> controllers =
        List.generate(items.length, (index) => TextEditingController());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Confirm Received Items',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue[800])),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    double requiredQuantity =
                        (items[index]['quantity'] as num?)?.toDouble() ?? 0.0;
                    double receivedQuantity =
                        (items[index]['receivedQuantity'] as num?)
                                ?.toDouble() ??
                            0.0;
                    double remainingQuantity =
                        requiredQuantity - receivedQuantity;

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[index]['name'] ?? 'Unknown Item',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87)),
                            SizedBox(height: 8),
                            Text(
                                'Requested: $requiredQuantity ${items[index]['unit'] ?? ''}',
                                style: TextStyle(
                                    color: Colors.green[700], fontSize: 14)),
                            Text(
                                'Remaining: $remainingQuantity ${items[index]['unit'] ?? ''}',
                                style: TextStyle(
                                    color: Colors.blue[700], fontSize: 14)),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: controllers[index],
                              decoration: InputDecoration(
                                labelText: 'Received',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                suffixText: items[index]['unit'] ?? '',
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (value) {
                                double? receivedQuantity =
                                    double.tryParse(value);
                                if (receivedQuantity != null &&
                                    receivedQuantity > remainingQuantity) {
                                  controllers[index].text =
                                      remainingQuantity.toString();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Cannot receive more than the remaining quantity'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel',
                      style: TextStyle(fontSize: 14, color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('Confirm', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () =>
                      _updateRequest(context, request, items, controllers),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateRequest(
      BuildContext context,
      Map<String, dynamic> request,
      List<Map<String, dynamic>> items,
      List<TextEditingController> controllers) async {
    bool isFullyFulfilled = true;
    for (int i = 0; i < items.length; i++) {
      double newlyReceivedQuantity =
          double.tryParse(controllers[i].text) ?? 0.0;
      double previouslyReceivedQuantity =
          (items[i]['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
      double totalReceivedQuantity =
          previouslyReceivedQuantity + newlyReceivedQuantity;
      double totalQuantity = (items[i]['quantity'] as num?)?.toDouble() ?? 0.0;

      items[i]['receivedQuantity'] = totalReceivedQuantity;
      items[i]['remainingQuantity'] =
          math.max(0, totalQuantity - totalReceivedQuantity);

      if (items[i]['remainingQuantity'] > 0) {
        isFullyFulfilled = false;
      }
    }

    String newStatus = isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';

    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request['id'])
          .update({
        'status': newStatus,
        'items': items,
        'fulfilledAt': isFullyFulfilled ? FieldValue.serverTimestamp() : null,
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFullyFulfilled
              ? 'Request fully fulfilled!'
              : 'Items partially received successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error updating request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // void _updateRequest(
  //     BuildContext context,
  //     Map<String, dynamic> request,
  //     List<Map<String, dynamic>> items,
  //     List<TextEditingController> controllers) async {
  //   bool isFullyFulfilled = true;
  //   for (int i = 0; i < items.length; i++) {
  //     double newlyReceivedQuantity =
  //         double.tryParse(controllers[i].text) ?? 0.0;
  //     double previouslyReceivedQuantity =
  //         (items[i]['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
  //     double totalReceivedQuantity =
  //         previouslyReceivedQuantity + newlyReceivedQuantity;
  //     double totalQuantity = (items[i]['quantity'] as num?)?.toDouble() ?? 0.0;

  //     items[i]['receivedQuantity'] = totalReceivedQuantity;
  //     items[i]['remainingQuantity'] = totalQuantity - totalReceivedQuantity;

  //     if (totalReceivedQuantity < totalQuantity) {
  //       isFullyFulfilled = false;
  //     }
  //   }

  //   String newStatus = isFullyFulfilled ? 'fulfilled' : 'partially_fulfilled';

  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('requests')
  //         .doc(request['id'])
  //         .update({
  //       'status': newStatus,
  //       'items': items,
  //       'fulfilledAt': isFullyFulfilled ? FieldValue.serverTimestamp() : null,
  //     });

  //     Navigator.of(context).pop();
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(isFullyFulfilled
  //             ? 'Request fully fulfilled!'
  //             : 'Items partially received successfully!'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //   } catch (e) {
  //     print("Error updating request: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error updating request. Please try again.'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  double _calculateFulfillmentProgress(Map<String, dynamic> request) {
    List<dynamic> items = request['items'] ?? [];
    if (items.isEmpty) return 0.0;

    double totalReceived = 0.0;
    double totalRequested = 0.0;

    for (var item in items) {
      totalReceived += (item['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
      totalRequested += (item['quantity'] as num?)?.toDouble() ?? 0.0;
    }

    return totalRequested > 0 ? totalReceived / totalRequested : 0.0;
  }

  String _formatItems(List<dynamic>? items) {
    if (items == null || items.isEmpty) return 'No items';
    return items
        .map((item) =>
            '${item['quantity'] ?? 0} ${item['unit'] ?? ''} x ${item['name'] ?? 'Unknown'}')
        .join(', ');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'fulfilled':
        return Colors.blue;
      case 'partially_fulfilled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class RecentRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
              return _buildEmptyWidget(requestProvider);
            }
            return _buildRequestList(context, requests);
          },
        );
      },
    );
  }

  Widget _buildEmptyWidget(RequestProvider requestProvider) {
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
        return _buildRecentRequestCard(context, request);
      },
    );
  }

  Widget _buildRecentRequestCard(
      BuildContext context, Map<String, dynamic> request) {
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
                ...request['items'].map<Widget>((item) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Text('${item['quantity']} x ${item['name']}'),
                    )),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
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

// the end
