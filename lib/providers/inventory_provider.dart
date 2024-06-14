import 'package:flutter/material.dart';

class InventoryProvider with ChangeNotifier {
  List<String> _items = [];

  List<String> get items => _items;

  void fetchItems() {
    // Simulate fetching data from a database
    _items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];
    notifyListeners();
  }
}
