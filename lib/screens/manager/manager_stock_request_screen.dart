import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';

class ManagerStockRequestScreen extends StatefulWidget {
  @override
  _ManagerStockRequestScreenState createState() =>
      _ManagerStockRequestScreenState();
}

class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
  Map<String, Map<String, dynamic>> _selectedItems = {};
  String _searchQuery = '';
  String _selectedCategory = 'All';
  TextEditingController _noteController = TextEditingController();

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
        title: Text('Create Stock Request'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(child: _buildInventoryList()),
          _buildSelectedItemsList(),
          _buildNoteField(),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search Items',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        List<String> categories = ['All', ...inventoryProvider.getCategories()];
        return DropdownButton<String>(
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
            });
          },
        );
      },
    );
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        List<Map<String, dynamic>> filteredItems = inventoryProvider.items
            .where((item) =>
                (_selectedCategory == 'All' ||
                    item['category'] == _selectedCategory) &&
                item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        return ListView.builder(
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return ListTile(
              title: Text(item['name']),
              subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
              trailing: _buildQuantityControls(item),
            );
          },
        );
      },
    );
  }

  Widget _buildQuantityControls(Map<String, dynamic> item) {
    String itemId = item['id'];
    int quantity = _selectedItems[itemId]?['quantity'] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed:
              quantity > 0 ? () => _updateQuantity(item, quantity - 1) : null,
        ),
        Text('$quantity'),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () => _updateQuantity(item, quantity + 1),
        ),
      ],
    );
  }

  void _updateQuantity(Map<String, dynamic> item, int newQuantity) {
    setState(() {
      String itemId = item['id'];
      if (newQuantity > 0) {
        _selectedItems[itemId] = {
          'id': itemId,
          'name': item['name'],
          'quantity': newQuantity,
          'unit': item['unit'],
        };
      } else {
        _selectedItems.remove(itemId);
      }
    });
  }

  Widget _buildSelectedItemsList() {
    return Container(
      height: 100,
      child: ListView.builder(
        itemCount: _selectedItems.length,
        itemBuilder: (context, index) {
          String itemId = _selectedItems.keys.elementAt(index);
          Map<String, dynamic> item = _selectedItems[itemId]!;
          return ListTile(
            title:
                Text('${item['name']} x ${item['quantity']} ${item['unit']}'),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _updateQuantity(item, 0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoteField() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _noteController,
        decoration: InputDecoration(
          labelText: 'Note',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      child: Text('Submit Stock Request'),
      onPressed: _submitStockRequest,
    );
  }

  void _submitStockRequest() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    List<Map<String, dynamic>> items = _selectedItems.values.toList();

    try {
      await requestProvider.addStockRequest(
        items: items,
        note: _noteController.text,
        createdBy: authProvider.currentUserEmail!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock request submitted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit stock request: $e')),
      );
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class ManagerStockRequestScreen extends StatefulWidget {
//   @override
//   _ManagerStockRequestScreenState createState() =>
//       _ManagerStockRequestScreenState();
// }

// class _ManagerStockRequestScreenState extends State<ManagerStockRequestScreen> {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';
//   String _selectedCategory = 'All';
//   TextEditingController _noteController = TextEditingController();

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
//         title: Text('Create Stock Request'),
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           _buildCategoryFilter(),
//           Expanded(child: _buildInventoryList()),
//           _buildSelectedItemsList(),
//           _buildNoteField(),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         decoration: InputDecoration(
//           labelText: 'Search Items',
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(Icons.search),
//         ),
//         onChanged: (value) {
//           setState(() {
//             _searchQuery = value;
//           });
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryFilter() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<String> categories = ['All', ...inventoryProvider.getCategories()];
//         return DropdownButton<String>(
//           value: _selectedCategory,
//           items: categories.map((String category) {
//             return DropdownMenuItem<String>(
//               value: category,
//               child: Text(category),
//             );
//           }).toList(),
//           onChanged: (String? newValue) {
//             setState(() {
//               _selectedCategory = newValue!;
//             });
//           },
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             final item = filteredItems[index];
//             return ListTile(
//               title: Text(item['name']),
//               subtitle: Text('Available: ${item['quantity']} ${item['unit']}'),
//               trailing: _buildQuantityControls(item),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['name']] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['name'], quantity - 1)
//               : null,
//         ),
//         Text('$quantity'),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () => _updateQuantity(item['name'], quantity + 1),
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(String itemName, int newQuantity) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemName] = newQuantity;
//       } else {
//         _selectedItems.remove(itemName);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 100,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return ListTile(
//             title: Text('$itemName x $quantity'),
//             trailing: IconButton(
//               icon: Icon(Icons.delete),
//               onPressed: () => _updateQuantity(itemName, 0),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildNoteField() {
//     return Padding(
//       padding: EdgeInsets.all(8.0),
//       child: TextField(
//         controller: _noteController,
//         decoration: InputDecoration(
//           labelText: 'Note',
//           border: OutlineInputBorder(),
//         ),
//         maxLines: 3,
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return ElevatedButton(
//       child: Text('Submit Stock Request'),
//       onPressed: _submitStockRequest,
//     );
//   }

//   void _submitStockRequest() async {
//     if (_selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please select at least one item')),
//       );
//       return;
//     }

//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     List<Map<String, dynamic>> items = _selectedItems.entries
//         .map((entry) => {
//               'name': entry.key,
//               'quantity': entry.value,
//             })
//         .toList();

//     try {
//       await requestProvider.addStockRequest(
//         items: items,
//         note: _noteController.text,
//         createdBy: authProvider.currentUserEmail!,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request submitted successfully')),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to submit stock request: $e')),
//       );
//     }
//   }
// }
