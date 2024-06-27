import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class EditItemBottomSheet extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? item;

  EditItemBottomSheet({this.id, this.item});

  @override
  _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
}

class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      _categoryController.text = widget.item!['category'];
      _unitController.text = widget.item!['unit'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item == null ? 'Add Item' : 'Edit Item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Item Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter item name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter category';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _unitController,
                  decoration: InputDecoration(labelText: 'Unit'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter unit';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final newItem = {
                            'name': _nameController.text,
                            'category': _categoryController.text,
                            'unit': _unitController.text,
                          };

                          if (widget.id == null) {
                            Provider.of<InventoryProvider>(context,
                                    listen: false)
                                .addItem(newItem);
                          } else {
                            Provider.of<InventoryProvider>(context,
                                    listen: false)
                                .updateItem(widget.id!, newItem);
                          }

                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(widget.id == null ? 'Add' : 'Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditItemBottomSheet extends StatefulWidget {
//   final int? index;
//   final Map<String, dynamic>? item;

//   EditItemBottomSheet({this.index, this.item});

//   @override
//   _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
// }

// class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _categoryController = TextEditingController();
//   final _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.item != null) {
//       _nameController.text = widget.item!['name'];
//       _categoryController.text = widget.item!['category'];
//       _unitController.text = widget.item!['unit'];
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: MediaQuery.of(context).viewInsets,
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.item == null ? 'Add Item' : 'Edit Item',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(labelText: 'Item Name'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter item name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _categoryController,
//                   decoration: InputDecoration(labelText: 'Category'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter category';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _unitController,
//                   decoration: InputDecoration(labelText: 'Unit'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter unit';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           final newItem = {
//                             'name': _nameController.text,
//                             'category': _categoryController.text,
//                             'unit': _unitController.text,
//                           };

//                           if (widget.index == null) {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .addItem(newItem);
//                           } else {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .updateItem(widget.index!, newItem);
//                           }

//                           Navigator.of(context).pop();
//                         }
//                       },
//                       child: Text(widget.index == null ? 'Add' : 'Update'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditItemBottomSheet extends StatefulWidget {
//   final int? index;
//   final Map<String, dynamic>? item;

//   EditItemBottomSheet({this.index, this.item});

//   @override
//   _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
// }

// class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _categoryController = TextEditingController();
//   final _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.item != null) {
//       _nameController.text = widget.item!['name'];
//       _categoryController.text = widget.item!['category'];
//       _unitController.text = widget.item!['unit'];
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: MediaQuery.of(context).viewInsets,
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.item == null ? 'Add Item' : 'Edit Item',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(labelText: 'Item Name'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter item name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _categoryController,
//                   decoration: InputDecoration(labelText: 'Category'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter category';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _unitController,
//                   decoration: InputDecoration(labelText: 'Unit'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter unit';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           final newItem = {
//                             'name': _nameController.text,
//                             'category': _categoryController.text,
//                             'unit': _unitController.text,
//                           };

//                           if (widget.index == null) {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .addItem(
//                               _nameController.text,
//                               _categoryController.text,
//                               _unitController.text,
//                             );
//                           } else {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .updateItem(
//                               widget.index!,
//                               newItem,
//                             );
//                           }

//                           Navigator.of(context).pop();
//                         }
//                       },
//                       child: Text(widget.index == null ? 'Add' : 'Update'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditItemBottomSheet extends StatefulWidget {
//   final int? index;
//   final Map<String, dynamic>? item;

//   EditItemBottomSheet({this.index, this.item});

//   @override
//   _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
// }

// class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _categoryController = TextEditingController();
//   final _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.item != null) {
//       _nameController.text = widget.item!['name'];
//       _categoryController.text = widget.item!['category'];
//       _unitController.text = widget.item!['unit'];
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: MediaQuery.of(context).viewInsets,
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.item == null ? 'Add Item' : 'Edit Item',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(labelText: 'Item Name'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter item name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _categoryController,
//                   decoration: InputDecoration(labelText: 'Category'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter category';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _unitController,
//                   decoration: InputDecoration(labelText: 'Unit'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter unit';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           final newItem = {
//                             'name': _nameController.text,
//                             'category': _categoryController.text,
//                             'unit': _unitController.text,
//                           };

//                           if (widget.index == null) {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .addItem(newItem);
//                           } else {
//                             Provider.of<InventoryProvider>(context,
//                                     listen: false)
//                                 .updateItem(widget.index!, newItem);
//                           }

//                           Navigator.of(context).pop();
//                         }
//                       },
//                       child: Text(widget.index == null ? 'Add' : 'Update'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
