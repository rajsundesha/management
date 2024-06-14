import 'package:dhavla_road_project/models/approved_request.dart';
import 'package:flutter/material.dart';

class DistributionDetailScreen extends StatelessWidget {
  final ApprovedRequest request;

  DistributionDetailScreen({required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Distribution Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('Request from: ${request.userName}'),
            Text('Items: ${request.items.join(', ')}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Confirm distribution
              },
              child: Text('Confirm Distribution'),
            ),
          ],
        ),
      ),
    );
  }
}
