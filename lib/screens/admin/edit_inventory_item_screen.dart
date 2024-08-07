// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class EditInventoryItemScreen extends StatefulWidget {
//   final String itemId;

//   EditInventoryItemScreen({required this.itemId});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();
//   TextEditingController _quantityController = TextEditingController();
//   TextEditingController _pipeLengthController = TextEditingController();
//   TextEditingController _lengthController = TextEditingController();
//   TextEditingController _widthController = TextEditingController();
//   TextEditingController _heightController = TextEditingController();
//   bool _isPipe = false;

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items
//         .firstWhere((item) => item['id'] == widget.itemId);
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//     _quantityController.text = item['quantity'].toString();
//     _isPipe = item['isPipe'] ?? false;
//     _pipeLengthController.text = (item['pipeLength'] ?? 0).toString();
//     _lengthController.text = (item['length'] ?? '').toString();
//     _widthController.text = (item['width'] ?? '').toString();
//     _heightController.text = (item['height'] ?? '').toString();
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
//           child: ListView(
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
//               TextFormField(
//                 controller: _quantityController,
//                 decoration: InputDecoration(labelText: 'Quantity'),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the quantity';
//                   }
//                   if (double.tryParse(value) == null) {
//                     return 'Please enter a valid number';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 16),
//               Text('Dimensions (LWH):',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextFormField(
//                       controller: _lengthController,
//                       decoration: InputDecoration(labelText: 'Length'),
//                       keyboardType: TextInputType.number,
//                     ),
//                   ),
//                   SizedBox(width: 16),
//                   Expanded(
//                     child: TextFormField(
//                       controller: _widthController,
//                       decoration: InputDecoration(labelText: 'Width'),
//                       keyboardType: TextInputType.number,
//                     ),
//                   ),
//                   SizedBox(width: 16),
//                   Expanded(
//                     child: TextFormField(
//                       controller: _heightController,
//                       decoration: InputDecoration(labelText: 'Height'),
//                       keyboardType: TextInputType.number,
//                     ),
//                   ),
//                 ],
//               ),
//               SwitchListTile(
//                 title: Text('Is this item a pipe?'),
//                 value: _isPipe,
//                 onChanged: (bool value) {
//                   setState(() {
//                     _isPipe = value;
//                   });
//                 },
//               ),
//               if (_isPipe)
//                 TextFormField(
//                   controller: _pipeLengthController,
//                   decoration:
//                       InputDecoration(labelText: 'Pipe Length (meters)'),
//                   keyboardType: TextInputType.number,
//                   validator: (value) {
//                     if (_isPipe) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter the pipe length';
//                       }
//                       if (double.tryParse(value) == null) {
//                         return 'Please enter a valid number';
//                       }
//                     }
//                     return null;
//                   },
//                 ),
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
//                       'quantity': double.parse(_quantityController.text),
//                       'isPipe': _isPipe,
//                       'pipeLength': _isPipe
//                           ? double.parse(_pipeLengthController.text)
//                           : 0,
//                       'length': _lengthController.text.isNotEmpty
//                           ? double.parse(_lengthController.text)
//                           : null,
//                       'width': _widthController.text.isNotEmpty
//                           ? double.parse(_widthController.text)
//                           : null,
//                       'height': _heightController.text.isNotEmpty
//                           ? double.parse(_heightController.text)
//                           : null,
//                     };
//                     inventoryProvider.updateItem(
//                       widget.itemId,
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
//   final String itemId;

