import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class EditInventoryItemScreen extends StatefulWidget {
  final String itemId;

  EditInventoryItemScreen({required this.itemId});

  @override
  _EditInventoryItemScreenState createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nameController = TextEditingController();
  TextEditingController _categoryController = TextEditingController();
  TextEditingController _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final item = inventoryProvider.items
        .firstWhere((item) => item['id'] == widget.itemId);
    _nameController.text = item['name'];
    _categoryController.text = item['category'];
    _unitController.text = item['unit'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Inventory Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(labelText: 'Category'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item category';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(labelText: 'Unit'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item unit';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final inventoryProvider =
                        Provider.of<InventoryProvider>(context, listen: false);
                    final updatedItem = {
                      'name': _nameController.text,
                      'category': _categoryController.text,
                      'unit': _unitController.text,
                    };
                    inventoryProvider.updateItem(
                      widget.itemId, // Use document ID instead of index
                      updatedItem,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditInventoryItemScreen extends StatefulWidget {
//   final int itemIndex;

//   EditInventoryItemScreen({required this.itemIndex});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items[widget.itemIndex];
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Inventory Item'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item name';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: InputDecoration(labelText: 'Category'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item category';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _unitController,
//                 decoration: InputDecoration(labelText: 'Unit'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item unit';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   if (_formKey.currentState!.validate()) {
//                     final inventoryProvider =
//                         Provider.of<InventoryProvider>(context, listen: false);
//                     final updatedItem = {
//                       'name': _nameController.text,
//                       'category': _categoryController.text,
//                       'unit': _unitController.text,
//                     };
//                     inventoryProvider.updateItem(
//                       widget.itemIndex,
//                       updatedItem,
//                     );
//                     Navigator.pop(context);
//                   }
//                 },
//                 child: Text('Save Changes'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditInventoryItemScreen extends StatefulWidget {
//   final int itemIndex;

//   EditInventoryItemScreen({required this.itemIndex});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items[widget.itemIndex];
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Inventory Item'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item name';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: InputDecoration(labelText: 'Category'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item category';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _unitController,
//                 decoration: InputDecoration(labelText: 'Unit'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item unit';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   if (_formKey.currentState!.validate()) {
//                     final inventoryProvider =
//                         Provider.of<InventoryProvider>(context, listen: false);
//                     final updatedItem = {
//                       'name': _nameController.text,
//                       'category': _categoryController.text,
//                       'unit': _unitController.text,
//                     };
//                     inventoryProvider.updateItem(
//                       widget.itemIndex,
//                       updatedItem,
//                     );
//                     Navigator.pop(context);
//                   }
//                 },
//                 child: Text('Save Changes'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditInventoryItemScreen extends StatefulWidget {
//   final int itemIndex;

//   EditInventoryItemScreen({required this.itemIndex});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items[widget.itemIndex];
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit Inventory Item'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item name';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _categoryController,
//                 decoration: InputDecoration(labelText: 'Category'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item category';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _unitController,
//                 decoration: InputDecoration(labelText: 'Unit'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the item unit';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   if (_formKey.currentState!.validate()) {
//                     final inventoryProvider =
//                         Provider.of<InventoryProvider>(context, listen: false);
//                     inventoryProvider.updateItem(
//                       widget.itemIndex,
//                       _nameController.text,
//                       _categoryController.text,
//                       _unitController.text,
//                     );
//                     Navigator.pop(context);
//                   }
//                 },
//                 child: Text('Save Changes'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
