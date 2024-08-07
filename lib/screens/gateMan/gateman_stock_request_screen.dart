import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart' as custom_auth;

class GatemanStockRequestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<custom_auth.AuthProvider>(context, listen: false);
    final gateManId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Active Stock Requests')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<RequestProvider>(context, listen: false)
            .getActiveStockRequestsStream(),
        builder: (context, snapshot) {
          print("StreamBuilder state: ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error in GatemanStockRequestScreen: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No active stock requests found.'));
          }
          final requests = snapshot.data!;
          print("Number of active stock requests: ${requests.length}");
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              print("Request $index: ${request['id']} - ${request['status']}");
              return StockRequestCard(request: request, gateManId: gateManId);
            },
          );
        },
      ),
    );
  }
}

class StockRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String? gateManId;

  StockRequestCard({required this.request, this.gateManId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Stock Request #${request['id'] ?? 'Unknown'}'),
        subtitle: Text(
            'Status: ${request['status'] ?? 'Unknown'}\nItems: ${_formatItems(request['items'])}'),
        trailing: ElevatedButton(
          child: Text('Receive'),
          onPressed: () => _showReceiveDialog(context),
        ),
      ),
    );
  }

  void _showReceiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          ReceiveStockDialog(request: request, gateManId: gateManId),
    );
  }

  String _formatItems(dynamic items) {
    if (items is! List) return 'No items';
    return items.map((item) {
      if (item is! Map) return 'Invalid item';
      return '${item['remainingQuantity'] ?? 0} x ${item['name'] ?? 'Unknown'}';
    }).join(', ');
  }
}

class ReceiveStockDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final String? gateManId;

  ReceiveStockDialog({required this.request, this.gateManId});

  @override
  _ReceiveStockDialogState createState() => _ReceiveStockDialogState();
}

class _ReceiveStockDialogState extends State<ReceiveStockDialog> {
  late List<Map<String, dynamic>> _receivedItems;

  @override
  void initState() {
    super.initState();
    _initializeReceivedItems();
  }

