import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/request_provider.dart';

class EditRequestBottomSheet extends StatefulWidget {
  final int index;
  final List<Map<String, dynamic>> items;

  EditRequestBottomSheet({required this.index, required this.items});

  @override
  _EditRequestBottomSheetState createState() => _EditRequestBottomSheetState();
}

class _EditRequestBottomSheetState extends State<EditRequestBottomSheet> {
  List<Map<String, dynamic>> _items = [];
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

    return SingleChildScrollView(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: 200, // Fixed height for the ListView
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('${_items[index]['name']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (_items[index]['quantity'] == 1) {
                                _items.removeAt(index);
                              } else {
                                _items[index]['quantity']--;
                              }
                            });
                          },
                        ),
                        Container(
                          width: 40,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _items[index]['quantity'] =
                                    int.tryParse(value) ?? 1;
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController()
                              ..text = _items[index]['quantity'].toString(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _items[index]['quantity']++;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
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
                height: 150, // Fixed height for the filtered items ListView
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(filteredItems[index]),
                      onTap: () {
                        setState(() {
                          String selectedItem = filteredItems[index];
                          int existingIndex = _items.indexWhere(
                              (item) => item['name'] == selectedItem);

                          if (existingIndex != -1) {
                            _items[existingIndex]['quantity']++;
                          } else {
                            _items.add({
                              'name': selectedItem,
                              'quantity': 1,
                            });
                          }

                          _controller.clear();
                          _searchQuery = '';
                        });
                      },
                    );
                  },
                ),
              ),
            SizedBox(height: 16), // Add space between the list and buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Provider.of<RequestProvider>(context, listen: false)
                        .updateRequest(widget.index, _items);
                    Navigator.of(context).pop();
                  },
                  child: Text('Update Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).primaryColor, // Use primary color
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
