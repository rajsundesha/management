// manager_inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/inventory_provider.dart';

class ManagerInventoryScreen extends StatefulWidget {
  @override
  _ManagerInventoryScreenState createState() => _ManagerInventoryScreenState();
}

class _ManagerInventoryScreenState extends State<ManagerInventoryScreen> {
  String _searchQuery = '';
  Map<String, dynamic> _filters = {
    'category': 'All',
    'subcategory': 'All',
    'stockStatus': 'All',
    'quantityRange': RangeValues(0, 1000),
    'hashtags': <String>[],
  };
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildActiveFiltersChips(),
          _buildSortingOptions(),
          Expanded(
            child: _buildInventoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search items...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    List<Widget> chips = [];

    _filters.forEach((key, value) {
      if (key == 'quantityRange') {
        RangeValues range = value as RangeValues;
        if (range.start > 0 || range.end < 1000) {
          chips.add(Chip(
            label:
                Text('Quantity: ${range.start.round()} - ${range.end.round()}'),
            onDeleted: () {
              setState(() {
                _filters[key] = RangeValues(0, 1000);
              });
            },
          ));
        }
      } else if (value != 'All' &&
          value != null &&
          (value is! List || value.isNotEmpty)) {
        chips.add(Chip(
          label: Text('$key: $value'),
          onDeleted: () {
            setState(() {
              if (value is List) {
                _filters[key] = <String>[];
              } else {
                _filters[key] = 'All';
              }
            });
          },
        ));
      }
    });

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: chips,
    );
  }

  Widget _buildSortingOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text('Sort by: '),
          DropdownButton<String>(
            value: _sortBy,
            items: ['name', 'category', 'quantity', 'threshold']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value[0].toUpperCase() + value.substring(1)),
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
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        return StreamBuilder<QuerySnapshot>(
          stream: inventoryProvider.inventoryStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> documents = snapshot.data!.docs;
            List<Map<String, dynamic>> items = documents
                .map((doc) =>
                    {...doc.data() as Map<String, dynamic>, 'id': doc.id})
                .toList();

            List<Map<String, dynamic>> filteredItems = _applyFilters(items);
            _sortItems(filteredItems);

            if (filteredItems.isEmpty) {
              return Center(child: Text('No items found'));
            }

            return ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildInventoryItem(item);
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    return items.where((item) {
      bool matchesSearch = item['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      bool matchesCategory = _filters['category'] == 'All' ||
          item['category'] == _filters['category'];
      bool matchesSubcategory = _filters['subcategory'] == 'All' ||
          item['subcategory'] == _filters['subcategory'];
      bool matchesStockStatus = _filters['stockStatus'] == 'All' ||
          (_filters['stockStatus'] == 'Low Stock' &&
              item['quantity'] < item['threshold']) ||
          (_filters['stockStatus'] == 'In Stock' &&
              item['quantity'] >= item['threshold']);
      bool matchesQuantityRange =
          item['quantity'] >= _filters['quantityRange'].start &&
              item['quantity'] <= _filters['quantityRange'].end;
      bool matchesHashtags = _filters['hashtags'].isEmpty ||
          _filters['hashtags']
              .any((tag) => item['hashtag'].toString().contains(tag));

      return matchesSearch &&
          matchesCategory &&
          matchesSubcategory &&
          matchesStockStatus &&
          matchesQuantityRange &&
          matchesHashtags;
    }).toList();
  }

  void _sortItems(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      var aValue = a[_sortBy];
      var bValue = b[_sortBy];
      int comparison;
      if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final threshold = item['threshold'] ?? 0;
    final isLowStock = quantity < threshold;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          item['name'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Quantity: $quantity ${item['unit']}'),
        trailing: isLowStock
            ? Chip(
                label: Text('Low Stock'),
                backgroundColor: Colors.red[100],
                labelStyle: TextStyle(color: Colors.red),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${item['category']}'),
                Text('Subcategory: ${item['subcategory']}'),
                Text('Threshold: $threshold'),
                Text('Hashtag: ${item['hashtag']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Filter Inventory'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterDropdown(
                        'Category', ['All', 'P', 'R'], _filters['category'],
                        (newValue) {
                      setState(() => _filters['category'] = newValue);
                    }),
                    _buildFilterDropdown('Subcategory', ['All', 'P1', 'R1'],
                        _filters['subcategory'], (newValue) {
                      setState(() => _filters['subcategory'] = newValue);
                    }),
                    _buildFilterDropdown(
                        'Stock Status',
                        ['All', 'In Stock', 'Low Stock'],
                        _filters['stockStatus'], (newValue) {
                      setState(() => _filters['stockStatus'] = newValue);
                    }),
                    _buildQuantityRangeSlider(setState),
                    _buildHashtagFilter(setState),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Clear Filters'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _filters = {
                        'category': 'All',
                        'subcategory': 'All',
                        'stockStatus': 'All',
                        'quantityRange': RangeValues(0, 1000),
                        'hashtags': <String>[],
                      };
                    });
                  },
                ),
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    this.setState(() {});
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(String label, List<String> options,
      String currentValue, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: currentValue,
      items: options.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildQuantityRangeSlider(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity Range'),
        RangeSlider(
          values: _filters['quantityRange'],
          min: 0,
          max: 1000,
          divisions: 100,
          labels: RangeLabels(
            _filters['quantityRange'].start.round().toString(),
            _filters['quantityRange'].end.round().toString(),
          ),
          onChanged: (RangeValues values) {
            setDialogState(() {
              _filters['quantityRange'] = values;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHashtagFilter(StateSetter setDialogState) {
    TextEditingController _hashtagController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hashtags'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hashtagController,
                decoration: InputDecoration(hintText: 'Enter hashtag'),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                if (_hashtagController.text.isNotEmpty) {
                  setDialogState(() {
                    _filters['hashtags'].add(_hashtagController.text);
                    _hashtagController.clear();
                  });
                }
              },
            ),
          ],
        ),
        Wrap(
          spacing: 8.0,
          children: _filters['hashtags'].map<Widget>((String hashtag) {
            return Chip(
              label: Text(hashtag),
              onDeleted: () {
                setDialogState(() {
                  _filters['hashtags'].remove(hashtag);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
