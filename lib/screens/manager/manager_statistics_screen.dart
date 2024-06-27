import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ManagerStatisticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Statistics (Last 7 days)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatistics(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);

    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));

    final requestsLastWeek = requestProvider.requests.where((request) {
      final requestDate = request['timestamp'] as DateTime;
      return requestDate.isAfter(weekAgo) && requestDate.isBefore(now);
    }).toList();

    final pendingRequests = requestsLastWeek
        .where((request) => request['status'] == 'pending')
        .length;
    final approvedRequests = requestsLastWeek
        .where((request) => request['status'] == 'approved')
        .length;
    final fulfilledRequests = requestsLastWeek
        .where((request) => request['status'] == 'fulfilled')
        .length;

    final data = [
      RequestStatus('Pending', pendingRequests, Colors.orange),
      RequestStatus('Approved', approvedRequests, Colors.green),
      RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
    ];

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      series: <ChartSeries>[
        ColumnSeries<RequestStatus, String>(
          dataSource: data,
          xValueMapper: (RequestStatus status, _) => status.status,
          yValueMapper: (RequestStatus status, _) => status.count,
          pointColorMapper: (RequestStatus status, _) =>
              status.color, // Update here
        ),
      ],
    );
  }
}

class RequestStatus {
  final String status;
  final int count;
  final Color color;

  RequestStatus(this.status, this.count, this.color);
}
