import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/request_provider.dart';

class CreateRequestScreen extends StatefulWidget {
  @override
  _CreateRequestScreenState createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  Map<String, int> _selectedItems = {};
  String _searchQuery = '';
  String _selectedLocation = 'Default Location'; // Default location
  String _selectedCategory = 'All'; // Default category
  List<String> _locations = [
    'Default Location',
    'Location 1',
    'Location 2'
  ]; // List of locations
  TextEditingController _pickerNameController = TextEditingController();
  TextEditingController _pickerContactController = TextEditingController();
  TextEditingController _noteController =
      TextEditingController(); // Note Controller

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Request'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSearchBar(),
              SizedBox(height: 16),
              Text(
                'Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildCategoryList(),
              SizedBox(height: 16),
              Text(
                'Inventory List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildInventoryList(),
              SizedBox(height: 16),
              Text(
                'Selected Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildSelectedItemsList(),
              SizedBox(height: 16),
              _buildSendRequestButton(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
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
    );
  }

  Widget _buildCategoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        List<String> categories = inventoryProvider.items
            .map((item) => item['category'] as String)
            .toSet()
            .toList();
        categories.insert(0, 'All'); // Add "All" category

        return Container(
          height: 50, // Fixed height for the categories list
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              String category = categories[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _selectedCategory == category
                        ? Colors.blue
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      decoration: InputDecoration(
        labelText: 'Delivery Location',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      items: _locations.map((location) {
        return DropdownMenuItem(
          value: location,
          child: Text(location),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocation = value!;
        });
      },
    );
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        if (inventoryProvider.items.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        List<Map<String, dynamic>> filteredItems = inventoryProvider
            .getItemsByCategory(_selectedCategory)
            .where((item) =>
                item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        return Container(
          height: 200, // Set a fixed height for the inventory list
          child: ListView.builder(
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              String item = filteredItems[index]['name'];
              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: CircleAvatar(
                    child: Icon(Icons.inventory),
                  ),
                  title: Text(
                    item,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: _buildQuantityControls(item),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuantityControls(String item) {
    return _selectedItems.containsKey(item)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    if (_selectedItems[item] == 1) {
                      _selectedItems.remove(item);
                    } else {
                      _selectedItems[item] = _selectedItems[item]! - 1;
                    }
                  });
                },
              ),
              Text('${_selectedItems[item]}'),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _selectedItems[item] = _selectedItems[item]! + 1;
                  });
                },
              ),
            ],
          )
        : IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _selectedItems[item] = 1;
              });
            },
          );
  }

  Widget _buildSelectedItemsList() {
    return Container(
      height: 200, // Set a fixed height for the selected items list
      child: ListView.builder(
        itemCount: _selectedItems.length,
        itemBuilder: (context, index) {
          String item = _selectedItems.keys.elementAt(index);
          int quantity = _selectedItems[item]!;
          return Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: CircleAvatar(
                child: Icon(Icons.inventory),
              ),
              title: Text(
                '$item x$quantity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: _buildSelectedQuantityControls(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedQuantityControls(String item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (_selectedItems[item] == 1) {
                _selectedItems.remove(item);
              } else {
                _selectedItems[item] = _selectedItems[item]! - 1;
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
                _selectedItems[item] = int.tryParse(value) ?? 1;
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController()
              ..text = _selectedItems[item].toString(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              _selectedItems[item] = _selectedItems[item]! + 1;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () {
            setState(() {
              _selectedItems.remove(item);
            });
          },
        ),
      ],
    );
  }

  Widget _buildSendRequestButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _selectedItems.isEmpty
            ? null
            : () {
                _showRequestDetailsDialog(context);
              },
        child: Text('Send Request'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedItems.isEmpty ? Colors.grey : Colors.blue,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }

  void _showRequestDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Request Details'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildLocationDropdown(),
                SizedBox(height: 16),
                TextField(
                  controller: _pickerNameController,
                  decoration: InputDecoration(
                    labelText: 'Picker Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _pickerContactController,
                  decoration: InputDecoration(
                    labelText: 'Picker Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Optional Note',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_pickerNameController.text.isEmpty ||
                    _pickerContactController.text.isEmpty ||
                    _selectedLocation.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Please fill all the required fields (Picker Name, Contact Number, Location).'),
                    ),
                  );
                  return;
                }

                List<Map<String, dynamic>> requestItems = _selectedItems.entries
                    .map((entry) => {
                          'name': entry.key,
                          'quantity': entry.value,
                        })
                    .toList();
                String location = _selectedLocation;
                String pickerName = _pickerNameController.text;
                String pickerContact = _pickerContactController.text;
                String note = _noteController.text; // Optional note

                Provider.of<RequestProvider>(context, listen: false).addRequest(
                    requestItems, location, pickerName, pickerContact, note);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Request added for ${_selectedItems.entries.map((e) => '${e.value} x ${e.key}').join(', ')} at $location'),
                  ),
                );

                setState(() {
                  _selectedItems.clear();
                  _selectedLocation =
                      'Default Location'; // Reset location to default
                  _pickerNameController.clear();
                  _pickerContactController.clear();
                  _noteController.clear(); // Clear the note field
                });

                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}
