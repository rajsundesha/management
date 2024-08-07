import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String unit;
  final double quantity;
  final int threshold;
  final bool isPipe;
  final double pipeLength;
  final double? length;
  final double? width;
  final double? height;
  final bool isHidden;
  final bool isDeadstock;

  InventoryItem({
    required this.id,
    required this.name,
    this.category = 'Uncategorized',
    this.subcategory = 'N/A',
    this.unit = 'N/A',
    this.quantity = 0,
    this.threshold = 0,
    this.isPipe = false,
    this.pipeLength = 0,
    this.length,
    this.width,
    this.height,
    this.isHidden = false,
    this.isDeadstock = false,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Item',
      category: map['category'] as String? ?? 'Uncategorized',
      subcategory: map['subcategory'] as String? ?? 'N/A',
      unit: map['unit'] as String? ?? 'N/A',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      threshold: map['threshold'] as int? ?? 0,
      isPipe: map['isPipe'] as bool? ?? false,
      pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
      length: (map['length'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      isHidden: map['isHidden'] as bool? ?? false,
      isDeadstock: map['isDeadstock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'subcategory': subcategory,
      'unit': unit,
      'quantity': quantity,
      'threshold': threshold,
      'isPipe': isPipe,
      'pipeLength': pipeLength,
      'length': length,
      'width': width,
      'height': height,
      'isHidden': isHidden,
      'isDeadstock': isDeadstock,
    };
  }

  double get totalLength => isPipe ? quantity * pipeLength : quantity;
  String get dimensionsString {
    if (length != null && width != null && height != null) {
      return 'L: $length, W: $width, H: $height';
    } else {
      return 'N/A';
    }
  }
}

class ManageInventoryScreen extends StatefulWidget {
  @override
  _ManageInventoryScreenState createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  bool _showOutOfStock = false;
  bool _showHiddenItems = false;
  bool _showDeadstock = false;
  RangeValues _quantityRange = RangeValues(0, 1000);
  List<String> _selectedItems = [];
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      final bool isAdminOrManager =
          authProvider.role == 'Admin' || authProvider.role == 'Manager';
      inventoryProvider.fetchItems(isAdminOrManager: isAdminOrManager);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdminOrManager =
        authProvider.role == 'Admin' || authProvider.role == 'Manager';
    print(
        "User role: ${authProvider.role}, isAdminOrManager: $isAdminOrManager");
    // ... rest of the build method

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: InventorySearch());
            },
          ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedItems.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(isAdminOrManager),
          Expanded(
            child: _buildInventoryList(isAdminOrManager),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(context),
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBar() : null,
    );
  }

  Widget _buildFilterSection(bool isAdminOrManager) {
    return ExpansionTile(
      title: Text('Filters'),
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              Consumer<InventoryProvider>(
                builder: (context, provider, child) {
                  Set<String> categories = {'All', ...provider.getCategories()};
                  return DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
                        _selectedSubcategory = 'All';
                      });
                    },
                    hint: Text('Select Category'),
                  );
                },
              ),
              Consumer<InventoryProvider>(
                builder: (context, provider, child) {
                  Set<String> subcategories = {
                    'All',
                    ...provider.items
                        .where((item) =>
                            _selectedCategory == 'All' ||
                            item['category'] == _selectedCategory)
                        .map((item) => item['subcategory'] as String)
                        .toSet()
                  };
                  return DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSubcategory,
                    items: subcategories.map((String subcategory) {
                      return DropdownMenuItem<String>(
                        value: subcategory,
                        child: Text(subcategory),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedSubcategory = newValue!;
                      });
                    },
                    hint: Text('Select Subcategory'),
                  );
                },
              ),
              SwitchListTile(
                title: Text('Show Out of Stock'),
                value: _showOutOfStock,
                onChanged: (bool value) {
                  setState(() {
                    _showOutOfStock = value;
                  });
                },
              ),
              if (isAdminOrManager) ...[
                SwitchListTile(
                  title: Text('Show Hidden Items'),
                  value: _showHiddenItems,
                  onChanged: (bool value) {
                    setState(() {
                      _showHiddenItems = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text('Show Deadstock'),
                  value: _showDeadstock,
                  onChanged: (bool value) {
                    setState(() {
                      _showDeadstock = value;
                    });
                  },
                ),
              ],
              Text('Quantity Range'),
              RangeSlider(
                values: _quantityRange,
                min: 0,
                max: 1000,
                divisions: 100,
                labels: RangeLabels(
                  _quantityRange.start.round().toString(),
                  _quantityRange.end.round().toString(),
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    _quantityRange = values;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryList(bool isAdminOrManager) {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        List<InventoryItem> filteredItems = inventoryProvider.items
            .map((item) => InventoryItem.fromMap(item))
            .where((item) {
          bool categoryMatch =
              _selectedCategory == 'All' || item.category == _selectedCategory;
          bool subcategoryMatch = _selectedSubcategory == 'All' ||
              item.subcategory == _selectedSubcategory;
          bool searchMatch =
              item.name.toLowerCase().contains(_searchQuery.toLowerCase());
          bool quantityMatch = item.quantity >= _quantityRange.start &&
              item.quantity <= _quantityRange.end;
          bool outOfStockMatch = _showOutOfStock ? true : item.quantity > 0;
          bool hiddenMatch = isAdminOrManager
              ? (_showHiddenItems ? true : !item.isHidden)
              : !item.isHidden;
          bool deadstockMatch = isAdminOrManager
              ? (_showDeadstock ? true : !item.isDeadstock)
              : !item.isDeadstock;

          return categoryMatch &&
              subcategoryMatch &&
              searchMatch &&
              quantityMatch &&
              outOfStockMatch &&
              hiddenMatch &&
              deadstockMatch;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(child: Text('No items match the current filters.'));
        }

        return ListView.builder(
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildInventoryItemTile(
                item, inventoryProvider, isAdminOrManager);
          },
        );
      },
    );
  }

  Widget _buildInventoryItemTile(InventoryItem item,
      InventoryProvider inventoryProvider, bool isAdminOrManager) {
    final isSelected = _selectedItems.contains(item.id);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm"),
              content: Text("Are you sure you want to delete this item?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("CANCEL"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("DELETE"),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        inventoryProvider.deleteItem(item.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("${item.name} deleted")));
      },
      child: Card(
        color: item.isHidden
            ? Colors.grey[200]
            : item.isDeadstock
                ? Colors.red[100]
                : item.quantity <= item.threshold
                    ? Colors.orange[100]
                    : null,
        child: ListTile(
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedItems.add(item.id);
                      } else {
                        _selectedItems.remove(item.id);
                      }
                    });
                  },
                )
              : CircleAvatar(
                  child: Text(item.name[0]),
                  backgroundColor: item.quantity <= item.threshold
                      ? Colors.orange
                      : Colors.blue,
                ),
          title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Category: ${item.category} - Subcategory: ${item.subcategory}'),
              Text('Quantity: ${item.quantity} ${item.unit}'),
              if (item.isPipe) Text('Pipe Length: ${item.pipeLength} meters'),
              if (item.dimensionsString != 'N/A')
                Text('Dimensions: ${item.dimensionsString}'),
              if (isAdminOrManager && item.isHidden)
                Text('Hidden', style: TextStyle(color: Colors.red)),
              if (isAdminOrManager && item.isDeadstock)
                Text('Deadstock', style: TextStyle(color: Colors.red)),
            ],
          ),
          trailing: isAdminOrManager
              ? PopupMenuButton<String>(
                  onSelected: (String result) {
                    switch (result) {
                      case 'edit':
                        _editItem(context, item.id, item.toMap());
                        break;
                      case 'toggle_visibility':
                        inventoryProvider.updateItem(item.id,
                            {...item.toMap(), 'isHidden': !item.isHidden});
                        break;
                      case 'toggle_deadstock':
                        inventoryProvider.updateItem(item.id, {
                          ...item.toMap(),
                          'isDeadstock': !item.isDeadstock
                        });
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_visibility',
                      child: Text(item.isHidden ? 'Unhide' : 'Hide'),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_deadstock',
                      child: Text(item.isDeadstock
                          ? 'Remove from Deadstock'
                          : 'Mark as Deadstock'),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_selectedItems.length} items selected'),
            ElevatedButton(
              onPressed: _selectedItems.isNotEmpty
                  ? () => _showBulkDeleteConfirmation(context)
                  : null,
              child: Text('Delete Selected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EditItemBottomSheet(),
        ),
      ),
    );
  }

  void _editItem(BuildContext context, String id, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EditItemBottomSheet(
            id: id,
            item: item,
          ),
        ),
      ),
    );
  }

  void _showBulkDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Selected Items'),
          content: Text(
              'Are you sure you want to delete ${_selectedItems.length} items?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                final inventoryProvider =
                    Provider.of<InventoryProvider>(context, listen: false);
                for (String id in _selectedItems) {
                  inventoryProvider.deleteItem(id);
                }
                setState(() {
                  _selectedItems.clear();
                  _isSelectionMode = false;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Selected items deleted")),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class InventorySearch extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestionsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsList(context);
  }

  Widget _buildSuggestionsList(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final suggestions = inventoryProvider.items
        .map((item) => InventoryItem.fromMap(item))
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(item.name[0]),
            backgroundColor:
                item.quantity <= item.threshold ? Colors.orange : Colors.blue,
          ),
          title: Text(item.name),
          subtitle: Text(
              '${item.category} - ${item.subcategory}\nQuantity: ${item.quantity} ${item.unit}'),
          onTap: () {
            close(context, item.name);
          },
        );
      },
    );
  }
}

