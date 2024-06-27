// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class AddInventoryItemScreen extends StatefulWidget {
//   @override
//   _AddInventoryItemScreenState createState() => _AddInventoryItemScreenState();
// }

// class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
//   final _formKey = GlobalKey<FormState>();
//   TextEditingController _nameController = TextEditingController();
//   TextEditingController _categoryController = TextEditingController();
//   TextEditingController _unitController = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Add Inventory Item'),
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
//                     inventoryProvider.addItem({
//                       'name': _nameController.text,
//                       'category': _categoryController.text,
//                       'unit': _unitController.text,
//                     });
//                     Navigator.pop(context);
//                   }
//                 },
//                 child: Text('Add Item'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
