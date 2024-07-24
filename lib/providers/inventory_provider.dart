import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;

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

  Future<void> fetchItems() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      print("Fetching inventory items...");
      final snapshot = await _firestore.collection('inventory').get();
      _items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        print("Fetched item: $data");
        return data;
      }).toList();
      print("Fetched items, count: ${_items.length}");
    } catch (e) {
      print("Error fetching inventory items: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshItems() async {
    await fetchItems();
  }

  // Add back the getItemsByCategory method
  List<Map<String, dynamic>> getItemsByCategory(String category) {
    if (category == 'All') {
      return _items;
    }
    return _items.where((item) => item['category'] == category).toList();
  }

  List<Map<String, dynamic>> getFilteredItems({
    String searchQuery = '',
    String category = 'All',
    String subcategory = 'All',
    String stockStatus = 'All',
    RangeValues quantityRange = const RangeValues(0, double.infinity),
    List<String> hashtags = const [],
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
      bool matchesHashtags = hashtags.isEmpty ||
          hashtags.any((tag) => item['hashtag'].toString().contains(tag));

      return matchesSearch &&
          matchesCategory &&
          matchesSubcategory &&
          matchesStockStatus &&
          matchesQuantityRange &&
          matchesHashtags;
    }).toList();
  }

  Future<void> addItem(Map<String, dynamic> item) async {
    try {
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
//   Future<void> updateInventoryQuantity(
//       String itemId, int quantityChange) async {
//     try {
//       DocumentReference docRef = _firestore.collection('inventory').doc(itemId);
//       await _firestore.runTransaction((transaction) async {
//         DocumentSnapshot snapshot = await transaction.get(docRef);
//         if (snapshot.exists) {
//           int currentQuantity = snapshot.get('quantity') as int;
//           int newQuantity = currentQuantity + quantityChange;
//           transaction.update(docRef, {'quantity': newQuantity});

//           // Update local state
//           int index = _items.indexWhere((item) => item['id'] == itemId);
//           if (index != -1) {
//             _items[index]['quantity'] = newQuantity;
//           }
//         }
//       });
//       notifyListeners();
//       print("Inventory quantity updated successfully for item $itemId");
//     } catch (e) {
//       print("Error updating inventory quantity: $e");
//       rethrow;
//     }
//   }
// }
  Future<void> updateInventoryQuantity(
      String itemId, int quantityChange) async {
    try {
      DocumentReference docRef = _firestore.collection('inventory').doc(itemId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          int currentQuantity = snapshot.get('quantity') as int;
          int newQuantity = currentQuantity + quantityChange;
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
}
