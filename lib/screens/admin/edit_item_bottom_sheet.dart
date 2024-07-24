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
  final _subcategoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _hashtagController = TextEditingController();
  final _thresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'] ?? '';
      _categoryController.text = widget.item!['category'] ?? '';
      _subcategoryController.text = widget.item!['subcategory'] ?? '';
      _unitController.text = widget.item!['unit'] ?? '';
      _quantityController.text = (widget.item!['quantity'] ?? 0).toString();
      _hashtagController.text = widget.item!['hashtag'] ?? '';
      _thresholdController.text = (widget.item!['threshold'] ?? 0).toString();
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
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
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
                  controller: _subcategoryController,
                  decoration: InputDecoration(labelText: 'Subcategory'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter subcategory';
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
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _hashtagController,
                  decoration: InputDecoration(labelText: 'Hashtag'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hashtag';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _thresholdController,
                  decoration: InputDecoration(labelText: 'Low Stock Threshold'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter threshold';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
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
                            'subcategory': _subcategoryController.text,
                            'unit': _unitController.text,
                            'quantity': int.parse(_quantityController.text),
                            'hashtag': _hashtagController.text,
                            'threshold': int.parse(_thresholdController.text),
                          };

                          if (widget.id == null) {
                            Provider.of<InventoryProvider>(context,
                                    listen: false)
                                .addItem(newItem);
                          } else {
                            newItem['id'] = widget.id!; // Ensure ID is included
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

