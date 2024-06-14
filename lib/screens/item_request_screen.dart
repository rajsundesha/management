import 'package:flutter/material.dart';

class ItemRequestScreen extends StatefulWidget {
  @override
  _ItemRequestScreenState createState() => _ItemRequestScreenState();
}

class _ItemRequestScreenState extends State<ItemRequestScreen> {
  final List<String> _items = ['Item 1', 'Item 2', 'Item 3']; // Example items
  final List<String> _selectedItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request Items')),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return CheckboxListTile(
            title: Text(_items[index]),
            value: _selectedItems.contains(_items[index]),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedItems.add(_items[index]);
                } else {
                  _selectedItems.remove(_items[index]);
                }
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Submit the selected items to the admin
        },
        child: Icon(Icons.send),
      ),
    );
  }
}
