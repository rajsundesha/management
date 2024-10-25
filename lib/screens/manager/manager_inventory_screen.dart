import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

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

class ManagerInventoryScreen extends StatefulWidget {
  @override
  _ManagerInventoryScreenState createState() => _ManagerInventoryScreenState();
}

class _ManagerInventoryScreenState extends State<ManagerInventoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  bool _showOutOfStock = false;
  bool _showHiddenItems = false;
  bool _showDeadstock = false;
  bool _showImagesInTiles = true;
  RangeValues _quantityRange = RangeValues(-1000, 1000);
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);
      inventoryProvider.initInventoryListener(isAdminOrManager: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Overview'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: InventorySearch());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFilterSection(),
              SizedBox(height: 10),
              _buildInventoryList(),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
    );
  }

  Widget _buildFilterSection() {
    return ExpansionTile(
      title: Text('Filters'),
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              SizedBox(height: 8),
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
              SizedBox(height: 8),
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
              SizedBox(height: 8),
              SwitchListTile(
                title: Text('Show Out of Stock'),
                value: _showOutOfStock,
                onChanged: (bool value) {
                  setState(() {
                    _showOutOfStock = value;
                  });
                },
              ),
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
              SwitchListTile(
                title: Text('Show Images in Tiles'),
                value: _showImagesInTiles,
                onChanged: (bool value) {
                  setState(() {
                    _showImagesInTiles = value;
                  });
                },
              ),
              SizedBox(height: 8),
              Text('Quantity Range'),
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
              Row(
                children: [
                  Text('Sort by: '),
                  DropdownButton<String>(
                    value: _sortBy,
                    items: ['name', 'category', 'quantity', 'threshold']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child:
                            Text(value[0].toUpperCase() + value.substring(1)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _sortBy = newValue!;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
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
          bool hiddenMatch = _showHiddenItems ? true : !item.isHidden;
          bool deadstockMatch = _showDeadstock ? true : !item.isDeadstock;

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

        filteredItems.sort((a, b) {
          dynamic aValue = a.toMap()[_sortBy];
          dynamic bValue = b.toMap()[_sortBy];
          int comparison;
          if (aValue is num && bValue is num) {
            comparison = aValue.compareTo(bValue);
          } else {
            comparison = aValue.toString().compareTo(bValue.toString());
          }
          return _sortAscending ? comparison : -comparison;
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildInventoryItemTile(item, inventoryProvider);
          },
        );
      },
    );
  }

  Widget _buildInventoryItemTile(
      InventoryItem item, InventoryProvider inventoryProvider) {
    return Card(
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
        leading: _showImagesInTiles && item.imageUrl != null
            ? Image.network(
                item.imageUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.broken_image);
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
            if (item.isHidden)
              Text('Hidden', style: TextStyle(color: Colors.red)),
            if (item.isDeadstock)
              Text('Deadstock', style: TextStyle(color: Colors.red)),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryItemDetailsPage(item: item),
            ),
          );
        },
      ),
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

class InventoryItemDetailsPage extends StatelessWidget {
  final InventoryItem item;

  InventoryItemDetailsPage({required this.item});

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
              Image.network(
                item.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text('No Image Available'));
                },
              ),
            SizedBox(height: 20),
            Text(
              'Category: ${item.category}',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Subcategory: ${item.subcategory}',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Quantity: ${item.quantity} ${item.unit}',
              style: TextStyle(fontSize: 18),
            ),
            if (item.isPipe) Text('Pipe Length: ${item.pipeLength} meters'),
            if (item.dimensionsString != 'N/A')
              Text('Dimensions: ${item.dimensionsString}'),
            SizedBox(height: 10),
            if (item.isDeadstock)
              Text(
                'Deadstock',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            if (item.isHidden)
              Text(
                'Hidden',
                style: TextStyle(fontSize: 18, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}

