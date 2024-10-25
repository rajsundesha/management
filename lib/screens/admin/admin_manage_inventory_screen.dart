import 'dart:async';
import 'dart:io';
import 'package:dhavla_road_project/providers/auth_provider.dart';
import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:image_downloader/image_downloader.dart';
import 'package:flutter/services.dart';

// INVENTORY ITEM CLASS
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
  final double? price;
  final String? imageUrl;

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
    this.price,
    this.imageUrl,
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
      price: (map['price'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] as String?,
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
      'price': price,
      'imageUrl': imageUrl,
    };
  }

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
  bool _showImagesInTiles = true;
  RangeValues _quantityRange = RangeValues(-1000, 1000);
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
      inventoryProvider.initInventoryListener(
          isAdminOrManager: isAdminOrManager);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdminOrManager =
        authProvider.role == 'Admin' || authProvider.role == 'Manager';

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Manager'),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedItems.isNotEmpty
                      ? () => _showBulkDeleteConfirmation(context)
                      : null,
                ),
              ]
            : [
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFilterSection(isAdminOrManager),
                    _buildInventoryList(isAdminOrManager),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context),
        icon: Icon(Icons.add),
        label: Text('Add Item'),
        backgroundColor: Colors.teal,
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBar() : null,
    );
  }

  Widget _buildFilterSection(bool isAdminOrManager) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.filter_alt, color: Colors.teal),
            SizedBox(width: 8),
            Text('Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildSearchBar(),
                SizedBox(height: 10),
                _buildCategoryDropdown(),
                SizedBox(height: 10),
                _buildSubcategoryDropdown(),
                SizedBox(height: 10),
                _buildStockSwitches(isAdminOrManager),
                SizedBox(height: 10),
                _buildQuantitySlider(),
                SizedBox(height: 10),
                _buildShowImagesSwitch(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        labelText: 'Search',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildCategoryDropdown() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        Set<String> categories = {'All', ...provider.getCategories()};
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            labelText: 'Category',
          ),
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
        );
      },
    );
  }

  Widget _buildSubcategoryDropdown() {
    return Consumer<InventoryProvider>(
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
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            labelText: 'Subcategory',
          ),
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
        );
      },
    );
  }

  Widget _buildStockSwitches(bool isAdminOrManager) {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildQuantitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity Range', style: TextStyle(fontWeight: FontWeight.bold)),
        RangeSlider(
          values: _quantityRange,
          min: -1000,
          max: 1000,
          divisions: 2000,
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
    );
  }

  Widget _buildShowImagesSwitch() {
    return SwitchListTile(
      title: Text('Show Images in Tiles'),
      value: _showImagesInTiles,
      onChanged: (bool value) {
        setState(() {
          _showImagesInTiles = value;
        });
      },
    );
  }

  // Widget _buildInventoryList(bool isAdminOrManager) {
  //   return Consumer<InventoryProvider>(
  //     builder: (context, inventoryProvider, child) {
  //       List<InventoryItem> filteredItems = inventoryProvider.items
  //           .map((item) => InventoryItem.fromMap(item))
  //           .where((item) {
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
          bool outOfStockMatch = _showOutOfStock ? true : item.quantity != 0;
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
          return Center(
            child: Text(
              'No items match the current filters.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        //       return ListView.builder(
        //         itemCount: filteredItems.length,
        //         itemBuilder: (context, index) {
        //           final item = filteredItems[index];
        //           return _buildInventoryItemTile(
        //               item, inventoryProvider, isAdminOrManager);
        //         },
        //       );
        //     },
        //   );
        // }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.role == 'Admin';

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
      onDismissed: (direction) async {
        await _deleteItem(item.id, item.imageUrl); // Ensure item deletion
        inventoryProvider.deleteItem(item.id); // Remove from provider's list

        // Ensure the list is updated in the UI
        setState(() {
          _selectedItems.remove(item.id);
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("${item.name} deleted")));
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              : (_showImagesInTiles && item.imageUrl != null)
                  ? Image.network(
                      item.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error); // Fallback if image fails
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
              if (isAdmin && item.price != null)
                Text('Price: \$${item.price!.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green)),
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
                        inventoryProvider
                            .updateItem(item.id, {'isHidden': !item.isHidden});
                        break;
                      case 'toggle_deadstock':
                        inventoryProvider.updateItem(
                            item.id, {'isDeadstock': !item.isDeadstock});
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
          onTap: _isSelectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedItems.remove(item.id);
                    } else {
                      _selectedItems.add(item.id);
                    }
                  });
                }
              : () => _openItemDetails(context, item),
        ),
      ),
    );
  }

  Future<void> _deleteItem(String itemId, String? imageUrl) async {
    // Delete the image from Firebase Storage if it exists
    if (imageUrl != null) {
      try {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRef.delete();
        print('Image deleted successfully.');
      } catch (e) {
        print('Error deleting image: $e');
      }
    }
  }

  Widget _buildSelectionBar() {
    return BottomAppBar(
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_selectedItems.length} items selected',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
          child: EditItemBottomSheet(
            onCancel: () => Navigator.pop(context),
          ),
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
            onCancel: () {
              Navigator.pop(context);
              setState(() {}); // This ensures UI updates after editing
            },
          ),
        ),
      ),
    );
  }

  void _openItemDetails(BuildContext context, InventoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailsPage(item: item),
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

// New Page: Display enlarged image and item details
class ItemDetailsPage extends StatelessWidget {
  final InventoryItem item;

  ItemDetailsPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImagePage(imageUrl: item.imageUrl!),
                    ),
                  );
                },
                child: Hero(
                  tag: item.imageUrl!, // Hero animation tag
                  child: Image.network(
                    item.imageUrl!,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.broken_image,
                          size: 100,
                          color: Colors.grey,
                        ), // Fallback in case of error
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 300,
                width: double.infinity,
                color: Colors.grey[300],
                child: Icon(
                  Icons.image_not_supported,
                  size: 100,
                  color: Colors.grey,
                ), // Placeholder when no image available
              ),
            SizedBox(height: 20),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Category: ${item.category}',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              'Subcategory: ${item.subcategory}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Quantity: ${item.quantity} ${item.unit}',
              style: TextStyle(fontSize: 16),
            ),
            if (item.isPipe)
              Text(
                'Pipe Length: ${item.pipeLength} meters',
                style: TextStyle(fontSize: 16),
              ),
            if (item.dimensionsString != 'N/A')
              Text(
                'Dimensions: ${item.dimensionsString}',
                style: TextStyle(fontSize: 16),
              ),
            if (item.price != null)
              Text(
                'Price: \$${item.price!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Full-Screen Image Page
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  FullScreenImagePage({required this.imageUrl});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      // Attempt to download the image and save it to the gallery
      var imageId = await ImageDownloader.downloadImage(imageUrl);
      if (imageId == null) {
        throw Exception("Failed to download image.");
      }

      // Provide feedback that the image was successfully downloaded
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to device.'),
          duration: Duration(seconds: 2),
        ),
      );
    } on PlatformException catch (error) {
      print('Error downloading image: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download image.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () =>
                _downloadImage(context), // Call the download function
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageUrl, // Hero animation tag
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Icon(
                  Icons.broken_image,
                  size: 100,
                  color: Colors.grey,
                ), // Fallback in case of error
              );
            },
          ),
        ),
      ),
    );
  }
}

