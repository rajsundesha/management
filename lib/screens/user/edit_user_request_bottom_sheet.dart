import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class EditUserRequestBottomSheet extends StatefulWidget {
  final String id;
  final List<Map<String, dynamic>> items;
  final String location;
  final String pickerName;
  final String pickerContact;
  final String note;

  EditUserRequestBottomSheet({
    required this.id,
    required this.items,
    required this.location,
    required this.pickerName,
    required this.pickerContact,
    required this.note,
  });

  @override
  _EditUserRequestBottomSheetState createState() =>
      _EditUserRequestBottomSheetState();
}

class _EditUserRequestBottomSheetState
    extends State<EditUserRequestBottomSheet> {
  late List<Map<String, dynamic>> _items;
  late TextEditingController _controller;
  late TextEditingController _pickerNameController;
  late TextEditingController _pickerContactController;
  late TextEditingController _noteController;
  String _searchQuery = '';
  String _selectedLocation = '';
  bool _isLoading = false;

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
        'pipeLength': item['pipeLength'] ?? 20.0, // Default pipe length
      };
    }));
    _selectedLocation = widget.location;
    _pickerNameController = TextEditingController(text: widget.pickerName);
    _pickerContactController =
        TextEditingController(text: widget.pickerContact);
    _noteController = TextEditingController(text: widget.note);
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pickerNameController.dispose();
    _pickerContactController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryItems = Provider.of<InventoryProvider>(context).items;
    final locationProvider = Provider.of<LocationProvider>(context);

    List<Map<String, dynamic>> filteredItems = inventoryItems
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
              constraints: BoxConstraints(maxHeight: 300), // Increased height
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text('${item['name']} (${item['unit']})'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                            });
                          },
                        ),
                      ),
                      if (item['isPipe'] == true) ...[
                        _buildPipeControls(item, index, true),
                        _buildPipeControls(item, index, false),
                      ] else
                        _buildRegularControls(item, index),
                      Divider(),
                    ],
                  );
                },
              ),
            ),
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
                              'pcs': 1,
                              'meters': 0.0,
                              'pipeLength':
                                  filteredItems[index]['pipeLength'] ?? 20.0,
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
              items: locationProvider.locations.map((location) {
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
            TextField(
              controller: _pickerNameController,
              decoration: InputDecoration(
                labelText: 'Picker Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pickerContactController,
                    decoration: InputDecoration(
                      labelText: 'Picker Contact Number',
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
                  onPressed: _isLoading ? null : () => _updateRequest(context),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Update Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the controls for a regular item (non-pipe).
  Widget _buildRegularControls(Map<String, dynamic> item, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Quantity:'),
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (item['quantity'] > 1) {
                item['quantity']--;
              } else {
                _items.removeAt(index);
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
                item['quantity'] = int.tryParse(value) ?? 1;
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController()
              ..text = item['quantity'].toString(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              item['quantity']++;
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
    );
  }

  /// Builds the controls for pipe items, including separate sections for `pcs` and `meters`.
  Widget _buildPipeControls(Map<String, dynamic> item, int index, bool isPcs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(isPcs ? 'Pieces:' : 'Length (m):'),
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (isPcs) {
                if (item['pcs'] > 1) {
                  item['pcs']--;
                } else {
                  item['pcs'] = 0;
                }
              } else {
                if (item['meters'] > 1) {
                  item['meters']--;
                } else {
                  item['meters'] = 0.0;
                }
              }
            });
          },
        ),
        Container(
          width: 40,
          child: TextField(
            keyboardType: isPcs
                ? TextInputType.number
                : TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                if (isPcs) {
                  item['pcs'] = int.tryParse(value) ?? 1;
                } else {
                  item['meters'] = double.tryParse(value) ?? 0.0;
                }
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController()
              ..text =
                  isPcs ? item['pcs'].toString() : item['meters'].toString(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {
            setState(() {
              if (isPcs) {
                item['pcs']++;
              } else {
                item['meters']++;
              }
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            setState(() {
              if (isPcs) {
                item['pcs'] = 0; // Clear pcs but don't remove entire item
              } else {
                item['meters'] =
                    0.0; // Clear meters but don't remove entire item
              }
            });
          },
        ),
      ],
    );
  }

  Future<void> _pickContact() async {
    try {
      final permissionStatus = await _getContactPermission();
      if (permissionStatus == PermissionStatus.granted) {
        final Contact? contact =
            await ContactsService.openDeviceContactPicker();
        if (contact != null) {
          final phone = contact.phones?.firstWhere(
            (phone) => phone.value != null,
            orElse: () => Item(label: 'mobile', value: ''),
          );
          setState(() {
            _pickerNameController.text = contact.displayName ?? '';
            _pickerContactController.text =
                _formatPhoneNumber(phone?.value ?? '');
          });
        }
      } else {
        _handleInvalidPermissions(permissionStatus);
      }
    } catch (e) {
      print("Error picking contact: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Unable to pick contact. Please enter details manually.")),
      );
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
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

  void _updateRequest(BuildContext context) async {
    if (_pickerNameController.text.isEmpty ||
        _pickerContactController.text.isEmpty ||
        _pickerContactController.text.length != 10 ||
        _selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUserEmail =
        Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

    if (currentUserEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User email not available. Please log in again.'),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      await Provider.of<RequestProvider>(context, listen: false).updateRequest(
        widget.id,
        _items,
        _selectedLocation,
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
      print("Error updating request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   late List<Map<String, dynamic>> _items;
//   late TextEditingController _controller;
//   late TextEditingController _pickerNameController;
//   late TextEditingController _pickerContactController;
//   late TextEditingController _noteController;
//   String _searchQuery = '';
//   String _selectedLocation = '';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//         'isPipe': item['isPipe'] ?? false,
//         'pcs': item['pcs'] ?? 0,
//         'meters': item['meters'] ?? 0.0,
//         'pipeLength': item['pipeLength'] ?? 20.0, // Default pipe length
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController = TextEditingController(text: widget.pickerName);
//     _pickerContactController =
//         TextEditingController(text: widget.pickerContact);
//     _noteController = TextEditingController(text: widget.note);
//     _controller = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;
//     final locationProvider = Provider.of<LocationProvider>(context);

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 300), // Increased height
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   final item = _items[index];
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ListTile(
//                         title: Text('${item['name']} (${item['unit']})'),
//                         trailing: IconButton(
//                           icon: Icon(Icons.delete),
//                           onPressed: () {
//                             setState(() {
//                               _items.removeAt(index);
//                             });
//                           },
//                         ),
//                       ),
//                       if (item['isPipe'] == true) ...[
//                         _buildPipeControls(item, index, true),
//                         _buildPipeControls(item, index, false),
//                       ] else
//                         _buildRegularControls(item, index),
//                       Divider(),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             if (_items[existingIndex]['isPipe'] == true) {
//                               _items[existingIndex]['pcs']++;
//                             } else {
//                               _items[existingIndex]['quantity']++;
//                             }
//                           } else {
//                             _items.add({
//                               'id': filteredItems[index]['id'],
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit'],
//                               'isPipe': filteredItems[index]['isPipe'] ?? false,
//                               'pcs': 1,
//                               'meters': 0.0,
//                               'pipeLength':
//                                   filteredItems[index]['pipeLength'] ?? 20.0,
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: locationProvider.locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _pickerContactController,
//                     decoration: InputDecoration(
//                       labelText: 'Picker Contact Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(10),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.contact_phone),
//                   onPressed: _pickContact,
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : () => _updateRequest(context),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Builds the controls for a regular item (non-pipe).
//   Widget _buildRegularControls(Map<String, dynamic> item, int index) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text('Quantity:'),
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (item['quantity'] > 1) {
//                 item['quantity']--;
//               } else {
//                 _items.removeAt(index);
//               }
//             });
//           },
//         ),
//         Container(
//           width: 40,
//           child: TextField(
//             keyboardType: TextInputType.number,
//             onChanged: (value) {
//               setState(() {
//                 item['quantity'] = int.tryParse(value) ?? 1;
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text = item['quantity'].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               item['quantity']++;
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.delete),
//           onPressed: () {
//             setState(() {
//               _items.removeAt(index);
//             });
//           },
//         ),
//       ],
//     );
//   }

//   /// Builds the controls for pipe items, including separate sections for `pcs` and `meters`.
//   Widget _buildPipeControls(Map<String, dynamic> item, int index, bool isPcs) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(isPcs ? 'Pieces:' : 'Length (m):'),
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 if (item['pcs'] > 1) {
//                   item['pcs']--;
//                 } else {
//                   item['pcs'] = 0;
//                 }
//               } else {
//                 if (item['meters'] > 1) {
//                   item['meters']--;
//                 } else {
//                   item['meters'] = 0.0;
//                 }
//               }
//             });
//           },
//         ),
//         Container(
//           width: 40,
//           child: TextField(
//             keyboardType: isPcs
//                 ? TextInputType.number
//                 : TextInputType.numberWithOptions(decimal: true),
//             onChanged: (value) {
//               setState(() {
//                 if (isPcs) {
//                   item['pcs'] = int.tryParse(value) ?? 1;
//                 } else {
//                   item['meters'] = double.tryParse(value) ?? 0.0;
//                 }
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text =
//                   isPcs ? item['pcs'].toString() : item['meters'].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 item['pcs']++;
//               } else {
//                 item['meters']++;
//               }
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.delete),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 item['pcs'] = 0; // Clear pcs but don't remove entire item
//               } else {
//                 item['meters'] =
//                     0.0; // Clear meters but don't remove entire item
//               }
//             });
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   late List<Map<String, dynamic>> _items;
//   late TextEditingController _controller;
//   late TextEditingController _pickerNameController;
//   late TextEditingController _pickerContactController;
//   late TextEditingController _noteController;
//   String _searchQuery = '';
//   String _selectedLocation = '';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//         'isPipe': item['isPipe'] ?? false,
//         'pcs': item['pcs'] ?? 0,
//         'meters': item['meters'] ?? 0.0,
//         'pipeLength': item['pipeLength'] ?? 20.0, // Default pipe length
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController = TextEditingController(text: widget.pickerName);
//     _pickerContactController =
//         TextEditingController(text: widget.pickerContact);
//     _noteController = TextEditingController(text: widget.note);
//     _controller = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;
//     final locationProvider = Provider.of<LocationProvider>(context);

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 300), // Increased height
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   final item = _items[index];
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ListTile(
//                         title: Text('${item['name']} (${item['unit']})'),
//                         trailing: IconButton(
//                           icon: Icon(Icons.delete),
//                           onPressed: () {
//                             setState(() {
//                               _items.removeAt(index);
//                             });
//                           },
//                         ),
//                       ),
//                       if (item['isPipe'] == true) ...[
//                         _buildPipeControls(item, index, true),
//                         _buildPipeControls(item, index, false),
//                       ] else
//                         _buildRegularControls(item, index),
//                       Divider(),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             if (_items[existingIndex]['isPipe'] == true) {
//                               _items[existingIndex]['pcs']++;
//                             } else {
//                               _items[existingIndex]['quantity']++;
//                             }
//                           } else {
//                             _items.add({
//                               'id': filteredItems[index]['id'],
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit'],
//                               'isPipe': filteredItems[index]['isPipe'] ?? false,
//                               'pcs': 1,
//                               'meters': 0.0,
//                               'pipeLength':
//                                   filteredItems[index]['pipeLength'] ?? 20.0,
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: locationProvider.locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _pickerContactController,
//                     decoration: InputDecoration(
//                       labelText: 'Picker Contact Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(10),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.contact_phone),
//                   onPressed: _pickContact,
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : () => _updateRequest(context),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Builds the controls for a regular item (non-pipe).
//   Widget _buildRegularControls(Map<String, dynamic> item, int index) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text('Quantity:'),
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (item['quantity'] > 1) {
//                 item['quantity']--;
//               } else {
//                 _items.removeAt(index);
//               }
//             });
//           },
//         ),
//         Container(
//           width: 40,
//           child: TextField(
//             keyboardType: TextInputType.number,
//             onChanged: (value) {
//               setState(() {
//                 item['quantity'] = int.tryParse(value) ?? 1;
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text = item['quantity'].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               item['quantity']++;
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.delete),
//           onPressed: () {
//             setState(() {
//               _items.removeAt(index);
//             });
//           },
//         ),
//       ],
//     );
//   }

//   /// Builds the controls for pipe items, including separate sections for `pcs` and `meters`.
//   Widget _buildPipeControls(Map<String, dynamic> item, int index, bool isPcs) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(isPcs ? 'Pieces:' : 'Length (m):'),
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 if (item['pcs'] > 1) {
//                   item['pcs']--;
//                 } else {
//                   _items.removeAt(index);
//                 }
//               } else {
//                 if (item['meters'] > 1) {
//                   item['meters']--;
//                 } else {
//                   _items.removeAt(index);
//                 }
//               }
//             });
//           },
//         ),
//         Container(
//           width: 40,
//           child: TextField(
//             keyboardType: TextInputType.numberWithOptions(decimal: !isPcs),
//             onChanged: (value) {
//               setState(() {
//                 if (isPcs) {
//                   item['pcs'] = int.tryParse(value) ?? 1;
//                 } else {
//                   item['meters'] = double.tryParse(value) ?? 0.0;
//                 }
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text =
//                   isPcs ? item['pcs'].toString() : item['meters'].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 item['pcs']++;
//               } else {
//                 item['meters']++;
//               }
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.delete),
//           onPressed: () {
//             setState(() {
//               if (isPcs) {
//                 _items.removeAt(index);
//               } else {
//                 _items.removeAt(index);
//               }
//             });
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   late List<Map<String, dynamic>> _items;
//   late TextEditingController _controller;
//   late TextEditingController _pickerNameController;
//   late TextEditingController _pickerContactController;
//   late TextEditingController _noteController;
//   String _searchQuery = '';
//   String _selectedLocation = '';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//         'isPipe': item['isPipe'] ?? false,
//         'pcs': item['pcs'] ?? 0,
//         'meters': item['meters'] ?? 0.0,
//         'pipeLength': item['pipeLength'] ?? 20.0, // Default pipe length
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController = TextEditingController(text: widget.pickerName);
//     _pickerContactController =
//         TextEditingController(text: widget.pickerContact);
//     _noteController = TextEditingController(text: widget.note);
//     _controller = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;
//     final locationProvider = Provider.of<LocationProvider>(context);

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 300), // Increased height
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   final item = _items[index];
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ListTile(
//                         title: Text('${item['name']} (${item['unit']})'),
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             IconButton(
//                               icon: Icon(Icons.remove),
//                               onPressed: () {
//                                 setState(() {
//                                   if (item['isPipe'] == true) {
//                                     if (item['pcs'] > 0) {
//                                       item['pcs']--;
//                                     } else if (item['meters'] > 0) {
//                                       item['meters']--;
//                                     }
//                                   } else {
//                                     if (item['quantity'] > 1) {
//                                       item['quantity']--;
//                                     } else {
//                                       _items.removeAt(index);
//                                     }
//                                   }
//                                 });
//                               },
//                             ),
//                             Container(
//                               width: 40,
//                               child: TextField(
//                                 keyboardType: TextInputType.number,
//                                 onChanged: (value) {
//                                   setState(() {
//                                     if (item['isPipe'] == true) {
//                                       item['pcs'] = int.tryParse(value) ?? 1;
//                                     } else {
//                                       item['quantity'] =
//                                           int.tryParse(value) ?? 1;
//                                     }
//                                   });
//                                 },
//                                 decoration: InputDecoration(
//                                   contentPadding: EdgeInsets.symmetric(
//                                       vertical: 8, horizontal: 8),
//                                   isDense: true,
//                                   border: OutlineInputBorder(),
//                                 ),
//                                 controller: TextEditingController()
//                                   ..text = item['isPipe'] == true
//                                       ? item['pcs'].toString()
//                                       : item['quantity'].toString(),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.add),
//                               onPressed: () {
//                                 setState(() {
//                                   if (item['isPipe'] == true) {
//                                     item['pcs']++;
//                                   } else {
//                                     item['quantity']++;
//                                   }
//                                 });
//                               },
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.delete),
//                               onPressed: () {
//                                 setState(() {
//                                   _items.removeAt(index);
//                                 });
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (item['isPipe'] == true)
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text('Length (m): ${item['meters']}'),
//                               IconButton(
//                                 icon: Icon(Icons.remove),
//                                 onPressed: () {
//                                   setState(() {
//                                     if (item['meters'] > 0) {
//                                       item['meters']--;
//                                     }
//                                   });
//                                 },
//                               ),
//                               Container(
//                                 width: 40,
//                                 child: TextField(
//                                   keyboardType: TextInputType.numberWithOptions(
//                                       decimal: true),
//                                   onChanged: (value) {
//                                     setState(() {
//                                       item['meters'] =
//                                           double.tryParse(value) ?? 0.0;
//                                     });
//                                   },
//                                   decoration: InputDecoration(
//                                     contentPadding: EdgeInsets.symmetric(
//                                         vertical: 8, horizontal: 8),
//                                     isDense: true,
//                                     border: OutlineInputBorder(),
//                                   ),
//                                   controller: TextEditingController()
//                                     ..text = item['meters'].toString(),
//                                 ),
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.add),
//                                 onPressed: () {
//                                   setState(() {
//                                     item['meters']++;
//                                   });
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       Divider(),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             if (_items[existingIndex]['isPipe'] == true) {
//                               _items[existingIndex]['pcs']++;
//                             } else {
//                               _items[existingIndex]['quantity']++;
//                             }
//                           } else {
//                             _items.add({
//                               'id': filteredItems[index]['id'],
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit'],
//                               'isPipe': filteredItems[index]['isPipe'] ?? false,
//                               'pcs': 1,
//                               'meters': 0.0,
//                               'pipeLength':
//                                   filteredItems[index]['pipeLength'] ?? 20.0,
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: locationProvider.locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _pickerContactController,
//                     decoration: InputDecoration(
//                       labelText: 'Picker Contact Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(10),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.contact_phone),
//                   onPressed: _pickContact,
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : () => _updateRequest(context),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   late List<Map<String, dynamic>> _items;
//   late TextEditingController _controller;
//   late TextEditingController _pickerNameController;
//   late TextEditingController _pickerContactController;
//   late TextEditingController _noteController;
//   String _searchQuery = '';
//   String _selectedLocation = '';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController = TextEditingController(text: widget.pickerName);
//     _pickerContactController =
//         TextEditingController(text: widget.pickerContact);
//     _noteController = TextEditingController(text: widget.note);
//     _controller = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;
//     final locationProvider = Provider.of<LocationProvider>(context);

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 200),
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   return ListTile(
//                     title: Text(
//                         '${_items[index]['name']} (${_items[index]['unit']})'),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.remove),
//                           onPressed: () {
//                             setState(() {
//                               if (_items[index]['quantity'] > 1) {
//                                 _items[index]['quantity']--;
//                               } else {
//                                 _items.removeAt(index);
//                               }
//                             });
//                           },
//                         ),
//                         Container(
//                           width: 40,
//                           child: TextField(
//                             keyboardType: TextInputType.number,
//                             onChanged: (value) {
//                               setState(() {
//                                 _items[index]['quantity'] =
//                                     int.tryParse(value) ?? 1;
//                               });
//                             },
//                             decoration: InputDecoration(
//                               contentPadding: EdgeInsets.symmetric(
//                                   vertical: 8, horizontal: 8),
//                               isDense: true,
//                               border: OutlineInputBorder(),
//                             ),
//                             controller: TextEditingController()
//                               ..text = _items[index]['quantity'].toString(),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add),
//                           onPressed: () {
//                             setState(() {
//                               _items[index]['quantity']++;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete),
//                           onPressed: () {
//                             setState(() {
//                               _items.removeAt(index);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             _items[existingIndex]['quantity']++;
//                           } else {
//                             _items.add({
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit']
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: locationProvider.locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _pickerContactController,
//                     decoration: InputDecoration(
//                       labelText: 'Picker Contact Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                     keyboardType: TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(10),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.contact_phone),
//                   onPressed: _pickContact,
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : () => _updateRequest(context),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   late List<Map<String, dynamic>> _items;
//   late TextEditingController _controller;
//   late TextEditingController _pickerNameController;
//   late TextEditingController _pickerContactController;
//   late TextEditingController _noteController;
//   String _searchQuery = '';
//   String _selectedLocation = 'Default Location';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController = TextEditingController(text: widget.pickerName);
//     _pickerContactController =
//         TextEditingController(text: widget.pickerContact);
//     _noteController = TextEditingController(text: widget.note);
//     _controller = TextEditingController();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 200),
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   return ListTile(
//                     title: Text(
//                         '${_items[index]['name']} (${_items[index]['unit']})'),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.remove),
//                           onPressed: () {
//                             setState(() {
//                               if (_items[index]['quantity'] > 1) {
//                                 _items[index]['quantity']--;
//                               } else {
//                                 _items.removeAt(index);
//                               }
//                             });
//                           },
//                         ),
//                         Container(
//                           width: 40,
//                           child: TextField(
//                             keyboardType: TextInputType.number,
//                             onChanged: (value) {
//                               setState(() {
//                                 _items[index]['quantity'] =
//                                     int.tryParse(value) ?? 1;
//                               });
//                             },
//                             decoration: InputDecoration(
//                               contentPadding: EdgeInsets.symmetric(
//                                   vertical: 8, horizontal: 8),
//                               isDense: true,
//                               border: OutlineInputBorder(),
//                             ),
//                             controller: TextEditingController()
//                               ..text = _items[index]['quantity'].toString(),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add),
//                           onPressed: () {
//                             setState(() {
//                               _items[index]['quantity']++;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete),
//                           onPressed: () {
//                             setState(() {
//                               _items.removeAt(index);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             _items[existingIndex]['quantity']++;
//                           } else {
//                             _items.add({
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit']
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: _locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerContactController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Contact Number',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.phone),
//               ),
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//               ],
//               maxLength: 10,
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : () => _updateRequest(context),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';

// class EditUserRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;

//   EditUserRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//   });

//   @override
//   _EditUserRequestBottomSheetState createState() =>
//       _EditUserRequestBottomSheetState();
// }

// class _EditUserRequestBottomSheetState
//     extends State<EditUserRequestBottomSheet> {
//   List<Map<String, dynamic>> _items = [];
//   TextEditingController _controller = TextEditingController();
//   TextEditingController _pickerNameController = TextEditingController();
//   TextEditingController _pickerContactController = TextEditingController();
//   TextEditingController _noteController = TextEditingController();
//   String _searchQuery = '';
//   String _selectedLocation = 'Default Location';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false; // Add this line

//   @override
//   void initState() {
//     super.initState();
//     _items = List.from(widget.items.map((item) {
//       return {
//         'name': item['name'],
//         'quantity': item['quantity'] ?? 1,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }));
//     _selectedLocation = widget.location;
//     _pickerNameController.text = widget.pickerName;
//     _pickerContactController.text = widget.pickerContact;
//     _noteController.text = widget.note;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final inventoryItems = Provider.of<InventoryProvider>(context).items;

//     List<Map<String, dynamic>> filteredItems = inventoryItems
//         .where((item) =>
//             item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//         .toList();

//     return SingleChildScrollView(
//       child: Padding(
//         padding: MediaQuery.of(context).viewInsets,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Edit Request',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               constraints: BoxConstraints(maxHeight: 200),
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: _items.length,
//                 itemBuilder: (context, index) {
//                   return ListTile(
//                     title: Text(
//                         '${_items[index]['name']} (${_items[index]['unit']})'),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.remove),
//                           onPressed: () {
//                             setState(() {
//                               if (_items[index]['quantity'] > 1) {
//                                 _items[index]['quantity']--;
//                               } else {
//                                 _items.removeAt(index);
//                               }
//                             });
//                           },
//                         ),
//                         Container(
//                           width: 40,
//                           child: TextField(
//                             keyboardType: TextInputType.number,
//                             onChanged: (value) {
//                               setState(() {
//                                 _items[index]['quantity'] =
//                                     int.tryParse(value) ?? 1;
//                               });
//                             },
//                             decoration: InputDecoration(
//                               contentPadding: EdgeInsets.symmetric(
//                                   vertical: 8, horizontal: 8),
//                               isDense: true,
//                               border: OutlineInputBorder(),
//                             ),
//                             controller: TextEditingController()
//                               ..text = _items[index]['quantity'].toString(),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add),
//                           onPressed: () {
//                             setState(() {
//                               _items[index]['quantity']++;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete),
//                           onPressed: () {
//                             setState(() {
//                               _items.removeAt(index);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             TextField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 labelText: 'Add Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.add),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _searchQuery = value;
//                 });
//               },
//             ),
//             if (filteredItems.isNotEmpty)
//               Container(
//                 height: 150,
//                 child: ListView.builder(
//                   itemCount: filteredItems.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       title: Text(
//                           '${filteredItems[index]['name']} (${filteredItems[index]['unit']})'),
//                       onTap: () {
//                         setState(() {
//                           String selectedItem = filteredItems[index]['name'];
//                           int existingIndex = _items.indexWhere(
//                               (item) => item['name'] == selectedItem);

//                           if (existingIndex != -1) {
//                             _items[existingIndex]['quantity']++;
//                           } else {
//                             _items.add({
//                               'name': selectedItem,
//                               'quantity': 1,
//                               'unit': filteredItems[index]['unit']
//                             });
//                           }

//                           _controller.clear();
//                           _searchQuery = '';
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),
//             SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedLocation,
//               decoration: InputDecoration(
//                 labelText: 'Delivery Location',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               items: _locations.map((location) {
//                 return DropdownMenuItem(
//                   value: location,
//                   child: Text(location),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedLocation = value!;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerNameController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Name',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.person),
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _pickerContactController,
//               decoration: InputDecoration(
//                 labelText: 'Picker Contact Number',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.phone),
//               ),
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//               ],
//               maxLength: 10,
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _noteController,
//               decoration: InputDecoration(
//                 labelText: 'Optional Note',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.note),
//               ),
//               maxLines: 3,
//             ),
//             SizedBox(height: 16),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text('Close'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     _updateRequest(context);
//                   },
//                   child: Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _updateRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }

//     try {
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);
//       await Provider.of<RequestProvider>(context, listen: false).updateRequest(
//         widget.id,
//         _items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request updated successfully')),
//       );

//       Navigator.of(context).pop();
//     } catch (e) {
//       print("Error updating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating request: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }
