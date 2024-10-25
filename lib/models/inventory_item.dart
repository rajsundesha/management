// class InventoryItem {
//   final String id;
//   final String name;
//   final String category;
//   final String subcategory;
//   final String unit;
//   final double quantity;
//   final int threshold;
//   final bool isPipe;
//   final double pipeLength;
//   final double? length;
//   final double? width;
//   final double? height;
//   final bool isHidden;
//   final bool isDeadstock;
//   final double? price;

//   InventoryItem({
//     required this.id,
//     required this.name,
//     this.category = 'Uncategorized',
//     this.subcategory = 'N/A',
//     this.unit = 'N/A',
//     this.quantity = 0,
//     this.threshold = 0,
//     this.isPipe = false,
//     this.pipeLength = 0,
//     this.length,
//     this.width,
//     this.height,
//     this.isHidden = false,
//     this.isDeadstock = false,
//     this.price,
//   });

//   factory InventoryItem.fromMap(Map<String, dynamic> map) {
//     return InventoryItem(
//       id: map['id'] ?? '',
//       name: map['name'] ?? 'Unnamed Item',
//       category: map['category'] as String? ?? 'Uncategorized',
//       subcategory: map['subcategory'] as String? ?? 'N/A',
//       unit: map['unit'] as String? ?? 'N/A',
//       quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
//       threshold: map['threshold'] as int? ?? 0,
//       isPipe: map['isPipe'] as bool? ?? false,
//       pipeLength: (map['pipeLength'] as num?)?.toDouble() ?? 0,
//       length: (map['length'] as num?)?.toDouble(),
//       width: (map['width'] as num?)?.toDouble(),
//       height: (map['height'] as num?)?.toDouble(),
//       isHidden: map['isHidden'] as bool? ?? false,
//       isDeadstock: map['isDeadstock'] as bool? ?? false,
//       price: (map['price'] as num?)?.toDouble(),
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'category': category,
//       'subcategory': subcategory,
//       'unit': unit,
//       'quantity': quantity,
//       'threshold': threshold,
//       'isPipe': isPipe,
//       'pipeLength': pipeLength,
//       'length': length,
//       'width': width,
//       'height': height,
//       'isHidden': isHidden,
//       'isDeadstock': isDeadstock,
//       'price': price,
//     };
//   }

//   double get totalLength => isPipe ? quantity * pipeLength : quantity;
//   String get dimensionsString {
//     if (length != null && width != null && height != null) {
//       return 'L: $length, W: $width, H: $height';
//     } else {
//       return 'N/A';
//     }
//   }
// }