class EditItemBottomSheet extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? item;

  EditItemBottomSheet({this.id, this.item});

  @override
  _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
}

class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _subcategoryController;
  late TextEditingController _unitController;
  late TextEditingController _quantityController;
  late TextEditingController _thresholdController;
  late TextEditingController _pipeLengthController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  bool _isPipe = false;
  bool _isHidden = false;
  bool _isDeadstock = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _categoryController =
        TextEditingController(text: widget.item?['category'] ?? '');
    _subcategoryController =
        TextEditingController(text: widget.item?['subcategory'] ?? '');
    _unitController = TextEditingController(text: widget.item?['unit'] ?? '');
    _quantityController =
        TextEditingController(text: widget.item?['quantity']?.toString() ?? '');
    _thresholdController = TextEditingController(
        text: widget.item?['threshold']?.toString() ?? '');
    _pipeLengthController = TextEditingController(
        text: widget.item?['pipeLength']?.toString() ?? '');
    _lengthController =
        TextEditingController(text: widget.item?['length']?.toString() ?? '');
    _widthController =
        TextEditingController(text: widget.item?['width']?.toString() ?? '');
    _heightController =
        TextEditingController(text: widget.item?['height']?.toString() ?? '');
    _isPipe = widget.item?['isPipe'] ?? false;
    _isHidden = widget.item?['isHidden'] ?? false;
    _isDeadstock = widget.item?['isDeadstock'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _subcategoryController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _pipeLengthController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(labelText: 'Category'),
            ),
            TextFormField(
              controller: _subcategoryController,
              decoration: InputDecoration(labelText: 'Subcategory'),
            ),
            TextFormField(
              controller: _unitController,
              decoration: InputDecoration(labelText: 'Unit'),
            ),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _thresholdController,
              decoration: InputDecoration(labelText: 'Threshold'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a threshold';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid integer';
                }
                return null;
              },
            ),
            CheckboxListTile(
              title: Text('Is Pipe?'),
              value: _isPipe,
              onChanged: (bool? value) {
                setState(() {
                  _isPipe = value ?? false;
                });
              },
            ),
            if (_isPipe)
              TextFormField(
                controller: _pipeLengthController,
                decoration: InputDecoration(labelText: 'Pipe Length (meters)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a pipe length';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            TextFormField(
              controller: _lengthController,
              decoration: InputDecoration(labelText: 'Length'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _widthController,
              decoration: InputDecoration(labelText: 'Width'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _heightController,
              decoration: InputDecoration(labelText: 'Height'),
              keyboardType: TextInputType.number,
            ),
            CheckboxListTile(
              title: Text('Hidden'),
              value: _isHidden,
              onChanged: (bool? value) {
                setState(() {
                  _isHidden = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: Text('Deadstock'),
              value: _isDeadstock,
              onChanged: (bool? value) {
                setState(() {
                  _isDeadstock = value ?? false;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text(widget.id == null ? 'Add Item' : 'Update Item'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final inventoryProvider =
                      Provider.of<InventoryProvider>(context, listen: false);
                  final item = {
                    'id': widget.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': _nameController.text,
                    'category': _categoryController.text,
                    'subcategory': _subcategoryController.text,
                    'unit': _unitController.text,
                    'quantity': double.parse(_quantityController.text),
                    'threshold': int.parse(_thresholdController.text),
                    'isPipe': _isPipe,
                    'pipeLength':
                        _isPipe ? double.parse(_pipeLengthController.text) : 0,
                    'length': double.tryParse(_lengthController.text),
                    'width': double.tryParse(_widthController.text),
                    'height': double.tryParse(_heightController.text),
                    'isHidden': _isHidden,
                    'isDeadstock': _isDeadstock,
                  };
                  if (widget.id == null) {
                    inventoryProvider.addItem(item);
                  } else {
                    inventoryProvider.updateItem(widget.id!, item);
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';

// class InventoryItem {
//   final String id;
//   final String name;
//   final String category;
//   final String subcategory;
//   final String unit;
//   final double quantity;
//   final int threshold;
//   final bool isPipe;
//   final double pipeLength;
//   final double? length;
//   final double? width;
//   final double? height;

//   InventoryItem({
//     required this.id,
//     required this.name,
//     this.category = 'Uncategorized',
//     this.subcategory = 'N/A',
//     this.unit = 'N/A',
//     this.quantity = 0,
//     this.threshold = 0,
//     this.isPipe = false,
//     this.pipeLength = 0,
//     this.length,
//     this.width,
//     this.height,
//   });

//   factory InventoryItem.fromMap(Map<String, dynamic> map) {
//     return InventoryItem(
//       id: map['id'] ?? '',
//       name: map['name'] ?? 'Unnamed Item',
//       category: map['category'] as String? ?? 'Uncategorized',
//       subcategory: map['subcategory'] as String? ?? 'N/A',
//       unit: map['unit'] as String? ?? 'N/A',
//       quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
//       threshold: map['threshold'] as int? ?? 0,
//       isPipe: map['isPipe'] as bool? ?? false,
//       pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
//       length: (map['length'] as num?)?.toDouble(),
//       width: (map['width'] as num?)?.toDouble(),
//       height: (map['height'] as num?)?.toDouble(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'category': category,
//       'subcategory': subcategory,
//       'unit': unit,
//       'quantity': quantity,
//       'threshold': threshold,
//       'isPipe': isPipe,
//       'pipeLength': pipeLength,
//       'length': length,
//       'width': width,
//       'height': height,
//     };
//   }

//   double get totalLength => isPipe ? quantity * pipeLength : quantity;
//   String get dimensionsString {
//     if (length != null && width != null && height != null) {
//       return 'L: $length, W: $width, H: $height';
//     } else {
//       return 'N/A';
//     }
//   }
// }

// class ManageInventoryScreen extends StatefulWidget {
//   @override
//   _ManageInventoryScreenState createState() => _ManageInventoryScreenState();
// }

// class _ManageInventoryScreenState extends State<ManageInventoryScreen>
//     with SingleTickerProviderStateMixin {
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   List<String> _selectedItems = [];
//   bool _isSelectionMode = false;
//   late AnimationController _controller;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(
//       parent: _controller,
//       curve: Curves.easeInOut,
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: <Widget>[
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(
//             child: _buildFilterSection(),
//           ),
//           _buildInventoryList(),
//         ],
//       ),
//       floatingActionButton: _buildFloatingActionButton(),
//       bottomNavigationBar: _isSelectionMode ? _buildSelectionBar() : null,
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: Text('Inventory Manager'),
//         background: Image.network(
//           'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80',
//           fit: BoxFit.cover,
//         ),
//       ),
//       actions: [
//         IconButton(
//           icon: Icon(Icons.search),
//           onPressed: () {
//             showSearch(context: context, delegate: InventorySearch());
//           },
//         ),
//         IconButton(
//           icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
//           onPressed: () {
//             setState(() {
//               _isSelectionMode = !_isSelectionMode;
//               _selectedItems.clear();
//               if (_isSelectionMode) {
//                 _controller.forward();
//               } else {
//                 _controller.reverse();
//               }
//             });
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildFilterSection() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         Set<String> categories = {'All'};
//         for (var item in inventoryProvider.items) {
//           String category = item['category'] as String? ?? 'Uncategorized';
//           categories.add(category);
//         }
//         List<String> sortedCategories = categories.toList()..sort();

//         return Padding(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             children: [
//               TextField(
//                 decoration: InputDecoration(
//                   hintText: 'Search items...',
//                   prefixIcon: Icon(Icons.search),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   filled: true,
//                   fillColor: Colors.grey[200],
//                 ),
//                 onChanged: (value) {
//                   setState(() {
//                     _searchQuery = value;
//                   });
//                 },
//               ),
//               SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: _selectedCategory,
//                 items: sortedCategories
//                     .map((category) => DropdownMenuItem(
//                           value: category,
//                           child: Text(category),
//                         ))
//                     .toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedCategory = value!;
//                   });
//                 },
//                 decoration: InputDecoration(
//                   labelText: 'Category',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   filled: true,
//                   fillColor: Colors.grey[200],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == 'All' ||
//               (item['category'] as String).toLowerCase() ==
//                   _selectedCategory.toLowerCase();
//           bool searchMatch = _searchQuery.isEmpty ||
//               (item['name'] as String)
//                   .toLowerCase()
//                   .contains(_searchQuery.toLowerCase());
//           return categoryMatch && searchMatch;
//         }).toList();

//         if (filteredItems.isEmpty) {
//           return SliverFillRemaining(
//             child: Center(child: Text('No items available.')),
//           );
//         }

//         return SliverList(
//           delegate: SliverChildBuilderDelegate(
//             (context, index) {
//               final item = filteredItems[index];
//               return _buildInventoryItemTile(item, inventoryProvider);
//             },
//             childCount: filteredItems.length,
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryItemTile(
//       Map<String, dynamic> item, InventoryProvider inventoryProvider) {
//     final isSelected = _selectedItems.contains(item['id']);
//     final bool isPipe = item['isPipe'] ?? false;
//     final double quantity = (item['quantity'] as num).toDouble();
//     final double pipeLength = (item['pipeLength'] as num?)?.toDouble() ?? 0;

//     return Dismissible(
//       key: Key(item['id']),
//       background: Container(
//         color: Colors.red,
//         alignment: Alignment.centerRight,
//         padding: EdgeInsets.only(right: 20),
//         child: Icon(Icons.delete, color: Colors.white),
//       ),
//       direction: DismissDirection.endToStart,
//       confirmDismiss: (direction) async {
//         return await _showDeleteConfirmation(context, item, inventoryProvider);
//       },
//       child: AnimatedContainer(
//         duration: Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//         margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         decoration: BoxDecoration(
//           color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 4,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: ListTile(
//           contentPadding: EdgeInsets.all(16),
//           leading: _isSelectionMode
//               ? Checkbox(
//                   value: isSelected,
//                   onChanged: (bool? value) {
//                     setState(() {
//                       if (value == true) {
//                         _selectedItems.add(item['id']);
//                       } else {
//                         _selectedItems.remove(item['id']);
//                       }
//                     });
//                   },
//                 )
//               : CircleAvatar(
//                   backgroundColor: _getColorForCategory(item['category']),
//                   child: Text(
//                     item['name'].substring(0, 1).toUpperCase(),
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//           title: Text(
//             item['name'],
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           subtitle: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('${item['category']} - ${item['subcategory']}'),
//               if (isPipe)
//                 Text(
//                     'Quantity: ${quantity.toStringAsFixed(2)} pcs (${(quantity * pipeLength).toStringAsFixed(2)} m)'),
//               if (!isPipe)
//                 Text(
//                     'Quantity: ${quantity.toStringAsFixed(2)} ${item['unit']}'),
//               if (item['length'] != null &&
//                   item['width'] != null &&
//                   item['height'] != null)
//                 Text(
//                     'Dimensions: L: ${item['length']}, W: ${item['width']}, H: ${item['height']}'),
//               if (isPipe)
//                 Text('Pipe Length: ${pipeLength.toStringAsFixed(2)} meters'),
//             ],
//           ),
//           trailing: quantity <= (item['threshold'] ?? 0)
//               ? Tooltip(
//                   message: 'Low stock',
//                   child: Icon(Icons.warning, color: Colors.orange),
//                 )
//               : null,
//           onTap: _isSelectionMode
//               ? () {
//                   setState(() {
//                     if (isSelected) {
//                       _selectedItems.remove(item['id']);
//                     } else {
//                       _selectedItems.add(item['id']);
//                     }
//                   });
//                 }
//               : () => _editItem(context, item['id'], item),
//         ),
//       ),
//     );
//   }

//   Widget _buildFloatingActionButton() {
//     return ScaleTransition(
//       scale: _animation,
//       child: FloatingActionButton.extended(
//         onPressed: () => _addItem(context),
//         icon: Icon(Icons.add),
//         label: Text('Add Item'),
//       ),
//     );
//   }

//   Widget _buildSelectionBar() {
//     return BottomAppBar(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text('${_selectedItems.length} items selected'),
//             ElevatedButton(
//               onPressed: _selectedItems.isNotEmpty
//                   ? () => _showBulkDeleteConfirmation(context)
//                   : null,
//               child: Text('Delete Selected'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Color _getColorForCategory(String category) {
//     switch (category.toLowerCase()) {
//       case 'electronics':
//         return Colors.blue;
//       case 'furniture':
//         return Colors.green;
//       case 'clothing':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }

//   void _addItem(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
//       ),
//       builder: (context) => SingleChildScrollView(
//         child: Container(
//           padding: EdgeInsets.only(
//             bottom: MediaQuery.of(context).viewInsets.bottom,
//           ),
//           child: EditItemBottomSheet(),
//         ),
//       ),
//     );
//   }

//   void _editItem(BuildContext context, String id, Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
//       ),
//       builder: (context) => SingleChildScrollView(
//         child: Container(
//           padding: EdgeInsets.only(
//             bottom: MediaQuery.of(context).viewInsets.bottom,
//           ),
//           child: EditItemBottomSheet(
//             id: id,
//             item: item,
//           ),
//         ),
//       ),
//     );
//   }

//   Future<bool> _showDeleteConfirmation(BuildContext context,
//       Map<String, dynamic> item, InventoryProvider inventoryProvider) async {
//     return await showDialog(
//           context: context,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               title: Text('Delete Item'),
//               content: Text('Are you sure you want to delete ${item['name']}?'),
//               actions: <Widget>[
//                 TextButton(
//                   child: Text('Cancel'),
//                   onPressed: () {
//                     Navigator.of(context).pop(false);
//                   },
//                 ),
//                 TextButton(
//                   child: Text('Delete'),
//                   onPressed: () {
//                     inventoryProvider.deleteItem(item['id']);
//                     Navigator.of(context).pop(true);
//                   },
//                 ),
//               ],
//             );
//           },
//         ) ??
//         false;
//   }

//   void _showBulkDeleteConfirmation(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Delete Selected Items'),
//           content: Text(
//               'Are you sure you want to delete ${_selectedItems.length} items?'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: Text('Delete'),
//               onPressed: () {
//                 final inventoryProvider =
//                     Provider.of<InventoryProvider>(context, listen: false);
//                 for (String id in _selectedItems) {
//                   inventoryProvider.deleteItem(id);
//                 }
//                 setState(() {
//                   _selectedItems.clear();
//                   _isSelectionMode = false;
//                 });
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class InventorySearch extends SearchDelegate<String> {
//   @override
//   List<Widget> buildActions(BuildContext context) {
//     return [
//       IconButton(
//         icon: Icon(Icons.clear),
//         onPressed: () {
//           query = '';
//         },
//       ),
//     ];
//   }

//   @override
//   Widget buildLeading(BuildContext context) {
//     return IconButton(
//       icon: Icon(Icons.arrow_back),
//       onPressed: () {
//         close(context, '');
//       },
//     );
//   }

//   @override
//   Widget buildResults(BuildContext context) {
//     return _buildSuggestionsList(context);
//   }

//   @override
//   Widget buildSuggestions(BuildContext context) {
//     return _buildSuggestionsList(context);
//   }

//   Widget _buildSuggestionsList(BuildContext context) {
//     final inventoryProvider = Provider.of<InventoryProvider>(context);
//     final suggestions = inventoryProvider.items
//         .map((item) => InventoryItem.fromMap(item))
//         .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
//         .toList();

//     return ListView.builder(
//       itemCount: suggestions.length,
//       itemBuilder: (context, index) {
//         final item = suggestions[index];
//         return ListTile(
//           leading: CircleAvatar(
//             backgroundColor: _getColorForCategory(item.category),
//             child: Text(
//               item.name.substring(0, 1).toUpperCase(),
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//           title: Text(item.name),
//           subtitle: Text(
//               '${item.category} - ${item.subcategory}\nQuantity: ${item.quantity} ${item.unit}'),
//           onTap: () {
//             close(context, item.name);
//           },
//         );
//       },
//     );
//   }

//   Color _getColorForCategory(String category) {
//     switch (category.toLowerCase()) {
//       case 'electronics':
//         return Colors.blue;
//       case 'furniture':
//         return Colors.green;
//       case 'clothing':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }
// }

// class EditItemBottomSheet extends StatefulWidget {
//   final String? id;
//   final Map<String, dynamic>? item;

//   EditItemBottomSheet({this.id, this.item});

//   @override
//   _EditItemBottomSheetState createState() => _EditItemBottomSheetState();
// }

// class _EditItemBottomSheetState extends State<EditItemBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _categoryController;
//   late TextEditingController _subcategoryController;
//   late TextEditingController _unitController;
//   late TextEditingController _quantityController;
//   late TextEditingController _thresholdController;
//   late TextEditingController _pipeLengthController;
//   late TextEditingController _lengthController;
//   late TextEditingController _widthController;
//   late TextEditingController _heightController;
//   bool _isPipe = false;

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.item?['name'] ?? '');
//     _categoryController =
//         TextEditingController(text: widget.item?['category'] ?? '');
//     _subcategoryController =
//         TextEditingController(text: widget.item?['subcategory'] ?? '');
//     _unitController = TextEditingController(text: widget.item?['unit'] ?? '');
//     _quantityController =
//         TextEditingController(text: widget.item?['quantity']?.toString() ?? '');
//     _thresholdController = TextEditingController(
//         text: widget.item?['threshold']?.toString() ?? '');
//     _pipeLengthController = TextEditingController(
//         text: widget.item?['pipeLength']?.toString() ?? '');
//     _lengthController =
//         TextEditingController(text: widget.item?['length']?.toString() ?? '');
//     _widthController =
//         TextEditingController(text: widget.item?['width']?.toString() ?? '');
//     _heightController =
//         TextEditingController(text: widget.item?['height']?.toString() ?? '');
//     _isPipe = widget.item?['isPipe'] ?? false;
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _categoryController.dispose();
//     _subcategoryController.dispose();
//     _unitController.dispose();
//     _quantityController.dispose();
//     _thresholdController.dispose();
//     _pipeLengthController.dispose();
//     _lengthController.dispose();
//     _widthController.dispose();
//     _heightController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[
//             TextFormField(
//               controller: _nameController,
//               decoration: InputDecoration(labelText: 'Name'),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter a name';
//                 }
//                 return null;
//               },
//             ),
//             TextFormField(
//               controller: _categoryController,
//               decoration: InputDecoration(labelText: 'Category'),
//             ),
//             TextFormField(
//               controller: _subcategoryController,
//               decoration: InputDecoration(labelText: 'Subcategory'),
//             ),
//             TextFormField(
//               controller: _unitController,
//               decoration: InputDecoration(labelText: 'Unit'),
//             ),
//             TextFormField(
//               controller: _quantityController,
//               decoration: InputDecoration(labelText: 'Quantity'),
//               keyboardType: TextInputType.number,
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter a quantity';
//                 }
//                 if (double.tryParse(value) == null) {
//                   return 'Please enter a valid number';
//                 }
//                 return null;
//               },
//             ),
//             TextFormField(
//               controller: _thresholdController,
//               decoration: InputDecoration(labelText: 'Threshold'),
//               keyboardType: TextInputType.number,
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter a threshold';
//                 }
//                 if (int.tryParse(value) == null) {
//                   return 'Please enter a valid integer';
//                 }
//                 return null;
//               },
//             ),
//             CheckboxListTile(
//               title: Text('Is Pipe?'),
//               value: _isPipe,
//               onChanged: (bool? value) {
//                 setState(() {
//                   _isPipe = value ?? false;
//                 });
//               },
//             ),
//             if (_isPipe)
//               TextFormField(
//                 controller: _pipeLengthController,
//                 decoration: InputDecoration(labelText: 'Pipe Length (meters)'),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter a pipe length';
//                   }
//                   if (double.tryParse(value) == null) {
//                     return 'Please enter a valid number';
//                   }
//                   return null;
//                 },
//               ),
//             TextFormField(
//               controller: _lengthController,
//               decoration: InputDecoration(labelText: 'Length'),
//               keyboardType: TextInputType.number,
//             ),
//             TextFormField(
//               controller: _widthController,
//               decoration: InputDecoration(labelText: 'Width'),
//               keyboardType: TextInputType.number,
//             ),
//             TextFormField(
//               controller: _heightController,
//               decoration: InputDecoration(labelText: 'Height'),
//               keyboardType: TextInputType.number,
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               child: Text(widget.id == null ? 'Add Item' : 'Update Item'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   final inventoryProvider =
//                       Provider.of<InventoryProvider>(context, listen: false);
//                   final item = {
//                     'id': widget.id ??
//                         DateTime.now().millisecondsSinceEpoch.toString(),
//                     'name': _nameController.text,
//                     'category': _categoryController.text,
//                     'subcategory': _subcategoryController.text,
//                     'unit': _unitController.text,
//                     'quantity': double.parse(_quantityController.text),
//                     'threshold': int.parse(_thresholdController.text),
//                     'isPipe': _isPipe,
//                     'pipeLength':
//                         _isPipe ? double.parse(_pipeLengthController.text) : 0,
//                     'length': double.tryParse(_lengthController.text),
//                     'width': double.tryParse(_widthController.text),
//                     'height': double.tryParse(_heightController.text),
//                   };
//                   if (widget.id == null) {
//                     inventoryProvider.addItem(item);
//                   } else {
//                     inventoryProvider.updateItem(widget.id!, item);
//                   }
//                   Navigator.pop(context);
//                 }
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_item_bottom_sheet.dart';

// class InventoryItem {
//   final String id;
//   final String name;
//   final String category;
//   final String subcategory;
//   final String unit;
//   final double quantity;
//   final int threshold;
//   final bool isPipe;
//   final double pipeLength; // Length of one pipe piece in meters
//   final double? length;
//   final double? width;
//   final double? height;

//   InventoryItem({
//     required this.id,
//     required this.name,
//     this.category = 'Uncategorized',
//     this.subcategory = 'N/A',
//     this.unit = 'N/A',
//     this.quantity = 0,
//     this.threshold = 0,
//     this.isPipe = false,
//     this.pipeLength = 0,
//     this.length,
//     this.width,
//     this.height,
//   });

//   factory InventoryItem.fromMap(Map<String, dynamic> map) {
//     return InventoryItem(
//       id: map['id'] ?? '',
//       name: map['name'] ?? 'Unnamed Item',
//       category: map['category'] as String? ?? 'Uncategorized',
//       subcategory: map['subcategory'] as String? ?? 'N/A',
//       unit: map['unit'] as String? ?? 'N/A',
//       quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
//       threshold: map['threshold'] as int? ?? 0,
//       isPipe: map['isPipe'] as bool? ?? false,
//       pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
//       length: (map['length'] as num?)?.toDouble(),
//       width: (map['width'] as num?)?.toDouble(),
//       height: (map['height'] as num?)?.toDouble(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'category': category,
//       'subcategory': subcategory,
//       'unit': unit,
//       'quantity': quantity,
//       'threshold': threshold,
//       'isPipe': isPipe,
//       'pipeLength': pipeLength,
//       'length': length,
//       'width': width,
//       'height': height,
//     };
//   }

//   double get totalLength => isPipe ? quantity * pipeLength : quantity;
//   String get dimensionsString {
//     if (length != null && width != null && height != null) {
//       return 'L: $length, W: $width, H: $height';
//     } else {
//       return 'N/A';
//     }
//   }
// }

// // class InventoryItem {
// //   final String id;
// //   final String name;
// //   final String category;
// //   final String subcategory;
// //   final String unit;
// //   final double quantity;
// //   final int threshold;
// //   final bool isPipe;
// //   final double pipeLength; // Length of one pipe piece in meters
// //   final String? dimension;

// //   InventoryItem({
// //     required this.id,
// //     required this.name,
// //     this.category = 'Uncategorized',
// //     this.subcategory = 'N/A',
// //     this.unit = 'N/A',
// //     this.quantity = 0,
// //     this.threshold = 0,
// //     this.isPipe = false,
// //     this.pipeLength = 0,
// //     this.dimension,
// //   });

// //   factory InventoryItem.fromMap(Map<String, dynamic> map) {
// //     return InventoryItem(
// //       id: map['id'] ?? '',
// //       name: map['name'] ?? 'Unnamed Item',
// //       category: map['category'] as String? ?? 'Uncategorized',
// //       subcategory: map['subcategory'] as String? ?? 'N/A',
// //       unit: map['unit'] as String? ?? 'N/A',
// //       quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
// //       threshold: map['threshold'] as int? ?? 0,
// //       isPipe: map['isPipe'] as bool? ?? false,
// //       pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
// //       dimension: map['dimension'] as String?,
// //     );
// //   }

// //   Map<String, dynamic> toMap() {
// //     return {
// //       'id': id,
// //       'name': name,
// //       'category': category,
// //       'subcategory': subcategory,
// //       'unit': unit,
// //       'quantity': quantity,
// //       'threshold': threshold,
// //       'isPipe': isPipe,
// //       'pipeLength': pipeLength,
// //       'dimension': dimension,
// //     };
// //   }

// //   double get totalLength => isPipe ? quantity * pipeLength : quantity;
// // }

// class ManageInventoryScreen extends StatefulWidget {
//   @override
//   _ManageInventoryScreenState createState() => _ManageInventoryScreenState();
// }

// class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   List<String> _selectedItems = [];

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
//         title: Text('Manage Inventory'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.search),
//             onPressed: () {
//               showSearch(context: context, delegate: InventorySearch());
//             },
//           ),
//         ],
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
//             Consumer<InventoryProvider>(
//               builder: (context, inventoryProvider, child) {
//                 Set<String> categories = {'All'};
//                 for (var item in inventoryProvider.items) {
//                   String category =
//                       item['category'] as String? ?? 'Uncategorized';
//                   categories.add(category);
//                 }
//                 List<String> sortedCategories = categories.toList()..sort();

//                 return DropdownButton<String>(
//                   value: _selectedCategory,
//                   items: sortedCategories
//                       .map((category) => DropdownMenuItem(
//                             value: category,
//                             child: Text(category),
//                           ))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedCategory = value!;
//                     });
//                   },
//                   hint: Text('Filter by Category'),
//                 );
//               },
//             ),
//             Expanded(
//               child: Consumer<InventoryProvider>(
//                 builder: (context, inventoryProvider, child) {
//                   List<InventoryItem> filteredItems = inventoryProvider.items
//                       .map((item) => InventoryItem.fromMap(item))
//                       .where((item) {
//                     bool categoryMatch = _selectedCategory == 'All' ||
//                         item.category.toLowerCase() ==
//                             _selectedCategory.toLowerCase();
//                     bool searchMatch = _searchQuery.isEmpty ||
//                         item.name
//                             .toLowerCase()
//                             .contains(_searchQuery.toLowerCase());
//                     return categoryMatch && searchMatch;
//                   }).toList();

//                   if (filteredItems.isEmpty) {
//                     return Center(child: Text('No items available.'));
//                   }

//                   return ListView.builder(
//                     itemCount: filteredItems.length,
//                     itemBuilder: (context, index) {
//                       final item = filteredItems[index];
//                       final isSelected = _selectedItems.contains(item.id);

//                       // return Card(
//                       //   child: ListTile(
//                       //     leading: Checkbox(
//                       //       value: isSelected,
//                       //       onChanged: (bool? value) {
//                       //         setState(() {
//                       //           if (value == true) {
//                       //             _selectedItems.add(item.id);
//                       //           } else {
//                       //             _selectedItems.remove(item.id);
//                       //           }
//                       //         });
//                       //       },
//                       //     ),
//                       //     title: Text(item.name),
//                       //     subtitle: Text(
//                       //         'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Dimension: ${item.dimension ?? 'N/A'}'),
//                       //     trailing: Row(
//                       //       mainAxisSize: MainAxisSize.min,
//                       //       children: [
//                       //         if (item.quantity <= item.threshold)
//                       //           Icon(Icons.warning, color: Colors.red),
//                       //         IconButton(
//                       //           icon: Icon(Icons.edit, color: Colors.blue),
//                       //           onPressed: () {
//                       //             _editItem(context, item.id, item.toMap());
//                       //           },
//                       //         ),
//                       //         IconButton(
//                       //           icon: Icon(Icons.delete, color: Colors.red),
//                       //           onPressed: () {
//                       //             inventoryProvider.deleteItem(item.id);
//                       //           },
//                       //         ),
//                       //       ],
//                       //     ),
//                       //   ),
//                       // );
//                       return Card(
//                         child: ListTile(
//                           leading: Checkbox(
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   _selectedItems.add(item.id);
//                                 } else {
//                                   _selectedItems.remove(item.id);
//                                 }
//                               });
//                             },
//                           ),
//                           title: Text(item.name),
//                           subtitle: Text(
//                               'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Dimensions: ${item.dimensionsString}'),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               if (item.quantity <= item.threshold)
//                                 Icon(Icons.warning, color: Colors.red),
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editItem(context, item.id, item.toMap());
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   inventoryProvider.deleteItem(item.id);
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
//             if (_selectedItems.isNotEmpty)
//               Center(
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: Implement bulk delete functionality
//                     setState(() {
//                       _selectedItems.clear();
//                     });
//                   },
//                   child: Text('Delete Selected'),
//                 ),
//               ),
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

//   void _editItem(BuildContext context, String id, Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(
//         id: id,
//         item: item,
//       ),
//     );
//   }
// }

// class InventorySearch extends SearchDelegate<String> {
//   @override
//   List<Widget>? buildActions(BuildContext context) {
//     return [
//       IconButton(
//         icon: Icon(Icons.clear),
//         onPressed: () {
//           query = '';
//         },
//       ),
//     ];
//   }

//   @override
//   Widget? buildLeading(BuildContext context) {
//     return IconButton(
//       icon: Icon(Icons.arrow_back),
//       onPressed: () {
//         close(context, '');
//       },
//     );
//   }

//   @override
//   Widget buildResults(BuildContext context) {
//     return Container();
//   }

//   @override
//   Widget buildSuggestions(BuildContext context) {
//     final inventoryProvider = Provider.of<InventoryProvider>(context);
//     final suggestions = inventoryProvider.items
//         .map((item) => InventoryItem.fromMap(item))
//         .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
//         .toList();

//     return ListView.builder(
//       itemCount: suggestions.length,
//       itemBuilder: (context, index) {
//         final item = suggestions[index];
//         return ListTile(
//           title: Text(item.name),
//           subtitle: Text(
//               'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Dimensions: ${item.dimensionsString}'),
//           onTap: () {
//             close(context, item.name);
//             // TODO: Implement further action on item tap if needed
//           },
//         );
//       },
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/inventory_provider.dart';
// import 'edit_item_bottom_sheet.dart';

// class InventoryItem {
//   final String id;
//   final String name;
//   final String category;
//   final String subcategory;
//   final String unit;
//   final double quantity;
//   final String hashtag;
//   final int threshold;
//   final bool isPipe;
//   final double pipeLength; // Length of one pipe piece in meters
//   final String? dimension;

//   InventoryItem({
//     required this.id,
//     required this.name,
//     this.category = 'Uncategorized',
//     this.subcategory = 'N/A',
//     this.unit = 'N/A',
//     this.quantity = 0,
//     this.hashtag = 'N/A',
//     this.threshold = 0,
//     this.isPipe = false,
//     this.pipeLength = 0,
//       this.dimension,
//   });

//   factory InventoryItem.fromMap(Map<String, dynamic> map) {
//     return InventoryItem(
//       id: map['id'] ?? '',
//       name: map['name'] ?? 'Unnamed Item',
//       category: map['category'] as String? ?? 'Uncategorized',
//       subcategory: map['subcategory'] as String? ?? 'N/A',
//       unit: map['unit'] as String? ?? 'N/A',
//       quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
//       hashtag: map['hashtag'] as String? ?? 'N/A',
//       threshold: map['threshold'] as int? ?? 0,
//       isPipe: map['isPipe'] as bool? ?? false,
//       pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
//        dimension: map['dimension'] as String?,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'category': category,
//       'subcategory': subcategory,
//       'unit': unit,
//       'quantity': quantity,
//       'hashtag': hashtag,
//       'threshold': threshold,
//       'isPipe': isPipe,
//       'pipeLength': pipeLength,
//          'dimension': dimension,
//     };
//   }

//   double get totalLength => isPipe ? quantity * pipeLength : quantity;
// }


// class ManageInventoryScreen extends StatefulWidget {
//   @override
//   _ManageInventoryScreenState createState() => _ManageInventoryScreenState();
// }

// class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   List<String> _selectedItems = [];

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
//         title: Text('Manage Inventory'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.search),
//             onPressed: () {
//               showSearch(context: context, delegate: InventorySearch());
//             },
//           ),
//         ],
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
//             Consumer<InventoryProvider>(
//               builder: (context, inventoryProvider, child) {
//                 Set<String> categories = {'All'};
//                 for (var item in inventoryProvider.items) {
//                   String category =
//                       item['category'] as String? ?? 'Uncategorized';
//                   categories.add(category);
//                 }
//                 List<String> sortedCategories = categories.toList()..sort();

//                 return DropdownButton<String>(
//                   value: _selectedCategory,
//                   items: sortedCategories
//                       .map((category) => DropdownMenuItem(
//                             value: category,
//                             child: Text(category),
//                           ))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedCategory = value!;
//                     });
//                   },
//                   hint: Text('Filter by Category'),
//                 );
//               },
//             ),
//             Expanded(
//               child: Consumer<InventoryProvider>(
//                 builder: (context, inventoryProvider, child) {
//                   List<InventoryItem> filteredItems = inventoryProvider.items
//                       .map((item) => InventoryItem.fromMap(item))
//                       .where((item) {
//                     bool categoryMatch = _selectedCategory == 'All' ||
//                         item.category.toLowerCase() ==
//                             _selectedCategory.toLowerCase();
//                     bool searchMatch = _searchQuery.isEmpty ||
//                         item.name
//                             .toLowerCase()
//                             .contains(_searchQuery.toLowerCase());
//                     return categoryMatch && searchMatch;
//                   }).toList();

//                   if (filteredItems.isEmpty) {
//                     return Center(child: Text('No items available.'));
//                   }

//                   // return ListView.builder(
//                   //   itemCount: filteredItems.length,
//                   //   itemBuilder: (context, index) {
//                   //     final item = filteredItems[index];
//                   //     final isSelected = _selectedItems.contains(item.id);

//                   //     return Card(
//                   //       child: ListTile(
//                   //         leading: Checkbox(
//                   //           value: isSelected,
//                   //           onChanged: (bool? value) {
//                   //             setState(() {
//                   //               if (value == true) {
//                   //                 _selectedItems.add(item.id);
//                   //               } else {
//                   //                 _selectedItems.remove(item.id);
//                   //               }
//                   //             });
//                   //           },
//                   //         ),
//                   //         title: Text(item.name),
//                   //         subtitle: Text(
//                   //             'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Hashtag: ${item.hashtag}'),
//                   //         trailing: Row(
//                   //           mainAxisSize: MainAxisSize.min,
//                   //           children: [
//                   //             if (item.quantity <= item.threshold)
//                   //               Icon(Icons.warning, color: Colors.red),
//                   //             IconButton(
//                   //               icon: Icon(Icons.edit, color: Colors.blue),
//                   //               onPressed: () {
//                   //                 _editItem(context, item.id, item.toMap());
//                   //               },
//                   //             ),
//                   //             IconButton(
//                   //               icon: Icon(Icons.delete, color: Colors.red),
//                   //               onPressed: () {
//                   //                 inventoryProvider.deleteItem(item.id);
//                   //               },
//                   //             ),
//                   //           ],
//                   //         ),
//                   //       ),
//                   //     );
//                   //   },
//                   // );
//                   return ListView.builder(
//                     itemCount: filteredItems.length,
//                     itemBuilder: (context, index) {
//                       final item = filteredItems[index];
//                       final isSelected = _selectedItems.contains(item.id);

//                       return Card(
//                         child: ListTile(
//                           leading: Checkbox(
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   _selectedItems.add(item.id);
//                                 } else {
//                                   _selectedItems.remove(item.id);
//                                 }
//                               });
//                             },
//                           ),
//                           title: Text(item.name),
//                           subtitle: Text(
//                               'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Dimension: ${item.dimension ?? 'N/A'}'),
//                           trailing: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               if (item.quantity <= item.threshold)
//                                 Icon(Icons.warning, color: Colors.red),
//                               IconButton(
//                                 icon: Icon(Icons.edit, color: Colors.blue),
//                                 onPressed: () {
//                                   _editItem(context, item.id, item.toMap());
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.delete, color: Colors.red),
//                                 onPressed: () {
//                                   inventoryProvider.deleteItem(item.id);
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
//             if (_selectedItems.isNotEmpty)
//               Center(
//                 child: ElevatedButton(
//                   onPressed: () {
//                     // TODO: Implement bulk delete functionality
//                     setState(() {
//                       _selectedItems.clear();
//                     });
//                   },
//                   child: Text('Delete Selected'),
//                 ),
//               ),
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

//   void _editItem(BuildContext context, String id, Map<String, dynamic> item) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => EditItemBottomSheet(
//         id: id,
//         item: item,
//       ),
//     );
//   }
// }

// class InventorySearch extends SearchDelegate<String> {
//   @override
//   List<Widget>? buildActions(BuildContext context) {
//     return [
//       IconButton(
//         icon: Icon(Icons.clear),
//         onPressed: () {
//           query = '';
//         },
//       ),
//     ];
//   }

//   @override
//   Widget? buildLeading(BuildContext context) {
//     return IconButton(
//       icon: Icon(Icons.arrow_back),
//       onPressed: () {
//         close(context, '');
//       },
//     );
//   }

//   @override
//   Widget buildResults(BuildContext context) {
//     return Container();
//   }

//   @override
//   Widget buildSuggestions(BuildContext context) {
//     final inventoryProvider = Provider.of<InventoryProvider>(context);
//     final suggestions = inventoryProvider.items
//         .map((item) => InventoryItem.fromMap(item))
//         .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
//         .toList();

//     return ListView.builder(
//       itemCount: suggestions.length,
//       itemBuilder: (context, index) {
//         final item = suggestions[index];
//         return ListTile(
//           title: Text(item.name),
//           subtitle: Text(
//               'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Hashtag: ${item.hashtag}'),
//           onTap: () {
//             close(context, item.name);
//             // TODO: Implement further action on item tap if needed
//           },
//         );
//       },
//     );
//   }
// }
