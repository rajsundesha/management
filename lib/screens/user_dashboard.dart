import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/request_provider.dart';

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  List<String> _selectedItems = [];
  String _searchQuery = '';

  void _showRequestOptions(
      BuildContext context, int index, List<String> items) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...items.map((item) => ListTile(title: Text(item))).toList(),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _editRequest(context, index, items);
                },
                child: Text('Edit Request'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteRequest(context, index);
                },
                child: Text('Delete Request'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editRequest(BuildContext context, int index, List<String> items) {
    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(index: index, items: items),
    );
  }

  void _deleteRequest(BuildContext context, int index) {
    Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
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
                prefixIcon: Icon(Icons.search),
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
            SizedBox(height: 8),
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
                      return Card(
                        child: ListTile(
                          title: Text(filteredItems[index]),
                          trailing: Checkbox(
                            value:
                                _selectedItems.contains(filteredItems[index]),
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
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedItems.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_selectedItems[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedItems.removeAt(index);
                          });
                        },
                      ),
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
                            .addRequest(List.from(_selectedItems));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Request added for ${_selectedItems.join(', ')}'),
                          ),
                        );
                        setState(() {
                          _selectedItems.clear();
                        });
                      },
                child: Text('Send Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedItems.isEmpty
                      ? Colors.grey
                      : Theme.of(context).primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Text(
              'Request Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: Consumer<RequestProvider>(
                builder: (context, requestProvider, child) {
                  return ListView.builder(
                    itemCount: requestProvider.requests.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text(
                            'Items: ${requestProvider.requests[index]['items'].join(', ')}',
                          ),
                          subtitle: Text(
                            'Status: ${requestProvider.requests[index]['status']}',
                          ),
                          leading: Icon(
                            requestProvider.requests[index]['status'] ==
                                    'approved'
                                ? Icons.check_circle
                                : requestProvider.requests[index]['status'] ==
                                        'rejected'
                                    ? Icons.cancel
                                    : Icons.hourglass_empty,
                            color: requestProvider.requests[index]['status'] ==
                                    'approved'
                                ? Colors.green
                                : requestProvider.requests[index]['status'] ==
                                        'rejected'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          onTap: () => _showRequestOptions(
                              context,
                              index,
                              List.from(
                                  requestProvider.requests[index]['items'])),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Provider.of<InventoryProvider>(context, listen: false).fetchItems();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}

class EditRequestDialog extends StatefulWidget {
  final int index;
  final List<String> items;

  EditRequestDialog({required this.index, required this.items});

  @override
  _EditRequestDialogState createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<EditRequestDialog> {
  List<String> _items = [];
  TextEditingController _controller = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final inventoryItems = Provider.of<InventoryProvider>(context).items;

    List<String> filteredItems = inventoryItems
        .where(
            (item) => item.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text('Edit Request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: 200, // Fixed height for the ListView
              ),
              child: ListView(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: _items
                    .map((item) => ListTile(
                          title: Text(item),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _items.remove(item);
                              });
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Add Item',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            if (filteredItems.isNotEmpty)
              Container(
                constraints: BoxConstraints(
                  maxHeight:
                      150, // Fixed height for the filtered items ListView
                ),
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(filteredItems[index]),
                      onTap: () {
                        setState(() {
                          _items.add(filteredItems[index]);
                          _controller.clear();
                          _searchQuery = '';
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Provider.of<RequestProvider>(context, listen: false)
                .updateRequest(widget.index, _items);
            Navigator.of(context).pop();
          },
          child: Text('Close'),
        ),
      ],
    );
  }
}
