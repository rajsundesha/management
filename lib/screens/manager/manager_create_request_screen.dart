import 'package:flutter/material.dart';
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

                List<Map<String, dynamic>> requestItems = _selectedItems.entries
                    .map((entry) => {
                          'name': entry.key,
                          'quantity': entry.value,
                        })
                    .toList();
                String location = _selectedLocation;
                String pickerName = _pickerNameController.text;
                String pickerContact = _pickerContactController.text;
                String note = _noteController.text;
                final currentUserEmail =
                    Provider.of<AuthProvider>(context, listen: false)
                        .currentUserEmail!;

                Provider.of<RequestProvider>(context, listen: false).addRequest(
                    requestItems,
                    location,
                    pickerName,
                    pickerContact,
                    note,
                    currentUserEmail);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Request added for ${_selectedItems.entries.map((e) => '${e.value} x ${e.key}').join(', ')} at $location'),
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
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';

// class ManagerCreateRequestScreen extends StatefulWidget {
//   @override
//   _ManagerCreateRequestScreenState createState() =>
//       _ManagerCreateRequestScreenState();
// }

// class _ManagerCreateRequestScreenState
//     extends State<ManagerCreateRequestScreen> {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';
//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   TextEditingController _pickerNameController = TextEditingController();
//   TextEditingController _pickerContactController = TextEditingController();
//   TextEditingController _noteController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               _buildSearchBar(),
//               SizedBox(height: 16),
//               Text('Categories',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildCategoryList(),
//               SizedBox(height: 16),
//               Text('Inventory List',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildInventoryList(),
//               SizedBox(height: 16),
//               Text('Selected Items',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildSelectedItemsList(),
//               SizedBox(height: 16),
//               _buildSendRequestButton(),
//               SizedBox(height: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<String> categories = inventoryProvider.items
//             .map((item) => item['category'] as String)
//             .toSet()
//             .toList();
//         categories.insert(0, 'All');

//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories[index];
//               return GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     _selectedCategory = category;
//                   });
//                 },
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   margin: EdgeInsets.symmetric(horizontal: 8),
//                   decoration: BoxDecoration(
//                     color: _selectedCategory == category
//                         ? Colors.blue
//                         : Colors.grey,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Center(
//                     child: Text(
//                       category,
//                       style: TextStyle(
//                           color: Colors.white, fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         if (inventoryProvider.items.isEmpty) {
//           return Center(child: CircularProgressIndicator());
//         }

//         List<Map<String, dynamic>> filteredItems = inventoryProvider
//             .getItemsByCategory(_selectedCategory)
//             .where((item) =>
//                 item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//             .toList();

//         return Container(
//           height: 200,
//           child: ListView.builder(
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   contentPadding: EdgeInsets.all(16),
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text(item['name'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildQuantityControls(item),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     return _selectedItems.containsKey(item['name'])
//         ? Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove),
//                 onPressed: () {
//                   setState(() {
//                     if (_selectedItems[item['name']] == 1) {
//                       _selectedItems.remove(item['name']);
//                     } else {
//                       _selectedItems[item['name']] =
//                           _selectedItems[item['name']]! - 1;
//                     }
//                   });
//                 },
//               ),
//               Text('${_selectedItems[item['name']]} ${item['unit']}'),
//               IconButton(
//                 icon: Icon(Icons.add),
//                 onPressed: () {
//                   setState(() {
//                     _selectedItems[item['name']] =
//                         _selectedItems[item['name']]! + 1;
//                   });
//                 },
//               ),
//             ],
//           )
//         : IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () {
//               setState(() {
//                 _selectedItems[item['name']] = 1;
//               });
//             },
//           );
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 200,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return Consumer<InventoryProvider>(
//             builder: (context, inventoryProvider, child) {
//               Map<String, dynamic> item = inventoryProvider.items
//                   .firstWhere((element) => element['name'] == itemName);
//               return Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   contentPadding: EdgeInsets.all(16),
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text('$itemName x$quantity ${item['unit']}',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildSelectedQuantityControls(itemName),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildSelectedQuantityControls(String itemName) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (_selectedItems[itemName] == 1) {
//                 _selectedItems.remove(itemName);
//               } else {
//                 _selectedItems[itemName] = _selectedItems[itemName]! - 1;
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
//                 _selectedItems[itemName] = int.tryParse(value) ?? 1;
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text = _selectedItems[itemName].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               _selectedItems[itemName] = _selectedItems[itemName]! + 1;
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.remove_circle, color: Colors.red),
//           onPressed: () {
//             setState(() {
//               _selectedItems.remove(itemName);
//             });
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Center(
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () {
//                 _showRequestDetailsDialog(context);
//               },
//         child: Text('Send Request'),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _selectedItems.isEmpty ? Colors.grey : Colors.blue,
//           padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//         ),
//       ),
//     );
//   }

//   void _showRequestDetailsDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 DropdownButtonFormField<String>(
//                   value: _selectedLocation,
//                   decoration: InputDecoration(
//                     labelText: 'Delivery Location',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.location_on),
//                   ),
//                   items: _locations.map((location) {
//                     return DropdownMenuItem(
//                       value: location,
//                       child: Text(location),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedLocation = value!;
//                     });
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.phone),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_pickerNameController.text.isEmpty ||
//                     _pickerContactController.text.isEmpty ||
//                     _pickerContactController.text.length != 10 ||
//                     _selectedLocation.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                           'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//                     ),
//                   );
//                   return;
//                 }

//                 List<Map<String, dynamic>> requestItems = _selectedItems.entries
//                     .map((entry) => {
//                           'name': entry.key,
//                           'quantity': entry.value,
//                         })
//                     .toList();
//                 String location = _selectedLocation;
//                 String pickerName = _pickerNameController.text;
//                 String pickerContact = _pickerContactController.text;
//                 String note = _noteController.text;

//                 Provider.of<RequestProvider>(context, listen: false).addRequest(
//                     requestItems, location, pickerName, pickerContact, note);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                         'Request added for ${_selectedItems.entries.map((e) => '${e.value} x ${e.key}').join(', ')} at $location'),
//                   ),
//                 );

//                 setState(() {
//                   _selectedItems.clear();
//                   _selectedLocation = 'Default Location';
//                   _pickerNameController.clear();
//                   _pickerContactController.clear();
//                   _noteController.clear();
//                 });

//                 Navigator.of(context).pop();
//               },
//               child: Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
