import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class ManagerInventoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Items',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, child) {
                  if (inventoryProvider.items.isEmpty) {
                    return Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    itemCount: inventoryProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = inventoryProvider.items[index];
                      final quantity =
                          item['quantity'] ?? 0; // Handle null quantity
                      return Card(
                        child: ListTile(
                          title: Text('${item['name']}'),
                          subtitle: Text(
                              'Category: ${item['category']} - Unit: ${item['unit']}'),
                          trailing: quantity < 10
                              ? Text('Low Stock',
                                  style: TextStyle(color: Colors.red))
                              : null,
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
}