  void _initializeReceivedItems() {
    _receivedItems = [];
    var items = widget.request['items'];
    if (items is List) {
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          _receivedItems.add({
            'id': item['id'] ?? '',
            'name': item['name'] ?? '',
            'quantity': item['quantity'] ?? 0,
            'remainingQuantity':
                item['remainingQuantity'] ?? item['quantity'] ?? 0,
            'receivedQuantity': 0,
          });
        }
      }
    }
    print("Initialized received items: $_receivedItems");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Receive Stock'),
      content: SingleChildScrollView(
        child: Column(
          children:
              _receivedItems.map((item) => _buildItemReceiveRow(item)).toList(),
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Confirm'),
          onPressed: () => _confirmReceive(context),
        ),
      ],
    );
  }

  Widget _buildItemReceiveRow(Map<String, dynamic> item) {
    return Row(
      children: [
        Expanded(child: Text('${item['name']}:')),
        SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            initialValue: '0',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: '/ ${item['remainingQuantity']}',
            ),
            onChanged: (value) {
              setState(() {
                item['receivedQuantity'] = int.tryParse(value) ?? 0;
              });
            },
          ),
        ),
      ],
    );
  }

  void _confirmReceive(BuildContext context) {
    bool isValid = _receivedItems.every((item) {
      int receivedQuantity = item['receivedQuantity'] ?? 0;
      int remainingQuantity = item['remainingQuantity'] ?? 0;
      return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
    });

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please check the received quantities'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    var itemsToUpdate = _receivedItems.where((item) {
      int receivedQuantity = item['receivedQuantity'] ?? 0;
      return receivedQuantity > 0;
    }).toList();

    if (itemsToUpdate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items received. Please enter quantities.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    if (widget.gateManId == null) {
      Navigator.of(context).pop(); // Dismiss the loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Gate Man ID not found. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Provider.of<RequestProvider>(context, listen: false)
        .fulfillStockRequest(
            widget.request['id'], itemsToUpdate, widget.gateManId!)
        .then((_) {
      Navigator.of(context).pop(); // Dismiss the loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock request updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // Close the ReceiveStockDialog
    }).catchError((error) {
      Navigator.of(context).pop(); // Dismiss the loading indicator
      String errorMessage = 'Error updating stock request';
      if (error is CustomException) {
        errorMessage = error.toString();
      } else if (error is FirebaseException) {
        errorMessage = 'Firebase error: ${error.message}';
      } else {
        errorMessage = 'Unexpected error: $error';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      print('Error in fulfillStockRequest: $error');
    });
  }
}

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';

// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//     final gateManId = authProvider.user?.uid;

//     return Scaffold(
//       appBar: AppBar(title: Text('Active Stock Requests')),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: Provider.of<RequestProvider>(context, listen: false)
//             .getActiveStockRequestsStream(),
//         builder: (context, snapshot) {
//           print("StreamBuilder state: ${snapshot.connectionState}");
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             print("Error in GatemanStockRequestScreen: ${snapshot.error}");
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No active stock requests found.'));
//           }
//           final requests = snapshot.data!;
//           print("Number of active stock requests: ${requests.length}");
//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               print("Request $index: ${request['id']} - ${request['status']}");
//               return StockRequestCard(request: request, gateManId: gateManId);
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class StockRequestCard extends StatelessWidget {
//   final Map<String, dynamic> request;
//   final String? gateManId;

//   StockRequestCard({required this.request, this.gateManId});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id'] ?? 'Unknown'}'),
//         subtitle: Text(
//             'Status: ${request['status'] ?? 'Unknown'}\nItems: ${_formatItems(request['items'])}'),
//         trailing: ElevatedButton(
//           child: Text('Receive'),
//           onPressed: () => _showReceiveDialog(context),
//         ),
//       ),
//     );
//   }

//   void _showReceiveDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) =>
//           ReceiveStockDialog(request: request, gateManId: gateManId),
//     );
//   }

//   String _formatItems(dynamic items) {
//     if (items is! List) return 'No items';
//     return items.map((item) {
//       if (item is! Map) return 'Invalid item';
//       return '${item['remainingQuantity'] ?? 0} x ${item['name'] ?? 'Unknown'}';
//     }).join(', ');
//   }
// }

// class ReceiveStockDialog extends StatefulWidget {
//   final Map<String, dynamic> request;
//   final String? gateManId;

//   ReceiveStockDialog({required this.request, this.gateManId});

//   @override
//   _ReceiveStockDialogState createState() => _ReceiveStockDialogState();
// }

// class _ReceiveStockDialogState extends State<ReceiveStockDialog> {
//   late List<Map<String, dynamic>> _receivedItems;

//   @override
//   void initState() {
//     super.initState();
//     _initializeReceivedItems();
//   }

//   void _initializeReceivedItems() {
//     _receivedItems = [];
//     var items = widget.request['items'];
//     if (items is List) {
//       for (var item in items) {
//         if (item is Map<String, dynamic>) {
//           _receivedItems.add({
//             'id': item['id'] ?? '',
//             'name': item['name'] ?? '',
//             'quantity': item['quantity'] ?? 0,
//             'remainingQuantity':
//                 item['remainingQuantity'] ?? item['quantity'] ?? 0,
//             'receivedQuantity': 0,
//           });
//         }
//       }
//     }
//     print("Initialized received items: $_receivedItems");
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Receive Stock'),
//       content: SingleChildScrollView(
//         child: Column(
//           children:
//               _receivedItems.map((item) => _buildItemReceiveRow(item)).toList(),
//         ),
//       ),
//       actions: [
//         TextButton(
//           child: Text('Cancel'),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         ElevatedButton(
//           child: Text('Confirm'),
//           onPressed: () => _confirmReceive(context),
//         ),
//       ],
//     );
//   }

//   Widget _buildItemReceiveRow(Map<String, dynamic> item) {
//     return Row(
//       children: [
//         Expanded(child: Text('${item['name']}:')),
//         SizedBox(width: 10),
//         Expanded(
//           child: TextFormField(
//             initialValue: '0',
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               suffixText: '/ ${item['remainingQuantity']}',
//             ),
//             onChanged: (value) {
//               setState(() {
//                 item['receivedQuantity'] = int.tryParse(value) ?? 0;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   void _confirmReceive(BuildContext context) {
//     bool isValid = _receivedItems.every((item) {
//       int receivedQuantity = item['receivedQuantity'] ?? 0;
//       int remainingQuantity = item['remainingQuantity'] ?? 0;
//       return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
//     });

//     if (!isValid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please check the received quantities'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     var itemsToUpdate = _receivedItems.where((item) {
//       int receivedQuantity = item['receivedQuantity'] ?? 0;
//       return receivedQuantity > 0;
//     }).toList();

//     if (itemsToUpdate.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('No items received. Please enter quantities.'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     if (widget.gateManId == null) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: Gate Man ID not found. Please log in again.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     Provider.of<RequestProvider>(context, listen: false)
//         .fulfillStockRequest(
//             widget.request['id'], itemsToUpdate, widget.gateManId!)
//         .then((_) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Stock request updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       Navigator.of(context).pop(); // Close the ReceiveStockDialog
//     }).catchError((error) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       String errorMessage = 'Error updating stock request';
//       if (error is CustomException) {
//         errorMessage = error.toString();
//       } else if (error is FirebaseException) {
//         errorMessage = 'Firebase error: ${error.message}';
//       } else {
//         errorMessage = 'Unexpected error: $error';
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           backgroundColor: Colors.red,
//         ),
//       );
//       print('Error in fulfillStockRequest: $error');
//     });
//   }
// }

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';

// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Active Stock Requests')),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: Provider.of<RequestProvider>(context, listen: false)
//             .getActiveStockRequestsStream(),
//         builder: (context, snapshot) {
//           print("StreamBuilder state: ${snapshot.connectionState}");
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             print("Error in GatemanStockRequestScreen: ${snapshot.error}");
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No active stock requests found.'));
//           }
//           final requests = snapshot.data!;
//           print("Number of active stock requests: ${requests.length}");
//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               print("Request $index: ${request['id']} - ${request['status']}");
//               return StockRequestCard(request: request);
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class StockRequestCard extends StatelessWidget {
//   final Map<String, dynamic> request;

//   StockRequestCard({required this.request});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id'] ?? 'Unknown'}'),
//         subtitle: Text(
//             'Status: ${request['status'] ?? 'Unknown'}\nItems: ${_formatItems(request['items'])}'),
//         trailing: ElevatedButton(
//           child: Text('Receive'),
//           onPressed: () => _showReceiveDialog(context),
//         ),
//       ),
//     );
//   }

//   void _showReceiveDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => ReceiveStockDialog(request: request),
//     );
//   }

//   String _formatItems(dynamic items) {
//     if (items is! List) return 'No items';
//     return items.map((item) {
//       if (item is! Map) return 'Invalid item';
//       return '${item['remainingQuantity'] ?? 0} x ${item['name'] ?? 'Unknown'}';
//     }).join(', ');
//   }
// }

// class ReceiveStockDialog extends StatefulWidget {
//   final Map<String, dynamic> request;

//   ReceiveStockDialog({required this.request});

//   @override
//   _ReceiveStockDialogState createState() => _ReceiveStockDialogState();
// }

// class _ReceiveStockDialogState extends State<ReceiveStockDialog> {
//   late List<Map<String, dynamic>> _receivedItems;

//   @override
//   void initState() {
//     super.initState();
//     _initializeReceivedItems();
//   }

//   // void _initializeReceivedItems() {
//   //   _receivedItems = [];
//   //   var items = widget.request['items'];
//   //   if (items is List) {
//   //     for (var item in items) {
//   //       if (item is Map<String, dynamic>) {
//   //         _receivedItems.add({
//   //           'id': item['id'] ?? '',
//   //           'name': item['name'] ?? '',
//   //           'quantity': item['quantity'] ?? 0,
//   //           'remainingQuantity':
//   //               item['remainingQuantity'] ?? item['quantity'] ?? 0,
//   //           'receivedQuantity': 0,
//   //         });
//   //       }
//   //     }
//   //   }
//   //   print("Initialized received items: $_receivedItems");
//   // }
//   void _initializeReceivedItems() {
//     _receivedItems = [];
//     var items = widget.request['items'];
//     if (items is List) {
//       for (var item in items) {
//         if (item is Map<String, dynamic>) {
//           _receivedItems.add({
//             'id': item['id'] ?? '',
//             'name': item['name'] ?? '',
//             'quantity': item['quantity'] ?? 0,
//             'remainingQuantity':
//                 item['remainingQuantity'] ?? item['quantity'] ?? 0,
//             'receivedQuantity': 0,
//           });
//         }
//       }
//     }
//     print("Initialized received items: $_receivedItems");
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Receive Stock'),
//       content: SingleChildScrollView(
//         child: Column(
//           children:
//               _receivedItems.map((item) => _buildItemReceiveRow(item)).toList(),
//         ),
//       ),
//       actions: [
//         TextButton(
//           child: Text('Cancel'),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         ElevatedButton(
//           child: Text('Confirm'),
//           onPressed: () => _confirmReceive(context),
//         ),
//       ],
//     );
//   }

//   Widget _buildItemReceiveRow(Map<String, dynamic> item) {
//     return Row(
//       children: [
//         Expanded(child: Text('${item['name']}:')),
//         SizedBox(width: 10),
//         Expanded(
//           child: TextFormField(
//             initialValue: '0',
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               suffixText: '/ ${item['remainingQuantity']}',
//             ),
//             onChanged: (value) {
//               setState(() {
//                 item['receivedQuantity'] = int.tryParse(value) ?? 0;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }

// //   void _confirmReceive(BuildContext context) {
// //     bool isValid = _receivedItems.every((item) {
// //       int receivedQuantity = item['receivedQuantity'] ?? 0;
// //       int remainingQuantity = item['remainingQuantity'] ?? 0;
// //       return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
// //     });

// //     if (!isValid) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Please check the received quantities')),
// //       );
// //       return;
// //     }

// // //     var itemsToUpdate = _receivedItems.where((item) {
// // //       int receivedQuantity = item['receivedQuantity'] ?? 0;
// // //       return receivedQuantity > 0;
// // //     }).toList();

// // //     if (itemsToUpdate.isEmpty) {
// // //       ScaffoldMessenger.of(context).showSnackBar(
// // //         SnackBar(content: Text('No items received. Please enter quantities.')),
// // //       );
// // //       return;
// // //     }

// // //     showDialog(
// // //       context: context,
// // //       barrierDismissible: false,
// // //       builder: (BuildContext context) {
// // //         return Center(child: CircularProgressIndicator());
// // //       },
// // //     );

// // //     Provider.of<RequestProvider>(context, listen: false)
// // //         .fulfillStockRequest(widget.request['id'], itemsToUpdate, context)
// // //         .then((_) {
// // //       Navigator.of(context).pop(); // Dismiss the loading indicator
// // //       ScaffoldMessenger.of(context).showSnackBar(
// // //         SnackBar(content: Text('Stock request updated successfully')),
// // //       );
// // //       Navigator.of(context).pop(); // Close the ReceiveStockDialog
// // //     }).catchError((error) {
// // //       Navigator.of(context).pop(); // Dismiss the loading indicator
// // //       ScaffoldMessenger.of(context).showSnackBar(
// // //         SnackBar(content: Text('Error updating stock request: $error')),
// // //       );
// // //     });
// // //   }
// // // }
// //     var itemsToUpdate = _receivedItems.where((item) {
// //       int receivedQuantity = item['receivedQuantity'] ?? 0;
// //       return receivedQuantity > 0;
// //     }).toList();

// //     if (itemsToUpdate.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('No items received. Please enter quantities.')),
// //       );
// //       return;
// //     }

// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (BuildContext context) {
// //         return Center(child: CircularProgressIndicator());
// //       },
// //     );

// //     Provider.of<RequestProvider>(context, listen: false)
// //         .fulfillStockRequest(widget.request['id'], itemsToUpdate, context)
// //         .then((_) {
// //       Navigator.of(context).pop(); // Dismiss the loading indicator
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Stock request updated successfully')),
// //       );
// //       Navigator.of(context).pop(); // Close the ReceiveStockDialog
// //     }).catchError((error) {
// //       Navigator.of(context).pop(); // Dismiss the loading indicator
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error updating stock request: $error')),
// //       );
// //     });
// //   }
// //   void _confirmReceive(BuildContext context) {
// //     bool isValid = _receivedItems.every((item) {
// //       int receivedQuantity = item['receivedQuantity'] ?? 0;
// //       int remainingQuantity = item['remainingQuantity'] ?? 0;
// //       return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
// //     });

// //     if (!isValid) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Please check the received quantities')),
// //       );
// //       return;
// //     }

// //     var itemsToUpdate = _receivedItems.where((item) {
// //       int receivedQuantity = item['receivedQuantity'] ?? 0;
// //       return receivedQuantity > 0;
// //     }).toList();

// //     if (itemsToUpdate.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('No items received. Please enter quantities.')),
// //       );
// //       return;
// //     }

// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (BuildContext context) {
// //         return Center(child: CircularProgressIndicator());
// //       },
// //     );

// //     Provider.of<RequestProvider>(context, listen: false)
// //         .fulfillStockRequest(widget.request['id'], itemsToUpdate)
// //         .then((_) {
// //       Navigator.of(context).pop(); // Dismiss the loading indicator
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Stock request updated successfully')),
// //       );
// //       Navigator.of(context).pop(); // Close the ReceiveStockDialog
// //     }).catchError((error) {
// //       Navigator.of(context).pop(); // Dismiss the loading indicator
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error updating stock request: $error')),
// //       );
// //     });
// //   }
// // }

// void _confirmReceive(BuildContext context) {
//   bool isValid = _receivedItems.every((item) {
//     int receivedQuantity = item['receivedQuantity'] ?? 0;
//     int remainingQuantity = item['remainingQuantity'] ?? 0;
//     return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
//   });

//   if (!isValid) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Please check the received quantities'),
//         backgroundColor: Colors.orange,
//       ),
//     );
//     return;
//   }

//   var itemsToUpdate = _receivedItems.where((item) {
//     int receivedQuantity = item['receivedQuantity'] ?? 0;
//     return receivedQuantity > 0;
//   }).toList();

//   if (itemsToUpdate.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('No items received. Please enter quantities.'),
//         backgroundColor: Colors.orange,
//       ),
//     );
//     return;
//   }

//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext context) {
//       return Center(child: CircularProgressIndicator());
//     },
//   );

//   final authProvider = Provider.of<AuthProvider>(context, listen: false);
//   final gateManId = authProvider.user?.uid;

//   if (gateManId == null) {
//     Navigator.of(context).pop(); // Dismiss the loading indicator
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Error: Gate Man ID not found. Please log in again.'),
//         backgroundColor: Colors.red,
//       ),
//     );
//     return;
//   }

//   Provider.of<RequestProvider>(context, listen: false)
//       .fulfillStockRequest(widget.request['id'], itemsToUpdate, gateManId)
//       .then((_) {
//     Navigator.of(context).pop(); // Dismiss the loading indicator
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Stock request updated successfully'),
//         backgroundColor: Colors.green,
//       ),
//     );
//     Navigator.of(context).pop(); // Close the ReceiveStockDialog
//   }).catchError((error) {
//     Navigator.of(context).pop(); // Dismiss the loading indicator
//     String errorMessage = 'Error updating stock request';
//     if (error is CustomException) {
//       errorMessage = error.toString();
//     } else if (error is FirebaseException) {
//       errorMessage = 'Firebase error: ${error.message}';
//     } else {
//       errorMessage = 'Unexpected error: $error';
//     }
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(errorMessage),
//         backgroundColor: Colors.red,
//       ),
//     );
//     print('Error in fulfillStockRequest: $error');
//   });
// }
// }



// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Active Stock Requests')),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: Provider.of<RequestProvider>(context, listen: false)
//             .getActiveStockRequestsStream(),
//         builder: (context, snapshot) {
//           print("StreamBuilder state: ${snapshot.connectionState}");
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             print("Error in GatemanStockRequestScreen: ${snapshot.error}");
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No active stock requests found.'));
//           }
//           final requests = snapshot.data!;
//           print("Number of active stock requests: ${requests.length}");
//           return ListView.builder(
//             itemCount: requests.length,
//             itemBuilder: (context, index) {
//               final request = requests[index];
//               print("Request $index: ${request['id']} - ${request['status']}");
//               return StockRequestCard(request: request);
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class StockRequestCard extends StatelessWidget {
//   final Map<String, dynamic> request;

//   StockRequestCard({required this.request});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id'] ?? 'Unknown'}'),
//         subtitle: Text(
//             'Status: ${request['status'] ?? 'Unknown'}\nItems: ${_formatItems(request['items'])}'),
//         trailing: ElevatedButton(
//           child: Text('Receive'),
//           onPressed: () => _showReceiveDialog(context),
//         ),
//       ),
//     );
//   }

//   void _showReceiveDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => ReceiveStockDialog(request: request),
//     );
//   }

//   String _formatItems(dynamic items) {
//     if (items is! List) return 'No items';
//     return items.map((item) {
//       if (item is! Map) return 'Invalid item';
//       return '${item['remainingQuantity'] ?? 0} x ${item['name'] ?? 'Unknown'}';
//     }).join(', ');
//   }
// }

// class ReceiveStockDialog extends StatefulWidget {
//   final Map<String, dynamic> request;

//   ReceiveStockDialog({required this.request});

//   @override
//   _ReceiveStockDialogState createState() => _ReceiveStockDialogState();
// }

// class _ReceiveStockDialogState extends State<ReceiveStockDialog> {
//   late List<Map<String, dynamic>> _receivedItems;

//   @override
//   void initState() {
//     super.initState();
//     _initializeReceivedItems();
//   }

//   void _initializeReceivedItems() {
//     _receivedItems = [];
//     var items = widget.request['items'];
//     if (items is List) {
//       for (var item in items) {
//         if (item is Map<String, dynamic>) {
//           _receivedItems.add({
//             'id': item['id'] ?? '',
//             'name': item['name'] ?? '',
//             'quantity': item['quantity'] ?? 0,
//             'remainingQuantity':
//                 item['remainingQuantity'] ?? item['quantity'] ?? 0,
//             'receivedQuantity': 0,
//           });
//         }
//       }
//     }
//     print("Initialized received items: $_receivedItems");
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text('Receive Stock'),
//       content: SingleChildScrollView(
//         child: Column(
//           children:
//               _receivedItems.map((item) => _buildItemReceiveRow(item)).toList(),
//         ),
//       ),
//       actions: [
//         TextButton(
//           child: Text('Cancel'),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         ElevatedButton(
//           child: Text('Confirm'),
//           onPressed: () => _confirmReceive(context),
//         ),
//       ],
//     );
//   }

//   Widget _buildItemReceiveRow(Map<String, dynamic> item) {
//     return Row(
//       children: [
//         Expanded(child: Text('${item['name']}:')),
//         SizedBox(width: 10),
//         Expanded(
//           child: TextFormField(
//             initialValue: '0',
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               suffixText: '/ ${item['remainingQuantity']}',
//             ),
//             onChanged: (value) {
//               setState(() {
//                 item['receivedQuantity'] = int.tryParse(value) ?? 0;
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   void _confirmReceive(BuildContext context) {
//     bool isValid = _receivedItems.every((item) {
//       int receivedQuantity = item['receivedQuantity'] ?? 0;
//       int remainingQuantity = item['remainingQuantity'] ?? 0;
//       return receivedQuantity >= 0 && receivedQuantity <= remainingQuantity;
//     });

//     if (!isValid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please check the received quantities')),
//       );
//       return;
//     }

//     var itemsToUpdate = _receivedItems.where((item) {
//       int receivedQuantity = item['receivedQuantity'] ?? 0;
//       return receivedQuantity > 0;
//     }).toList();

//     if (itemsToUpdate.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('No items received. Please enter quantities.')),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     Provider.of<RequestProvider>(context, listen: false)
//         .fulfillStockRequest(widget.request['id'], itemsToUpdate, context)
//         .then((_) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request updated successfully')),
//       );
//       Navigator.of(context).pop(); // Close the ReceiveStockDialog
//     }).catchError((error) {
//       Navigator.of(context).pop(); // Dismiss the loading indicator
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error updating stock request: $error')),
//       );
//     });
//   }
// }
