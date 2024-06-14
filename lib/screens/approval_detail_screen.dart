import 'package:dhavla_road_project/models/item_request.dart';
import 'package:flutter/material.dart';

class ApprovalDetailScreen extends StatelessWidget {
  final ItemRequest request;

  ApprovalDetailScreen({required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('Request from: ${request.userName}'),
            Text('Items: ${request.items.join(', ')}'),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    // Approve request
                  },
                  child: Text('Approve'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Reject request
                  },
                  child: Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
