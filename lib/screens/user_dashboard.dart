import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/request_provider.dart';

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  List<String> _selectedItems = [];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Handle logout
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16),
            Text(
              'Inventory List',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, child) {
                  List<String> filteredItems = inventoryProvider.items
                      .where((item) => item
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();
                  return ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(filteredItems[index]),
                        trailing: Checkbox(
                          value: _selectedItems.contains(filteredItems[index]),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedItems.add(filteredItems[index]);
                              } else {
                                _selectedItems.remove(filteredItems[index]);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Selected Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedItems.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_selectedItems[index]),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle),
                      onPressed: () {
                        setState(() {
                          _selectedItems.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _selectedItems.isEmpty
                    ? null
                    : () {
                        Provider.of<RequestProvider>(context, listen: false)
                            .addRequest(_selectedItems);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Request added for ${_selectedItems.join(', ')}')),
                        );
                        setState(() {
                          _selectedItems.clear();
                        });
                      },
                child: Text('Send Request'),
              ),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Text(
              'Request Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Consumer<RequestProvider>(
                builder: (context, requestProvider, child) {
                  return ListView.builder(
                    itemCount: requestProvider.requests.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                            'Items: ${requestProvider.requests[index]['items'].join(', ')}'),
                        subtitle: Text(
                            'Status: ${requestProvider.requests[index]['status']}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Provider.of<InventoryProvider>(context, listen: false).fetchItems();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
