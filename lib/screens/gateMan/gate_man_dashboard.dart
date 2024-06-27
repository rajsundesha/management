import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class GateManDashboard extends StatefulWidget {
  @override
  _GateManDashboardState createState() => _GateManDashboardState();
}

class _GateManDashboardState extends State<GateManDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gate Man Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            SizedBox(height: 16),
            _buildStatistics(context),
            SizedBox(height: 16),
            Text(
              'Approved Requests',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<RequestProvider>(
                builder: (context, requestProvider, child) {
                  final approvedRequests =
                      requestProvider.requests.where((request) {
                    return request['status'] == 'approved' &&
                        (request['pickerName']
                                .toString()
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            request['pickerContact']
                                .toString()
                                .contains(_searchQuery));
                  }).toList();

                  return ListView.builder(
                    itemCount: approvedRequests.length,
                    itemBuilder: (context, index) {
                      final request = approvedRequests[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
                          ),
                          subtitle: Text(
                            'Location: ${request['location']}\n'
                            'Picker: ${request['pickerName']}\n'
                            'Contact: ${request['pickerContact']}\n'
                            'Status: ${request['status']}\n'
                            'Unique Code: ${request['uniqueCode']}',
                          ),
                          leading: Icon(
                            Icons.request_page,
                            color: Colors.green,
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.verified, color: Colors.blue),
                            onPressed: () {
                              _verifyCodeDialog(context, request['uniqueCode']);
                            },
                          ),
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

  Widget _buildStatistics(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);
    final todayRequests = requestProvider.requests.where((request) {
      final now = DateTime.now();
      final requestDate = request['timestamp'] as DateTime;
      return requestDate.year == now.year &&
          requestDate.month == now.month &&
          requestDate.day == now.day;
    }).toList();

    final approvedRequests = todayRequests
        .where((request) => request['status'] == 'approved')
        .length;
    final fulfilledRequests = todayRequests
        .where((request) => request['status'] == 'fulfilled')
        .length;
    final pendingRequests =
        todayRequests.where((request) => request['status'] == 'pending').length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatisticCard('Total', todayRequests.length),
            _buildStatisticCard('Approved', approvedRequests),
            _buildStatisticCard('Fulfilled', fulfilledRequests),
          ],
        ),
        SizedBox(height: 16),
        _buildRequestStatusChart(
            pendingRequests, approvedRequests, fulfilledRequests),
      ],
    );
  }

  Widget _buildStatisticCard(String title, int count) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusChart(int pending, int approved, int fulfilled) {
    final data = [
      RequestStatus('Pending', pending, Colors.orange),
      RequestStatus('Approved', approved, Colors.green),
      RequestStatus('Fulfilled', fulfilled, Colors.blue),
    ];

    return Container(
      height: 200,
      child: SfCircularChart(
        legend: Legend(isVisible: true),
        series: <CircularSeries>[
          PieSeries<RequestStatus, String>(
            dataSource: data,
            xValueMapper: (RequestStatus data, _) => data.status,
            yValueMapper: (RequestStatus data, _) => data.count,
            pointColorMapper: (RequestStatus data, _) => data.color,
          ),
        ],
      ),
    );
  }

  void _verifyCodeDialog(BuildContext context, String uniqueCode) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _codeController = TextEditingController();
        return AlertDialog(
          title: Text('Verify Unique Code'),
          content: TextField(
            controller: _codeController,
            decoration: InputDecoration(labelText: 'Enter Unique Code'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _verifyCode(context, _codeController.text, uniqueCode);
              },
              child: Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void _verifyCode(
      BuildContext context, String enteredCode, String uniqueCode) {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    if (enteredCode == uniqueCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code verified! Items can be collected.')),
      );
      // Update request status to fulfilled
      requestProvider.fulfillRequestByCode(uniqueCode);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid code!')),
      );
    }
  }
}

class RequestStatus {
  final String status;
  final int count;
  final Color color;

  RequestStatus(this.status, this.count, this.color);
}


