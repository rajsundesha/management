import 'package:flutter/material.dart';

class InventoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  void fetchItems() {
    // Simulating network fetch with a delay
    Future.delayed(Duration(seconds: 1), () {
      _items = [
        {'name': 'Item 1', 'category': 'Category 1'},
        {'name': 'Item 2', 'category': 'Category 1'},
        {'name': 'Item 3', 'category': 'Category 2'},
        {'name': 'Item 4', 'category': 'Category 2'},
        {'name': 'Item 5', 'category': 'Category 3'},
      ];
      notifyListeners();
    });
  }

  List<Map<String, dynamic>> getItemsByCategory(String category) {
    if (category == 'All') {
      return _items;
    }
    return _items.where((item) => item['category'] == category).toList();
  }
}
