import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  InventoryProvider() {
    fetchItems();
  }

  Future<void> fetchItems() async {
    QuerySnapshot snapshot = await _firestore.collection('inventory').get();
    _items = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'name': doc['name'],
              'category': doc['category'],
              'unit': doc['unit'],
            })
        .toList();
    notifyListeners();
  }

  Future<void> addItem(Map<String, dynamic> item) async {
    DocumentReference docRef =
        await _firestore.collection('inventory').add(item);
    item['id'] = docRef.id;
    _items.add(item);
    notifyListeners();
  }

  Future<void> updateItem(String id, Map<String, dynamic> item) async {
    await _firestore.collection('inventory').doc(id).update(item);
    int index = _items.indexWhere((item) => item['id'] == id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    await _firestore.collection('inventory').doc(id).delete();
    _items.removeWhere((item) => item['id'] == id);
    notifyListeners();
  }

  List<Map<String, dynamic>> getItemsByCategory(String category) {
    if (category == 'All') {
      return _items;
    }
    return _items.where((item) => item['category'] == category).toList();
  }

  int convertUnits(String fromUnit, String toUnit, int quantity) {
    if (fromUnit == toUnit) return quantity;

    if (fromUnit == 'ft' && toUnit == 'm') {
      return (quantity * 0.3048).round();
    } else if (fromUnit == 'm' && toUnit == 'ft') {
      return (quantity / 0.3048).round();
    } else {
      throw UnsupportedError(
          'Conversion from $fromUnit to $toUnit is not supported.');
    }
  }
}


// import 'package:flutter/material.dart';

// class InventoryProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _items = [];

//   List<Map<String, dynamic>> get items => _items;

//   void fetchItems() {
//     // Simulating network fetch with a delay
//     Future.delayed(Duration(seconds: 1), () {
//       _items = [
//         {'name': 'Item 1', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 2', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 3', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 4', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 5', 'category': 'Category 3', 'unit': 'pcs'},
//       ];
//       notifyListeners();
//     });
//   }

//   void addItem(Map<String, dynamic> item) {
//     _items.add(item);
//     notifyListeners();
//   }

//   void updateItem(int index, Map<String, dynamic> item) {
//     _items[index] = item;
//     notifyListeners();
//   }

//   void deleteItem(int index) {
//     _items.removeAt(index);
//     notifyListeners();
//   }

//   List<Map<String, dynamic>> getItemsByCategory(String category) {
//     if (category == 'All') {
//       return _items;
//     }
//     return _items.where((item) => item['category'] == category).toList();
//   }

//   int convertUnits(String fromUnit, String toUnit, int quantity) {
//     if (fromUnit == toUnit) return quantity;

//     if (fromUnit == 'ft' && toUnit == 'm') {
//       return (quantity * 0.3048).round();
//     } else if (fromUnit == 'm' && toUnit == 'ft') {
//       return (quantity / 0.3048).round();
//     } else {
//       throw UnsupportedError(
//           'Conversion from $fromUnit to $toUnit is not supported.');
//     }
//   }
// }


// import 'package:flutter/material.dart';

// class InventoryProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _items = [];

//   List<Map<String, dynamic>> get items => _items;

//   void fetchItems() {
//     // Simulating network fetch with a delay
//     Future.delayed(Duration(seconds: 1), () {
//       _items = [
//         {'name': 'Item 1', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 2', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 3', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 4', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 5', 'category': 'Category 3', 'unit': 'pcs'},
//       ];
//       notifyListeners();
//     });
//   }

//   void addItem(String name, String category, String unit) {
//     _items.add({
//       'name': name,
//       'category': category,
//       'unit': unit,
//     });
//     notifyListeners();
//   }

//   void updateItem(int index, Map<String, dynamic> item) {
//     _items[index] = item;
//     notifyListeners();
//   }

//   void deleteItem(int index) {
//     _items.removeAt(index);
//     notifyListeners();
//   }

//   List<Map<String, dynamic>> getItemsByCategory(String category) {
//     if (category == 'All') {
//       return _items;
//     }
//     return _items.where((item) => item['category'] == category).toList();
//   }

//   int convertUnits(String fromUnit, String toUnit, int quantity) {
//     if (fromUnit == toUnit) return quantity;

//     if (fromUnit == 'ft' && toUnit == 'm') {
//       return (quantity * 0.3048).round();
//     } else if (fromUnit == 'm' && toUnit == 'ft') {
//       return (quantity / 0.3048).round();
//     } else {
//       throw UnsupportedError(
//           'Conversion from $fromUnit to $toUnit is not supported.');
//     }
//   }
// }






// import 'package:flutter/material.dart';

// class InventoryProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _items = [];

//   List<Map<String, dynamic>> get items => _items;

//   void fetchItems() {
//     // Simulating network fetch with a delay
//     Future.delayed(Duration(seconds: 1), () {
//       _items = [
//         {'name': 'Item 1', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 2', 'category': 'Category 1', 'unit': 'ft'},
//         {'name': 'Item 3', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 4', 'category': 'Category 2', 'unit': 'm'},
//         {'name': 'Item 5', 'category': 'Category 3', 'unit': 'pcs'},
//       ];
//       notifyListeners();
//     });
//   }

//   void addItem(Map<String, dynamic> item) {
//     _items.add(item);
//     notifyListeners();
//   }

//   void updateItem(int index, Map<String, dynamic> item) {
//     _items[index] = item;
//     notifyListeners();
//   }

//   void deleteItem(int index) {
//     _items.removeAt(index);
//     notifyListeners();
//   }

//   List<Map<String, dynamic>> getItemsByCategory(String category) {
//     if (category == 'All') {
//       return _items;
//     }
//     return _items.where((item) => item['category'] == category).toList();
//   }

//   int convertUnits(String fromUnit, String toUnit, int quantity) {
//     if (fromUnit == toUnit) return quantity;

//     if (fromUnit == 'ft' && toUnit == 'm') {
//       return (quantity * 0.3048).round();
//     } else if (fromUnit == 'm' && toUnit == 'ft') {
//       return (quantity / 0.3048).round();
//     } else {
//       throw UnsupportedError(
//           'Conversion from $fromUnit to $toUnit is not supported.');
//     }
//   }
// }
