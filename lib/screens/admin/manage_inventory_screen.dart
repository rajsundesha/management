import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import 'edit_item_bottom_sheet.dart';

class ManageInventoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Inventory'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Items',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, child) {
                  if (inventoryProvider.items.isEmpty) {
                    return Center(child: Text('No items available.'));
                  }

                  return ListView.builder(
                    itemCount: inventoryProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = inventoryProvider.items[index];
                      return Card(
                        child: ListTile(
                          title: Text('${item['name']}'),
                          subtitle: Text(
                              'Category: ${item['category']} - Unit: ${item['unit']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editItem(context, item['id'], item);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  inventoryProvider.deleteItem(item['id']);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _addItem(context);
                },
                child: Text('Add Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addItem(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditItemBottomSheet(),
    );
  }

  void _editItem(BuildContext context, String id, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditItemBottomSheet(
        id: id,
        item: item,
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_item_bottom_sheet.dart';

// class ManageInventoryScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Inventory'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Inventory Items',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: Consumer<InventoryProvider>(
//                 builder: (context, inventoryProvider, child) {
//                   if (inventoryProvider.items.isEmpty) {
//                     return Center(child: Text('No items available.'));
//                   }

//                   return ListView.builder(
//                     itemCount: inventoryProvider.items.length,
//                     itemBuilder: (context, index) {
//                       final item = inventoryProvider.items[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text('${item['name']}'),
//                           subtitle: Text(
//                               'Category: ${item['category']} - Unit: ${item['unit']}'),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editItem(context, index, item);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   inventoryProvider.deleteItem(index);
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   _addItem(context);
//                 },
//                 child: Text('Add Item'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _addItem(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(),
//     );
//   }

//   void _editItem(BuildContext context, int index, Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(
//         index: index,
//         item: item,
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_item_bottom_sheet.dart';

// class ManageInventoryScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Inventory'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Inventory Items',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Expanded(
//               child: Consumer<InventoryProvider>(
//                 builder: (context, inventoryProvider, child) {
//                   if (inventoryProvider.items.isEmpty) {
//                     return Center(child: CircularProgressIndicator());
//                   }

//                   return ListView.builder(
//                     itemCount: inventoryProvider.items.length,
//                     itemBuilder: (context, index) {
//                       final item = inventoryProvider.items[index];
//                       return Card(
//                         child: ListTile(
//                           title: Text('${item['name']}'),
//                           subtitle: Text(
//                               'Category: ${item['category']} - Unit: ${item['unit']}'),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editItem(context, index, item);
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   inventoryProvider.deleteItem(index);
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   _addItem(context);
//                 },
//                 child: Text('Add Item'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _addItem(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(),
//     );
//   }

//   void _editItem(BuildContext context, int index, Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(
//         index: index,
//         item: item,
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_inventory_item_screen.dart';
// import 'add_inventory_item_screen.dart';

// class ManageInventoryScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Manage Inventory'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                     builder: (context) => AddInventoryItemScreen()),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Consumer<InventoryProvider>(
//         builder: (context, inventoryProvider, child) {
//           if (inventoryProvider.items.isEmpty) {
//             return Center(child: CircularProgressIndicator());
//           }
//           return ListView.builder(
//             itemCount: inventoryProvider.items.length,
//             itemBuilder: (context, index) {
//               final item = inventoryProvider.items[index];
//               return Card(
//                 margin: EdgeInsets.all(10),
//                 child: ListTile(
//                   title: Text('${item['name']}'),
//                   subtitle: Text(
//                       'Category: ${item['category']} \nUnit: ${item['unit']}'),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: Icon(Icons.edit, color: Colors.blue),
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) =>
//                                   EditInventoryItemScreen(itemIndex: index),
//                             ),
//                           );
//                         },
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete, color: Colors.red),
//                         onPressed: () {
//                           inventoryProvider.removeItem(index);
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
