import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart'; // Import LocationProvider

class EditAdminRequestBottomSheet extends StatefulWidget {
  final String id;
  final List<Map<String, dynamic>> items;
  final String location;
  final String pickerName;
  final String pickerContact;
  final String note;

  EditAdminRequestBottomSheet({
    required this.id,
    required this.items,
    required this.location,
    required this.pickerName,
    required this.pickerContact,
    required this.note,
  });

  @override
  _EditAdminRequestBottomSheetState createState() =>
      _EditAdminRequestBottomSheetState();
}

class _EditAdminRequestBottomSheetState
    extends State<EditAdminRequestBottomSheet> {
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _pickerNameController = TextEditingController();
  final TextEditingController _pickerContactController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';
  String?
      _selectedLocation; // Allow null to handle cases where location isn't found

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items.map((item) {
      return {
        'id': item['id'],
        'name': item['name'],
        'quantity': item['quantity'] ?? 1,
        'unit': item['unit'] ?? 'pcs',
        'isPipe': item['isPipe'] ?? false,
        'pcs': item['pcs'] ?? 0,
        'meters': item['meters'] ?? 0.0,
      };
    }));

    // Initialize text controllers with provided values
    _pickerNameController.text = widget.pickerName;
    _pickerContactController.text = widget.pickerContact;
    _noteController.text = widget.note;

    // Set default location
    _selectedLocation = widget.location;

    // Ensure _selectedLocation is not null
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      _selectedLocation = 'Default Location';
    }
  }

  @override
  void dispose() {
    // Dispose of controllers when no longer needed
    _controller.dispose();
    _pickerNameController.dispose();
    _pickerContactController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final currentUserEmail =
        Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

    List<Map<String, dynamic>> filteredItems = inventoryProvider.items
        .where((item) =>
            item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
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
                maxHeight: 300,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildItemTile(index);
                },
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Add Item',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            if (filteredItems.isNotEmpty)
              Container(
                height: 150,
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                          '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
                      onTap: () {
                        setState(() {
                          String selectedItem = filteredItems[index]['name'];
                          int existingIndex = _items.indexWhere(
                              (item) => item['name'] == selectedItem);

                          if (existingIndex != -1) {
                            if (_items[existingIndex]['isPipe'] == true) {
                              _items[existingIndex]['pcs']++;
                            } else {
                              _items[existingIndex]['quantity']++;
                            }
                          } else {
                            _items.add({
                              'id': filteredItems[index]['id'],
                              'name': selectedItem,
                              'quantity': 1,
                              'unit': filteredItems[index]['unit'],
                              'isPipe': filteredItems[index]['isPipe'] ?? false,
                              'pcs': 0,
                              'meters': 0.0,
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
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: InputDecoration(
                labelText: 'Delivery Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              items: [
                // Add a default option if it doesn't exist in the list
                if (!locationProvider.locations.contains(_selectedLocation))
                  DropdownMenuItem(
                      value: _selectedLocation,
                      child: Text(_selectedLocation ?? 'Select Location')),
                ...locationProvider.locations.map((location) {
                  return DropdownMenuItem(
                    value: location,
                    child: Text(location),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a location';
                }
                return null;
              },
            ),
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
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            SizedBox(height: 16),
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
                  onPressed: () async {
                    if (_pickerContactController.text.length != 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Contact number must be 10 digits.')),
                      );
                      return;
                    }

                    if (_selectedLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please select a valid location.'),
                        ),
                      );
                      return;
                    }

                    if (currentUserEmail == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'User email not available. Please log in again.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await Provider.of<RequestProvider>(context, listen: false)
                          .updateRequest(
                        widget.id,
                        _items,
                        _selectedLocation!,
                        _pickerNameController.text,
                        _pickerContactController.text,
                        _noteController.text,
                        currentUserEmail,
                        inventoryProvider,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Request updated successfully')),
                      );

                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating request: $e')),
                      );
                    }
                  },
                  child: Text('Update Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(int index) {
    bool isPipe = _items[index]['isPipe'] ?? false;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _items[index]['name'] ?? 'Unknown Item',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (isPipe)
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pcs:'),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (_items[index]['pcs'] > 0) {
                              _items[index]['pcs']--;
                            }
                          });
                        },
                      ),
                      Container(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _items[index]['pcs'] = int.tryParse(value) ?? 0;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController()
                            ..text = _items[index]['pcs'].toString(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _items[index]['pcs']++;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Meters:'),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (_items[index]['meters'] > 0) {
                              _items[index]['meters']--;
                            }
                          });
                        },
                      ),
                      Container(
                        width: 60,
                        child: TextField(
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              _items[index]['meters'] =
                                  double.tryParse(value) ?? 0.0;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController()
                            ..text = _items[index]['meters'].toString(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _items[index]['meters']++;
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
                ],
              )
            else
              Row(
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
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _items[index]['quantity'] = int.tryParse(value) ?? 1;
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
          ],
        ),
      ),
    );
  }
}