class EditItemBottomSheet extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? item;
  final VoidCallback? onCancel;

  EditItemBottomSheet({this.id, this.item, this.onCancel});

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
  late TextEditingController _priceController;
  bool _isPipe = false;
  bool _isHidden = false;
  bool _isDeadstock = false;
  File? _image;
  final picker = ImagePicker();
  String? _imageUrl;

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
    _priceController =
        TextEditingController(text: widget.item?['price']?.toString() ?? '');
    _isPipe = widget.item?['isPipe'] ?? false;
    _isHidden = widget.item?['isHidden'] ?? false;
    _isDeadstock = widget.item?['isDeadstock'] ?? false;
    _imageUrl = widget.item?['imageUrl'];
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
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        // Load the selected image
        final File selectedImage = File(pickedFile.path);

        // Read the image as bytes
        final imageBytes = selectedImage.readAsBytesSync();

        // Decode the image (this is necessary for compression)
        img.Image? originalImage = img.decodeImage(imageBytes);

        // Compress the image by resizing it (you can adjust the width/height as per your needs)
        if (originalImage != null) {
          // For example, resize to 50% of the original size
          img.Image compressedImage =
              img.copyResize(originalImage, width: originalImage.width ~/ 2);

          // Save the compressed image back to the file
          final compressedImageBytes = img.encodeJpg(compressedImage,
              quality: 55); // 85% quality to reduce size
          File compressedFile = File(pickedFile.path)
            ..writeAsBytesSync(compressedImageBytes);

          // Set the compressed image file to _image
          setState(() {
            _image = compressedFile;
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storage = FirebaseStorage.instance;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          storage.ref().child('inventory_images').child(fileName);

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});

      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Image uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  bool _isDeletingImage = false; // Track if deletion is in progress

  Future<void> _deleteImage() async {
    // If a deletion is already in progress, avoid further deletions
    if (_isDeletingImage) {
      print('Image deletion already in progress.');
      return;
    }

    if (_imageUrl != null) {
      try {
        _isDeletingImage =
            true; // Set the flag to indicate the deletion is in progress

        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(_imageUrl!);

        // Attempt to get the download URL to ensure the image exists before deleting
        await storageRef.getDownloadURL();

        // If the image exists, proceed with deletion
        await storageRef.delete();

        // Update UI and clear the image reference after deletion
        setState(() {
          _imageUrl = null;
          _image = null; // Clear any locally picked image if exists
        });

        // Also notify the inventoryProvider if you wish to update it
        final inventoryProvider =
            Provider.of<InventoryProvider>(context, listen: false);
        inventoryProvider.updateItem(
            widget.id!, {'imageUrl': null}); // Update item in provider

        print("Image deleted successfully");
      } catch (e) {
        if (e is FirebaseException && e.code == 'object-not-found') {
          // Handle case where image doesn't exist
          print('Error deleting image: Image not found in storage.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image does not exist in Firebase Storage")),
          );

          // Since the image is not found, reset image references and UI
          setState(() {
            _imageUrl = null;
            _image = null;
          });

          // Update the item in the provider to reflect the missing image
          final inventoryProvider =
              Provider.of<InventoryProvider>(context, listen: false);
          inventoryProvider.updateItem(widget.id!, {'imageUrl': null});
        } else if (e is FirebaseException && e.code == 'permission-denied') {
          // Handle Firebase Storage permission errors
          print('Error deleting image: Permission denied.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("You don't have permission to delete this image")),
          );
        } else {
          // Handle other errors
          print('Error deleting image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Failed to delete image. Please try again later.")),
          );
        }
      } finally {
        _isDeletingImage = false; // Reset the deletion flag in all cases
      }
    } else {
      // Handle case where there's no image to delete
      print("No image to delete");
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Photo Library'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.gallery); // Select image from gallery
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.camera); // Capture image with camera
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        _image != null
            ? Image.file(_image!, height: 100)
            : _imageUrl != null
                ? Column(
                    children: [
                      Image.network(
                        _imageUrl!,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            children: [
                              Icon(Icons.error, size: 100, color: Colors.red),
                              Text('Failed to load image'),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _deleteImage,
                        child: Text('Delete Image',
                            style: TextStyle(color: Colors.red)),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Container(
                    child: Text("No image available"),
                  ),
        ElevatedButton(
          onPressed:
              _showImageSourceOptions, // Show the options for gallery or camera
          child: Text('Select Image'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.role == 'Admin';

    return Container(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  decoration:
                      InputDecoration(labelText: 'Pipe Length (meters)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _widthController,
                decoration: InputDecoration(labelText: 'Width'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _heightController,
                decoration: InputDecoration(labelText: 'Height'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
              if (isAdmin)
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: 'Price (Optional)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                    }
                    return null;
                  },
                ),
              SizedBox(height: 16),
              _buildImageSection(),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    child: Text(widget.id == null ? 'Add Item' : 'Update Item'),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final inventoryProvider =
                            Provider.of<InventoryProvider>(context,
                                listen: false);

                        String? uploadedImageUrl;
                        if (_image != null) {
                          uploadedImageUrl = await _uploadImage(_image!);
                          _imageUrl = uploadedImageUrl;
                        }

                        final item = {
                          'name': _nameController.text,
                          'category': _categoryController.text,
                          'subcategory': _subcategoryController.text,
                          'unit': _unitController.text,
                          'quantity': double.parse(_quantityController.text),
                          'threshold': int.parse(_thresholdController.text),
                          'isPipe': _isPipe,
                          'pipeLength': _isPipe
                              ? double.parse(_pipeLengthController.text)
                              : 0,
                          'length': double.tryParse(_lengthController.text),
                          'width': double.tryParse(_widthController.text),
                          'height': double.tryParse(_heightController.text),
                          'isHidden': _isHidden,
                          'isDeadstock': _isDeadstock,
                          'price': _priceController.text.isNotEmpty
                              ? double.parse(_priceController.text)
                              : null,
                          'imageUrl': _imageUrl,
                        };

                        if (widget.id == null) {
                          await inventoryProvider.addItem(item);
                        } else {
                          await inventoryProvider.updateItem(widget.id!, item);
                        }

                        Navigator.pop(context); // Close after update
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
