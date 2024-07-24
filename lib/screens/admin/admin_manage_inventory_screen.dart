import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import 'edit_item_bottom_sheet.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String unit;
  final int quantity;
  final String hashtag;
  final int threshold;

  InventoryItem({
    required this.id,
    required this.name,
    this.category = 'Uncategorized',
    this.subcategory = 'N/A',
    this.unit = 'N/A',
    this.quantity = 0,
    this.hashtag = 'N/A',
    this.threshold = 0,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Item',
      category: map['category'] as String? ?? 'Uncategorized',
      subcategory: map['subcategory'] as String? ?? 'N/A',
      unit: map['unit'] as String? ?? 'N/A',
      quantity: map['quantity'] as int? ?? 0,
      hashtag: map['hashtag'] as String? ?? 'N/A',
      threshold: map['threshold'] as int? ?? 0,
    );
  }
// class InventoryItem {
//   final String id;
//   final String name;
//   final String category;
//   final String subcategory;
//   final String unit;
//   final int quantity;
//   final String hashtag;
//   final int threshold;

//   InventoryItem({
//     required this.id,
//     required this.name,
//     this.category = 'Uncategorized',
//     this.subcategory = 'N/A',
//     this.unit = 'N/A',
//     this.quantity = 0,
//     this.hashtag = 'N/A',
//     this.threshold = 0,
//   });

//   factory InventoryItem.fromMap(Map<String, dynamic> map) {
//     print("Creating InventoryItem from map: $map");
//     return InventoryItem(
//       id: map['id'] ?? '',
//       name: map['name'] ?? 'Unnamed Item',
//       category: map['category'] ?? 'Uncategorized',
//       subcategory: map['subcategory'] ?? 'N/A',
//       unit: map['unit'] ?? 'N/A',
//       quantity: map['quantity'] ?? 0,
//       hashtag: map['hashtag'] ?? 'N/A',
//       threshold: map['threshold'] ?? 0,
//     );
//   }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'subcategory': subcategory,
      'unit': unit,
      'quantity': quantity,
      'hashtag': hashtag,
      'threshold': threshold,
    };
  }
}

class ManageInventoryScreen extends StatefulWidget {
  @override
  _ManageInventoryScreenState createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _selectedItems = [];

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
        title: Text('Manage Inventory'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: InventorySearch());
            },
          ),
        ],
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
            Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                Set<String> categories = {'All'};
                for (var item in inventoryProvider.items) {
                  String category =
                      item['category'] as String? ?? 'Uncategorized';
                  categories.add(category);
                }
                List<String> sortedCategories = categories.toList()..sort();

                return DropdownButton<String>(
                  value: _selectedCategory,
                  items: sortedCategories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  hint: Text('Filter by Category'),
                );
              },
            ),
            Expanded(
              child: Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, child) {
                  List<InventoryItem> filteredItems = inventoryProvider.items
                      .map((item) => InventoryItem.fromMap(item))
                      .where((item) {
                    bool categoryMatch = _selectedCategory == 'All' ||
                        item.category.toLowerCase() ==
                            _selectedCategory.toLowerCase();
                    bool searchMatch = _searchQuery.isEmpty ||
                        item.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                    return categoryMatch && searchMatch;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(child: Text('No items available.'));
                  }

                  return ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = _selectedItems.contains(item.id);

                      return Card(
                        child: ListTile(
                          leading: Checkbox(
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
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                              'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Hashtag: ${item.hashtag}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.quantity <= item.threshold)
                                Icon(Icons.warning, color: Colors.red),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editItem(context, item.id, item.toMap());
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  inventoryProvider.deleteItem(item.id);
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
//     print(
//         "Building ManageInventoryScreen, selectedCategory: $_selectedCategory, searchQuery: $_searchQuery");
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
//                 List<String> categories = [
//                   'All',
//                   ...inventoryProvider.items
//                       .map((item) => item['category'] as String)
//                       .toSet()
//                       .toList()
//                 ];
//                 return DropdownButton<String>(
//                   value: _selectedCategory,
//                   items: categories
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
//                   print(
//                       "Building Consumer, total items: ${inventoryProvider.items.length}");
//                   List<InventoryItem> filteredItems = inventoryProvider.items
//                       .map((item) => InventoryItem.fromMap(item))
//                       .toList();
//                   print("Mapped items, count: ${filteredItems.length}");

//                   if (_selectedCategory != 'All') {
//                     filteredItems = filteredItems
//                         .where((item) =>
//                             item.category.toLowerCase() ==
//                             _selectedCategory.toLowerCase())
//                         .toList();
//                     print(
//                         "Filtered by category ($_selectedCategory), count: ${filteredItems.length}");
//                   }
//                   if (_searchQuery.isNotEmpty) {
//                     filteredItems = filteredItems
//                         .where((item) => item.name
//                             .toLowerCase()
//                             .contains(_searchQuery.toLowerCase()))
//                         .toList();
//                     print(
//                         "Filtered by search query, count: ${filteredItems.length}");
//                   }

//                   if (filteredItems.isEmpty) {
//                     return Center(child: Text('No items available.'));
//                   }

//                   return ListView.builder(
//                     itemCount: filteredItems.length,
//                     itemBuilder: (context, index) {
//                       final item = filteredItems[index];
//                       final isSelected = _selectedItems.contains(item.id);
//                       print("Building item: ${item.name}");

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
//                               'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Quantity: ${item.quantity} - Hashtag: ${item.hashtag}'),
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
            SizedBox(height: 16),
            if (_selectedItems.isNotEmpty)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement bulk delete functionality
                    setState(() {
                      _selectedItems.clear();
                    });
                  },
                  child: Text('Delete Selected'),
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

class InventorySearch extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) {
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
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
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
          title: Text(item.name),
          subtitle: Text(
              'Category: ${item.category} - Subcategory: ${item.subcategory} - Unit: ${item.unit} - Hashtag: ${item.hashtag}'),
          onTap: () {
            close(context, item.name);
            // TODO: Implement further action on item tap if needed
          },
        );
      },
    );
  }
}
