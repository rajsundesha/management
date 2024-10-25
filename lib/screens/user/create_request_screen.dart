import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import '../../providers/request_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';

class CreateUserRequestScreen extends StatefulWidget {
  @override
  _CreateUserRequestScreenState createState() =>
      _CreateUserRequestScreenState();
}

class _CreateUserRequestScreenState extends State<CreateUserRequestScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, Map<String, dynamic>> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pickerNameController = TextEditingController();
  final TextEditingController _pickerContactController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  String _selectedLocation = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedSubSubcategory;
  bool _isLoading = false;
  bool _isListening = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInventoryItems();
      _fetchLocations();
    });
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech recognition status: $status'),
      onError: (errorNotification) =>
          print('Speech recognition error: $errorNotification'),
    );
    if (available) {
      setState(() => _isListening = false);
    } else {
      print("The user has denied the use of speech recognition.");
    }
  }

  Future<void> _fetchInventoryItems() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAdminOrManager =
          authProvider.role == 'Admin' || authProvider.role == 'Manager';
      await Provider.of<InventoryProvider>(context, listen: false)
          .fetchItems(isAdminOrManager: isAdminOrManager);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching inventory items: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  // Future<void> _fetchInventoryItems() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error fetching inventory items: $e')),
  //     );
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _fetchLocations() async {
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.fetchLocations();
    } catch (e) {
      print('Error fetching locations in CreateUserRequestScreen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching locations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildSearchBar(),
                      _buildCategorySelector(),
                      if (_selectedCategory != null)
                        _buildSubcategorySelector(),
                      if (_selectedSubcategory != null)
                        _buildSubSubcategorySelector(),
                      _buildQuickAddGrid(),
                      _buildInventoryList(),
                      _buildSelectedItemsList(),
                      SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Create New Request',
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
              speed: Duration(milliseconds: 100),
            ),
          ],
          totalRepeatCount: 1,
          pause: Duration(milliseconds: 1000),
          displayFullTextOnTap: true,
          stopPauseOnTap: true,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade700, Colors.blue.shade900],
            ),
          ),
          child: Center(
            child: Icon(Icons.inventory,
                size: 80, color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TypeAheadField<Map<String, dynamic>>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search and add items',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30)),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              suggestionsCallback: (pattern) async {
                return await _getSuggestions(pattern);
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['name']),
                  subtitle: Text(
                      '${suggestion['category']} - ${suggestion['subcategory']}'),
                );
              },
              onSuggestionSelected: (suggestion) {
                _quickAddItem(suggestion);
                _searchController.clear();
              },
            ),
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            onPressed: _toggleListening,
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSuggestions(String pattern) async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    return inventoryProvider.items
        .where((item) =>
            item['name'].toLowerCase().contains(pattern.toLowerCase()) ||
            item['category'].toLowerCase().contains(pattern.toLowerCase()))
        .toList();
  }

  void _toggleListening() {
    if (!_isListening) {
      bool available = _speech.isAvailable;
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Widget _buildCategorySelector() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        Set<String> categories = inventoryProvider.items
            .map((item) => item['category'] as String)
            .toSet();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : null;
                        _selectedSubcategory = null;
                        _selectedSubSubcategory = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubcategorySelector() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        Set<String> subcategories = inventoryProvider.items
            .where((item) => item['category'] == _selectedCategory)
            .map((item) => item['subcategory'] as String)
            .toSet();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Subcategory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subcategories.map((subcategory) {
                  return ChoiceChip(
                    label: Text(subcategory),
                    selected: _selectedSubcategory == subcategory,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubcategory = selected ? subcategory : null;
                        _selectedSubSubcategory = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubSubcategorySelector() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        Set<String> subSubcategories = inventoryProvider.items
            .where((item) =>
                item['category'] == _selectedCategory &&
                item['subcategory'] == _selectedSubcategory &&
                item['subSubcategory'] != null)
            .map((item) => item['subSubcategory'] as String)
            .toSet();

        if (subSubcategories.isEmpty) {
          return SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Sub-subcategory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subSubcategories.map((subSubcategory) {
                  return ChoiceChip(
                    label: Text(subSubcategory),
                    selected: _selectedSubSubcategory == subSubcategory,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubSubcategory =
                            selected ? subSubcategory : null;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAddGrid() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        List<Map<String, dynamic>> filteredItems =
            inventoryProvider.items.where((item) {
          bool isVisible =
              !(item['isHidden'] == true || item['isDeadstock'] == true);
          bool categoryMatch = _selectedCategory == null ||
              item['category'] == _selectedCategory;
          bool subcategoryMatch = _selectedSubcategory == null ||
              item['subcategory'] == _selectedSubcategory;
          bool subSubcategoryMatch = _selectedSubSubcategory == null ||
              item['subSubcategory'] == _selectedSubSubcategory;
          return isVisible &&
              categoryMatch &&
              subcategoryMatch &&
              subSubcategoryMatch;
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> item = filteredItems[index];
              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () => _quickAddItem(item),
                  child: Center(
                    child: Text(
                      item['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

// Helper function to safely convert to double
  double? _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  void _quickAddItem(Map<String, dynamic> item) {
    setState(() {
      String itemId = item['id'] as String? ?? '';
      bool isPipe = item['isPipe'] as bool? ?? false;

      if (_selectedItems.containsKey(itemId)) {
        if (isPipe) {
          _selectedItems[itemId]!['pcs'] =
              (_selectedItems[itemId]!['pcs'] as int? ?? 0) + 1;
          double currentMeters =
              _toDouble(_selectedItems[itemId]!['meters']) ?? 0.0;
          double itemPipeLength = _toDouble(item['pipeLength']) ?? 1.0;
          _selectedItems[itemId]!['meters'] = currentMeters + itemPipeLength;
        } else {
          _selectedItems[itemId]!['quantity'] =
              (_selectedItems[itemId]!['quantity'] as int? ?? 0) + 1;
        }
      } else {
        _selectedItems[itemId] = {
          'isPipe': isPipe,
          'name': item['name'] as String? ?? 'Unknown Item',
          'unit': item['unit'] as String? ?? 'pc',
          'category': item['category'] as String? ?? 'Uncategorized',
          'subcategory': item['subcategory'] as String? ?? 'N/A',
        };
        if (isPipe) {
          _selectedItems[itemId]!['pcs'] = 1;
          _selectedItems[itemId]!['meters'] =
              _toDouble(item['pipeLength']) ?? 1.0;
          _selectedItems[itemId]!['pipeLength'] =
              _toDouble(item['pipeLength']) ?? 1.0;
        } else {
          _selectedItems[itemId]!['quantity'] = 1;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${item['name'] ?? 'Item'} to the request'),
        duration: Duration(seconds: 1),
      ),
    );
    _animateFloatingActionButton();
  }

  void _updatePipeLength(
      String itemId, double newLength, Map<String, dynamic> itemData) {
    setState(() {
      double pipeLength = _toDouble(itemData['pipeLength']) ?? 1.0;
      double newPieces = newLength / pipeLength;
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': newPieces,
        'meters': newLength,
        'isPipe': true,
        'name': itemData['name'] ?? 'Unknown Item',
        'unit': 'pcs',
        'pipeLength': pipeLength,
        'category': itemData['category'] ?? 'Uncategorized',
        'subcategory': itemData['subcategory'] ?? 'N/A',
      };
    });
    _animateFloatingActionButton();
  }

  Widget _buildInventoryList() {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, _) {
        List<Map<String, dynamic>> filteredItems =
            inventoryProvider.items.where((item) {
          bool isVisible =
              !(item['isHidden'] == true || item['isDeadstock'] == true);
          bool categoryMatch = _selectedCategory == null ||
              item['category'] == _selectedCategory;
          bool subcategoryMatch = _selectedSubcategory == null ||
              item['subcategory'] == _selectedSubcategory;
          bool subSubcategoryMatch = _selectedSubSubcategory == null ||
              item['subSubcategory'] == _selectedSubcategory;
          bool searchMatch = _searchController.text.isEmpty ||
              item['name']
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase());
          return isVisible &&
              categoryMatch &&
              subcategoryMatch &&
              subSubcategoryMatch &&
              searchMatch;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(child: Text('No items available.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> item = filteredItems[index];
            bool isPipe = item['isPipe'] ?? false;
            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  item['name'],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                subtitle: Text('${item['category']} - ${item['subcategory']}'),
                trailing: isPipe
                    ? _buildPipeControls(item)
                    : _buildQuantityControls(item),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuantityControls(Map<String, dynamic> item) {
    int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove_circle_outline),
          onPressed: quantity > 0
              ? () => _updateQuantity(item['id'], quantity - 1, item)
              : null,
        ),
        Text('$quantity ${item['unit']}',
            style: TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
        ),
      ],
    );
  }

  Widget _buildPipeControls(Map<String, dynamic> item) {
    return ElevatedButton(
      child: Text('Select'),
      onPressed: () => _showPipeSelectionModal(item['id'], item),
    );
  }

  void _showPipeSelectionModal(String itemId, Map<String, dynamic> itemData) {
    final TextEditingController lengthController = TextEditingController(
        text: (_selectedItems[itemId]?['meters'] ?? 0.0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Pipe Length',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: lengthController,
                    decoration: InputDecoration(
                      labelText: 'Length in meters',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      double newLength =
                          double.tryParse(lengthController.text) ?? 0.0;
                      _updatePipeLength(itemId, newLength, itemData);
                      Navigator.of(context).pop();
                    },
                    child: Text('Select'),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditQuantityDialog(String itemId, int currentQuantity) {
    final TextEditingController quantityController =
        TextEditingController(text: currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity'),
        content: TextField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              int newQuantity = int.tryParse(quantityController.text) ?? 0;
              _updateQuantity(itemId, newQuantity, _selectedItems[itemId]!);
              Navigator.of(context).pop();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditPipeDialog(String itemId, Map<String, dynamic> itemData) {
    final TextEditingController pcsController = TextEditingController(
        text: (_selectedItems[itemId]?['pcs'] ?? 0.0).toStringAsFixed(2));
    final TextEditingController metersController = TextEditingController(
        text: (_selectedItems[itemId]?['meters'] ?? 0.0).toStringAsFixed(2));

    double pipeLength = _toDouble(itemData['pipeLength']) ?? 1.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Pipe Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pcsController,
                decoration: InputDecoration(
                  labelText: 'Pieces',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  double pcs = double.tryParse(value) ?? 0;
                  setState(() {
                    metersController.text =
                        (pcs * pipeLength).toStringAsFixed(2);
                  });
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: metersController,
                decoration: InputDecoration(
                  labelText: 'Meters',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  double meters = double.tryParse(value) ?? 0.0;
                  setState(() {
                    pcsController.text =
                        (meters / pipeLength).toStringAsFixed(2);
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                double pcs = double.tryParse(pcsController.text) ?? 0;
                double meters = double.tryParse(metersController.text) ?? 0.0;
                _updatePipeDetails(itemId, pcs, meters, itemData);
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _updatePipeDetails(
      String itemId, double pcs, double meters, Map<String, dynamic> itemData) {
    setState(() {
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': pcs,
        'meters': meters,
        'isPipe': true,
        'name': itemData['name'] ?? 'Unknown Item',
        'unit': 'pcs',
        'pipeLength': _toDouble(itemData['pipeLength']) ?? 1.0,
        'category': itemData['category'] ?? 'Uncategorized',
        'subcategory': itemData['subcategory'] ?? 'N/A',
      };
    });
    _animateFloatingActionButton();
  }

  // void _updatePipeDetails(
  //     String itemId, int pcs, double meters, Map<String, dynamic> itemData) {
  //   setState(() {
  //     _selectedItems[itemId] = {
  //       ..._selectedItems[itemId] ?? {},
  //       'pcs': pcs,
  //       'meters': meters,
  //       'isPipe': true,
  //       'name': itemData['name'],
  //       'unit': 'pcs',
  //       'pipeLength': itemData['pipeLength'],
  //       'category': itemData['category'],
  //       'subcategory': itemData['subcategory'],
  //     };
  //   });
  //   _animateFloatingActionButton();
  // }
  Widget _buildSelectedItemsList() {
    List<MapEntry<String, Map<String, dynamic>>> selectedItems =
        _selectedItems.entries.where((entry) {
      var item = entry.value;
      final pcs = _toDouble(item['pcs']) ?? 0.0;
      final meters = _toDouble(item['meters']) ?? 0.0;
      final quantity = item['quantity'] as int? ?? 0;

      return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
          (item['isPipe'] != true && quantity > 0);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Selected Items',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: selectedItems.length,
          itemBuilder: (context, index) {
            String itemId = selectedItems[index].key;
            Map<String, dynamic> itemData = selectedItems[index].value;
            bool isPipe = itemData['isPipe'] ?? false;

            return Slidable(
              endActionPane: ActionPane(
                motion: ScrollMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => isPipe
                        ? _showEditPipeDialog(itemId, itemData)
                        : _showEditQuantityDialog(
                            itemId, itemData['quantity'] as int? ?? 0),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    icon: Icons.edit,
                    label: 'Edit',
                  ),
                  SlidableAction(
                    onPressed: (_) {
                      setState(() {
                        _selectedItems.remove(itemId);
                      });
                      _animateFloatingActionButton();
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: 'Delete',
                  ),
                ],
              ),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                        isPipe ? Icons.architecture : Icons.shopping_cart,
                        color: Colors.white),
                    backgroundColor: isPipe ? Colors.orange : Colors.green,
                  ),
                  title: Text(itemData['name'] ?? 'Unknown Item',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPipe) ...[
                        Text('Pieces: ${(_toDouble(itemData['pcs']) ?? 0.0).toStringAsFixed(2)}, ' +
                            'Length: ${(_toDouble(itemData['meters']) ?? 0.0).toStringAsFixed(2)} m'),
                      ] else ...[
                        Text(
                            'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
                      ],
                      Text(
                          '${itemData['category'] ?? 'Uncategorized'} - ${itemData['subcategory'] ?? 'N/A'}'),
                    ],
                  ),
                  trailing: Icon(Icons.swipe_left, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: FloatingActionButton.extended(
            onPressed: _selectedItems.isEmpty
                ? null
                : () => _showRequestDetailsDialog(context),
            label: Text('Send Request'),
            icon: Icon(Icons.send),
            backgroundColor:
                _selectedItems.isEmpty ? Colors.grey : Colors.blue.shade700,
          ),
        );
      },
    );
  }

  void _updateQuantity(
      String itemId, int newQuantity, Map<String, dynamic> item) {
    setState(() {
      if (newQuantity > 0) {
        _selectedItems[itemId] = {
          'quantity': newQuantity,
          'isPipe': item['isPipe'] ?? false,
          'name': item['name'],
          'unit': item['unit'],
          'category': item['category'],
          'subcategory': item['subcategory'],
        };
      } else {
        _selectedItems.remove(itemId);
      }
    });
    _animateFloatingActionButton();
  }

  // void _updatePipePieces(
  //     String itemId, int newPieces, Map<String, dynamic> itemData) {
  //   setState(() {
  //     double pipeLength = itemData['pipeLength'] ?? 1.0;
  //     _selectedItems[itemId] = {
  //       ..._selectedItems[itemId] ?? {},
  //       'pcs': newPieces,
  //       'meters': newPieces * pipeLength,
  //       'isPipe': true,
  //       'name': itemData['name'],
  //       'unit': 'pcs',
  //       'pipeLength': pipeLength,
  //       'category': itemData['category'],
  //       'subcategory': itemData['subcategory'],
  //     };
  //   });
  //   _animateFloatingActionButton();
  // }

  void _updatePipePieces(
      String itemId, double newPieces, Map<String, dynamic> itemData) {
    setState(() {
      double pipeLength = _toDouble(itemData['pipeLength']) ?? 1.0;
      double newLength = newPieces * pipeLength;
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': newPieces,
        'meters': newLength,
        'isPipe': true,
        'name': itemData['name'] ?? 'Unknown Item',
        'unit': 'pcs',
        'pipeLength': pipeLength,
        'category': itemData['category'] ?? 'Uncategorized',
        'subcategory': itemData['subcategory'] ?? 'N/A',
      };
    });
    _animateFloatingActionButton();
  }

  void _animateFloatingActionButton() {
    if (_selectedItems.isNotEmpty) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _showRequestDetailsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Enter Request Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, _) {
                    if (locationProvider.isLoading) {
                      return CircularProgressIndicator();
                    }
                    if (locationProvider.locations.isEmpty) {
                      return Text('No locations available.');
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedLocation.isNotEmpty
                          ? _selectedLocation
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Delivery Location',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: locationProvider.locations.map((location) {
                        return DropdownMenuItem(
                            value: location, child: Text(location));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedLocation = value);
                        }
                      },
                      hint: Text('Select a location'),
                    );
                  },
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _pickerNameController,
                  decoration: InputDecoration(
                    labelText: 'Picker Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _pickerContactController,
                  decoration: InputDecoration(
                    labelText: 'Picker Contact Number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    prefixIcon: Icon(Icons.phone),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.contacts),
                      onPressed: _pickContact,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Optional Note',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _submitRequest(context),
              child: Text('Submit'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickContact() async {
    var status = await Permission.contacts.status;
    if (status.isGranted) {
      try {
        Contact? contact = await ContactsService.openDeviceContactPicker();
        if (contact != null) {
          String phoneNumber = contact.phones?.first.value ?? '';
          phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
          if (phoneNumber.length > 10) {
            phoneNumber = phoneNumber.substring(phoneNumber.length - 10);
          }
          setState(() {
            _pickerNameController.text = contact.displayName ?? '';
            _pickerContactController.text = phoneNumber;
          });
        }
      } catch (e) {
        print('Error picking contact: $e');
      }
    } else {
      showPermissionDeniedDialog(context);
    }
  }

  void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Contact Permission Required'),
        content: Text(
            'This app needs access to contacts to function properly. Please grant permission in the app settings.'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest(BuildContext context) async {
    if (_pickerNameController.text.isEmpty ||
        _pickerContactController.text.isEmpty ||
        _pickerContactController.text.length != 10 ||
        _selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all the required fields with valid data.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserEmail = authProvider.currentUserEmail;
    final currentUserId = authProvider.user?.uid;
    final currentUserRole = authProvider.role;

    if (currentUserEmail == null ||
        currentUserId == null ||
        currentUserRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('User information not available. Please log in again.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Creating request..."),
            ],
          ),
        );
      },
    );

    try {
      final requestProvider =
          Provider.of<RequestProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
        final itemData = entry.value;
        final isPipe = itemData['isPipe'] ?? false;

        if (isPipe) {
          double meters = _toDouble(itemData['meters']) ?? 0.0;
          double pcs = _toDouble(itemData['pcs']) ?? 0.0;
          return {
            'id': entry.key,
            'name': itemData['name'],
            'quantity': pcs, // Store as double for pipes
            'meters': meters,
            'isPipe': true,
            'pipeLength': _toDouble(itemData['pipeLength']) ?? 1.0,
            'category': itemData['category'] ?? 'Uncategorized',
            'subcategory': itemData['subcategory'] ?? 'N/A',
            'unit': 'pcs',
          };
        } else {
          return {
            'id': entry.key,
            'name': itemData['name'],
            'quantity': itemData['quantity'] as int? ??
                0, // Ensure this is an int for non-pipes
            'unit': itemData['unit'],
            'isPipe': false,
            'category': itemData['category'] ?? 'Uncategorized',
            'subcategory': itemData['subcategory'] ?? 'N/A',
          };
        }
      }).toList();

      String requestId = await requestProvider.addRequest(
        items,
        _selectedLocation,
        _pickerNameController.text,
        _pickerContactController.text,
        _noteController.text,
        currentUserEmail,
        inventoryProvider,
      );

      // Close the "Creating request..." dialog
      Navigator.of(context).pop();

      // Show "Sending notifications..." dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Sending notifications..."),
              ],
            ),
          );
        },
      );

      // Trigger notifications asynchronously
      requestProvider
          .handleRequestCreationNotification(
        currentUserId,
        currentUserRole,
        requestId,
      )
          .catchError((error) {
        print("Error sending notifications: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Notification sending failed, but request was created.')),
        );
      });

      // Close the "Sending notifications..." dialog
      Navigator.of(context).pop();

      // Generate a unique code for the request
      String uniqueCode = _generateUniqueCode();

      // Prepare the SMS message
      String smsMessage = '''
New Request: $requestId
Code: $uniqueCode
Location: $_selectedLocation
Items: ${items.length}
Picker: ${_pickerNameController.text}
''';

      await _shareRequestDetails(requestId, items);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request created successfully!')),
      );

      Navigator.of(context).pop(); // Close the dialog
      Navigator.of(context).pop(); // Go back to the previous screen
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).pop();

      print("Error creating request or sending notifications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating request: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateUniqueCode() {
    // Generate a random 6-digit code
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> _shareRequestDetails(
      String requestId, List<Map<String, dynamic>> items) async {
    final itemDetails = items.map((item) {
      if (item['isPipe'] as bool) {
        return '${item['name']} - ${item['quantity']} pcs, ${item['meters']} meters';
      } else {
        return '${item['name']} - ${item['quantity']} ${item['unit']}';
      }
    }).join('\n');

    final shareContent = '''
Request ID: $requestId
Location: $_selectedLocation
Picker: ${_pickerNameController.text}

Items:
$itemDetails

Note: ${_noteController.text.isEmpty ? 'N/A' : _noteController.text}
''';

    await Share.share(shareContent);
  }
}
