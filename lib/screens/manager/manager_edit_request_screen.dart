import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';

class ManagerEditRequestScreen extends StatefulWidget {
  @override
  _ManagerEditRequestScreenState createState() =>
      _ManagerEditRequestScreenState();
}

class _ManagerEditRequestScreenState extends State<ManagerEditRequestScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          return ListView.builder(
            itemCount: requestProvider.requests.length,
            itemBuilder: (context, index) {
              final request = requestProvider.requests[index];
              final isOwnRequest = request['createdBy'] == currentUserEmail;
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${request['location']}\n'
                    'Picker: ${request['pickerName']}\n'
                    'Contact: ${request['pickerContact']}\n'
                    'Status: ${request['status']}',
                  ),
                  leading: Icon(
                    Icons.request_page,
                    color: request['status'] == 'pending'
                        ? Colors.orange
                        : Colors.green,
                  ),
                  trailing: isOwnRequest
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _editRequest(context, request['id'], request);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                try {
                                  final inventoryProvider =
                                      Provider.of<InventoryProvider>(context,
                                          listen: false);
                                  await Provider.of<RequestProvider>(context,
                                          listen: false)
                                      .cancelRequest(
                                          request['id'], inventoryProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Request cancelled successfully')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error cancelling request: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editRequest(
      BuildContext context, String id, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditManagerRequestBottomSheet(
        id: id,
        items: List<Map<String, dynamic>>.from(request['items']),
        location: request['location'] ?? 'Default Location',
        pickerName: request['pickerName'] ?? '',
        pickerContact: request['pickerContact'] ?? '',
        note: request['note'] ?? '',
        createdBy: request['createdBy'] ?? 'Unknown',
      ),
    );
  }
}

class EditManagerRequestBottomSheet extends StatefulWidget {
  final String id;
  final List<Map<String, dynamic>> items;
  final String location;
  final String pickerName;
  final String pickerContact;
  final String note;
  final String createdBy;

  EditManagerRequestBottomSheet({
    required this.id,
    required this.items,
    required this.location,
    required this.pickerName,
    required this.pickerContact,
    required this.note,
    required this.createdBy,
  });

  @override
  _EditManagerRequestBottomSheetState createState() =>
      _EditManagerRequestBottomSheetState();
}

