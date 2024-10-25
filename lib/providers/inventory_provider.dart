import 'package:dhavla_road_project/screens/common/listener_manager.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:math' as math;
import 'dart:async'; // Import for StreamSubscription
// import 'listener_manager.dart'; // Import ListenerManager

class InventoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ListenerManager _listenerManager; // Inject ListenerManager
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _isAdminOrManager = false;
  StreamSubscription<QuerySnapshot>? _inventorySubscription;

  // Constructor to initialize ListenerManager and set up listeners
  InventoryProvider(this._listenerManager) {
    initInventoryListener(); // Initialize the listener when the provider is created
  }

  /// Getter for items
  List<Map<String, dynamic>> get items {
    print("Getting items, count: ${_items.length}");
    return _items;
  }

  /// Getter for loading state
  bool get isLoading => _isLoading;

  /// Initializes a real-time listener to the Firestore 'inventory' collection
  void initInventoryListener({bool isAdminOrManager = false}) {
    _isAdminOrManager = isAdminOrManager;

    // Cancel any existing subscription before initializing a new one
    _inventorySubscription?.cancel();

    _inventorySubscription =
        _firestore.collection('inventory').snapshots().listen(
      (snapshot) {
        _items = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        if (!_isAdminOrManager) {
          _items = _items
              .where((item) =>
                  !(item['isHidden'] == true || item['isDeadstock'] == true))
              .toList();
        }

        notifyListeners();
      },
      onError: (error) {
        print("InventoryProvider listener error: $error");
      },
    );

    // Add the listener to ListenerManager
    _listenerManager.addListener(_inventorySubscription!);
  }

  /// Cancels the Firestore listener
  Future<void> cancelListener() async {
    await _inventorySubscription?.cancel();
    _inventorySubscription = null;
    print("InventoryProvider listener canceled");
  }

  /// Refreshes items by reinitializing the listener
  Future<void> refreshItems({bool? isAdminOrManager}) async {
    await cancelListener();
    initInventoryListener(
        isAdminOrManager: isAdminOrManager ?? _isAdminOrManager);
  }

  /// Sets the admin or manager status and reinitializes the listener
  Future<void> setAdminOrManagerStatus(bool status) async {
    _isAdminOrManager = status;
    await cancelListener();
    initInventoryListener(isAdminOrManager: _isAdminOrManager);
  }

  /// Gets items by category, with visibility based on admin status
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

  /// Gets filtered items based on various criteria
  List<Map<String, dynamic>> getFilteredItems({
    String searchQuery = '',
    String category = 'All',
    String subcategory = 'All',
    String stockStatus = 'All',
    RangeValues quantityRange = const RangeValues(-1000, 1000),
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
              (item['quantity'] as num) < (item['threshold'] as num)) ||
          (stockStatus == 'In Stock' &&
              (item['quantity'] as num) >= (item['threshold'] as num));
      bool matchesQuantityRange =
          (item['quantity'] as num) >= quantityRange.start &&
              (item['quantity'] as num) <= quantityRange.end;
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

  /// Fetches items from Firestore (manual fetch)
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

      bool adminManagerStatus = isAdminOrManager ?? _isAdminOrManager;

      if (!adminManagerStatus) {
        _items = _items
            .where((item) =>
                !(item['isHidden'] == true || item['isDeadstock'] == true))
            .toList();
      }

      print("Fetched items, count: ${_items.length}");
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print("Permission denied while fetching items: ${e.message}");
        // Optionally, notify the user via UI
      } else {
        print("FirebaseException while fetching items: ${e.message}");
      }
      rethrow;
    } catch (e) {
      print("Error fetching inventory items: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new item to Firestore
  Future<void> addItem(Map<String, dynamic> item) async {
    try {
      if (item['isPipe'] == true) {
        item['quantity'] = (item['quantity'] as num).toDouble();
        item['pipeLength'] = (item['pipeLength'] as num?)?.toDouble() ?? 20.0;
        item['unit'] = 'pcs'; // Ensure unit is set to 'pcs' for pipes
      }
      item['isHidden'] = item['isHidden'] ?? false;
      item['isDeadstock'] = item['isDeadstock'] ?? false;
      item['imageUrl'] = item['imageUrl'] ?? null; // Handle imageUrl

      await _firestore.collection('inventory').add(item);
      // No need to manually update _items; the listener will handle it
      print("Item added successfully");
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print("Permission denied while adding item: ${e.message}");
        // Optionally, notify the user via UI
      } else {
        print("FirebaseException while adding item: ${e.message}");
      }
      rethrow;
    } catch (e) {
      print("Error adding item: $e");
      rethrow;
    }
  }

  /// Updates an existing item in Firestore
  Future<void> updateItem(String id, Map<String, dynamic> item) async {
    try {
      if (item['isPipe'] == true) {
        item['quantity'] = (item['quantity'] as num).toDouble();
        item['pipeLength'] = (item['pipeLength'] as num?)?.toDouble() ?? 20.0;
        item['unit'] = 'pcs'; // Ensure unit is set to 'pcs' for pipes
      }

      Map<String, dynamic> updateData = {...item};
      if (item.containsKey('imageUrl')) {
        updateData['imageUrl'] = item['imageUrl'];
      }

      await _firestore.collection('inventory').doc(id).update(updateData);
      // No need to manually update _items; the listener will handle it
      print("Item updated successfully");
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print("Permission denied while updating item: ${e.message}");
        // Optionally, notify the user via UI
      } else {
        print("FirebaseException while updating item: ${e.message}");
      }
      rethrow;
    } catch (e) {
      print("Error updating item: $e");
      rethrow;
    }
  }

  /// Updates the quantity of an inventory item
  Future<void> updateInventoryQuantity(String itemId, double quantityChange,
      {String? unit}) async {
    try {
      DocumentReference docRef = _firestore.collection('inventory').doc(itemId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          bool isPipe = data['isPipe'] as bool? ?? false;
          double pipeLength = (data['pipeLength'] as num?)?.toDouble() ?? 1.0;
          double currentQuantity = (data['quantity'] as num).toDouble();

          double adjustedQuantityChange;
          if (isPipe && unit == 'meters') {
            // Convert meters to pieces
            adjustedQuantityChange = quantityChange / pipeLength;
          } else {
            adjustedQuantityChange = quantityChange;
          }

          // Change this line
          double newQuantity = currentQuantity + adjustedQuantityChange;

          // Round to 2 decimal places to avoid floating point precision issues
          newQuantity = (newQuantity * 100).round() / 100;

          transaction.update(docRef, {'quantity': newQuantity});

          print(
              "Inventory quantity updated in Firestore for item $itemId. New quantity: $newQuantity");
        } else {
          throw Exception('Inventory item not found');
        }
      });
    } on FirebaseException catch (e) {
      print(
          "FirebaseException while updating inventory quantity: ${e.message}");
      rethrow;
    } catch (e) {
      print("Error updating inventory quantity: $e");
      rethrow;
    }
  }

  /// Retrieves the list of categories from the items
  List<String> getCategories() {
    Set<String> categories =
        _items.map((item) => item['category'] as String).toSet();
    return categories.toList();
  }

  /// Deletes an item from Firestore
  Future<void> deleteItem(String id) async {
    try {
      await _firestore.collection('inventory').doc(id).delete();
      // No need to manually update _items; the listener will handle it
      print("Item deleted successfully");
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print("Permission denied while deleting item: ${e.message}");
        // Optionally, notify the user via UI
      } else {
        print("FirebaseException while deleting item: ${e.message}");
      }
      rethrow;
    } catch (e) {
      print("Error deleting item: $e");
      rethrow;
    }
  }

  /// Cancels the listener when the provider is disposed
  @override
  void dispose() {
    _inventorySubscription?.cancel();
    super.dispose();
    print("InventoryProvider disposed and listener canceled");
  }
}
