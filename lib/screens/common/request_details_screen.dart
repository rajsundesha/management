import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class RequestDetailsScreen extends StatelessWidget {
  final String requestId;
  final bool isStockRequest;

  const RequestDetailsScreen({
    Key? key,
    required this.requestId,
    required this.isStockRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(isStockRequest ? 'Stock Request Details' : 'Request Details'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: isStockRequest
                ? requestProvider.getStockRequestById(requestId)
                : requestProvider.getRequestById(requestId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return Center(child: Text('Request not found'));
              }

              final request = snapshot.data!;
              return SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request ID: $requestId',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Status: ${request['status']}'),
                    SizedBox(height: 8),
                    Text('Created At: ${request['createdAt'].toString()}'),
                    SizedBox(height: 16),
                    Text('Items:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...buildItemsList(request['items']),
                    if (!isStockRequest) ...[
                      SizedBox(height: 16),
                      Text('Location: ${request['location']}'),
                      SizedBox(height: 8),
                      Text('Picker Name: ${request['pickerName']}'),
                      SizedBox(height: 8),
                      Text('Picker Contact: ${request['pickerContact']}'),
                    ],
                    SizedBox(height: 16),
                    Text('Note: ${request['note']}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> buildItemsList(List<dynamic> items) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
        child: Text(
          '${item['name']}: ${item['quantity']} (Received: ${item['receivedQuantity'] ?? 0})',
        ),
      );
    }).toList();
  }
}