//   EditInventoryItemScreen({required this.itemId});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();
//   TextEditingController _quantityController = TextEditingController();
//   TextEditingController _pipeLengthController = TextEditingController();
//   TextEditingController _dimensionController = TextEditingController();
//   bool _isPipe = false;

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items
//         .firstWhere((item) => item['id'] == widget.itemId);
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//     _quantityController.text = item['quantity'].toString();
//     _isPipe = item['isPipe'] ?? false;
//     _pipeLengthController.text = (item['pipeLength'] ?? 0).toString();
//     _dimensionController.text = item['dimension'] ?? '';
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
//           child: ListView(
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
//               TextFormField(
//                 controller: _quantityController,
//                 decoration: InputDecoration(labelText: 'Quantity'),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the quantity';
//                   }
//                   if (double.tryParse(value) == null) {
//                     return 'Please enter a valid number';
//                   }
//                   return null;
//                 },
//               ),
//               TextFormField(
//                 controller: _dimensionController,
//                 decoration: InputDecoration(labelText: 'Dimension'),
//                 validator: (value) {
//                   // Dimension is optional, so no validation needed
//                   return null;
//                 },
//               ),
//               SwitchListTile(
//                 title: Text('Is this item a pipe?'),
//                 value: _isPipe,
//                 onChanged: (bool value) {
//                   setState(() {
//                     _isPipe = value;
//                   });
//                 },
//               ),
//               if (_isPipe)
//                 TextFormField(
//                   controller: _pipeLengthController,
//                   decoration:
//                       InputDecoration(labelText: 'Pipe Length (meters)'),
//                   keyboardType: TextInputType.number,
//                   validator: (value) {
//                     if (_isPipe) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter the pipe length';
//                       }
//                       if (double.tryParse(value) == null) {
//                         return 'Please enter a valid number';
//                       }
//                     }
//                     return null;
//                   },
//                 ),
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
//                       'quantity': double.parse(_quantityController.text),
//                       'isPipe': _isPipe,
//                       'pipeLength': _isPipe
//                           ? double.parse(_pipeLengthController.text)
//                           : 0,
//                       'dimension': _dimensionController.text,
//                     };
//                     inventoryProvider.updateItem(
//                       widget.itemId,
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
//   final String itemId;

//   EditInventoryItemScreen({required this.itemId});

//   @override
//   _EditInventoryItemScreenState createState() =>
//       _EditInventoryItemScreenState();
// }

// class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();
//   TextEditingController _quantityController = TextEditingController();
//   TextEditingController _pipeLengthController = TextEditingController();
//   bool _isPipe = false;

//   @override
//   void initState() {
//     super.initState();
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final item = inventoryProvider.items
//         .firstWhere((item) => item['id'] == widget.itemId);
//     _nameController.text = item['name'];
//     _categoryController.text = item['category'];
//     _unitController.text = item['unit'];
//     _quantityController.text = item['quantity'].toString();
//     _isPipe = item['isPipe'] ?? false;
//     _pipeLengthController.text = (item['pipeLength'] ?? 0).toString();
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
//           child: ListView(
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
//               TextFormField(
//                 controller: _quantityController,
//                 decoration: InputDecoration(labelText: 'Quantity'),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the quantity';
//                   }
//                   if (double.tryParse(value) == null) {
//                     return 'Please enter a valid number';
//                   }
//                   return null;
//                 },
//               ),
//               SwitchListTile(
//                 title: Text('Is this item a pipe?'),
//                 value: _isPipe,
//                 onChanged: (bool value) {
//                   setState(() {
//                     _isPipe = value;
//                   });
//                 },
//               ),
//               if (_isPipe)
//                 TextFormField(
//                   controller: _pipeLengthController,
//                   decoration:
//                       InputDecoration(labelText: 'Pipe Length (meters)'),
//                   keyboardType: TextInputType.number,
//                   validator: (value) {
//                     if (_isPipe) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter the pipe length';
//                       }
//                       if (double.tryParse(value) == null) {
//                         return 'Please enter a valid number';
//                       }
//                     }
//                     return null;
//                   },
//                 ),
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
//                       'quantity': double.parse(_quantityController.text),
//                       'isPipe': _isPipe,
//                       'pipeLength': _isPipe
//                           ? double.parse(_pipeLengthController.text)
//                           : 0,
//                     };
//                     inventoryProvider.updateItem(
//                       widget.itemId,
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
//   final String itemId;

//   EditInventoryItemScreen({required this.itemId});

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
//     final item = inventoryProvider.items
//         .firstWhere((item) => item['id'] == widget.itemId);
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
//                       widget.itemId, // Use document ID instead of index
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
