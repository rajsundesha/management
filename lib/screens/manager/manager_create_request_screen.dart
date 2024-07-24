import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';

class CreateManagerRequestScreen extends StatefulWidget {
  @override
  _CreateManagerRequestScreenState createState() =>
      _CreateManagerRequestScreenState();
}

class _CreateManagerRequestScreenState
    extends State<CreateManagerRequestScreen> {
  Map<String, int> _selectedItems = {};
  String _searchQuery = '';
  String _selectedLocation = 'Default Location';
  String _selectedCategory = 'All';
  List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
  TextEditingController _pickerNameController = TextEditingController();
  TextEditingController _pickerContactController = TextEditingController();
  TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInventoryItems();
    });
  }

  Future<void> _fetchInventoryItems() async {
    try {
      await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
      print("Inventory items fetched successfully");
    } catch (e) {
      print("Error fetching inventory items: $e");
    }
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
              Text('Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildCategoryList(),
              SizedBox(height: 16),
              Text('Inventory List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildInventoryList(),
              SizedBox(height: 16),
              Text('Selected Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        categories.insert(0, 'All');

        return Container(
          height: 50,
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
                          color: Colors.white, fontWeight: FontWeight.bold),
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
          height: 200,
          child: ListView.builder(
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> item = filteredItems[index];
              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: CircleAvatar(child: Icon(Icons.inventory)),
                  title: Text(item['name'],
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: _buildQuantityControls(item),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuantityControls(Map<String, dynamic> item) {
    return _selectedItems.containsKey(item['name'])
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove),
                onPressed: () {
                  setState(() {
                    if (_selectedItems[item['name']] == 1) {
                      _selectedItems.remove(item['name']);
                    } else {
                      _selectedItems[item['name']] =
                          _selectedItems[item['name']]! - 1;
                    }
                  });
                },
              ),
              Text('${_selectedItems[item['name']]} ${item['unit']}'),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _selectedItems[item['name']] =
                        _selectedItems[item['name']]! + 1;
                  });
                },
              ),
            ],
          )
        : IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _selectedItems[item['name']] = 1;
              });
            },
          );
  }

  Widget _buildSelectedItemsList() {
    return Container(
      height: 200,
      child: ListView.builder(
        itemCount: _selectedItems.length,
        itemBuilder: (context, index) {
          String itemName = _selectedItems.keys.elementAt(index);
          int quantity = _selectedItems[itemName]!;
          return Consumer<InventoryProvider>(
            builder: (context, inventoryProvider, child) {
              Map<String, dynamic> item = inventoryProvider.items
                  .firstWhere((element) => element['name'] == itemName);
              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: CircleAvatar(child: Icon(Icons.inventory)),
                  title: Text('$itemName x$quantity ${item['unit']}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: _buildSelectedQuantityControls(itemName),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedQuantityControls(String itemName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (_selectedItems[itemName] == 1) {
                _selectedItems.remove(itemName);
              } else {
                _selectedItems[itemName] = _selectedItems[itemName]! - 1;
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
                _selectedItems[itemName] = int.tryParse(value) ?? 1;
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController()
              ..text = _selectedItems[itemName].toString(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              _selectedItems[itemName] = _selectedItems[itemName]! + 1;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () {
            setState(() {
              _selectedItems.remove(itemName);
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



  Widget _buildPickerNameField() {
    return TextField(
      controller: _pickerNameController,
      decoration: InputDecoration(
        labelText: 'Picker Name (at least 2 letters)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  Widget _buildPickerContactField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _pickerContactController,
            decoration: InputDecoration(
              labelText: 'Picker Contact Number (10 digits)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.contact_phone),
          onPressed: _pickContact,
        ),
      ],
    );
  }

  Future<void> _pickContact() async {
    final PermissionStatus permissionStatus = await _getContactPermission();
    if (permissionStatus == PermissionStatus.granted) {
      final Contact? contact = await ContactsService.openDeviceContactPicker();
      if (contact != null) {
        final phone = contact.phones?.firstWhere((phone) => phone.value != null,
            orElse: () => Item(label: 'mobile', value: ''));
        setState(() {
          _pickerNameController.text = contact.displayName ?? '';
          _pickerContactController.text =
              phone?.value?.replaceAll(RegExp(r'\D'), '') ?? '';
        });
      }
    } else {
      _handleInvalidPermissions(permissionStatus);
    }
  }

  Future<PermissionStatus> _getContactPermission() async {
    PermissionStatus permission = await Permission.contacts.status;
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.permanentlyDenied) {
      PermissionStatus permissionStatus = await Permission.contacts.request();
      return permissionStatus;
    } else {
      return permission;
    }
  }

  void _handleInvalidPermissions(PermissionStatus permissionStatus) {
    if (permissionStatus == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access to contact data denied')),
      );
    } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact data not available on device')),
      );
    }
  }

  bool _validateInputs() {
    // Validate picker name
    String pickerName = _pickerNameController.text.trim();
    if (pickerName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picker name must be at least 2 letters.')),
      );
      return false;
    }

    // Validate mobile number
    if (_pickerContactController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mobile number must be 10 digits.')),
      );
      return false;
    }

    if (_selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a delivery location.')),
      );
      return false;
    }

    return true;
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
                DropdownButtonFormField<String>(
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
                ),
                SizedBox(height: 16),
                _buildPickerNameField(),
                SizedBox(height: 16),
                _buildPickerContactField(),
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
              onPressed: () async {
                print("Submit button pressed");
                if (!_validateInputs()) {
                  print("Validation failed");
                  return;
                }
                print("Validation passed");

                List<Map<String, dynamic>> requestItems =
                    _selectedItems.entries.map((entry) {
                  final item =
                      Provider.of<InventoryProvider>(context, listen: false)
                          .items
                          .firstWhere((item) => item['name'] == entry.key);
                  return {
                    'id': item['id'],
                    'name': entry.key,
                    'quantity': entry.value,
                    'unit': item['unit'] ?? 'pcs',
                  };
                }).toList();

                String location = _selectedLocation;
                String pickerName = _pickerNameController.text;
                String pickerContact = _pickerContactController.text;
                String note = _noteController.text;
                final currentUserEmail =
                    Provider.of<AuthProvider>(context, listen: false)
                        .currentUserEmail!;
                final inventoryProvider =
                    Provider.of<InventoryProvider>(context, listen: false);
                final requestProvider =
                    Provider.of<RequestProvider>(context, listen: false);

                try {
                  print("Attempting to add request");
                  await requestProvider.addRequest(
                    requestItems,
                    location,
                    pickerName,
                    pickerContact,
                    note,
                    currentUserEmail,
                    inventoryProvider,
                  );

                  print("Request added successfully");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
                    ),
                  );

                  setState(() {
                    _selectedItems.clear();
                    _selectedLocation = 'Default Location';
                    _pickerNameController.clear();
                    _pickerContactController.clear();
                    _noteController.clear();
                  });

                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                } catch (error) {
                  print("Error creating request: $error");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating request: $error'),
                    ),
                  );
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}