class _EditManagerRequestBottomSheetState
    extends State<EditManagerRequestBottomSheet> {
  List<Map<String, dynamic>> _items = [];
  TextEditingController _controller = TextEditingController();
  TextEditingController _pickerNameController = TextEditingController();
  TextEditingController _pickerContactController = TextEditingController();
  TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';
  String _selectedLocation = 'Default Location';
  List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items.map((item) {
      return {
        'name': item['name'],
        'quantity': item['quantity'] ?? 1,
        'unit': item['unit'] ?? 'pcs',
      };
    }));
    _selectedLocation = widget.location;
    _pickerNameController.text = widget.pickerName;
    _pickerContactController.text = widget.pickerContact;
    _noteController.text = widget.note;
  }

  @override
  Widget build(BuildContext context) {
    final inventoryItems = Provider.of<InventoryProvider>(context).items;

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
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                        '${_items[index]['name']} (${_items[index]['unit']})'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              if (_items[index]['quantity'] > 1) {
                                _items[index]['quantity']--;
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
                            _items[existingIndex]['quantity']++;
                          } else {
                            _items.add({
                              'name': selectedItem,
                              'quantity': 1,
                              'unit': filteredItems[index]['unit']
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
            TextField(
              controller: _pickerNameController,
              decoration: InputDecoration(
                labelText: 'Picker Name (at least 2 letters)',
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
                    if (!_validateInputs()) {
                      return;
                    }

                    final currentUserEmail =
                        Provider.of<AuthProvider>(context, listen: false)
                            .currentUserEmail;

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
                      final inventoryProvider = Provider.of<InventoryProvider>(
                          context,
                          listen: false);
                      await Provider.of<RequestProvider>(context, listen: false)
                          .updateRequest(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating request: $e')),
                      );
                    }
                  },
                  child: Text('Update Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _validateInputs() {
    String pickerName = _pickerNameController.text.trim();
    if (pickerName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picker name must be at least 2 letters.')),
      );
      return false;
    }

    if (_pickerContactController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mobile number must be 10 digits.')),
      );
      return false;
    }

    return true;
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
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class ManagerEditRequestScreen extends StatefulWidget {
//   @override
//   _ManagerEditRequestScreenState createState() =>
//       _ManagerEditRequestScreenState();
// }

// class _ManagerEditRequestScreenState extends State<ManagerEditRequestScreen> {
//   @override

//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final currentUserEmail = authProvider.currentUserEmail;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Requests'),
//       ),
//       body: Consumer<RequestProvider>(
//         builder: (context, requestProvider, child) {
//           return ListView.builder(
//             itemCount: requestProvider.requests.length,
//             itemBuilder: (context, index) {
//               final request = requestProvider.requests[index];
//               final isOwnRequest = request['createdBy'] == currentUserEmail;
//               return Card(
//                 child: ListTile(
//                   title: Text(
//                     'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//                   ),
//                   subtitle: Text(
//                     'Location: ${request['location']}\n'
//                     'Picker: ${request['pickerName']}\n'
//                     'Contact: ${request['pickerContact']}\n'
//                     'Status: ${request['status']}',
//                   ),
//                   leading: Icon(
//                     Icons.request_page,
//                     color: request['status'] == 'pending'
//                         ? Colors.orange
//                         : Colors.green,
//                   ),
//                   //                 trailing: Row(
//                   //                   mainAxisSize: MainAxisSize.min,
//                   //                   children: [
//                   //                     if (request['status'] == 'pending' &&
//                   //                         request['createdBy'] == currentUserEmail)
//                   //                       IconButton(
//                   //                         icon: Icon(Icons.edit, color: Colors.blue),
//                   //                         onPressed: () {
//                   //                           _editRequest(context, request['id'], request);
//                   //                         },
//                   //                       ),
//                   //                     if (request['status'] == 'pending' &&
//                   //                         request['createdBy'] == currentUserEmail)
//                   //                       IconButton(
//                   //                         icon: Icon(Icons.delete, color: Colors.red),
//                   //                         onPressed: () {
//                   //                           requestProvider.cancelRequest(request['id']);
//                   //                         },
//                   //                       ),
//                   //                   ],
//                   //                 ),
//                   //               ),
//                   //             );
//                   //           },
//                   //         );
//                   //       },
//                   //     ),
//                   //   );
//                   // }
//                   // trailing: isOwnRequest
//                   //     ? Row(
//                   //         mainAxisSize: MainAxisSize.min,
//                   //         children: [
//                   //           IconButton(
//                   //             icon: Icon(Icons.edit, color: Colors.blue),
//                   //             onPressed: () {
//                   //               _editRequest(context, request['id'], request);
//                   //             },
//                   //           ),
//                   //           IconButton(
//                   //             icon: Icon(Icons.delete, color: Colors.red),
//                   //             onPressed: () {
//                   //               requestProvider.cancelRequest(request['id']);
//                   //             },
//                   //           ),
//                   //         ],
//                   //       )
//                   //     : null,
//                   trailing: isOwnRequest
//                         ? Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editRequest(context, request['id'], request);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () async {
//                                   try {
//                                     final inventoryProvider =
//                                         Provider.of<InventoryProvider>(context,
//                                             listen: false);
//                                     await Provider.of<RequestProvider>(context,
//                                             listen: false)
//                                         .cancelRequest(
//                                             request['id'], inventoryProvider);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                           content: Text(
//                                               'Request cancelled successfully')),
//                                     );
//                                   } catch (e) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                           content: Text(
//                                               'Error cancelling request: $e')),
//                                     );
//                                   }
//                                 },
//                               ),
//                             ],
//                           )
//                         : null,
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   void _editRequest(
//       BuildContext context, String id, Map<String, dynamic> request) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditManagerRequestBottomSheet(
//         id: id,
//         items: List<Map<String, dynamic>>.from(request['items']),
//         location: request['location'] ?? 'Default Location',
//         pickerName: request['pickerName'] ?? '',
//         pickerContact: request['pickerContact'] ?? '',
//         note: request['note'] ?? '',
//         createdBy: request['createdBy'] ?? 'Unknown',
//       ),
//     );
//   }
// }

// class EditManagerRequestBottomSheet extends StatefulWidget {
//   final String id;
//   final List<Map<String, dynamic>> items;
//   final String location;
//   final String pickerName;
//   final String pickerContact;
//   final String note;
//   final String createdBy;

//   EditManagerRequestBottomSheet({
//     required this.id,
//     required this.items,
//     required this.location,
//     required this.pickerName,
//     required this.pickerContact,
//     required this.note,
//     required this.createdBy,
//   });

//   @override
//   _EditManagerRequestBottomSheetState createState() =>
//       _EditManagerRequestBottomSheetState();
// }

// class _EditManagerRequestBottomSheetState
//     extends State<EditManagerRequestBottomSheet> {
//   List<Map<String, dynamic>> _items = [];
//   TextEditingController _controller = TextEditingController();
//   TextEditingController _pickerNameController = TextEditingController();
//   TextEditingController _pickerContactController = TextEditingController();
//   TextEditingController _noteController = TextEditingController();
//   String _searchQuery = '';
//   String _selectedLocation = 'Default Location'; // Default location
//   List<String> _locations = [
//     'Default Location',
//     'Location 1',
//     'Location 2'
//   ]; // List of locations

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
//               constraints: BoxConstraints(
//                   maxHeight: 200), // Fixed height for the ListView
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
//                               if (_items[index]['quantity'] == 1) {
//                                 _items.removeAt(index);
//                               } else {
//                                 _items[index]['quantity']--;
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
//                 height: 150, // Fixed height for the filtered items ListView
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
//                               'unit': filteredItems[index]['unit'],
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
//               keyboardType: TextInputType.phone,
//               maxLength: 10,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
//                   onPressed: () async {
//                     if (_pickerContactController.text.length != 10) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text('Contact number must be 10 digits.')),
//                       );
//                       return;
//                     }

//                     final currentUserEmail =
//                         Provider.of<AuthProvider>(context, listen: false)
//                             .currentUserEmail;

//                     if (currentUserEmail == null) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                               'User email not available. Please log in again.'),
//                         ),
//                       );
//                       return;
//                     }

//                     try {
//                       final inventoryProvider = Provider.of<InventoryProvider>(
//                           context,
//                           listen: false);
//                       await Provider.of<RequestProvider>(context, listen: false)
//                           .updateRequest(
//                         widget.id,
//                         _items,
//                         _selectedLocation,
//                         _pickerNameController.text,
//                         _pickerContactController.text,
//                         _noteController.text,
//                         currentUserEmail,
//                         inventoryProvider,
//                       );

//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Request updated successfully')),
//                       );

//                       Navigator.of(context).pop();
//                     } catch (e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Error updating request: $e')),
//                       );
//                     }
//                   },
//                   child: Text('Update Request'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blueAccent,
//                   ),
//                 )
               
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

