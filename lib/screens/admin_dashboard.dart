import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../models/item_request.dart';
import '../providers/item_request_provider.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Dashboard')),
      body: Consumer<ItemRequestProvider>(
        builder: (context, itemRequestProvider, child) {
          return ListView.builder(
            itemCount: itemRequestProvider.requests.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                    'Request from ${itemRequestProvider.requests[index].userName}'),
                subtitle: Text(
                    'Items: ${itemRequestProvider.requests[index].items.join(', ')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check),
                      onPressed: () {
                        itemRequestProvider.approveRequest(index);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        itemRequestProvider.rejectRequest(index);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Provider.of<ItemRequestProvider>(context, listen: false)
              .fetchRequests();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
