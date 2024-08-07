



import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class InventoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isAdminOrManager = false;

  InventoryProvider() {
    fetchItems(); // Fetch items when the provider is created
  }

  List<Map<String, dynamic>> get items {
    print("Getting items, count: ${_items.length}");
    return _items;
  }

  bool get isLoading => _isLoading;

  Stream<QuerySnapshot> get inventoryStream {
    return _firestore.collection('inventory').snapshots();
  }

  Future<void> fetchItems({bool? isAdminOrManager}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      print("Fetching inventory items...");
      final snapshot = await _firestore.collection('inventory').get();
      _items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Use the passed isAdminOrManager if provided, otherwise use the stored value
      bool adminManagerStatus = isAdminOrManager ?? _isAdminOrManager;

      if (!adminManagerStatus) {
        _items = _items
            .where((item) =>
                !(item['isHidden'] == true || item['isDeadstock'] == true))
            .toList();
      }

      print("Fetched items, count: ${_items.length}");
    } catch (e) {
      print("Error fetching inventory items: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshItems({bool? isAdminOrManager}) async {
    await fetchItems(isAdminOrManager: isAdminOrManager);
  }

  void setAdminOrManagerStatus(bool status) {
    _isAdminOrManager = status;
    fetchItems(); // Refetch items when the status changes
  }
  
  List<Map<String, dynamic>> getItemsByCategory(String category,
      {bool isAdminOrManager = false}) {
    if (category == 'All') {
      return isAdminOrManager
          ? _items
          : _items
              .where((item) =>
                  !(item['isHidden'] == true || item['isDeadstock'] == true))
              .toList();
    }
    return _items
        .where((item) =>
            item['category'] == category &&
            (isAdminOrManager ||
                !(item['isHidden'] == true || item['isDeadstock'] == true)))
        .toList();
  }

  List<Map<String, dynamic>> getFilteredItems({
    String searchQuery = '',
    String category = 'All',
    String subcategory = 'All',
    String stockStatus = 'All',
    RangeValues quantityRange = const RangeValues(0, double.infinity),
    bool isAdminOrManager = false,
  }) {
    return _items.where((item) {
      bool matchesSearch = item['name']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      bool matchesCategory = category == 'All' || item['category'] == category;
      bool matchesSubcategory =
          subcategory == 'All' || item['subcategory'] == subcategory;
      bool matchesStockStatus = stockStatus == 'All' ||
          (stockStatus == 'Low Stock' &&
              item['quantity'] < item['threshold']) ||
          (stockStatus == 'In Stock' && item['quantity'] >= item['threshold']);
      bool matchesQuantityRange = item['quantity'] >= quantityRange.start &&
          item['quantity'] <= quantityRange.end;
      bool isVisible = isAdminOrManager ||
          !(item['isHidden'] == true || item['isDeadstock'] == true);

      return matchesSearch &&
          matchesCategory &&
          matchesSubcategory &&
          matchesStockStatus &&
          matchesQuantityRange &&
          isVisible;
    }).toList();
  }

  Future<void> addItem(Map<String, dynamic> item) async {
    try {
      if (item['isPipe'] == true) {
        item['quantity'] = (item['quantity'] as num).toDouble();
        item['pipeLength'] = (item['pipeLength'] as num?)?.toDouble() ?? 20.0;
        item['unit'] = 'pcs'; // Ensure unit is set to 'pcs' for pipes
      }
      item['isHidden'] = item['isHidden'] ?? false;
      item['isDeadstock'] = item['isDeadstock'] ?? false;
      DocumentReference docRef =
          await _firestore.collection('inventory').add(item);
      item['id'] = docRef.id;
      _items.add(item);
      notifyListeners();
      print("Item added successfully");
    } catch (e) {
      print("Error adding item: $e");
      rethrow;
    }
  }

  Future<void> updateItem(String id, Map<String, dynamic> item) async {
    try {
      if (item['isPipe'] == true) {
        item['quantity'] = (item['quantity'] as num).toDouble();
        item['pipeLength'] = (item['pipeLength'] as num?)?.toDouble() ?? 20.0;
        item['unit'] = 'pcs'; // Ensure unit is set to 'pcs' for pipes
      }
      await _firestore.collection('inventory').doc(id).update(item);
      int index = _items.indexWhere((existingItem) => existingItem['id'] == id);
      if (index != -1) {
        _items[index] = {..._items[index], ...item, 'id': id};
        notifyListeners();
      }
      print("Item updated successfully");
    } catch (e) {
      print("Error updating item: $e");
      rethrow;
    }
  }

  Future<void> updateInventoryQuantity(String itemId, double quantityChange,
      {String? unit}) async {
    try {
      DocumentReference docRef = _firestore.collection('inventory').doc(itemId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          double currentQuantity = (data['quantity'] as num).toDouble();
          bool isPipe = data['isPipe'] as bool? ?? false;
          double pipeLength = (data['pipeLength'] as num?)?.toDouble() ?? 1.0;

          double newQuantity;
          if (isPipe && unit == 'meters') {
            // Convert meters to pieces
            double piecesChange = quantityChange / pipeLength;
            newQuantity = currentQuantity - piecesChange;
          } else {
            newQuantity = currentQuantity - quantityChange;
          }

          // Ensure quantity doesn't go below zero
          newQuantity = math.max(0, newQuantity);

          transaction.update(docRef, {'quantity': newQuantity});

          // Update local state
          int index = _items.indexWhere((item) => item['id'] == itemId);
          if (index != -1) {
            _items[index]['quantity'] = newQuantity;
          }
        } else {
          throw Exception('Inventory item not found');
        }
      });
      notifyListeners();
      print("Inventory quantity updated successfully for item $itemId");
    } catch (e) {
      print("Error updating inventory quantity: $e");
      rethrow;
    }
  }

  List<String> getCategories() {
    Set<String> categories =
        _items.map((item) => item['category'] as String).toSet();
    return categories.toList();
  }

  Future<void> deleteItem(String id) async {
    try {
      await _firestore.collection('inventory').doc(id).delete();
      _items.removeWhere((item) => item['id'] == id);
      notifyListeners();
      print("Item deleted successfully");
    } catch (e) {
      print("Error deleting item: $e");
      rethrow;
    }
  }

}
