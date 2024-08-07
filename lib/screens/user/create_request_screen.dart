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

  // Widget _buildQuickAddGrid() {
  //   return Consumer<InventoryProvider>(
  //     builder: (context, inventoryProvider, _) {
  //       List<Map<String, dynamic>> filteredItems =
  //           inventoryProvider.items.where((item) {
  //         bool categoryMatch = _selectedCategory == null ||
  //             item['category'] == _selectedCategory;
  //         bool subcategoryMatch = _selectedSubcategory == null ||
  //             item['subcategory'] == _selectedSubcategory;
  //         bool subSubcategoryMatch = _selectedSubSubcategory == null ||
  //             item['subSubcategory'] == _selectedSubSubcategory;
  //         return categoryMatch && subcategoryMatch && subSubcategoryMatch;
  //       }).toList();

  //       return Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  //         child: GridView.builder(
  //           shrinkWrap: true,
  //           physics: NeverScrollableScrollPhysics(),
  //           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //             crossAxisCount: 3,
  //             childAspectRatio: 2.5,
  //             crossAxisSpacing: 10,
  //             mainAxisSpacing: 10,
  //           ),
  //           itemCount: filteredItems.length,
  //           itemBuilder: (context, index) {
  //             Map<String, dynamic> item = filteredItems[index];
  //             return Card(
  //               elevation: 2,
  //               child: InkWell(
  //                 onTap: () => _quickAddItem(item),
  //                 child: Center(
  //                   child: Text(
  //                     item['name'],
  //                     textAlign: TextAlign.center,
  //                     style: TextStyle(fontWeight: FontWeight.bold),
  //                     overflow: TextOverflow.ellipsis,
  //                     maxLines: 2,
  //                   ),
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       );
  //     },
  //   );
  // }
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

  void _quickAddItem(Map<String, dynamic> item) {
    setState(() {
      String itemId = item['id'] as String;
      bool isPipe = item['isPipe'] as bool? ?? false;

      if (_selectedItems.containsKey(itemId)) {
        if (isPipe) {
          _selectedItems[itemId]!['pcs'] =
              (_selectedItems[itemId]!['pcs'] as int? ?? 0) + 1;
          _selectedItems[itemId]!['meters'] =
              (_selectedItems[itemId]!['meters'] as double? ?? 0.0) +
                  (item['pipeLength'] as double? ?? 1.0);
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
              item['pipeLength'] as double? ?? 1.0;
          _selectedItems[itemId]!['pipeLength'] =
              item['pipeLength'] as double? ?? 1.0;
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

  // Widget _buildInventoryList() {
  //   return Consumer<InventoryProvider>(
  //     builder: (context, inventoryProvider, _) {
  //       List<Map<String, dynamic>> filteredItems =
  //           inventoryProvider.items.where((item) {
  //         bool categoryMatch = _selectedCategory == null ||
  //             item['category'] == _selectedCategory;
  //         bool subcategoryMatch = _selectedSubcategory == null ||
  //             item['subcategory'] == _selectedSubcategory;
  //         bool subSubcategoryMatch = _selectedSubSubcategory == null ||
  //             item['subSubcategory'] == _selectedSubSubcategory;
  //         bool searchMatch = _searchController.text.isEmpty ||
  //             item['name']
  //                 .toLowerCase()
  //                 .contains(_searchController.text.toLowerCase());
  //         return categoryMatch &&
  //             subcategoryMatch &&
  //             subSubcategoryMatch &&
  //             searchMatch;
  //       }).toList();

  //       return ListView.builder(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         itemCount: filteredItems.length,
  //         itemBuilder: (context, index) {
  //           Map<String, dynamic> item = filteredItems[index];
  //           bool isPipe = item['isPipe'] ?? false;
  //           return Card(
  //             elevation: 2,
  //             margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //             child: ListTile(
  //               title: Text(
  //                 item['name'],
  //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //                 overflow: TextOverflow.ellipsis,
  //                 maxLines: 2,
  //               ),
  //               subtitle: Text('${item['category']} - ${item['subcategory']}'),
  //               trailing: isPipe
  //                   ? _buildPipeControls(item)
  //                   : _buildQuantityControls(item),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
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
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
            ],
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
        text: (_selectedItems[itemId]?['pcs'] ?? 0).toString());
    final TextEditingController metersController = TextEditingController(
        text: (_selectedItems[itemId]?['meters'] ?? 0.0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 10),
            TextField(
              controller: metersController,
              decoration: InputDecoration(
                labelText: 'Meters',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
              int pcs = int.tryParse(pcsController.text) ?? 0;
              double meters = double.tryParse(metersController.text) ?? 0.0;
              _updatePipeDetails(itemId, pcs, meters, itemData);
              Navigator.of(context).pop();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updatePipeDetails(
      String itemId, int pcs, double meters, Map<String, dynamic> itemData) {
    setState(() {
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': pcs,
        'meters': meters,
        'isPipe': true,
        'name': itemData['name'],
        'unit': 'pcs',
        'pipeLength': itemData['pipeLength'],
        'category': itemData['category'],
        'subcategory': itemData['subcategory'],
      };
    });
    _animateFloatingActionButton();
  }

  Widget _buildSelectedItemsList() {
    List<MapEntry<String, Map<String, dynamic>>> selectedItems =
        _selectedItems.entries.where((entry) {
      var item = entry.value;
      final pcs = item['pcs'] as int? ?? 0;
      final meters = item['meters'] as double? ?? 0.0;
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
                      isPipe
                          ? Text(
                              'Pieces: ${itemData['pcs']}, Length: ${itemData['meters'].toStringAsFixed(2)} m')
                          : Text(
                              'Quantity: ${itemData['quantity']} ${itemData['unit']}'),
                      Text(
                          '${itemData['category']} - ${itemData['subcategory']}'),
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

  void _updatePipePieces(
      String itemId, int newPieces, Map<String, dynamic> itemData) {
    setState(() {
      double pipeLength = itemData['pipeLength'] ?? 1.0;
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': newPieces,
        'meters': newPieces * pipeLength,
        'isPipe': true,
        'name': itemData['name'],
        'unit': 'pcs',
        'pipeLength': pipeLength,
        'category': itemData['category'],
        'subcategory': itemData['subcategory'],
      };
    });
    _animateFloatingActionButton();
  }

  void _updatePipeLength(
      String itemId, double newLength, Map<String, dynamic> itemData) {
    setState(() {
      double pipeLength = itemData['pipeLength'] ?? 1.0;
      int newPieces = (newLength / pipeLength).ceil();
      _selectedItems[itemId] = {
        ..._selectedItems[itemId] ?? {},
        'pcs': newPieces,
        'meters': newLength,
        'isPipe': true,
        'name': itemData['name'],
        'unit': 'pcs',
        'pipeLength': pipeLength,
        'category': itemData['category'],
        'subcategory': itemData['subcategory'],
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

    final currentUserEmail =
        Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

    if (currentUserEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('User email not available. Please log in again.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final requestProvider =
          Provider.of<RequestProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
        final itemData = entry.value;
        final isPipe = itemData['isPipe'] ?? false;

        if (isPipe) {
          double meters = itemData['meters'] as double? ?? 0.0;
          int pcs = itemData['pcs'] as int? ?? 0;
          return {
            'id': entry.key,
            'name': itemData['name'],
            'quantity': pcs,
            'meters': meters,
            'isPipe': true,
            'pipeLength': itemData['pipeLength'] ?? 1.0,
            'category': itemData['category'] ?? 'Uncategorized',
            'subcategory': itemData['subcategory'] ?? 'N/A',
            'unit': 'pcs',
          };
        } else {
          return {
            'id': entry.key,
            'name': itemData['name'],
            'quantity': itemData['quantity'],
            'unit': itemData['unit'],
            'isPipe': false,
            'category': itemData['category'] ?? 'Uncategorized',
            'subcategory': itemData['subcategory'] ?? 'N/A',
          };
        }
      }).where((item) {
        if (item['isPipe']) {
          return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
        } else {
          return (item['quantity'] as num) > 0;
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

      _shareRequestDetails(requestId, items);

      Navigator.of(context).pop(); // Close the dialog
      Navigator.of(context).pop(); // Go back to the previous screen
    } catch (e) {
      print("Error creating request or sending SMS: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating request or sending SMS: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all the required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('User email not available. Please log in again.')),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           double meters = itemData['meters'] as double? ?? 0.0;
//           int pcs = itemData['pcs'] as int? ?? 0;
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': pcs,
//             'meters': meters,
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//             'unit': 'pcs',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       String requestId = await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       // Generate a unique code for the request
//       String uniqueCode = _generateUniqueCode();

//       // Prepare the SMS message
//       String smsMessage = '''
// New Request: $requestId
// Code: $uniqueCode
// Location: $_selectedLocation
// Items: ${items.length}
// Picker: ${_pickerNameController.text}
// ''';

//       // Send SMS using Twilio Firebase Extension
//       await _sendSMSUsingTwilioExtension(
//           _pickerContactController.text, smsMessage);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created and SMS sent successfully')),
//       );

//       _shareRequestDetails(requestId, items);

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request or sending SMS: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request or sending SMS: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

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


// import 'dart:math';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_typeahead/flutter_typeahead.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:intl/intl.dart';
// import 'package:app_settings/app_settings.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen>
//     with SingleTickerProviderStateMixin {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   String _selectedLocation = '';
//   String? _selectedCategory;
//   String? _selectedSubcategory;
//   String? _selectedSubSubcategory;
//   bool _isLoading = false;
//   bool _isListening = false;

//   late AnimationController _animationController;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _initializeSpeech();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _initializeSpeech() async {
//     bool available = await _speech.initialize(
//       onStatus: (status) => print('Speech recognition status: $status'),
//       onError: (errorNotification) =>
//           print('Speech recognition error: $errorNotification'),
//     );
//     if (available) {
//       setState(() => _isListening = false);
//     } else {
//       print("The user has denied the use of speech recognition.");
//     }
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : Column(
//                     children: [
//                       _buildSearchBar(),
//                       _buildCategorySelector(),
//                       if (_selectedCategory != null)
//                         _buildSubcategorySelector(),
//                       if (_selectedSubcategory != null)
//                         _buildSubSubcategorySelector(),
//                       _buildQuickAddGrid(),
//                       _buildInventoryList(),
//                       _buildSelectedItemsList(),
//                       SizedBox(height: 80),
//                     ],
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildFloatingActionButton(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: AnimatedTextKit(
//           animatedTexts: [
//             TypewriterAnimatedText(
//               'Create New Request',
//               textStyle: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20.0,
//               ),
//               speed: Duration(milliseconds: 100),
//             ),
//           ],
//           totalRepeatCount: 1,
//           pause: Duration(milliseconds: 1000),
//           displayFullTextOnTap: true,
//           stopPauseOnTap: true,
//         ),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Colors.blue.shade700, Colors.blue.shade900],
//             ),
//           ),
//           child: Center(
//             child: Icon(Icons.inventory,
//                 size: 80, color: Colors.white.withOpacity(0.3)),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         children: [
//           Expanded(
//             child: TypeAheadField<Map<String, dynamic>>(
//               textFieldConfiguration: TextFieldConfiguration(
//                 controller: _searchController,
//                 decoration: InputDecoration(
//                   labelText: 'Search and add items',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(30)),
//                   prefixIcon: Icon(Icons.search),
//                 ),
//               ),
//               suggestionsCallback: (pattern) async {
//                 return await _getSuggestions(pattern);
//               },
//               itemBuilder: (context, suggestion) {
//                 return ListTile(
//                   title: Text(suggestion['name']),
//                   subtitle: Text(
//                       '${suggestion['category']} - ${suggestion['subcategory']}'),
//                 );
//               },
//               onSuggestionSelected: (suggestion) {
//                 _quickAddItem(suggestion);
//                 _searchController.clear();
//               },
//             ),
//           ),
//           IconButton(
//             icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
//             onPressed: _toggleListening,
//           ),
//         ],
//       ),
//     );
//   }

//   Future<List<Map<String, dynamic>>> _getSuggestions(String pattern) async {
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     return inventoryProvider.items
//         .where((item) =>
//             item['name'].toLowerCase().contains(pattern.toLowerCase()) ||
//             item['category'].toLowerCase().contains(pattern.toLowerCase()))
//         .toList();
//   }

//   void _toggleListening() {
//     if (!_isListening) {
//       bool available = _speech.isAvailable;
//       if (available) {
//         setState(() => _isListening = true);
//         _speech.listen(
//           onResult: (result) {
//             setState(() {
//               _searchController.text = result.recognizedWords;
//             });
//           },
//         );
//       }
//     } else {
//       setState(() => _isListening = false);
//       _speech.stop();
//     }
//   }

//   Widget _buildCategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = inventoryProvider.items
//             .map((item) => item['category'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Category',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: categories.map((category) {
//                   return ChoiceChip(
//                     label: Text(category),
//                     selected: _selectedCategory == category,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedCategory = selected ? category : null;
//                         _selectedSubcategory = null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subcategories = inventoryProvider.items
//             .where((item) => item['category'] == _selectedCategory)
//             .map((item) => item['subcategory'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subcategories.map((subcategory) {
//                   return ChoiceChip(
//                     label: Text(subcategory),
//                     selected: _selectedSubcategory == subcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubcategory = selected ? subcategory : null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subSubcategories = inventoryProvider.items
//             .where((item) =>
//                 item['category'] == _selectedCategory &&
//                 item['subcategory'] == _selectedSubcategory &&
//                 item['subSubcategory'] != null)
//             .map((item) => item['subSubcategory'] as String)
//             .toSet();

//         if (subSubcategories.isEmpty) {
//           return SizedBox.shrink();
//         }

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Sub-subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subSubcategories.map((subSubcategory) {
//                   return ChoiceChip(
//                     label: Text(subSubcategory),
//                     selected: _selectedSubSubcategory == subSubcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubSubcategory =
//                             selected ? subSubcategory : null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuickAddGrid() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == null ||
//               item['category'] == _selectedCategory;
//           bool subcategoryMatch = _selectedSubcategory == null ||
//               item['subcategory'] == _selectedSubcategory;
//           bool subSubcategoryMatch = _selectedSubSubcategory == null ||
//               item['subSubcategory'] == _selectedSubSubcategory;
//           return categoryMatch && subcategoryMatch && subSubcategoryMatch;
//         }).toList();

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: GridView.builder(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 3,
//               childAspectRatio: 2.5,
//               crossAxisSpacing: 10,
//               mainAxisSpacing: 10,
//             ),
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 elevation: 2,
//                 child: InkWell(
//                   onTap: () => _quickAddItem(item),
//                   child: Center(
//                     child: Text(
//                       item['name'],
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                       overflow: TextOverflow.ellipsis,
//                       maxLines: 2,
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   void _quickAddItem(Map<String, dynamic> item) {
//     setState(() {
//       String itemId = item['id'] as String;
//       bool isPipe = item['isPipe'] as bool? ?? false;

//       if (_selectedItems.containsKey(itemId)) {
//         if (isPipe) {
//           _selectedItems[itemId]!['pcs'] =
//               (_selectedItems[itemId]!['pcs'] as int? ?? 0) + 1;
//           _selectedItems[itemId]!['meters'] =
//               (_selectedItems[itemId]!['meters'] as double? ?? 0.0) +
//                   (item['pipeLength'] as double? ?? 1.0);
//         } else {
//           _selectedItems[itemId]!['quantity'] =
//               (_selectedItems[itemId]!['quantity'] as int? ?? 0) + 1;
//         }
//       } else {
//         _selectedItems[itemId] = {
//           'isPipe': isPipe,
//           'name': item['name'] as String? ?? 'Unknown Item',
//           'unit': item['unit'] as String? ?? 'pc',
//           'category': item['category'] as String? ?? 'Uncategorized',
//           'subcategory': item['subcategory'] as String? ?? 'N/A',
//         };
//         if (isPipe) {
//           _selectedItems[itemId]!['pcs'] = 1;
//           _selectedItems[itemId]!['meters'] =
//               item['pipeLength'] as double? ?? 1.0;
//           _selectedItems[itemId]!['pipeLength'] =
//               item['pipeLength'] as double? ?? 1.0;
//         } else {
//           _selectedItems[itemId]!['quantity'] = 1;
//         }
//       }
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Added ${item['name'] ?? 'Item'} to the request'),
//         duration: Duration(seconds: 1),
//       ),
//     );
//     _animateFloatingActionButton();
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == null ||
//               item['category'] == _selectedCategory;
//           bool subcategoryMatch = _selectedSubcategory == null ||
//               item['subcategory'] == _selectedSubcategory;
//           bool subSubcategoryMatch = _selectedSubSubcategory == null ||
//               item['subSubcategory'] == _selectedSubSubcategory;
//           bool searchMatch = _searchController.text.isEmpty ||
//               item['name']
//                   .toLowerCase()
//                   .contains(_searchController.text.toLowerCase());
//           return categoryMatch &&
//               subcategoryMatch &&
//               subSubcategoryMatch &&
//               searchMatch;
//         }).toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: ListTile(
//                 title: Text(
//                   item['name'],
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 2,
//                 ),
//                 subtitle: Text('${item['category']} - ${item['subcategory']}'),
//                 trailing: isPipe
//                     ? _buildPipeControls(item)
//                     : _buildQuantityControls(item),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     return ElevatedButton(
//       child: Text('Select'),
//       onPressed: () => _showPipeSelectionModal(item['id'], item),
//     );
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       final pcs = item['pcs'] as int? ?? 0;
//       final meters = item['meters'] as double? ?? 0.0;
//       final quantity = item['quantity'] as int? ?? 0;

//       return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Text(
//             'Selected Items',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(
//                             itemId, itemData['quantity'] as int? ?? 0),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                       _animateFloatingActionButton();
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(
//                         isPipe ? Icons.architecture : Icons.shopping_cart,
//                         color: Colors.white),
//                     backgroundColor: isPipe ? Colors.orange : Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       isPipe
//                           ? Text(
//                               'Pieces: ${itemData['pcs']}, Length: ${itemData['meters'].toStringAsFixed(2)} m')
//                           : Text(
//                               'Quantity: ${itemData['quantity']} ${itemData['unit']}'),
//                       Text(
//                           '${itemData['category']} - ${itemData['subcategory']}'),
//                     ],
//                   ),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildFloatingActionButton() {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _animation.value,
//           child: FloatingActionButton.extended(
//             onPressed: _selectedItems.isEmpty
//                 ? null
//                 : () => _showRequestDetailsDialog(context),
//             label: Text('Send Request'),
//             icon: Icon(Icons.send),
//             backgroundColor:
//                 _selectedItems.isEmpty ? Colors.grey : Colors.blue.shade700,
//           ),
//         );
//       },
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//           'category': item['category'],
//           'subcategory': item['subcategory'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//     _animateFloatingActionButton();
//   }

//   void _updatePipePieces(
//       String itemId, int newPieces, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newPieces * pipeLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       int newPieces = (newLength / pipeLength).ceil();
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   void _animateFloatingActionButton() {
//     if (_selectedItems.isNotEmpty) {
//       _animationController.forward();
//     } else {
//       _animationController.reverse();
//     }
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text('No locations available.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Future<void> _showAddLocationDialog(BuildContext context) async {
//   //   final TextEditingController _locationController = TextEditingController();
//   //   return showDialog(
//   //     context: context,
//   //     builder: (context) => AlertDialog(
//   //       title: Text('Add New Location'),
//   //       content: TextField(
//   //         controller: _locationController,
//   //         decoration: InputDecoration(
//   //           labelText: 'Location Name',
//   //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//   //         ),
//   //       ),
//   //       actions: [
//   //         TextButton(
//   //           onPressed: () => Navigator.of(context).pop(),
//   //           child: Text('Cancel'),
//   //         ),
//   //         ElevatedButton(
//   //           onPressed: () async {
//   //             if (_locationController.text.isNotEmpty) {
//   //               await Provider.of<LocationProvider>(context, listen: false)
//   //                   .addLocation(_locationController.text);
//   //               Navigator.of(context).pop();
//   //               ScaffoldMessenger.of(context).showSnackBar(
//   //                 SnackBar(content: Text('Location added for admin approval')),
//   //               );
//   //             }
//   //           },
//   //           child: Text('Add'),
//   //           style:
//   //               ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//   // Future<void> _showAddLocationDialog(BuildContext context) async {
//   //   final TextEditingController _locationController = TextEditingController();
//   //   final formKey = GlobalKey<FormState>();

//   //   return showDialog(
//   //     context: context,
//   //     builder: (BuildContext dialogContext) => AlertDialog(
//   //       title: Text('Suggest New Location'),
//   //       content: Form(
//   //         key: formKey,
//   //         child: TextFormField(
//   //           controller: _locationController,
//   //           decoration: InputDecoration(
//   //             labelText: 'Location Name',
//   //             border:
//   //                 OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//   //           ),
//   //           validator: (value) {
//   //             if (value == null || value.isEmpty) {
//   //               return 'Please enter a location name';
//   //             }
//   //             return null;
//   //           },
//   //         ),
//   //       ),
//   //       actions: [
//   //         TextButton(
//   //           onPressed: () => Navigator.of(dialogContext).pop(),
//   //           child: Text('Cancel'),
//   //         ),
//   //         ElevatedButton(
//   //           onPressed: () async {
//   //             if (formKey.currentState!.validate()) {
//   //               try {
//   //                 await Provider.of<LocationProvider>(context, listen: false)
//   //                     .suggestLocation(_locationController.text);
//   //                 Navigator.of(dialogContext).pop();
//   //                 ScaffoldMessenger.of(context).showSnackBar(
//   //                   SnackBar(
//   //                     content:
//   //                         Text('Location suggestion submitted for approval'),
//   //                   ),
//   //                 );
//   //               } catch (e) {
//   //                 print('Error suggesting location: $e');
//   //                 ScaffoldMessenger.of(context).showSnackBar(
//   //                   SnackBar(
//   //                     content:
//   //                         Text('Error suggesting location: ${e.toString()}'),
//   //                     backgroundColor: Colors.red,
//   //                   ),
//   //                 );
//   //               }
//   //             }
//   //           },
//   //           child: Text('Suggest'),
//   //           style:
//   //               ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//   // Future<void> _showAddLocationDialog(BuildContext context) async {
//   //   final TextEditingController _locationController = TextEditingController();
//   //   final formKey = GlobalKey<FormState>();

//   //   return showDialog(
//   //     context: context,
//   //     builder: (BuildContext dialogContext) => AlertDialog(
//   //       title: Text('Suggest New Location'),
//   //       content: Form(
//   //         key: formKey,
//   //         child: TextFormField(
//   //           controller: _locationController,
//   //           decoration: InputDecoration(
//   //             labelText: 'Location Name',
//   //             border:
//   //                 OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//   //           ),
//   //           validator: (value) {
//   //             if (value == null || value.isEmpty) {
//   //               return 'Please enter a location name';
//   //             }
//   //             return null;
//   //           },
//   //         ),
//   //       ),
//   //       actions: [
//   //         TextButton(
//   //           onPressed: () => Navigator.of(dialogContext).pop(),
//   //           child: Text('Cancel'),
//   //         ),
//   //         ElevatedButton(
//   //           onPressed: () async {
//   //             if (formKey.currentState!.validate()) {
//   //               try {
//   //                 await Provider.of<LocationProvider>(context, listen: false)
//   //                     .suggestLocation(_locationController.text);
//   //                 Navigator.of(dialogContext).pop();
//   //                 ScaffoldMessenger.of(context).showSnackBar(
//   //                   SnackBar(
//   //                     content:
//   //                         Text('Location suggestion submitted for approval'),
//   //                   ),
//   //                 );
//   //               } catch (e) {
//   //                 print('Error suggesting location: $e');
//   //                 Navigator.of(dialogContext).pop();
//   //                 ScaffoldMessenger.of(context).showSnackBar(
//   //                   SnackBar(
//   //                     content:
//   //                         Text('Error suggesting location: ${e.toString()}'),
//   //                     backgroundColor: Colors.red,
//   //                   ),
//   //                 );
//   //               }
//   //             }
//   //           },
//   //           child: Text('Suggest'),
//   //           style:
//   //               ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
//   //              // Use a post-frame callback to update the state
// //                   WidgetsBinding.instance.addPostFrameCallback((_) {
// //                     ScaffoldMessenger.of(context).showSnackBar(
// //                       SnackBar(
// //                           content: Text(
// //                               'Location suggestion submitted for approval')),
// //                     );
// //                   });
// //                 } catch (e) {
// //                   ScaffoldMessenger.of(context).showSnackBar(
// //                     SnackBar(content: Text('Error suggesting location: $e')),
// //                   );
// //                 }
// //               }
// //             },
// //             child: Text('Suggest'),
// //             style:
// //                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

//   Future<void> _pickContact() async {
//     var status = await Permission.contacts.status;
//     if (status.isGranted) {
//       try {
//         Contact? contact = await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           String phoneNumber = contact.phones?.first.value ?? '';
//           phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
//           if (phoneNumber.length > 10) {
//             phoneNumber = phoneNumber.substring(phoneNumber.length - 10);
//           }
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text = phoneNumber;
//           });
//         }
//       } catch (e) {
//         print('Error picking contact: $e');
//       }
//     } else {
//       showPermissionDeniedDialog(context);
//     }
//   }

//   void showPermissionDeniedDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: Text('Contact Permission Required'),
//         content: Text(
//             'This app needs access to contacts to function properly. Please grant permission in the app settings.'),
//         actions: <Widget>[
//           TextButton(
//             child: Text('Cancel'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           TextButton(
//             child: Text('Open Settings'),
//             onPressed: () {
//               Navigator.of(context).pop();
//               AppSettings.openAppSettings();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all the required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('User email not available. Please log in again.')),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           double meters = itemData['meters'] as double? ?? 0.0;
//           int pcs = itemData['pcs'] as int? ?? 0;
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': pcs,
//             'meters': meters,
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//             'unit': 'pcs',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       String requestId = await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       // Generate a unique code for the request
//       String uniqueCode = _generateUniqueCode();

//       // Prepare the SMS message
//       String smsMessage = '''
// New Request: $requestId
// Code: $uniqueCode
// Location: $_selectedLocation
// Items: ${items.length}
// Picker: ${_pickerNameController.text}
// ''';

//       // Send SMS using Twilio Firebase Extension
//       await _sendSMSUsingTwilioExtension(
//           _pickerContactController.text, smsMessage);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created and SMS sent successfully')),
//       );

//       _shareRequestDetails(requestId, items);

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request or sending SMS: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request or sending SMS: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   String _generateUniqueCode() {
//     // Generate a random 6-digit code
//     return (100000 + Random().nextInt(900000)).toString();
//   }

//   Future<void> _sendSMSUsingTwilioExtension(
//       String phoneNumber, String message) async {
//     try {
//       // Add a document to the 'messages' collection to trigger the Twilio extension
//       await FirebaseFirestore.instance.collection('messages').add({
//         'to': phoneNumber,
//         'body': message,
//         // You can add the 'from' field here if you want to specify a sender number
//         // 'from': 'YOUR_TWILIO_PHONE_NUMBER',
//       });

//       print("SMS queued for delivery");
//     } catch (e) {
//       print("Error queuing SMS: $e");
//       throw e;
//     }
//   }
//   // Future<void> _submitRequest(BuildContext context) async {
//   //   if (_pickerNameController.text.isEmpty ||
//   //       _pickerContactController.text.isEmpty ||
//   //       _pickerContactController.text.length != 10 ||
//   //       _selectedLocation.isEmpty) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text('Please fill all the required fields with valid data.'),
//   //       ),
//   //     );
//   //     return;
//   //   }

//   //   setState(() => _isLoading = true);

//   //   final currentUserEmail =
//   //       Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//   //   if (currentUserEmail == null) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //           content: Text('User email not available. Please log in again.')),
//   //     );
//   //     setState(() => _isLoading = false);
//   //     return;
//   //   }

//   //   try {
//   //     final requestProvider =
//   //         Provider.of<RequestProvider>(context, listen: false);
//   //     final inventoryProvider =
//   //         Provider.of<InventoryProvider>(context, listen: false);

//   //     List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//   //       final itemData = entry.value;
//   //       final isPipe = itemData['isPipe'] ?? false;

//   //       if (isPipe) {
//   //         double meters = itemData['meters'] as double? ?? 0.0;
//   //         int pcs = itemData['pcs'] as int? ?? 0;
//   //         return {
//   //           'id': entry.key,
//   //           'name': itemData['name'],
//   //           'quantity': pcs,
//   //           'meters': meters,
//   //           'isPipe': true,
//   //           'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //           'category': itemData['category'] ?? 'Uncategorized',
//   //           'subcategory': itemData['subcategory'] ?? 'N/A',
//   //           'unit': 'pcs',
//   //         };
//   //       } else {
//   //         return {
//   //           'id': entry.key,
//   //           'name': itemData['name'],
//   //           'quantity': itemData['quantity'],
//   //           'unit': itemData['unit'],
//   //           'isPipe': false,
//   //           'category': itemData['category'] ?? 'Uncategorized',
//   //           'subcategory': itemData['subcategory'] ?? 'N/A',
//   //         };
//   //       }
//   //     }).where((item) {
//   //       if (item['isPipe']) {
//   //         return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//   //       } else {
//   //         return (item['quantity'] as num) > 0;
//   //       }
//   //     }).toList();

//   //     String requestId = await requestProvider.addRequest(
//   //       items,
//   //       _selectedLocation,
//   //       _pickerNameController.text,
//   //       _pickerContactController.text,
//   //       _noteController.text,
//   //       currentUserEmail,
//   //       inventoryProvider,
//   //     );

//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Request created successfully')),
//   //     );

//   //     _shareRequestDetails(requestId, items);

//   //     Navigator.of(context).pop(); // Close the dialog
//   //     Navigator.of(context).pop(); // Go back to the previous screen
//   //   } catch (e) {
//   //     print("Error creating request: $e");
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Error creating request: $e')),
//   //     );
//   //   } finally {
//   //     setState(() => _isLoading = false);
//   //   }
//   // }
//   // // Future<void> _submitRequest(BuildContext context) async {
//   //   if (_pickerNameController.text.isEmpty ||
//   //       _pickerContactController.text.isEmpty ||
//   //       _pickerContactController.text.length != 10 ||
//   //       _selectedLocation.isEmpty) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text('Please fill all the required fields with valid data.'),
//   //       ),
//   //     );
//   //     return;
//   //   }

//   //   setState(() => _isLoading = true);

//   //   final currentUserEmail =
//   //       Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//   //   if (currentUserEmail == null) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //           content: Text('User email not available. Please log in again.')),
//   //     );
//   //     setState(() => _isLoading = false);
//   //     return;
//   //   }

//   //   try {
//   //     final requestProvider =
//   //         Provider.of<RequestProvider>(context, listen: false);
//   //     final inventoryProvider =
//   //         Provider.of<InventoryProvider>(context, listen: false);

//   //     List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//   //       final itemData = entry.value;
//   //       final isPipe = itemData['isPipe'] ?? false;

//   //       if (isPipe) {
//   //         double meters = itemData['meters'] as double? ?? 0.0;
//   //         int pcs = itemData['pcs'] as int? ?? 0;
//   //         return {
//   //           'id': entry.key,
//   //           'name': itemData['name'],
//   //           'quantity': pcs,
//   //           'meters': meters,
//   //           'isPipe': true,
//   //           'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //           'category': itemData['category'] ?? 'Uncategorized',
//   //           'subcategory': itemData['subcategory'] ?? 'N/A',
//   //           'unit': 'pcs',
//   //         };
//   //       } else {
//   //         return {
//   //           'id': entry.key,
//   //           'name': itemData['name'],
//   //           'quantity': itemData['quantity'],
//   //           'unit': itemData['unit'],
//   //           'isPipe': false,
//   //           'category': itemData['category'] ?? 'Uncategorized',
//   //           'subcategory': itemData['subcategory'] ?? 'N/A',
//   //         };
//   //       }
//   //     }).where((item) {
//   //       if (item['isPipe']) {
//   //         return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//   //       } else {
//   //         return (item['quantity'] as num) > 0;
//   //       }
//   //     }).toList();

//   //     String requestId = await requestProvider.addRequest(
//   //       items,
//   //       _selectedLocation,
//   //       _pickerNameController.text,
//   //       _pickerContactController.text,
//   //       _noteController.text,
//   //       currentUserEmail,
//   //       inventoryProvider,
//   //     );

//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Request created successfully')),
//   //     );

//   //     _shareRequestDetails(requestId, items);

//   //     Navigator.of(context).pop(); // Close the dialog
//   //     Navigator.of(context).pop(); // Go back to the previous screen
//   //   } catch (e) {
//   //     print("Error creating request: $e");
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Error creating request: $e')),
//   //     );
//   //   } finally {
//   //     setState(() => _isLoading = false);
//   //   }
//   // }

//   void _shareRequestDetails(
//       String requestId, List<Map<String, dynamic>> items) {
//     String formattedDate =
//         DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
//     String message = '''
// Request Details:
// Date: $formattedDate
// Request ID: $requestId

// Items:
// ${items.map((item) {
//       if (item['isPipe']) {
//         return "${item['name']} - ${item['quantity']} pcs (${item['meters'].toStringAsFixed(2)} m)";
//       } else {
//         return "${item['name']} - ${item['quantity']} ${item['unit']}";
//       }
//     }).join('\n')}

// Location: $_selectedLocation
// Picker: ${_pickerNameController.text}
// Contact: ${_pickerContactController.text}

// Note: ${_noteController.text}
// ''';

//     Share.share(message, subject: 'New Request Details');
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(
//             labelText: 'Quantity',
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController pcsController =
//         TextEditingController(text: itemData['pcs'].toString());
//     final TextEditingController metersController =
//         TextEditingController(text: itemData['meters'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: pcsController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Quantity (pieces)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: metersController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Length (meters)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newPcs = int.tryParse(pcsController.text) ?? 0;
//               double newMeters = double.tryParse(metersController.text) ?? 0.0;
//               _updatePipePieces(itemId, newPcs, itemData);
//               _updatePipeLength(itemId, newMeters, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showPipeSelectionModal(String itemId, Map<String, dynamic> itemData) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (context) => SingleChildScrollView(
//         child: Container(
//           padding:
//               EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
//           child: PipeSelectionModal(
//             initialData: _selectedItems[itemId] ?? {},
//             onUpdate: (updatedData) {
//               setState(() {
//                 _selectedItems[itemId] = {
//                   ..._selectedItems[itemId] ?? {},
//                   ...updatedData,
//                   'isPipe': true,
//                   'name': itemData['name'],
//                   'unit': 'pcs',
//                   'category': itemData['category'],
//                   'subcategory': itemData['subcategory'],
//                 };
//               });
//               _animateFloatingActionButton();
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }
// }

// class PipeSelectionModal extends StatefulWidget {
//   final Map<String, dynamic> initialData;
//   final Function(Map<String, dynamic>) onUpdate;

//   PipeSelectionModal({required this.initialData, required this.onUpdate});

//   @override
//   _PipeSelectionModalState createState() => _PipeSelectionModalState();
// }

// class _PipeSelectionModalState extends State<PipeSelectionModal> {
//   late double _selectedLength;
//   late int _selectedPieces;
//   late double _pipeLength;

//   @override
//   void initState() {
//     super.initState();
//     _selectedLength = widget.initialData['meters'] ?? 0.0;
//     _selectedPieces = widget.initialData['pcs'] ?? 0;
//     _pipeLength = widget.initialData['pipeLength'] ?? 1.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text('Select Pipe Length',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [3.0, 6.0, 9.0, 12.0].map((length) {
//               return ElevatedButton(
//                 child: Text('${length.toStringAsFixed(1)}m'),
//                 onPressed: () => _updateLength(length),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       _selectedLength == length ? Colors.blue : null,
//                 ),
//               );
//             }).toList(),
//           ),
//           SizedBox(height: 20),
//           Slider(
//             value: _selectedLength,
//             min: 0,
//             max: 20,
//             divisions: 40,
//             label: _selectedLength.toStringAsFixed(1),
//             onChanged: (value) => _updateLength(value),
//           ),
//           Text('Selected Length: ${_selectedLength.toStringAsFixed(1)}m'),
//           SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove_circle_outline),
//                 onPressed: _selectedPieces > 0
//                     ? () => _updatePieces(_selectedPieces - 1)
//                     : null,
//               ),
//               Text('$_selectedPieces pieces', style: TextStyle(fontSize: 18)),
//               IconButton(
//                 icon: Icon(Icons.add_circle_outline),
//                 onPressed: () => _updatePieces(_selectedPieces + 1),
//               ),
//             ],
//           ),
//           SizedBox(height: 20),
//           Text(
//               'Total Length: ${(_selectedLength * _selectedPieces).toStringAsFixed(1)}m',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           SizedBox(height: 20),
//           ElevatedButton(
//             child: Text('Confirm Selection'),
//             onPressed: () {
//               widget.onUpdate({
//                 'meters': _selectedLength * _selectedPieces,
//                 'pcs': _selectedPieces,
//                 'pipeLength': _pipeLength,
//               });
//               Navigator.of(context).pop();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _updateLength(double length) {
//     setState(() {
//       _selectedLength = length;
//       _selectedPieces = (_selectedLength / _pipeLength).ceil();
//     });
//   }

//   void _updatePieces(int pieces) {
//     setState(() {
//       _selectedPieces = pieces;
//       _selectedLength = _selectedPieces * _pipeLength;
//     });
//   }
// }



























// import 'package:app_settings/app_settings.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_typeahead/flutter_typeahead.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';
// // import 'package:app_settings/app_settings.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen>
//     with SingleTickerProviderStateMixin {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   String _selectedLocation = '';
//   String? _selectedCategory;
//   String? _selectedSubcategory;
//   String? _selectedSubSubcategory;
//   bool _isLoading = false;
//   bool _isListening = false;

//   late AnimationController _animationController;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _initializeSpeech();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _initializeSpeech() async {
//     bool available = await _speech.initialize(
//       onStatus: (status) => print('Speech recognition status: $status'),
//       onError: (errorNotification) =>
//           print('Speech recognition error: $errorNotification'),
//     );
//     if (available) {
//       setState(() => _isListening = false);
//     } else {
//       print("The user has denied the use of speech recognition.");
//     }
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : Column(
//                     children: [
//                       _buildSearchBar(),
//                       _buildCategorySelector(),
//                       if (_selectedCategory != null)
//                         _buildSubcategorySelector(),
//                       if (_selectedSubcategory != null)
//                         _buildSubSubcategorySelector(),
//                       _buildQuickAddGrid(),
//                       _buildInventoryList(),
//                       _buildSelectedItemsList(),
//                       SizedBox(height: 80), // Add extra space at the bottom
//                     ],
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildFloatingActionButton(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: AnimatedTextKit(
//           animatedTexts: [
//             TypewriterAnimatedText(
//               'Create New Request',
//               textStyle: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20.0,
//               ),
//               speed: Duration(milliseconds: 100),
//             ),
//           ],
//           totalRepeatCount: 1,
//           pause: Duration(milliseconds: 1000),
//           displayFullTextOnTap: true,
//           stopPauseOnTap: true,
//         ),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Colors.blue.shade700,
//                 Colors.blue.shade900,
//               ],
//             ),
//           ),
//           child: Center(
//             child: Icon(
//               Icons.inventory,
//               size: 80,
//               color: Colors.white.withOpacity(0.3),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         children: [
//           Expanded(
//             child: TypeAheadField<Map<String, dynamic>>(
//               textFieldConfiguration: TextFieldConfiguration(
//                 controller: _searchController,
//                 decoration: InputDecoration(
//                   labelText: 'Search and add items',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(30)),
//                   prefixIcon: Icon(Icons.search),
//                 ),
//               ),
//               suggestionsCallback: (pattern) async {
//                 return await _getSuggestions(pattern);
//               },
//               itemBuilder: (context, suggestion) {
//                 return ListTile(
//                   title: Text(suggestion['name']),
//                   subtitle: Text(
//                       '${suggestion['category']} - ${suggestion['subcategory']}'),
//                 );
//               },
//               onSuggestionSelected: (suggestion) {
//                 _quickAddItem(suggestion);
//                 _searchController.clear();
//               },
//             ),
//           ),
//           IconButton(
//             icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
//             onPressed: _toggleListening,
//           ),
//         ],
//       ),
//     );
//   }

//   Future<List<Map<String, dynamic>>> _getSuggestions(String pattern) async {
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     return inventoryProvider.items
//         .where((item) =>
//             item['name'].toLowerCase().contains(pattern.toLowerCase()) ||
//             item['category'].toLowerCase().contains(pattern.toLowerCase()))
//         .toList();
//   }

//   void _toggleListening() {
//     if (!_isListening) {
//       bool available = _speech.isAvailable;
//       if (available) {
//         setState(() => _isListening = true);
//         _speech.listen(
//           onResult: (result) {
//             setState(() {
//               _searchController.text = result.recognizedWords;
//             });
//           },
//         );
//       }
//     } else {
//       setState(() => _isListening = false);
//       _speech.stop();
//     }
//   }

//   Widget _buildCategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = inventoryProvider.items
//             .map((item) => item['category'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Category',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: categories.map((category) {
//                   return ChoiceChip(
//                     label: Text(category),
//                     selected: _selectedCategory == category,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedCategory = selected ? category : null;
//                         _selectedSubcategory = null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subcategories = inventoryProvider.items
//             .where((item) => item['category'] == _selectedCategory)
//             .map((item) => item['subcategory'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subcategories.map((subcategory) {
//                   return ChoiceChip(
//                     label: Text(subcategory),
//                     selected: _selectedSubcategory == subcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubcategory = selected ? subcategory : null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subSubcategories = inventoryProvider.items
//             .where((item) =>
//                 item['category'] == _selectedCategory &&
//                 item['subcategory'] == _selectedSubcategory &&
//                 item['subSubcategory'] != null)
//             .map((item) => item['subSubcategory'] as String)
//             .toSet();

//         if (subSubcategories.isEmpty) {
//           return SizedBox.shrink();
//         }

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Sub-subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subSubcategories.map((subSubcategory) {
//                   return ChoiceChip(
//                     label: Text(subSubcategory),
//                     selected: _selectedSubSubcategory == subSubcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubSubcategory =
//                             selected ? subSubcategory : null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuickAddGrid() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == null ||
//               item['category'] == _selectedCategory;
//           bool subcategoryMatch = _selectedSubcategory == null ||
//               item['subcategory'] == _selectedSubcategory;
//           bool subSubcategoryMatch = _selectedSubSubcategory == null ||
//               item['subSubcategory'] == _selectedSubSubcategory;
//           return categoryMatch && subcategoryMatch && subSubcategoryMatch;
//         }).toList();

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: GridView.builder(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 3,
//               childAspectRatio: 2.5,
//               crossAxisSpacing: 10,
//               mainAxisSpacing: 10,
//             ),
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 elevation: 2,
//                 child: InkWell(
//                   onTap: () => _quickAddItem(item),
//                   child: Center(
//                     child: Text(
//                       item['name'],
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }


//   void _quickAddItem(Map<String, dynamic> item) {
//     setState(() {
//       String itemId = item['id'] as String;
//       bool isPipe = item['isPipe'] as bool? ?? false;

//       if (_selectedItems.containsKey(itemId)) {
//         if (isPipe) {
//           _selectedItems[itemId]!['pcs'] =
//               (_selectedItems[itemId]!['pcs'] as int? ?? 0) + 1;
//           _selectedItems[itemId]!['meters'] =
//               (_selectedItems[itemId]!['meters'] as double? ?? 0.0) +
//                   (item['pipeLength'] as double? ?? 1.0);
//         } else {
//           _selectedItems[itemId]!['quantity'] =
//               (_selectedItems[itemId]!['quantity'] as int? ?? 0) + 1;
//         }
//       } else {
//         _selectedItems[itemId] = {
//           'isPipe': isPipe,
//           'name': item['name'] as String? ?? 'Unknown Item',
//           'unit': item['unit'] as String? ?? 'pc',
//           'category': item['category'] as String? ?? 'Uncategorized',
//           'subcategory': item['subcategory'] as String? ?? 'N/A',
//         };

//         if (isPipe) {
//           _selectedItems[itemId]!['pcs'] = 1;
//           _selectedItems[itemId]!['meters'] =
//               item['pipeLength'] as double? ?? 1.0;
//           _selectedItems[itemId]!['pipeLength'] =
//               item['pipeLength'] as double? ?? 1.0;
//         } else {
//           _selectedItems[itemId]!['quantity'] = 1;
//         }
//       }
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Added ${item['name'] ?? 'Item'} to the request'),
//         duration: Duration(seconds: 1),
//       ),
//     );
//     _animateFloatingActionButton();
//   }


//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == null ||
//               item['category'] == _selectedCategory;
//           bool subcategoryMatch = _selectedSubcategory == null ||
//               item['subcategory'] == _selectedSubcategory;
//           bool subSubcategoryMatch = _selectedSubSubcategory == null ||
//               item['subSubcategory'] == _selectedSubSubcategory;
//           bool searchMatch = _searchController.text.isEmpty ||
//               item['name']
//                   .toLowerCase()
//                   .contains(_searchController.text.toLowerCase());
//           return categoryMatch &&
//               subcategoryMatch &&
//               subSubcategoryMatch &&
//               searchMatch;
//         }).toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: isPipe
//                   ? _buildPipeItemTile(item)
//                   : _buildRegularItemTile(item),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildPipeItemTile(Map<String, dynamic> item) {
//     double pipeLength = item['pipeLength'] ?? 1.0;
//     int selectedPieces = _selectedItems[item['id']]?['pcs'] ?? 0;
//     double selectedLength = _selectedItems[item['id']]?['meters'] ?? 0.0;

//     // Ensure selectedLength is within the Slider's range
//     double maxSliderValue = 30.0;
//     selectedLength = selectedLength.clamp(0.0, maxSliderValue);

//     return ExpansionTile(
//       title: Text(item['name'],
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//       subtitle: Text('Pipe - ${pipeLength}m per piece',
//           style: TextStyle(color: Colors.blue)),
//       leading: Icon(Icons.architecture, color: Colors.blue),
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Quick Select (meters):',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: [3.0, 6.0, 9.0, 12.0, 15.0, 18.0].map((length) {
//                   return ElevatedButton(
//                     child: Text('${length.toStringAsFixed(1)}m'),
//                     onPressed: () =>
//                         _quickSelectPipeLength(item['id'], length, item),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor:
//                           selectedLength == length ? Colors.blue : null,
//                     ),
//                   );
//                 }).toList(),
//               ),
//               SizedBox(height: 16),
//               Text('Fine Tune:', style: TextStyle(fontWeight: FontWeight.bold)),
//               Row(
//                 children: [
//                   Expanded(
//                     child: Slider(
//                       value: selectedLength,
//                       min: 0,
//                       max: maxSliderValue,
//                       divisions: 60,
//                       label: selectedLength.toStringAsFixed(1),
//                       onChanged: (value) =>
//                           _updatePipeLength(item['id'], value, item),
//                     ),
//                   ),
//                   Text('${selectedLength.toStringAsFixed(1)}m',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                 ],
//               ),
//               SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text('Pieces: $selectedPieces',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Row(
//                     children: [
//                       IconButton(
//                         icon: Icon(Icons.remove_circle_outline),
//                         onPressed: selectedPieces > 0
//                             ? () => _updatePipePieces(
//                                 item['id'], selectedPieces - 1, item)
//                             : null,
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.add_circle_outline),
//                         onPressed: () => _updatePipePieces(
//                             item['id'], selectedPieces + 1, item),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               SizedBox(height: 8),
//               Text(
//                   'Total Length: ${(selectedPieces * pipeLength).toStringAsFixed(1)}m',
//                   style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildRegularItemTile(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;

//     return ListTile(
//       title: Text(item['name'],
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//       subtitle: Text('${item['category']} - ${item['subcategory']}'),
//       trailing: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           IconButton(
//             icon: Icon(Icons.remove_circle_outline),
//             onPressed: quantity > 0
//                 ? () => _updateQuantity(item['id'], quantity - 1, item)
//                 : null,
//           ),
//           Text('$quantity',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//           IconButton(
//             icon: Icon(Icons.add_circle_outline),
//             onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatDimensions(Map<String, dynamic> item) {
//     List<String> dimensions = [];
//     if (item['length'] != null) dimensions.add('L: ${item['length']}');
//     if (item['width'] != null) dimensions.add('W: ${item['width']}');
//     if (item['height'] != null) dimensions.add('H: ${item['height']}');
//     return dimensions.join(', ');
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }


//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     if (!_selectedItems.containsKey(item['id'])) {
//       _selectedItems[item['id']] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'unit': 'pcs',
//         'pipeLength': item['pipeLength'] ?? 1.0,
//       };
//     }

//     int pieces = _selectedItems[item['id']]?['pcs'] ?? 0;
//     double length = _selectedItems[item['id']]?['meters'] ?? 0.0;
//     double pipeLength = _selectedItems[item['id']]?['pipeLength'] ?? 1.0;

//     return Card(
//       elevation: 2,
//       margin: EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Pipe Selection',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             SizedBox(height: 12),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Pieces:', style: TextStyle(fontWeight: FontWeight.bold)),
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: Icon(Icons.remove_circle_outline),
//                       onPressed: pieces > 0
//                           ? () =>
//                               _updatePipePieces(item['id'], pieces - 1, item)
//                           : null,
//                     ),
//                     Text('$pieces',
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.bold)),
//                     IconButton(
//                       icon: Icon(Icons.add_circle_outline),
//                       onPressed: () =>
//                           _updatePipePieces(item['id'], pieces + 1, item),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Total Length:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 Text('${length.toStringAsFixed(1)} m',
//                     style:
//                         TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//               ],
//             ),
//             SizedBox(height: 16),
//             Text('Quick Select Length:',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [3.0, 6.0, 9.0, 12.0].map((quickLength) {
//                 return ElevatedButton(
//                   child: Text('${quickLength.toStringAsFixed(1)}m'),
//                   onPressed: () =>
//                       _quickSelectPipeLength(item['id'], quickLength, item),
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     backgroundColor:
//                         length == quickLength ? Colors.blue.shade700 : null,
//                   ),
//                 );
//               }).toList(),
//             ),
//             SizedBox(height: 16),
//             Text('Custom Length:',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             SizedBox(height: 8),
//             Slider(
//               value: length,
//               min: 0,
//               max: 20,
//               divisions: 40,
//               label: length.toStringAsFixed(1),
//               onChanged: (value) => _updatePipeLength(item['id'], value, item),
//             ),
//             SizedBox(height: 8),
//             Text(
//                 'Selected: ${pieces} pieces of ${pipeLength.toStringAsFixed(1)}m each',
//                 style: TextStyle(fontStyle: FontStyle.italic)),
//           ],
//         ),
//       ),
//     );
//   }


//   void _showPipeSelectionModal(String itemId, Map<String, dynamic> itemData) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (context) => SingleChildScrollView(
//         child: Container(
//           padding:
//               EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
//           child: PipeSelectionModal(
//             initialData: _selectedItems[itemId] ?? {},
//             onUpdate: (updatedData) {
//               setState(() {
//                 _selectedItems[itemId] = {
//                   ..._selectedItems[itemId] ?? {},
//                   ...updatedData,
//                   'isPipe': true,
//                   'name': itemData['name'],
//                   'unit': 'pcs',
//                   'category': itemData['category'],
//                   'subcategory': itemData['subcategory'],
//                 };
//               });
//               _animateFloatingActionButton();
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   void _quickSelectPipeLength(
//       String itemId, double length, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       int newPieces = (length / pipeLength).ceil();
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': length,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       final pcs = item['pcs'] as int? ?? 0;
//       final meters = item['meters'] as double? ?? 0.0;
//       final quantity = item['quantity'] as int? ?? 0;

//       return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Text(
//             'Selected Items',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(
//                             itemId, itemData['quantity'] as int? ?? 0),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                       _animateFloatingActionButton();
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(
//                         isPipe ? Icons.architecture : Icons.shopping_cart,
//                         color: Colors.white),
//                     backgroundColor: isPipe ? Colors.orange : Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       isPipe
//                           ? Text(
//                               'Pieces: ${itemData['pcs']}, Length: ${itemData['meters'].toStringAsFixed(2)} m')
//                           : Text(
//                               'Quantity: ${itemData['quantity']} ${itemData['unit']}'),
//                       Text(
//                           '${itemData['category']} - ${itemData['subcategory']}'),
//                     ],
//                   ),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildFloatingActionButton() {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _animation.value,
//           child: FloatingActionButton.extended(
//             onPressed: _selectedItems.isEmpty
//                 ? null
//                 : () => _showRequestDetailsDialog(context),
//             label: Text('Send Request'),
//             icon: Icon(Icons.send),
//             backgroundColor:
//                 _selectedItems.isEmpty ? Colors.grey : Colors.blue.shade700,
//           ),
//         );
//       },
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//           'category': item['category'],
//           'subcategory': item['subcategory'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//     _animateFloatingActionButton();
//   }

//   void _updatePipePieces(
//       String itemId, int newPieces, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newPieces * pipeLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }


//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       int newPieces = (newLength / pipeLength).ceil();
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   void _animateFloatingActionButton() {
//     if (_selectedItems.isNotEmpty) {
//       _animationController.forward();
//     } else {
//       _animationController.reverse();
//     }
//   }

// // void _quickSelectPipeLength(
// //       String itemId, double length, Map<String, dynamic> itemData) {
// //     _updatePipeLength(itemId, length, itemData);
// //   }
// // ... (previous code remains the same)

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     var status = await Permission.contacts.status;
//     if (status.isGranted) {
//       try {
//         Contact? contact = await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text = contact.phones?.first.value ?? '';
//           });
//         }
//       } catch (e) {
//         print('Error picking contact: $e');
//         // Handle the error, maybe show a dialog to the user
//       }
//     } else if (status.isDenied) {
//       // Request permission
//       status = await Permission.contacts.request();
//       if (status.isGranted) {
//         _pickContact(); // Recursively call this function if permission is granted
//       } else {
//         showPermissionDeniedDialog(context);
//       }
//     } else if (status.isPermanentlyDenied) {
//       showPermissionDeniedDialog(context);
//     }
//   }

//   void showPermissionDeniedDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: Text('Contact Permission Required'),
//         content: Text(
//             'This app needs access to contacts to function properly. Please grant permission in the app settings.'),
//         actions: <Widget>[
//           TextButton(
//             child: Text('Cancel'),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           TextButton(
//             child: Text('Open Settings'),
//             onPressed: () {
//               Navigator.of(context).pop();
//               AppSettings.openAppSettings();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     print("Current contact permission status: $permission");

//     if (permission != PermissionStatus.granted) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       print("New contact permission status after request: $permissionStatus");
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   Future<void> _openContactPicker() async {
//     final Contact? contact = await ContactsService.openDeviceContactPicker();
//     if (contact != null) {
//       final phone = contact.phones?.firstWhere(
//         (phone) => phone.value != null,
//         orElse: () => Item(label: 'mobile', value: ''),
//       );
//       setState(() {
//         _pickerNameController.text = contact.displayName ?? '';
//         _pickerContactController.text = _formatPhoneNumber(phone?.value ?? '');
//       });
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("No contact selected")),
//       );
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     String title = "Contact Permission Required";
//     String content =
//         "This app needs access to your contacts to select a picker. ";

//     if (permissionStatus == PermissionStatus.denied) {
//       content += "Please grant the permission when prompted.";
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       content +=
//           "The permission has been permanently denied. Please enable it in the app settings:\n\n"
//           "1. Open your device's Settings app\n"
//           "2. Navigate to Apps or Application Manager\n"
//           "3. Find this app in the list\n"
//           "4. Tap on Permissions\n"
//           "5. Enable the Contacts permission";
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: Text(title),
//         content: Text(content),
//         actions: <Widget>[
//           TextButton(
//             child: Text('OK'),
//             onPressed: () async {
//               Navigator.of(context).pop();
//               if (permissionStatus == PermissionStatus.denied) {
//                 // Try requesting permission again
//                 PermissionStatus newStatus =
//                     await Permission.contacts.request();
//                 if (newStatus == PermissionStatus.granted) {
//                   _openContactPicker();
//                 }
//               } else if (permissionStatus ==
//                   PermissionStatus.permanentlyDenied) {
//                 // Open app settings
//                 openAppSettings();
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('User email not available. Please log in again.')),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           double meters = itemData['meters'] as double? ?? 0.0;
//           int pcs = itemData['pcs'] as int? ?? 0;
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': pcs,
//             'meters': meters,
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//             'unit': 'pcs',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(
//             labelText: 'Quantity',
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController pcsController =
//         TextEditingController(text: itemData['pcs'].toString());
//     final TextEditingController metersController =
//         TextEditingController(text: itemData['meters'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: pcsController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Quantity (pieces)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: metersController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Length (meters)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newPcs = int.tryParse(pcsController.text) ?? 0;
//               double newMeters = double.tryParse(metersController.text) ?? 0.0;
//               _updatePipePieces(itemId, newPcs, itemData);
//               _updatePipeLength(itemId, newMeters, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }
// }

// class PipeSelectionModal extends StatefulWidget {
//   final Map<String, dynamic> initialData;
//   final Function(Map<String, dynamic>) onUpdate;

//   PipeSelectionModal({required this.initialData, required this.onUpdate});

//   @override
//   _PipeSelectionModalState createState() => _PipeSelectionModalState();
// }

// class _PipeSelectionModalState extends State<PipeSelectionModal> {
//   late double _selectedLength;
//   late int _selectedPieces;
//   late double _pipeLength;

//   @override
//   void initState() {
//     super.initState();
//     _selectedLength = widget.initialData['meters'] ?? 0.0;
//     _selectedPieces = widget.initialData['pcs'] ?? 0;
//     _pipeLength = widget.initialData['pipeLength'] ?? 1.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text('Select Pipe Length',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [3.0, 6.0, 9.0, 12.0].map((length) {
//               return ElevatedButton(
//                 child: Text('${length.toStringAsFixed(1)}m'),
//                 onPressed: () => _updateLength(length),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       _selectedLength == length ? Colors.blue : null,
//                 ),
//               );
//             }).toList(),
//           ),
//           SizedBox(height: 20),
//           Slider(
//             value: _selectedLength,
//             min: 0,
//             max: 20,
//             divisions: 40,
//             label: _selectedLength.toStringAsFixed(1),
//             onChanged: (value) => _updateLength(value),
//           ),
//           Text('Selected Length: ${_selectedLength.toStringAsFixed(1)}m'),
//           SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove_circle_outline),
//                 onPressed: _selectedPieces > 0
//                     ? () => _updatePieces(_selectedPieces - 1)
//                     : null,
//               ),
//               Text('$_selectedPieces pieces', style: TextStyle(fontSize: 18)),
//               IconButton(
//                 icon: Icon(Icons.add_circle_outline),
//                 onPressed: () => _updatePieces(_selectedPieces + 1),
//               ),
//             ],
//           ),
//           SizedBox(height: 20),
//           Text(
//               'Total Length: ${(_selectedLength * _selectedPieces).toStringAsFixed(1)}m',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           SizedBox(height: 20),
//           ElevatedButton(
//             child: Text('Confirm Selection'),
//             onPressed: () {
//               widget.onUpdate({
//                 'meters': _selectedLength * _selectedPieces,
//                 'pcs': _selectedPieces,
//                 'pipeLength': _pipeLength,
//               });
//               Navigator.of(context).pop();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _updateLength(double length) {
//     setState(() {
//       _selectedLength = length;
//       _selectedPieces = (_selectedLength / _pipeLength).ceil();
//     });
//   }

//   void _updatePieces(int pieces) {
//     setState(() {
//       _selectedPieces = pieces;
//       _selectedLength = _selectedPieces * _pipeLength;
//     });
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:animated_text_kit/animated_text_kit.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen>
//     with SingleTickerProviderStateMixin {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String? _selectedCategory;
//   String? _selectedSubcategory;
//   String? _selectedSubSubcategory;
//   bool _isLoading = false;

//   late AnimationController _animationController;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : Column(
//                     children: [
//                       _buildSearchBar(),
//                       _buildCategorySelector(),
//                       if (_selectedCategory != null)
//                         _buildSubcategorySelector(),
//                       if (_selectedSubcategory != null)
//                         _buildSubSubcategorySelector(),
//                       _buildInventoryList(),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildFloatingActionButton(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         title: AnimatedTextKit(
//           animatedTexts: [
//             TypewriterAnimatedText(
//               'Create New Request',
//               textStyle: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20.0,
//               ),
//               speed: Duration(milliseconds: 100),
//             ),
//           ],
//           totalRepeatCount: 1,
//           pause: Duration(milliseconds: 1000),
//           displayFullTextOnTap: true,
//           stopPauseOnTap: true,
//         ),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Colors.blue.shade700,
//                 Colors.blue.shade900,
//               ],
//             ),
//           ),
//           child: Center(
//             child: Icon(
//               Icons.inventory,
//               size: 80,
//               color: Colors.white.withOpacity(0.3),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//   // Widget _buildSliverAppBar() {
//   //   return SliverAppBar(
//   //     expandedHeight: 200.0,
//   //     floating: false,
//   //     pinned: true,
//   //     flexibleSpace: FlexibleSpaceBar(
//   //       title: AnimatedTextKit(
//   //         animatedTexts: [
//   //           TypewriterAnimatedText(
//   //             'Create New Request',
//   //             textStyle: TextStyle(
//   //               color: Colors.white,
//   //               fontWeight: FontWeight.bold,
//   //               fontSize: 20.0,
//   //             ),
//   //             speed: Duration(milliseconds: 100),
//   //           ),
//   //         ],
//   //         totalRepeatCount: 1,
//   //         pause: Duration(milliseconds: 1000),
//   //         displayFullTextOnTap: true,
//   //         stopPauseOnTap: true,
//   //       ),
//   //       background: Stack(
//   //         fit: StackFit.expand,
//   //         children: [
//   //           Image.asset(
//   //             'assets/images/inventory_background.jpg',
//   //             fit: BoxFit.cover,
//   //           ),
//   //           Container(
//   //             decoration: BoxDecoration(
//   //               gradient: LinearGradient(
//   //                 begin: Alignment.topCenter,
//   //                 end: Alignment.bottomCenter,
//   //                 colors: [
//   //                   Colors.transparent,
//   //                   Colors.black.withOpacity(0.7),
//   //                 ],
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: TextField(
//         controller: _searchController,
//         decoration: InputDecoration(
//           labelText: 'Search Items',
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//           prefixIcon: Icon(Icons.search),
//           filled: true,
//           fillColor: Colors.grey.shade200,
//         ),
//         onChanged: (_) => setState(() {}),
//       ),
//     );
//   }

//   Widget _buildCategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = inventoryProvider.items
//             .map((item) => item['category'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Category',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: categories.map((category) {
//                   return ChoiceChip(
//                     label: Text(category),
//                     selected: _selectedCategory == category,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedCategory = selected ? category : null;
//                         _selectedSubcategory = null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subcategories = inventoryProvider.items
//             .where((item) => item['category'] == _selectedCategory)
//             .map((item) => item['subcategory'] as String)
//             .toSet();
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subcategories.map((subcategory) {
//                   return ChoiceChip(
//                     label: Text(subcategory),
//                     selected: _selectedSubcategory == subcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubcategory = selected ? subcategory : null;
//                         _selectedSubSubcategory = null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSubSubcategorySelector() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> subSubcategories = inventoryProvider.items
//             .where((item) =>
//                 item['category'] == _selectedCategory &&
//                 item['subcategory'] == _selectedSubcategory &&
//                 item['subSubcategory'] != null)
//             .map((item) => item['subSubcategory'] as String)
//             .toSet();

//         if (subSubcategories.isEmpty) {
//           return SizedBox.shrink();
//         }

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Select Sub-subcategory',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 8),
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: subSubcategories.map((subSubcategory) {
//                   return ChoiceChip(
//                     label: Text(subSubcategory),
//                     selected: _selectedSubSubcategory == subSubcategory,
//                     onSelected: (selected) {
//                       setState(() {
//                         _selectedSubSubcategory =
//                             selected ? subSubcategory : null;
//                       });
//                     },
//                   );
//                 }).toList(),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems =
//             inventoryProvider.items.where((item) {
//           bool categoryMatch = _selectedCategory == null ||
//               item['category'] == _selectedCategory;
//           bool subcategoryMatch = _selectedSubcategory == null ||
//               item['subcategory'] == _selectedSubcategory;
//           bool subSubcategoryMatch = _selectedSubSubcategory == null ||
//               item['subSubcategory'] == _selectedSubSubcategory;
//           bool searchMatch = _searchController.text.isEmpty ||
//               item['name']
//                   .toLowerCase()
//                   .contains(_searchController.text.toLowerCase());
//           return categoryMatch &&
//               subcategoryMatch &&
//               subSubcategoryMatch &&
//               searchMatch;
//         }).toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: ExpansionTile(
//                 title: Text(
//                   item['name'],
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 subtitle: Text(
//                   '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                 ),
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         if (item['length'] != null ||
//                             item['width'] != null ||
//                             item['height'] != null)
//                           Text(
//                             'Dimensions: ${_formatDimensions(item)}',
//                             style: TextStyle(
//                                 fontSize: 14, color: Colors.grey[600]),
//                           ),
//                         if (isPipe && item['pipeLength'] != null)
//                           Text(
//                             'Pipe Length: ${item['pipeLength']} meters',
//                             style: TextStyle(
//                                 fontSize: 14, color: Colors.grey[600]),
//                           ),
//                         SizedBox(height: 8),
//                         isPipe
//                             ? _buildPipeControls(item)
//                             : _buildQuantityControls(item),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   String _formatDimensions(Map<String, dynamic> item) {
//     List<String> dimensions = [];
//     if (item['length'] != null) dimensions.add('L: ${item['length']}');
//     if (item['width'] != null) dimensions.add('W: ${item['width']}');
//     if (item['height'] != null) dimensions.add('H: ${item['height']}');
//     return dimensions.join(', ');
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     if (!_selectedItems.containsKey(item['id'])) {
//       _selectedItems[item['id']] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'unit': 'pcs',
//         'pipeLength': item['pipeLength'] ?? 1.0,
//       };
//     }

//     int pieces = _selectedItems[item['id']]?['pcs'] ?? 0;
//     double length = _selectedItems[item['id']]?['meters'] ?? 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: pieces > 0
//                   ? () => _updatePipePieces(item['id'], pieces - 1, item)
//                   : null,
//             ),
//             Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () => _updatePipePieces(item['id'], pieces + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             Text('Length (m): '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: length > 0
//                   ? () => _updatePipeLength(item['id'], length - 1.0, item)
//                   : null,
//             ),
//             Text('$length', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeLength(item['id'], length + 1.0, item),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       final pcs = item['pcs'] as num? ?? 0;
//       final meters = item['meters'] as num? ?? 0.0;
//       final quantity = item['quantity'] as num? ?? 0;

//       return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Text(
//             'Selected Items',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             final int pcs = itemData['pcs'] as int? ?? 0;
//             final double meters = itemData['meters'] as double? ?? 0.0;
//             final int quantity = itemData['quantity'] as int? ?? 0;
//             final String unit = itemData['unit'] ?? '';

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(itemId, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       isPipe
//                           ? Text('Pieces: $pcs, Length: $meters m')
//                           : Text('Quantity: $quantity $unit'),
//                       if (itemData['length'] != null ||
//                           itemData['width'] != null ||
//                           itemData['height'] != null)
//                         Text('Dimensions: ${_formatDimensions(itemData)}'),
//                       if (isPipe && itemData['pipeLength'] != null)
//                         Text('Pipe Length: ${itemData['pipeLength']} meters'),
//                     ],
//                   ),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildFloatingActionButton() {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _animation.value,
//           child: FloatingActionButton.extended(
//             onPressed: _selectedItems.isEmpty
//                 ? null
//                 : () => _showRequestDetailsDialog(context),
//             label: Text('Send Request'),
//             icon: Icon(Icons.send),
//             backgroundColor:
//                 _selectedItems.isEmpty ? Colors.grey : Colors.blue.shade700,
//           ),
//         );
//       },
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//           'category': item['category'],
//           'subcategory': item['subcategory'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//     _animateFloatingActionButton();
//   }

//   void _updatePipePieces(
//       String itemId, int newPieces, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newPieces * pipeLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       int newPieces = (newLength / pipeLength).ceil();
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//     _animateFloatingActionButton();
//   }

//   void _animateFloatingActionButton() {
//     if (_selectedItems.isNotEmpty) {
//       _animationController.forward();
//     } else {
//       _animationController.reverse();
//     }
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('User email not available. Please log in again.')),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           double meters = itemData['meters'] as double? ?? 0.0;
//           int pcs = itemData['pcs'] as int? ?? 0;
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': pcs,
//             'meters': meters,
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//             'unit': 'pcs',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(
//             labelText: 'Quantity',
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController pcsController =
//         TextEditingController(text: itemData['pcs'].toString());
//     final TextEditingController metersController =
//         TextEditingController(text: itemData['meters'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: pcsController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Quantity (pieces)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: metersController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Length (meters)',
//                 border:
//                     OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newPcs = int.tryParse(pcsController.text) ?? 0;
//               double newMeters = double.tryParse(metersController.text) ?? 0.0;
//               _updatePipePieces(itemId, newPcs, itemData);
//               _updatePipeLength(itemId, newMeters, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen>
//     with SingleTickerProviderStateMixin {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   late AnimationController _animationController;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   // Widget _buildInventoryList() {
//   //   return Consumer<InventoryProvider>(
//   //     builder: (context, inventoryProvider, _) {
//   //       List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//   //           .where((item) =>
//   //               (_selectedCategory == 'All' ||
//   //                   item['category'] == _selectedCategory) &&
//   //               item['name']
//   //                   .toLowerCase()
//   //                   .contains(_searchController.text.toLowerCase()))
//   //           .toList();

//   //       return ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: filteredItems.length,
//   //         itemBuilder: (context, index) {
//   //           Map<String, dynamic> item = filteredItems[index];
//   //           bool isPipe = item['isPipe'] ?? false;
//   //           return Card(
//   //             elevation: 2,
//   //             margin: EdgeInsets.symmetric(vertical: 8),
//   //             child: Padding(
//   //               padding: const EdgeInsets.all(8.0),
//   //               child: Column(
//   //                 crossAxisAlignment: CrossAxisAlignment.start,
//   //                 children: [
//   //                   Text(
//   //                     item['name'],
//   //                     style:
//   //                         TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//   //                   ),
//   //                   Text(
//   //                     '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//   //                     style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//   //                   ),
//   //                   if (item['dimensionsString'] != null &&
//   //                       item['dimensionsString'] != 'N/A')
//   //                     Text(
//   //                       'Dimensions: ${item['dimensionsString']}',
//   //                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//   //                     ),
//   //                   SizedBox(height: 8),
//   //                   isPipe
//   //                       ? _buildPipeControls(item)
//   //                       : _buildQuantityControls(item),
//   //                 ],
//   //               ),
//   //             ),
//   //           );
//   //         },
//   //       );
//   //     },
//   //   );
//   // }
//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['name'],
//                       style:
//                           TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     Text(
//                       '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                     // Display dimensions if available
//                     if (item['length'] != null ||
//                         item['width'] != null ||
//                         item['height'] != null)
//                       Text(
//                         'Dimensions: ${_formatDimensions(item)}',
//                         style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                       ),
//                     if (isPipe && item['pipeLength'] != null)
//                       Text(
//                         'Pipe Length: ${item['pipeLength']} meters',
//                         style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                       ),
//                     SizedBox(height: 8),
//                     isPipe
//                         ? _buildPipeControls(item)
//                         : _buildQuantityControls(item),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   String _formatDimensions(Map<String, dynamic> item) {
//     List<String> dimensions = [];
//     if (item['length'] != null) dimensions.add('L: ${item['length']}');
//     if (item['width'] != null) dimensions.add('W: ${item['width']}');
//     if (item['height'] != null) dimensions.add('H: ${item['height']}');
//     return dimensions.join(', ');
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       final pcs = item['pcs'] as num? ?? 0;
//       final meters = item['meters'] as num? ?? 0.0;
//       final quantity = item['quantity'] as num? ?? 0;

//       return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             final int pcs = itemData['pcs'] as int? ?? 0;
//             final double meters = itemData['meters'] as double? ?? 0.0;
//             final int quantity = itemData['quantity'] as int? ?? 0;
//             final String unit = itemData['unit'] ?? '';

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(itemId, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       isPipe
//                           ? Text('Pieces: $pcs, Length: $meters m')
//                           : Text('Quantity: $quantity $unit'),
//                       if (itemData['length'] != null ||
//                           itemData['width'] != null ||
//                           itemData['height'] != null)
//                         Text('Dimensions: ${_formatDimensions(itemData)}'),
//                       if (isPipe && itemData['pipeLength'] != null)
//                         Text('Pipe Length: ${itemData['pipeLength']} meters'),
//                     ],
//                   ),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     if (!_selectedItems.containsKey(item['id'])) {
//       _selectedItems[item['id']] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'unit': 'pcs',
//         'pipeLength': item['pipeLength'] ?? 1.0,
//       };
//     }

//     int pieces = _selectedItems[item['id']]?['pcs'] ?? 0;
//     double length = _selectedItems[item['id']]?['meters'] ?? 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: pieces > 0
//                   ? () => _updatePipePieces(item['id'], pieces - 1, item)
//                   : null,
//             ),
//             Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () => _updatePipePieces(item['id'], pieces + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             Text('Length (m): '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: length > 0
//                   ? () => _updatePipeLength(item['id'], length - 1.0, item)
//                   : null,
//             ),
//             Text('$length', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeLength(item['id'], length + 1.0, item),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//           'category': item['category'],
//           'subcategory': item['subcategory'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipePieces(
//       String itemId, int newPieces, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newPieces * pipeLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//   }
//   // void _updatePipePieces(
//   //     String itemId, int newPieces, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'pcs': newPieces,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'pcs',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //       'category': itemData['category'],
//   //       'subcategory': itemData['subcategory'],
//   //     };
//   //   });
//   // }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       double pipeLength = itemData['pipeLength'] ?? 1.0;
//       int newPieces = (newLength / pipeLength).ceil();
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'meters': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs', // Keep the unit as 'pcs' in the inventory
//         'pipeLength': pipeLength,
//         'category': itemData['category'],
//         'subcategory': itemData['subcategory'],
//       };
//     });
//   }

//   // void _updatePipeLength(
//   //     String itemId, double newLength, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'meters': newLength,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'meters',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //       'category': itemData['category'],
//   //       'subcategory': itemData['subcategory'],
//   //     };
//   //   });
//   // }

//   // Widget _buildSelectedItemsList() {
//   //   List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//   //       _selectedItems.entries.where((entry) {
//   //     var item = entry.value;
//   //     final pcs = item['pcs'] as num? ?? 0;
//   //     final meters = item['meters'] as num? ?? 0.0;
//   //     final quantity = item['quantity'] as num? ?? 0;

//   //     return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//   //         (item['isPipe'] != true && quantity > 0);
//   //   }).toList();

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         'Selected Items',
//   //         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//   //       ),
//   //       SizedBox(height: 8),
//   //       ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: selectedItems.length,
//   //         itemBuilder: (context, index) {
//   //           String itemId = selectedItems[index].key;
//   //           Map<String, dynamic> itemData = selectedItems[index].value;
//   //           bool isPipe = itemData['isPipe'] ?? false;

//   //           final int pcs = itemData['pcs'] as int? ?? 0;
//   //           final double meters = itemData['meters'] as double? ?? 0.0;
//   //           final int quantity = itemData['quantity'] as int? ?? 0;
//   //           final String unit = itemData['unit'] ?? '';

//   //           return Slidable(
//   //             endActionPane: ActionPane(
//   //               motion: ScrollMotion(),
//   //               children: [
//   //                 SlidableAction(
//   //                   onPressed: (_) => isPipe
//   //                       ? _showEditPipeDialog(itemId, itemData)
//   //                       : _showEditQuantityDialog(itemId, quantity),
//   //                   backgroundColor: Colors.blue,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.edit,
//   //                   label: 'Edit',
//   //                 ),
//   //                 SlidableAction(
//   //                   onPressed: (_) {
//   //                     setState(() {
//   //                       _selectedItems.remove(itemId);
//   //                     });
//   //                   },
//   //                   backgroundColor: Colors.red,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.delete,
//   //                   label: 'Delete',
//   //                 ),
//   //               ],
//   //             ),
//   //             child: Card(
//   //               elevation: 2,
//   //               margin: EdgeInsets.symmetric(vertical: 8),
//   //               child: ListTile(
//   //                 leading: CircleAvatar(
//   //                   child: Icon(Icons.shopping_cart, color: Colors.white),
//   //                   backgroundColor: Colors.green,
//   //                 ),
//   //                 title: Text(itemData['name'] ?? 'Unknown Item',
//   //                     style: TextStyle(fontWeight: FontWeight.bold)),
//   //                 subtitle: isPipe
//   //                     ? Text('Pieces: $pcs, Length: $meters m')
//   //                     : Text('Quantity: $quantity $unit'),
//   //                 trailing: Icon(Icons.swipe_left, color: Colors.grey),
//   //               ),
//   //             ),
//   //           );
//   //         },
//   //       ),
//   //     ],
//   //   );
//   // }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('User email not available. Please log in again.')),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     // try {
//     //   final requestProvider =
//     //       Provider.of<RequestProvider>(context, listen: false);
//     //   final inventoryProvider =
//     //       Provider.of<InventoryProvider>(context, listen: false);

//     //   List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//     //     final itemData = entry.value;
//     //     final isPipe = itemData['isPipe'] ?? false;

//     //     if (isPipe) {
//     //       return {
//     //         'id': entry.key,
//     //         'name': itemData['name'],
//     //         'pcs': itemData['pcs'],
//     //         'meters': itemData['meters'],
//     //         'isPipe': true,
//     //         'pipeLength': itemData['pipeLength'] ?? 1.0,
//     //         'category': itemData['category'] ?? 'Uncategorized',
//     //         'subcategory': itemData['subcategory'] ?? 'N/A',
//     //       };
//     //     } else {
//     //       return {
//     //         'id': entry.key,
//     //         'name': itemData['name'],
//     //         'quantity': itemData['quantity'],
//     //         'unit': itemData['unit'],
//     //         'isPipe': false,
//     //         'category': itemData['category'] ?? 'Uncategorized',
//     //         'subcategory': itemData['subcategory'] ?? 'N/A',
//     //       };
//     //     }
//     //   }).where((item) {
//     //     if (item['isPipe']) {
//     //       return (item['pcs'] as num) > 0 || (item['meters'] as num) > 0;
//     //     } else {
//     //       return (item['quantity'] as num) > 0;
//     //     }
//     //   }).toList();

//     //   print("Items to be submitted: $items"); // Debug print

//     //   await requestProvider.addRequest(
//     //     items,
//     //     _selectedLocation,
//     //     _pickerNameController.text,
//     //     _pickerContactController.text,
//     //     _noteController.text,
//     //     currentUserEmail,
//     //     inventoryProvider,
//     //   );

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           double meters = itemData['meters'] as double? ?? 0.0;
//           int pcs = itemData['pcs'] as int? ?? 0;
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': pcs,
//             'meters': meters,
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//             'unit': 'pcs',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['quantity'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       print("Items to be submitted: $items"); // Debug print

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController pcsController =
//         TextEditingController(text: itemData['pcs'].toString());
//     final TextEditingController metersController =
//         TextEditingController(text: itemData['meters'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: pcsController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: metersController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newPcs = int.tryParse(pcsController.text) ?? 0;
//               double newMeters = double.tryParse(metersController.text) ?? 0.0;
//               _updatePipePieces(itemId, newPcs, itemData);
//               _updatePipeLength(itemId, newMeters, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['name'],
//                       style:
//                           TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     Text(
//                       '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     isPipe
//                         ? _buildPipeControls(item)
//                         : _buildQuantityControls(item),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     // Ensure the selected item entry exists
//     if (!_selectedItems.containsKey(item['id'])) {
//       _selectedItems[item['id']] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'unit': 'pcs', // Assuming default unit is 'pcs'
//         'pipeLength': item['pipeLength'] ?? 1.0, // Default to 1 if not set
//       };
//     }

//     int pieces = _selectedItems[item['id']]?['pcs'] ?? 0;
//     double length = _selectedItems[item['id']]?['meters'] ?? 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: pieces > 0
//                   ? () => _updatePipePieces(item['id'], pieces - 1, item)
//                   : null,
//             ),
//             Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () => _updatePipePieces(item['id'], pieces + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             Text('Length (m): '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: length > 0
//                   ? () => _updatePipeLength(item['id'], length - 1.0, item)
//                   : null,
//             ),
//             Text('$length', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeLength(item['id'], length + 1.0, item),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipePieces(
//       String itemId, int newPieces, Map<String, dynamic> itemData) {
//     setState(() {
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'pcs': newPieces,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': itemData['pipeLength'] ?? 1.0,
//       };
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'meters': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'meters',
//         'pipeLength': itemData['pipeLength'] ?? 1.0,
//       };
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     // Filter selected items, ensuring non-null values for comparison
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       // Ensure non-null quantity and length for comparison
//       final pcs = item['pcs'] as num? ?? 0;
//       final meters = item['meters'] as num? ?? 0.0;
//       final quantity = item['quantity'] as num? ?? 0;

//       return (item['isPipe'] == true && (pcs > 0 || meters > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             // Use null-aware operators to safely access data
//             final int pcs = itemData['pcs'] as int? ?? 0;
//             final double meters = itemData['meters'] as double? ?? 0.0;
//             final int quantity = itemData['quantity'] as int? ?? 0;
//             final String unit = itemData['unit'] ?? '';

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(itemId, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text('Pieces: $pcs, Length: $meters m')
//                       : Text('Quantity: $quantity $unit'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController pcsController =
//         TextEditingController(text: itemData['pcs'].toString());
//     final TextEditingController metersController =
//         TextEditingController(text: itemData['meters'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: pcsController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: metersController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newPcs = int.tryParse(pcsController.text) ?? 0;
//               double newMeters = double.tryParse(metersController.text) ?? 0.0;
//               _updatePipePieces(itemId, newPcs, itemData);
//               _updatePipeLength(itemId, newMeters, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'pcs': itemData['pcs'], // Use 'pcs' for pieces
//             'meters': itemData['meters'], // Use 'meters' for meters
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['pcs'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       print("Items to be submitted: $items"); // Debug print

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail!,
//         inventoryProvider,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['name'],
//                       style:
//                           TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     Text(
//                       '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     isPipe
//                         ? _buildPipeControls(item)
//                         : _buildQuantityControls(item),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   // Widget _buildPipeControls(Map<String, dynamic> item) {
//   //   // Ensure the selected item entry exists
//   //   if (!_selectedItems.containsKey(item['id'])) {
//   //     _selectedItems[item['id']] = {
//   //       'quantity': 0,
//   //       'length': 0.0,
//   //       'isPipe': true,
//   //       'name': item['name'],
//   //       'unit': 'pcs', // Assuming default unit is 'pcs'
//   //       'pipeLength': item['pipeLength'] ?? 1.0, // Default to 1 if not set
//   //     };
//   //   }

//   //   int pieces = _selectedItems[item['id']]?['quantity'] ?? 0;
//   //   double length = _selectedItems[item['id']]?['length'] ?? 0.0;

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Row(
//   //         children: [
//   //           Text('Pieces: '),
//   //           IconButton(
//   //             icon: Icon(Icons.remove_circle_outline),
//   //             onPressed: pieces > 0
//   //                 ? () => _updatePipeQuantity(item['id'], pieces - 1, item)
//   //                 : null,
//   //           ),
//   //           Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//   //           IconButton(
//   //             icon: Icon(Icons.add_circle_outline),
//   //             onPressed: () =>
//   //                 _updatePipeQuantity(item['id'], pieces + 1, item),
//   //           ),
//   //         ],
//   //       ),
//   //       Row(
//   //         children: [
//   //           Text('Length (m): '),
//   //           SizedBox(
//   //             width: 60,
//   //             child: TextField(
//   //               controller: TextEditingController(text: length.toString()),
//   //               keyboardType: TextInputType.number,
//   //               onChanged: (value) {
//   //                 double parsedLength = double.tryParse(value) ?? 0.0;
//   //                 _updatePipeLength(item['id'], parsedLength, item);
//   //               },
//   //               decoration: InputDecoration(
//   //                 contentPadding: EdgeInsets.symmetric(horizontal: 8),
//   //                 border: OutlineInputBorder(),
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ],
//   //   );
//   // }

//   // void _updateQuantity(
//   //     String itemId, int newQuantity, Map<String, dynamic> item) {
//   //   setState(() {
//   //     if (newQuantity > 0) {
//   //       _selectedItems[itemId] = {
//   //         'quantity': newQuantity,
//   //         'isPipe': item['isPipe'] ?? false,
//   //         'name': item['name'],
//   //         'unit': item['unit'],
//   //       };
//   //     } else {
//   //       _selectedItems.remove(itemId);
//   //     }
//   //   });
//   // }

//   // void _updatePipeQuantity(
//   //     String itemId, int newQuantity, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'quantity': newQuantity,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'pcs',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //     };
//   //   });
//   // }

//   // void _updatePipeLength(
//   //     String itemId, double newLength, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'length': newLength,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'meters',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //     };
//   //   });
//   // }

//   // Widget _buildSelectedItemsList() {
//   //   // Filter selected items, ensuring non-null values for comparison
//   //   List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//   //       _selectedItems.entries.where((entry) {
//   //     var item = entry.value;
//   //     // Ensure non-null quantity and length for comparison
//   //     final quantity = item['quantity'] as num? ?? 0;
//   //     final length = item['length'] as num? ?? 0;

//   //     return (item['isPipe'] == true && (quantity > 0 || length > 0)) ||
//   //         (item['isPipe'] != true && quantity > 0);
//   //   }).toList();

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         'Selected Items',
//   //         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//   //       ),
//   //       SizedBox(height: 8),
//   //       ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: selectedItems.length,
//   //         itemBuilder: (context, index) {
//   //           String itemId = selectedItems[index].key;
//   //           Map<String, dynamic> itemData = selectedItems[index].value;
//   //           bool isPipe = itemData['isPipe'] ?? false;

//   //           // Use null-aware operators to safely access data
//   //           final int quantity = itemData['quantity'] as int? ?? 0;
//   //           final double length = itemData['length'] as double? ?? 0.0;
//   //           final String unit = itemData['unit'] ?? '';

//   //           return Slidable(
//   //             endActionPane: ActionPane(
//   //               motion: ScrollMotion(),
//   //               children: [
//   //                 SlidableAction(
//   //                   onPressed: (_) => isPipe
//   //                       ? _showEditPipeDialog(itemId, itemData)
//   //                       : _showEditQuantityDialog(itemId, quantity),
//   //                   backgroundColor: Colors.blue,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.edit,
//   //                   label: 'Edit',
//   //                 ),
//   //                 SlidableAction(
//   //                   onPressed: (_) {
//   //                     setState(() {
//   //                       _selectedItems.remove(itemId);
//   //                     });
//   //                   },
//   //                   backgroundColor: Colors.red,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.delete,
//   //                   label: 'Delete',
//   //                 ),
//   //               ],
//   //             ),
//   //             child: Card(
//   //               elevation: 2,
//   //               margin: EdgeInsets.symmetric(vertical: 8),
//   //               child: ListTile(
//   //                 leading: CircleAvatar(
//   //                   child: Icon(Icons.shopping_cart, color: Colors.white),
//   //                   backgroundColor: Colors.green,
//   //                 ),
//   //                 title: Text(itemData['name'] ?? 'Unknown Item',
//   //                     style: TextStyle(fontWeight: FontWeight.bold)),
//   //                 subtitle: isPipe
//   //                     ? Text('Pieces: $quantity, Length: $length m')
//   //                     : Text('Quantity: $quantity $unit'),
//   //                 trailing: Icon(Icons.swipe_left, color: Colors.grey),
//   //               ),
//   //             ),
//   //           );
//   //         },
//   //       ),
//   //     ],
//   //   );
//   // }
//   // Widget _buildPipeControls(Map<String, dynamic> item) {
//   //   // Ensure the selected item entry exists
//   //   if (!_selectedItems.containsKey(item['id'])) {
//   //     _selectedItems[item['id']] = {
//   //       'quantity': 0,
//   //       'length': 0.0,
//   //       'isPipe': true,
//   //       'name': item['name'],
//   //       'unit': 'pcs', // Assuming default unit is 'pcs'
//   //       'pipeLength': item['pipeLength'] ?? 1.0, // Default to 1 if not set
//   //     };
//   //   }

//   //   int pieces = _selectedItems[item['id']]?['quantity'] ?? 0;
//   //   double length = _selectedItems[item['id']]?['length'] ?? 0.0;

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Row(
//   //         children: [
//   //           Text('Pieces: '),
//   //           IconButton(
//   //             icon: Icon(Icons.remove_circle_outline),
//   //             onPressed: pieces > 0
//   //                 ? () => _updatePipeQuantity(item['id'], pieces - 1, item)
//   //                 : null,
//   //           ),
//   //           Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//   //           IconButton(
//   //             icon: Icon(Icons.add_circle_outline),
//   //             onPressed: () =>
//   //                 _updatePipeQuantity(item['id'], pieces + 1, item),
//   //           ),
//   //         ],
//   //       ),
//   //       Row(
//   //         children: [
//   //           Text('Length (m): '),
//   //           IconButton(
//   //             icon: Icon(Icons.remove_circle_outline),
//   //             onPressed: length > 0
//   //                 ? () => _updatePipeLength(item['id'], length - 1, item)
//   //                 : null,
//   //           ),
//   //           Text('$length', style: TextStyle(fontWeight: FontWeight.bold)),
//   //           IconButton(
//   //             icon: Icon(Icons.add_circle_outline),
//   //             onPressed: () => _updatePipeLength(item['id'], length + 1, item),
//   //           ),
//   //         ],
//   //       ),
//   //     ],
//   //   );
//   // }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   // void _updatePipeQuantity(
//   //     String itemId, int newQuantity, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'quantity': newQuantity,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'pcs',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //     };
//   //   });
//   // }

//   // void _updatePipeLength(
//   //     String itemId, double newLength, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     _selectedItems[itemId] = {
//   //       ..._selectedItems[itemId] ?? {},
//   //       'length': newLength,
//   //       'isPipe': true,
//   //       'name': itemData['name'],
//   //       'unit': 'meters',
//   //       'pipeLength': itemData['pipeLength'] ?? 1.0,
//   //     };
//   //   });
//   // }
//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     // Ensure the selected item entry exists
//     if (!_selectedItems.containsKey(item['id'])) {
//       _selectedItems[item['id']] = {
//         'quantity': 0,
//         'length': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'unit': 'pcs', // Assuming default unit is 'pcs'
//         'pipeLength': item['pipeLength'] ?? 1.0, // Default to 1 if not set
//       };
//     }

//     int pieces = _selectedItems[item['id']]?['quantity'] ?? 0;
//     double length = _selectedItems[item['id']]?['length'] ?? 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: pieces > 0
//                   ? () => _updatePipeQuantity(item['id'], pieces - 1, item)
//                   : null,
//             ),
//             Text('$pieces', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeQuantity(item['id'], pieces + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             Text('Length (m): '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: length > 0
//                   ? () => _updatePipeLength(item['id'], length - 1.0, item)
//                   : null,
//             ),
//             Text('$length', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeLength(item['id'], length + 1.0, item),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _updatePipeQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> itemData) {
//     setState(() {
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'quantity': newQuantity,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'pcs',
//         'pipeLength': itemData['pipeLength'] ?? 1.0,
//       };
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       _selectedItems[itemId] = {
//         ..._selectedItems[itemId] ?? {},
//         'length': newLength,
//         'isPipe': true,
//         'name': itemData['name'],
//         'unit': 'meters',
//         'pipeLength': itemData['pipeLength'] ?? 1.0,
//       };
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     // Filter selected items, ensuring non-null values for comparison
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       // Ensure non-null quantity and length for comparison
//       final quantity = item['quantity'] as num? ?? 0;
//       final length = item['length'] as num? ?? 0;

//       return (item['isPipe'] == true && (quantity > 0 || length > 0)) ||
//           (item['isPipe'] != true && quantity > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;

//             // Use null-aware operators to safely access data
//             final int quantity = itemData['quantity'] as int? ?? 0;
//             final double length = itemData['length'] as double? ?? 0.0;
//             final String unit = itemData['unit'] ?? '';

//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(itemId, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text('Pieces: $quantity, Length: $length m')
//                       : Text('Quantity: $quantity $unit'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController quantityController =
//         TextEditingController(text: itemData['quantity'].toString());
//     final TextEditingController lengthController =
//         TextEditingController(text: itemData['length'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: quantityController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: lengthController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               double newLength = double.tryParse(lengthController.text) ?? 0.0;
//               _updatePipeQuantity(itemId, newQuantity, itemData);
//               _updatePipeLength(itemId, newLength, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'pcs': itemData['quantity'], // Use 'quantity' for pieces
//             'meters': itemData['length'], // Use 'length' for meters
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 1.0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['pcs'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       print("Items to be submitted: $items"); // Debug print

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail!,
//         inventoryProvider,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['name'],
//                       style:
//                           TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     Text(
//                       '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     isPipe ? _buildPipeInput(item) : _buildQuantityInput(item),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityInput(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       children: [
//         Text('Quantity: '),
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeInput(Map<String, dynamic> item) {
//     String itemId = item['id'];
//     if (!_selectedItems.containsKey(itemId)) {
//       _selectedItems[itemId] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'pipeLength': item['pipeLength'] ?? 0,
//         'category': item['category'] ?? 'Uncategorized',
//         'subcategory': item['subcategory'] ?? 'N/A',
//       };
//     }

//     return StatefulBuilder(
//       builder: (BuildContext context, StateSetter setState) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildUnitInput(itemId, 'pcs', setState),
//             SizedBox(height: 8),
//             _buildUnitInput(itemId, 'meters', setState),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildUnitInput(String itemId, String unit, StateSetter setState) {
//     double value = (_selectedItems[itemId]![unit] as num).toDouble();

//     void updateValue(double newValue) {
//       if (newValue >= 0) {
//         this.setState(() {
//           _selectedItems[itemId]![unit] =
//               unit == 'pcs' ? newValue.toInt() : newValue;
//         });
//         setState(() {});
//       }
//     }

//     return Row(
//       children: [
//         Text('$unit: '),
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: () => updateValue(value - (unit == 'pcs' ? 1 : 0.5)),
//         ),
//         Expanded(
//           child: TextFormField(
//             initialValue: value.toString(),
//             keyboardType: TextInputType.number,
//             onChanged: (inputValue) {
//               double? parsedValue = double.tryParse(inputValue);
//               if (parsedValue != null) {
//                 updateValue(parsedValue);
//               }
//             },
//             decoration: InputDecoration(
//               labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => updateValue(value + (unit == 'pcs' ? 1 : 0.5)),
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'quantity': newQuantity,
//           'isPipe': true,
//           'name': itemData['name'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newLength > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'length': newLength,
//           'isPipe': true,
//           'name': itemData['name'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       return (item['isPipe'] == true &&
//               ((item['pcs'] as num) > 0 || (item['meters'] as num) > 0)) ||
//           (item['isPipe'] != true && (item['quantity'] as num) > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;
//             return Slidable(
//               // ... (rest of your Slidable widget code)
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text(
//                           'Pieces: ${itemData['pcs']}, Length: ${itemData['meters']} m')
//                       : Text(
//                           'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController quantityController =
//         TextEditingController(text: itemData['quantity'].toString());
//     final TextEditingController lengthController =
//         TextEditingController(text: itemData['length'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: quantityController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: lengthController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               double newLength = double.tryParse(lengthController.text) ?? 0.0;
//               _updatePipeQuantity(itemId, newQuantity, itemData);
//               _updatePipeLength(itemId, newLength, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'pcs': itemData['pcs'],
//             'meters': itemData['meters'],
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['pcs'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       print("Items to be submitted: $items"); // Debug print

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail!,
//         inventoryProvider,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   // Widget _buildInventoryList() {
//   //   return Consumer<InventoryProvider>(
//   //     builder: (context, inventoryProvider, _) {
//   //       List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//   //           .where((item) =>
//   //               (_selectedCategory == 'All' ||
//   //                   item['category'] == _selectedCategory) &&
//   //               item['name']
//   //                   .toLowerCase()
//   //                   .contains(_searchController.text.toLowerCase()))
//   //           .toList();

//   //       return ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: filteredItems.length,
//   //         itemBuilder: (context, index) {
//   //           Map<String, dynamic> item = filteredItems[index];
//   //           bool isPipe = item['isPipe'] ?? false;
//   //           return Card(
//   //             elevation: 2,
//   //             margin: EdgeInsets.symmetric(vertical: 8),
//   //             child: ListTile(
//   //               title: Text(item['name'],
//   //                   style: TextStyle(fontWeight: FontWeight.bold)),
//   //               subtitle: Text(
//   //                   '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}'),
//   //               trailing:
//   //                   isPipe ? _buildPipeInput(item) : _buildQuantityInput(item),
//   //             ),
//   //           );
//   //         },
//   //       );
//   //     },
//   //   );
//   // }
//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item['name'],
//                       style:
//                           TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     Text(
//                       '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}',
//                       style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                     ),
//                     SizedBox(height: 8),
//                     isPipe ? _buildPipeInput(item) : _buildQuantityInput(item),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityInput(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       children: [
//         Text('Quantity: '),
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//   //   double length = _selectedItems[item['id']]?['length'] ?? 0.0;
//   //   String unit = _selectedItems[item['id']]?['unit'] ?? 'pcs';

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Row(
//   //         children: [
//   //           Text('Unit: '),
//   //           DropdownButton<String>(
//   //             value: unit,
//   //             items: ['pcs', 'meters'].map((String value) {
//   //               return DropdownMenuItem<String>(
//   //                 value: value,
//   //                 child: Text(value),
//   //               );
//   //             }).toList(),
//   //             onChanged: (newValue) {
//   //               setState(() {
//   //                 _selectedItems[item['id']]?['unit'] = newValue;
//   //               });
//   //             },
//   //           ),
//   //         ],
//   //       ),
//   //       SizedBox(height: 8),
//   //       Row(
//   //         children: [
//   //           Expanded(
//   //             child: TextFormField(
//   //               keyboardType: TextInputType.number,
//   //               initialValue:
//   //                   unit == 'pcs' ? quantity.toString() : length.toString(),
//   //               onChanged: (value) {
//   //                 if (unit == 'pcs') {
//   //                   _updatePipeQuantity(
//   //                       item['id'], int.tryParse(value) ?? 0, item);
//   //                 } else {
//   //                   _updatePipeLength(
//   //                       item['id'], double.tryParse(value) ?? 0.0, item);
//   //                 }
//   //               },
//   //               decoration: InputDecoration(
//   //                 labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//   //                 border: OutlineInputBorder(),
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ],
//   //   );
//   // }

//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//   //   double length = _selectedItems[item['id']]?['length'] ?? 0.0;
//   //   String unit = _selectedItems[item['id']]?['unit'] ?? 'pcs';

//   //   return Row(
//   //     mainAxisSize: MainAxisSize.min,
//   //     children: [
//   //       DropdownButton<String>(
//   //         value: unit,
//   //         items: ['pcs', 'meters'].map((String value) {
//   //           return DropdownMenuItem<String>(
//   //             value: value,
//   //             child: Text(value),
//   //           );
//   //         }).toList(),
//   //         onChanged: (newValue) {
//   //           setState(() {
//   //             _selectedItems[item['id']]?['unit'] = newValue;
//   //           });
//   //         },
//   //       ),
//   //       SizedBox(width: 10),
//   //       Expanded(
//   //         child: TextFormField(
//   //           keyboardType: TextInputType.number,
//   //           initialValue:
//   //               unit == 'pcs' ? quantity.toString() : length.toString(),
//   //           onChanged: (value) {
//   //             if (unit == 'pcs') {
//   //               _updatePipeQuantity(item['id'], int.tryParse(value) ?? 0, item);
//   //             } else {
//   //               _updatePipeLength(
//   //                   item['id'], double.tryParse(value) ?? 0.0, item);
//   //             }
//   //           },
//   //           decoration: InputDecoration(
//   //             labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//   //             border: OutlineInputBorder(),
//   //           ),
//   //         ),
//   //       ),
//   //     ],
//   //   );
//   // }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   // void _updatePipeQuantity(
//   //     String itemId, int newQuantity, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     if (newQuantity > 0) {
//   //       _selectedItems[itemId] = {
//   //         ..._selectedItems[itemId] ?? {},
//   //         'quantity': newQuantity,
//   //         'isPipe': true,
//   //         'name': itemData['name'],
//   //         'unit': 'pcs',
//   //         'pipeLength': itemData['pipeLength'] ?? 0,
//   //       };
//   //     } else {
//   //       _selectedItems.remove(itemId);
//   //     }
//   //   });
//   // }

//   // void _updatePipeLength(
//   //     String itemId, double newLength, Map<String, dynamic> itemData) {
//   //   setState(() {
//   //     if (newLength > 0) {
//   //       _selectedItems[itemId] = {
//   //         ..._selectedItems[itemId] ?? {},
//   //         'length': newLength,
//   //         'isPipe': true,
//   //         'name': itemData['name'],
//   //         'unit': 'meters',
//   //         'pipeLength': itemData['pipeLength'] ?? 0,
//   //       };
//   //     } else {
//   //       _selectedItems.remove(itemId);
//   //     }
//   //   });

//   // }
//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   if (!_selectedItems.containsKey(itemId)) {
//   //     _selectedItems[itemId] = {
//   //       'pcs': 0,
//   //       'meters': 0.0,
//   //       'isPipe': true,
//   //       'name': item['name'],
//   //       'pipeLength': item['pipeLength'] ?? 0,
//   //     };
//   //   }

//   //   return StatefulBuilder(
//   //     builder: (BuildContext context, StateSetter setState) {
//   //       return Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           _buildUnitInput(itemId, 'pcs', setState),
//   //           SizedBox(height: 8),
//   //           _buildUnitInput(itemId, 'meters', setState),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }

//   // Widget _buildUnitInput(String itemId, String unit, StateSetter setState) {
//   //   double value = (_selectedItems[itemId]![unit] as num).toDouble();

//   //   void updateValue(double newValue) {
//   //     if (newValue >= 0) {
//   //       this.setState(() {
//   //         _selectedItems[itemId]![unit] =
//   //             unit == 'pcs' ? newValue.toInt() : newValue;
//   //       });
//   //       setState(() {});
//   //     }
//   //   }

//   //   return Row(
//   //     children: [
//   //       Text('$unit: '),
//   //       IconButton(
//   //         icon: Icon(Icons.remove_circle_outline),
//   //         onPressed: () => updateValue(value - (unit == 'pcs' ? 1 : 0.5)),
//   //       ),
//   //       Expanded(
//   //         child: TextFormField(
//   //           initialValue: value.toString(),
//   //           keyboardType: TextInputType.number,
//   //           onChanged: (inputValue) {
//   //             double? parsedValue = double.tryParse(inputValue);
//   //             if (parsedValue != null) {
//   //               updateValue(parsedValue);
//   //             }
//   //           },
//   //           decoration: InputDecoration(
//   //             labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//   //             border: OutlineInputBorder(),
//   //           ),
//   //         ),
//   //       ),
//   //       IconButton(
//   //         icon: Icon(Icons.add_circle_outline),
//   //         onPressed: () => updateValue(value + (unit == 'pcs' ? 1 : 0.5)),
//   //       ),
//   //     ],
//   //   );
//   // }
//   Widget _buildPipeInput(Map<String, dynamic> item) {
//     String itemId = item['id'];
//     if (!_selectedItems.containsKey(itemId)) {
//       _selectedItems[itemId] = {
//         'pcs': 0,
//         'meters': 0.0,
//         'isPipe': true,
//         'name': item['name'],
//         'pipeLength': item['pipeLength'] ?? 0,
//         'category': item['category'] ?? 'Uncategorized',
//         'subcategory': item['subcategory'] ?? 'N/A',
//       };
//     }

//     return StatefulBuilder(
//       builder: (BuildContext context, StateSetter setState) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildUnitInput(itemId, 'pcs', setState),
//             SizedBox(height: 8),
//             _buildUnitInput(itemId, 'meters', setState),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildUnitInput(String itemId, String unit, StateSetter setState) {
//     double value = (_selectedItems[itemId]![unit] as num).toDouble();

//     void updateValue(double newValue) {
//       if (newValue >= 0) {
//         this.setState(() {
//           _selectedItems[itemId]![unit] =
//               unit == 'pcs' ? newValue.toInt() : newValue;
//         });
//         setState(() {});
//       }
//     }

//     return Row(
//       children: [
//         Text('$unit: '),
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: () => updateValue(value - (unit == 'pcs' ? 1 : 0.5)),
//         ),
//         Expanded(
//           child: TextFormField(
//             initialValue: value.toString(),
//             keyboardType: TextInputType.number,
//             onChanged: (inputValue) {
//               double? parsedValue = double.tryParse(inputValue);
//               if (parsedValue != null) {
//                 updateValue(parsedValue);
//               }
//             },
//             decoration: InputDecoration(
//               labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => updateValue(value + (unit == 'pcs' ? 1 : 0.5)),
//         ),
//       ],
//     );
//   }
//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   if (!_selectedItems.containsKey(itemId)) {
//   //     _selectedItems[itemId] = {
//   //       'quantity': 0,
//   //       'length': 0.0,
//   //       'unit': 'pcs',
//   //       'isPipe': true,
//   //       'name': item['name'],
//   //       'pipeLength': item['pipeLength'] ?? 0,
//   //     };
//   //   }

//   //   return StatefulBuilder(
//   //     builder: (BuildContext context, StateSetter setState) {
//   //       String unit = _selectedItems[itemId]!['unit'] as String;
//   //       double value = unit == 'pcs'
//   //           ? (_selectedItems[itemId]!['quantity'] as num).toDouble()
//   //           : (_selectedItems[itemId]!['length'] as num).toDouble();

//   //       void updateValue(double newValue) {
//   //         if (newValue >= 0) {
//   //           this.setState(() {
//   //             if (unit == 'pcs') {
//   //               _selectedItems[itemId]!['quantity'] = newValue.toInt();
//   //               _selectedItems[itemId]!['length'] =
//   //                   newValue * (item['pipeLength'] ?? 1.0);
//   //             } else {
//   //               _selectedItems[itemId]!['length'] = newValue;
//   //               _selectedItems[itemId]!['quantity'] =
//   //                   (newValue / (item['pipeLength'] ?? 1.0)).ceil();
//   //             }
//   //           });
//   //           setState(() {
//   //             value = newValue;
//   //           });
//   //         }
//   //       }

//   //       return Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           Row(
//   //             children: [
//   //               Text('Unit: '),
//   //               DropdownButton<String>(
//   //                 value: unit,
//   //                 items: ['pcs', 'meters'].map((String value) {
//   //                   return DropdownMenuItem<String>(
//   //                     value: value,
//   //                     child: Text(value),
//   //                   );
//   //                 }).toList(),
//   //                 onChanged: (newValue) {
//   //                   if (newValue != null) {
//   //                     this.setState(() {
//   //                       _selectedItems[itemId]!['unit'] = newValue;
//   //                       // Reset quantity and length when changing units
//   //                       _selectedItems[itemId]!['quantity'] = 0;
//   //                       _selectedItems[itemId]!['length'] = 0.0;
//   //                     });
//   //                     setState(() {
//   //                       unit = newValue;
//   //                       value = 0;
//   //                     });
//   //                   }
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //           SizedBox(height: 8),
//   //           Row(
//   //             children: [
//   //               IconButton(
//   //                 icon: Icon(Icons.remove_circle_outline),
//   //                 onPressed: () => updateValue(value - 1),
//   //               ),
//   //               Expanded(
//   //                 child: TextFormField(
//   //                   initialValue: value.toString(),
//   //                   keyboardType: TextInputType.number,
//   //                   onChanged: (inputValue) {
//   //                     double? parsedValue = double.tryParse(inputValue);
//   //                     if (parsedValue != null) {
//   //                       updateValue(parsedValue);
//   //                     }
//   //                   },
//   //                   decoration: InputDecoration(
//   //                     labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//   //                     border: OutlineInputBorder(),
//   //                   ),
//   //                 ),
//   //               ),
//   //               IconButton(
//   //                 icon: Icon(Icons.add_circle_outline),
//   //                 onPressed: () => updateValue(value + 1),
//   //               ),
//   //             ],
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }
//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   if (!_selectedItems.containsKey(itemId)) {
//   //     _selectedItems[itemId] = {
//   //       'quantity': 0,
//   //       'length': 0.0,
//   //       'unit': 'pcs',
//   //       'isPipe': true,
//   //       'name': item['name'],
//   //       'pipeLength': item['pipeLength'] ?? 0,
//   //     };
//   //   }

//   //   return StatefulBuilder(
//   //     builder: (BuildContext context, StateSetter setState) {
//   //       String unit = _selectedItems[itemId]!['unit'] as String;
//   //       double value = unit == 'pcs'
//   //           ? (_selectedItems[itemId]!['quantity'] as num).toDouble()
//   //           : (_selectedItems[itemId]!['length'] as num).toDouble();

//   //       return Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           Row(
//   //             children: [
//   //               Text('Unit: '),
//   //               DropdownButton<String>(
//   //                 value: unit,
//   //                 items: ['pcs', 'meters'].map((String value) {
//   //                   return DropdownMenuItem<String>(
//   //                     value: value,
//   //                     child: Text(value),
//   //                   );
//   //                 }).toList(),
//   //                 onChanged: (newValue) {
//   //                   if (newValue != null) {
//   //                     this.setState(() {
//   //                       _selectedItems[itemId]!['unit'] = newValue;
//   //                       // Reset quantity and length when changing units
//   //                       _selectedItems[itemId]!['quantity'] = 0;
//   //                       _selectedItems[itemId]!['length'] = 0.0;
//   //                     });
//   //                     setState(() {}); // Rebuild the StatefulBuilder widget
//   //                   }
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //           SizedBox(height: 8),
//   //           Row(
//   //             children: [
//   //               Expanded(
//   //                 child: TextFormField(
//   //                   initialValue: value.toString(),
//   //                   keyboardType: TextInputType.number,
//   //                   onChanged: (value) {
//   //                     double? parsedValue = double.tryParse(value);
//   //                     if (parsedValue != null && parsedValue > 0) {
//   //                       this.setState(() {
//   //                         if (unit == 'pcs') {
//   //                           _selectedItems[itemId]!['quantity'] =
//   //                               parsedValue.toInt();
//   //                           _selectedItems[itemId]!['length'] =
//   //                               parsedValue * (item['pipeLength'] ?? 1.0);
//   //                         } else {
//   //                           _selectedItems[itemId]!['length'] = parsedValue;
//   //                           _selectedItems[itemId]!['quantity'] =
//   //                               (parsedValue / (item['pipeLength'] ?? 1.0))
//   //                                   .ceil();
//   //                         }
//   //                       });
//   //                     } else {
//   //                       this.setState(() {
//   //                         _selectedItems.remove(itemId);
//   //                       });
//   //                     }
//   //                   },
//   //                   decoration: InputDecoration(
//   //                     labelText: unit == 'pcs' ? 'Pieces' : 'Length (m)',
//   //                     border: OutlineInputBorder(),
//   //                   ),
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }
//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   Map<String, dynamic> selectedItem = _selectedItems[itemId] ??
//   //       {
//   //         'quantity': 0,
//   //         'length': 0.0,
//   //         'unit': 'pcs',
//   //         'isPipe': true,
//   //         'name': item['name'],
//   //         'pipeLength': item['pipeLength'] ?? 0,
//   //       };

//   //   TextEditingController controller = TextEditingController(
//   //     text: selectedItem['unit'] == 'pcs'
//   //         ? selectedItem['quantity'].toString()
//   //         : selectedItem['length'].toString(),
//   //   );

//   //   return StatefulBuilder(
//   //     builder: (BuildContext context, StateSetter setState) {
//   //       return Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           Row(
//   //             children: [
//   //               Text('Unit: '),
//   //               DropdownButton<String>(
//   //                 value: selectedItem['unit'] as String,
//   //                 items: ['pcs', 'meters'].map((String value) {
//   //                   return DropdownMenuItem<String>(
//   //                     value: value,
//   //                     child: Text(value),
//   //                   );
//   //                 }).toList(),
//   //                 onChanged: (newValue) {
//   //                   if (newValue != null) {
//   //                     setState(() {
//   //                       selectedItem['unit'] = newValue;
//   //                       // Reset quantity and length when changing units
//   //                       selectedItem['quantity'] = 0;
//   //                       selectedItem['length'] = 0.0;
//   //                       controller.text = '0';
//   //                     });
//   //                     this.setState(() {
//   //                       if (selectedItem['quantity'] > 0 ||
//   //                           selectedItem['length'] > 0) {
//   //                         _selectedItems[itemId] = selectedItem;
//   //                       } else {
//   //                         _selectedItems.remove(itemId);
//   //                       }
//   //                     });
//   //                   }
//   //                 },
//   //               ),
//   //             ],
//   //           ),
//   //           SizedBox(height: 8),
//   //           Row(
//   //             children: [
//   //               Expanded(
//   //                 child: TextFormField(
//   //                   controller: controller,
//   //                   keyboardType: TextInputType.number,
//   //                   onChanged: (value) {
//   //                     double? parsedValue = double.tryParse(value);
//   //                     if (parsedValue != null && parsedValue > 0) {
//   //                       setState(() {
//   //                         if (selectedItem['unit'] == 'pcs') {
//   //                           selectedItem['quantity'] = parsedValue.toInt();
//   //                           selectedItem['length'] =
//   //                               parsedValue * (item['pipeLength'] ?? 1.0);
//   //                         } else {
//   //                           selectedItem['length'] = parsedValue;
//   //                           selectedItem['quantity'] =
//   //                               (parsedValue / (item['pipeLength'] ?? 1.0))
//   //                                   .ceil();
//   //                         }
//   //                       });
//   //                       this.setState(() {
//   //                         _selectedItems[itemId] = selectedItem;
//   //                       });
//   //                     } else {
//   //                       this.setState(() {
//   //                         _selectedItems.remove(itemId);
//   //                       });
//   //                     }
//   //                   },
//   //                   decoration: InputDecoration(
//   //                     labelText: selectedItem['unit'] == 'pcs'
//   //                         ? 'Pieces'
//   //                         : 'Length (m)',
//   //                     border: OutlineInputBorder(),
//   //                   ),
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }

//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   Map<String, dynamic> selectedItem = _selectedItems[itemId] ??
//   //       {
//   //         'quantity': 0,
//   //         'length': 0.0,
//   //         'unit': 'pcs',
//   //         'isPipe': true,
//   //         'name': item['name'],
//   //         'pipeLength': item['pipeLength'] ?? 0,
//   //       };

//   //   TextEditingController controller = TextEditingController(
//   //     text: selectedItem['unit'] == 'pcs'
//   //         ? selectedItem['quantity'].toString()
//   //         : selectedItem['length'].toString(),
//   //   );

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Row(
//   //         children: [
//   //           Text('Unit: '),
//   //           DropdownButton<String>(
//   //             value: selectedItem['unit'] as String,
//   //             items: ['pcs', 'meters'].map((String value) {
//   //               return DropdownMenuItem<String>(
//   //                 value: value,
//   //                 child: Text(value),
//   //               );
//   //             }).toList(),
//   //             onChanged: (newValue) {
//   //               if (newValue != null) {
//   //                 setState(() {
//   //                   selectedItem['unit'] = newValue;
//   //                   // Reset quantity and length when changing units
//   //                   selectedItem['quantity'] = 0;
//   //                   selectedItem['length'] = 0.0;
//   //                   controller.text = '0';
//   //                   if (selectedItem['quantity'] > 0 ||
//   //                       selectedItem['length'] > 0) {
//   //                     _selectedItems[itemId] = selectedItem;
//   //                   } else {
//   //                     _selectedItems.remove(itemId);
//   //                   }
//   //                 });
//   //               }
//   //             },
//   //           ),
//   //         ],
//   //       ),
//   //       SizedBox(height: 8),
//   //       Row(
//   //         children: [
//   //           Expanded(
//   //             child: TextFormField(
//   //               controller: controller,
//   //               keyboardType: TextInputType.number,
//   //               onChanged: (value) {
//   //                 double? parsedValue = double.tryParse(value);
//   //                 if (parsedValue != null && parsedValue > 0) {
//   //                   setState(() {
//   //                     if (selectedItem['unit'] == 'pcs') {
//   //                       selectedItem['quantity'] = parsedValue.toInt();
//   //                       selectedItem['length'] =
//   //                           parsedValue * (item['pipeLength'] ?? 1.0);
//   //                     } else {
//   //                       selectedItem['length'] = parsedValue;
//   //                       selectedItem['quantity'] =
//   //                           (parsedValue / (item['pipeLength'] ?? 1.0)).ceil();
//   //                     }
//   //                     _selectedItems[itemId] = selectedItem;
//   //                   });
//   //                 } else {
//   //                   setState(() {
//   //                     _selectedItems.remove(itemId);
//   //                   });
//   //                 }
//   //               },
//   //               decoration: InputDecoration(
//   //                 labelText:
//   //                     selectedItem['unit'] == 'pcs' ? 'Pieces' : 'Length (m)',
//   //                 border: OutlineInputBorder(),
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ],
//   //   );
//   // }

//   // Widget _buildPipeInput(Map<String, dynamic> item) {
//   //   String itemId = item['id'];
//   //   Map<String, dynamic> selectedItem = _selectedItems[itemId] ??
//   //       {
//   //         'quantity': 0,
//   //         'length': 0.0,
//   //         'unit': 'pcs',
//   //         'isPipe': true,
//   //         'name': item['name'],
//   //         'pipeLength': item['pipeLength'] ?? 0,
//   //       };

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Row(
//   //         children: [
//   //           Text('Unit: '),
//   //           DropdownButton<String>(
//   //             value: selectedItem['unit'] as String,
//   //             items: ['pcs', 'meters'].map((String value) {
//   //               return DropdownMenuItem<String>(
//   //                 value: value,
//   //                 child: Text(value),
//   //               );
//   //             }).toList(),
//   //             onChanged: (newValue) {
//   //               if (newValue != null) {
//   //                 setState(() {
//   //                   selectedItem['unit'] = newValue;
//   //                   if (_selectedItems.containsKey(itemId)) {
//   //                     _selectedItems[itemId] = selectedItem;
//   //                   }
//   //                 });
//   //               }
//   //             },
//   //           ),
//   //         ],
//   //       ),
//   //       SizedBox(height: 8),
//   //       Row(
//   //         children: [
//   //           Expanded(
//   //             child: TextFormField(
//   //               keyboardType: TextInputType.number,
//   //               initialValue: selectedItem['unit'] == 'pcs'
//   //                   ? selectedItem['quantity'].toString()
//   //                   : selectedItem['length'].toString(),
//   //               onChanged: (value) {
//   //                 double? parsedValue = double.tryParse(value);
//   //                 if (parsedValue != null && parsedValue > 0) {
//   //                   setState(() {
//   //                     if (selectedItem['unit'] == 'pcs') {
//   //                       selectedItem['quantity'] = parsedValue.toInt();
//   //                       selectedItem['length'] =
//   //                           parsedValue * (item['pipeLength'] ?? 1.0);
//   //                     } else {
//   //                       selectedItem['length'] = parsedValue;
//   //                       selectedItem['quantity'] =
//   //                           (parsedValue / (item['pipeLength'] ?? 1.0)).ceil();
//   //                     }
//   //                     _selectedItems[itemId] = selectedItem;
//   //                   });
//   //                 } else if (_selectedItems.containsKey(itemId)) {
//   //                   setState(() {
//   //                     _selectedItems.remove(itemId);
//   //                   });
//   //                 }
//   //               },
//   //               decoration: InputDecoration(
//   //                 labelText:
//   //                     selectedItem['unit'] == 'pcs' ? 'Pieces' : 'Length (m)',
//   //                 border: OutlineInputBorder(),
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ],
//   //   );
//   // }

//   void _updatePipeQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'quantity': newQuantity,
//           'isPipe': true,
//           'name': itemData['name'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newLength > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'length': newLength,
//           'isPipe': true,
//           'name': itemData['name'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//         _selectedItems.entries.where((entry) {
//       var item = entry.value;
//       return (item['isPipe'] == true &&
//               ((item['pcs'] as num) > 0 || (item['meters'] as num) > 0)) ||
//           (item['isPipe'] != true && (item['quantity'] as num) > 0);
//     }).toList();

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = selectedItems[index].key;
//             Map<String, dynamic> itemData = selectedItems[index].value;
//             bool isPipe = itemData['isPipe'] ?? false;
//             return Slidable(
//               // ... (rest of your Slidable widget code)
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text(
//                           'Pieces: ${itemData['pcs']}, Length: ${itemData['meters']} m')
//                       : Text(
//                           'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//   // Widget _buildSelectedItemsList() {
//   //   List<MapEntry<String, Map<String, dynamic>>> selectedItems =
//   //       _selectedItems.entries.where((entry) {
//   //     var item = entry.value;
//   //     return (item['isPipe'] == true &&
//   //             ((item['quantity'] as num) > 0 || (item['length'] as num) > 0)) ||
//   //         (item['isPipe'] != true && (item['quantity'] as num) > 0);
//   //   }).toList();

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         'Selected Items',
//   //         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//   //       ),
//   //       SizedBox(height: 8),
//   //       ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: selectedItems.length,
//   //         itemBuilder: (context, index) {
//   //           String itemId = selectedItems[index].key;
//   //           Map<String, dynamic> itemData = selectedItems[index].value;
//   //           bool isPipe = itemData['isPipe'] ?? false;
//   //           return Slidable(
//   //             // ... (rest of your Slidable widget code)
//   //             child: Card(
//   //               elevation: 2,
//   //               margin: EdgeInsets.symmetric(vertical: 8),
//   //               child: ListTile(
//   //                 leading: CircleAvatar(
//   //                   child: Icon(Icons.shopping_cart, color: Colors.white),
//   //                   backgroundColor: Colors.green,
//   //                 ),
//   //                 title: Text(itemData['name'] ?? 'Unknown Item',
//   //                     style: TextStyle(fontWeight: FontWeight.bold)),
//   //                 subtitle: isPipe
//   //                     ? Text(
//   //                         '${itemData['unit'] == 'pcs' ? "Pieces" : "Length"}: ${itemData['unit'] == 'pcs' ? itemData['quantity'] : itemData['length']} ${itemData['unit']}')
//   //                     : Text(
//   //                         'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//   //                 trailing: Icon(Icons.swipe_left, color: Colors.grey),
//   //               ),
//   //             ),
//   //           );
//   //         },
//   //       ),
//   //     ],
//   //   );
//   // }

//   // Widget _buildSelectedItemsList() {
//   //   List<MapEntry<String, Map<String, dynamic>>> selectedItems = _selectedItems
//   //       .entries
//   //       .where((entry) =>
//   //           (entry.value['quantity'] as num) > 0 ||
//   //           (entry.value['length'] as num) > 0)
//   //       .toList();

//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.start,
//   //     children: [
//   //       Text(
//   //         'Selected Items',
//   //         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//   //       ),
//   //       SizedBox(height: 8),
//   //       ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: selectedItems.length,
//   //         itemBuilder: (context, index) {
//   //           String itemId = selectedItems[index].key;
//   //           Map<String, dynamic> itemData = selectedItems[index].value;
//   //           bool isPipe = itemData['isPipe'] ?? false;
//   //           return Slidable(
//   //             endActionPane: ActionPane(
//   //               motion: ScrollMotion(),
//   //               children: [
//   //                 SlidableAction(
//   //                   onPressed: (_) => isPipe
//   //                       ? _showEditPipeDialog(itemId, itemData)
//   //                       : _showEditQuantityDialog(
//   //                           itemId, itemData['quantity'] ?? 0),
//   //                   backgroundColor: Colors.blue,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.edit,
//   //                   label: 'Edit',
//   //                 ),
//   //                 SlidableAction(
//   //                   onPressed: (_) {
//   //                     setState(() {
//   //                       _selectedItems.remove(itemId);
//   //                     });
//   //                   },
//   //                   backgroundColor: Colors.red,
//   //                   foregroundColor: Colors.white,
//   //                   icon: Icons.delete,
//   //                   label: 'Delete',
//   //                 ),
//   //               ],
//   //             ),
//   //             child: Card(
//   //               elevation: 2,
//   //               margin: EdgeInsets.symmetric(vertical: 8),
//   //               child: ListTile(
//   //                 leading: CircleAvatar(
//   //                   child: Icon(Icons.shopping_cart, color: Colors.white),
//   //                   backgroundColor: Colors.green,
//   //                 ),
//   //                 title: Text(itemData['name'] ?? 'Unknown Item',
//   //                     style: TextStyle(fontWeight: FontWeight.bold)),
//   //                 subtitle: isPipe
//   //                     ? Text(
//   //                         'Pieces: ${itemData['quantity'] ?? 0}, Length: ${itemData['length'] ?? 0} m')
//   //                     : Text(
//   //                         'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//   //                 trailing: Icon(Icons.swipe_left, color: Colors.grey),
//   //               ),
//   //             ),
//   //           );
//   //         },
//   //       ),
//   //     ],
//   //   );
//   // }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController quantityController =
//         TextEditingController(text: itemData['quantity'].toString());
//     final TextEditingController lengthController =
//         TextEditingController(text: itemData['length'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: quantityController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: lengthController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               double newLength = double.tryParse(lengthController.text) ?? 0.0;
//               _updatePipeQuantity(itemId, newQuantity, itemData);
//               _updatePipeLength(itemId, newLength, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     // List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//     //   final itemData = entry.value;
//     //   final isPipe = itemData['isPipe'] ?? false;
//     //   final unit = itemData['unit'] as String;

//     //   double quantity;
//     //   if (isPipe) {
//     //     if (unit == 'meters') {
//     //       quantity = itemData['length'] ?? 0.0;
//     //     } else {
//     //       quantity = (itemData['quantity'] ?? 0).toDouble();
//     //     }
//     //   } else {
//     //     quantity = (itemData['quantity'] ?? 0).toDouble();
//     //   }

//     //   if (quantity <= 0) {
//     //     throw Exception(
//     //         'Requested quantity must be greater than 0 for item: ${itemData['name']}');
//     //   }

//     //   return {
//     //     'id': entry.key,
//     //     'name': itemData['name'],
//     //     'quantity': quantity,
//     //     'unit': unit,
//     //     'isPipe': isPipe,
//     //     'pipeLength': itemData['pipeLength'] ?? 0,
//     //     'category': itemData['category'] ?? 'Uncategorized',
//     //     'subcategory': itemData['subcategory'] ?? 'N/A',
//     //   };
//     // }).toList();
//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         final isPipe = itemData['isPipe'] ?? false;

//         if (isPipe) {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'pcs': itemData['pcs'],
//             'meters': itemData['meters'],
//             'isPipe': true,
//             'pipeLength': itemData['pipeLength'] ?? 0,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         } else {
//           return {
//             'id': entry.key,
//             'name': itemData['name'],
//             'quantity': itemData['quantity'],
//             'unit': itemData['unit'],
//             'isPipe': false,
//             'category': itemData['category'] ?? 'Uncategorized',
//             'subcategory': itemData['subcategory'] ?? 'N/A',
//           };
//         }
//       }).where((item) {
//         if (item['isPipe']) {
//           return (item['pcs'] as num) > 0 || (item['meters'] as num) > 0;
//         } else {
//           return (item['quantity'] as num) > 0;
//         }
//       }).toList();

//       print("Items to be submitted: $items"); // Debug print

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail!,
//         inventoryProvider,
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }





















// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Flexible(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true, // Add this line
//           physics: NeverScrollableScrollPhysics(), // Add this line
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 title: Text(item['name'],
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text(
//                     '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}'),
//                 trailing: isPipe
//                     ? _buildPipeControls(item)
//                     : _buildQuantityControls(item),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     // Use the null-aware operator to provide a default value if null
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     double length = _selectedItems[item['id']]?['length'] ?? 0.0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: quantity > 0
//                   ? () => _updatePipeQuantity(item['id'], quantity - 1, item)
//                   : null,
//             ),
//             Text('$quantity', style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () =>
//                   _updatePipeQuantity(item['id'], quantity + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Length (m): '),
//             SizedBox(
//               width: 60,
//               child: TextField(
//                 keyboardType: TextInputType.number,
//                 onChanged: (value) {
//                   // Use tryParse to safely convert to a double, default to 0 if parsing fails
//                   double parsedLength = double.tryParse(value) ?? 0.0;
//                   _updatePipeLength(item['id'], parsedLength, item);
//                 },
//                 decoration: InputDecoration(
//                   contentPadding: EdgeInsets.symmetric(horizontal: 8),
//                   hintText: length.toString(),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'quantity': newQuantity,
//           'isPipe': true,
//           'name': itemData['name'],
//           'unit': itemData['unit'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newLength > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'length': newLength,
//           'isPipe': true,
//           'name': itemData['name'],
//           'unit': itemData['unit'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems[itemId]?.remove('length');
//         if (_selectedItems[itemId]?.isEmpty ?? true) {
//           _selectedItems.remove(itemId);
//         }
//       }
//     });
//   }

//   Widget _buildSelectedItemsList() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: _selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = _selectedItems.keys.elementAt(index);
//             Map<String, dynamic> itemData = _selectedItems[itemId]!;
//             bool isPipe = itemData['isPipe'] ?? false;
//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(
//                             itemId, itemData['quantity'] ?? 0),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text(
//                           'Pieces: ${itemData['quantity'] ?? 0}, Length: ${itemData['length'] ?? 0} m')
//                       : Text(
//                           'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     // Fetch the item data from _selectedItems
//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController quantityController =
//         TextEditingController(text: itemData['quantity'].toString());
//     final TextEditingController lengthController =
//         TextEditingController(text: itemData['length'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: quantityController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: lengthController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               double newLength = double.tryParse(lengthController.text) ?? 0.0;
//               _updatePipeQuantity(itemId, newQuantity, itemData);
//               _updatePipeLength(itemId, newLength, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         return {
//           'id': entry.key,
//           'name': itemData['name'],
//           'quantity': itemData['quantity'],
//           'length': itemData['length'],
//           'unit': itemData['unit'],
//           'isPipe': itemData['isPipe'] ?? false,
//           'pipeLength': itemData['pipeLength'] ?? 0,
//           'category': itemData['category'] ?? 'Uncategorized',
//           'subcategory': itemData['subcategory'] ?? 'N/A',
//         };
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, Map<String, dynamic>> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
          
//                 Flexible(
//                   child: ListView(
//                     padding: EdgeInsets.all(16.0),
//                     children: [
//                       _buildSearchBar(),
//                       SizedBox(height: 16),
//                       _buildCategoryList(),
//                       SizedBox(height: 16),
//                       _buildInventoryList(),
//                       SizedBox(height: 16),
//                       _buildSelectedItemsList(),
//                     ],
//                   ),
//                 ),

//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           // Remove shrinkWrap: true and physics: NeverScrollableScrollPhysics()
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             bool isPipe = item['isPipe'] ?? false;
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 title: Text(item['name'],
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text(
//                     '${item['category']} - ${isPipe ? "Pipe" : "Regular Item"}'),
//                 trailing: isPipe
//                     ? _buildPipeControls(item)
//                     : _buildQuantityControls(item),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     int quantity = _selectedItems[item['id']]?['quantity'] ?? 0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['id'], quantity - 1, item)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
//           onPressed: () => _updateQuantity(item['id'], quantity + 1, item),
//         ),
//       ],
//     );
//   }

//   Widget _buildPipeControls(Map<String, dynamic> item) {
//     Map<String, dynamic> selectedData =
//         _selectedItems[item['id']] ?? {'quantity': 0, 'length': 0.0};
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Pieces: '),
//             IconButton(
//               icon: Icon(Icons.remove_circle_outline),
//               onPressed: selectedData['quantity'] > 0
//                   ? () => _updatePipeQuantity(
//                       item['id'], selectedData['quantity'] - 1, item)
//                   : null,
//             ),
//             Text('${selectedData['quantity']}',
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             IconButton(
//               icon: Icon(Icons.add_circle_outline),
//               onPressed: () => _updatePipeQuantity(
//                   item['id'], selectedData['quantity'] + 1, item),
//             ),
//           ],
//         ),
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Length (m): '),
//             SizedBox(
//               width: 60,
//               child: TextField(
//                 keyboardType: TextInputType.number,
//                 onChanged: (value) => _updatePipeLength(
//                     item['id'], double.tryParse(value) ?? 0, item),
//                 decoration: InputDecoration(
//                   contentPadding: EdgeInsets.symmetric(horizontal: 8),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   void _updateQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> item) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           'quantity': newQuantity,
//           'isPipe': item['isPipe'] ?? false,
//           'name': item['name'],
//           'unit': item['unit'],
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeQuantity(
//       String itemId, int newQuantity, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newQuantity > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'quantity': newQuantity,
//           'isPipe': true,
//           'name': itemData['name'],
//           'unit': itemData['unit'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems.remove(itemId);
//       }
//     });
//   }

//   void _updatePipeLength(
//       String itemId, double newLength, Map<String, dynamic> itemData) {
//     setState(() {
//       if (newLength > 0) {
//         _selectedItems[itemId] = {
//           ..._selectedItems[itemId] ?? {},
//           'length': newLength,
//           'isPipe': true,
//           'name': itemData['name'],
//           'unit': itemData['unit'],
//           'pipeLength': itemData['pipeLength'] ?? 0,
//         };
//       } else {
//         _selectedItems[itemId]?.remove('length');
//         if (_selectedItems[itemId]?.isEmpty ?? true) {
//           _selectedItems.remove(itemId);
//         }
//       }
//     });
//   }
 
//   Widget _buildSelectedItemsList() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: _selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemId = _selectedItems.keys.elementAt(index);
//             Map<String, dynamic> itemData = _selectedItems[itemId]!;
//             bool isPipe = itemData['isPipe'] ?? false;
//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) => isPipe
//                         ? _showEditPipeDialog(itemId, itemData)
//                         : _showEditQuantityDialog(
//                             itemId, itemData['quantity'] ?? 0),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) {
//                       setState(() {
//                         _selectedItems.remove(itemId);
//                       });
//                     },
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text(itemData['name'] ?? 'Unknown Item',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: isPipe
//                       ? Text(
//                           'Pieces: ${itemData['quantity'] ?? 0}, Length: ${itemData['length'] ?? 0} m')
//                       : Text(
//                           'Quantity: ${itemData['quantity'] ?? 0} ${itemData['unit'] ?? ''}'),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
  
//   Future<void> _showEditQuantityDialog(
//       String itemId, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());

//     // Fetch the item data from _selectedItems
//     Map<String, dynamic> itemData = _selectedItems[itemId] ?? {};

//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemId, newQuantity, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showEditPipeDialog(
//       String itemId, Map<String, dynamic> itemData) async {
//     final TextEditingController quantityController =
//         TextEditingController(text: itemData['quantity'].toString());
//     final TextEditingController lengthController =
//         TextEditingController(text: itemData['length'].toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Pipe Request'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: quantityController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Quantity (pieces)'),
//             ),
//             TextField(
//               controller: lengthController,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(labelText: 'Length (meters)'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity = int.tryParse(quantityController.text) ?? 0;
//               double newLength = double.tryParse(lengthController.text) ?? 0.0;
//               _updatePipeQuantity(itemId, newQuantity, itemData);
//               _updatePipeLength(itemId, newLength, itemData);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }


//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = entry.value;
//         return {
//           'id': entry.key,
//           'name': itemData['name'],
//           'quantity': itemData['quantity'],
//           'length': itemData['length'],
//           'unit': itemData['unit'],
//           'isPipe': itemData['isPipe'] ?? false,
//           'pipeLength': itemData['pipeLength'] ?? 0,
//           'category': itemData['category'] ?? 'Uncategorized',
//           'subcategory': itemData['subcategory'] ?? 'N/A',
//         };
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       final locationProvider =
//           Provider.of<LocationProvider>(context, listen: false);
//       await locationProvider.fetchLocations();
//       print(
//           "Locations in CreateUserRequestScreen: ${locationProvider.locations}");
//       if (locationProvider.locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locationProvider.locations.first;
//         });
//       }
//     } catch (e) {
//       print('Error fetching locations in CreateUserRequestScreen: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildSearchBar(),
//                           SizedBox(height: 16),
//                           _buildCategoryList(),
//                           SizedBox(height: 16),
//                           _buildInventoryList(),
//                           SizedBox(height: 16),
//                           _buildSelectedItemsList(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   // Widget _buildInventoryList() {
//   //   return Consumer<InventoryProvider>(
//   //     builder: (context, inventoryProvider, _) {
//   //       List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//   //           .where((item) =>
//   //               (_selectedCategory == 'All' ||
//   //                   item['category'] == _selectedCategory) &&
//   //               item['name']
//   //                   .toLowerCase()
//   //                   .contains(_searchController.text.toLowerCase()))
//   //           .toList();

//   //       return ListView.builder(
//   //         shrinkWrap: true,
//   //         physics: NeverScrollableScrollPhysics(),
//   //         itemCount: filteredItems.length,
//   //         itemBuilder: (context, index) {
//   //           Map<String, dynamic> item = filteredItems[index];
//   //           return Card(
//   //             elevation: 2,
//   //             margin: EdgeInsets.symmetric(vertical: 8),
//   //             child: ListTile(
//   //               leading: CircleAvatar(
//   //                 child: Icon(Icons.inventory, color: Colors.white),
//   //                 backgroundColor: Colors.blue.shade700,
//   //               ),
//   //               title: Text(item['name'],
//   //                   style: TextStyle(fontWeight: FontWeight.bold)),
//   //               subtitle: Text(item['category']),
//   //               trailing: _buildQuantityControls(item),
//   //             ),
//   //           );
//   //         },
//   //       );
//   //     },
//   //   );
//   // }
//    Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 leading: CircleAvatar(
//                   child: Icon(Icons.inventory, color: Colors.white),
//                   backgroundColor: Colors.blue.shade700,
//                 ),
//                 title: Text(item['name'],
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text(
//                     '${item['category']} - ${item['isPipe'] ? "Pipe" : "Regular Item"}'),
//                 trailing: item['isPipe']
//                     ? _buildPipeControls(item)
//                     : _buildQuantityControls(item),
//               ),
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
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['name'], quantity - 1)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
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
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: _selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemName = _selectedItems.keys.elementAt(index);
//             int quantity = _selectedItems[itemName]!;
//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) =>
//                         _showEditQuantityDialog(itemName, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) => _updateQuantity(itemName, 0),
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text('$itemName x $quantity',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemName, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemName, newQuantity);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Consumer<LocationProvider>(
//                   builder: (context, locationProvider, _) {
//                     print(
//                         "Building location dropdown. Locations: ${locationProvider.locations}");
//                     if (locationProvider.isLoading) {
//                       return CircularProgressIndicator();
//                     }
//                     if (locationProvider.locations.isEmpty) {
//                       return Text(
//                           'No locations available. Please add locations in the Manage Locations screen.');
//                     }
//                     return DropdownButtonFormField<String>(
//                       value: _selectedLocation.isNotEmpty
//                           ? _selectedLocation
//                           : null,
//                       decoration: InputDecoration(
//                         labelText: 'Delivery Location',
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(15)),
//                         prefixIcon: Icon(Icons.location_on),
//                       ),
//                       items: locationProvider.locations.map((location) {
//                         return DropdownMenuItem(
//                             value: location, child: Text(location));
//                       }).toList(),
//                       onChanged: (value) {
//                         if (value != null) {
//                           setState(() => _selectedLocation = value);
//                         }
//                       },
//                       hint: Text('Select a location'),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.phone),
//                     suffixIcon: IconButton(
//                       icon: Icon(Icons.contacts),
//                       onPressed: _pickContact,
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15)),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => _submitRequest(context),
//               child: Text('Submit'),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = inventoryProvider.items
//             .firstWhere((item) => item['name'] == entry.key);
//         return {
//           'id': itemData['id'],
//           'name': entry.key,
//           'quantity': entry.value,
//           'unit': itemData['unit'],
//           'isPipe': itemData['isPipe'] ?? false,
//           'pipeLength': itemData['pipeLength'] ?? 0,
//           'category': itemData['category'],
//           'subcategory': itemData['subcategory'] ?? 'N/A',
//         };
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
  // Future<void> _submitRequest(BuildContext context) async {
  //   if (_pickerNameController.text.isEmpty ||
  //       _pickerContactController.text.isEmpty ||
  //       _pickerContactController.text.length != 10 ||
  //       _selectedLocation.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //             'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
  //       ),
  //     );
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   final currentUserEmail =
  //       Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

  //   if (currentUserEmail == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('User email not available. Please log in again.'),
  //       ),
  //     );
  //     setState(() => _isLoading = false);
  //     return;
  //   }

  //   try {
  //     final requestProvider =
  //         Provider.of<RequestProvider>(context, listen: false);
  //     final inventoryProvider =
  //         Provider.of<InventoryProvider>(context, listen: false);

  //     List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
  //       final itemData = inventoryProvider.items
  //           .firstWhere((item) => item['name'] == entry.key);
  //       return {
  //         'name': entry.key,
  //         'quantity': entry.value,
  //         'unit': itemData['unit'],
  //       };
  //     }).toList();

  //     await requestProvider.addRequest(
  //       items,
  //       _selectedLocation,
  //       _pickerNameController.text,
  //       _pickerContactController.text,
  //       _noteController.text,
  //       currentUserEmail,
  //       inventoryProvider,
  //     );

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Request created successfully')),
  //     );

  //     Navigator.of(context).pop(); // Close the dialog
  //     Navigator.of(context).pop(); // Go back to the previous screen
  //   } catch (e) {
  //     print("Error creating request: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error creating request: $e')),
  //     );
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/location_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = '';
//   String _selectedCategory = 'All';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//       _fetchLocations();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchLocations() async {
//     try {
//       await Provider.of<LocationProvider>(context, listen: false)
//           .fetchLocations();
//       final locations =
//           Provider.of<LocationProvider>(context, listen: false).locations;
//       if (locations.isNotEmpty) {
//         setState(() {
//           _selectedLocation = locations.first;
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching locations: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildSearchBar(),
//                           SizedBox(height: 16),
//                           _buildCategoryList(),
//                           SizedBox(height: 16),
//                           _buildInventoryList(),
//                           SizedBox(height: 16),
//                           _buildSelectedItemsList(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 leading: CircleAvatar(
//                   child: Icon(Icons.inventory, color: Colors.white),
//                   backgroundColor: Colors.blue.shade700,
//                 ),
//                 title: Text(item['name'],
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text(item['category']),
//                 trailing: _buildQuantityControls(item),
//               ),
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
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['name'], quantity - 1)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
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
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: _selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemName = _selectedItems.keys.elementAt(index);
//             int quantity = _selectedItems[itemName]!;
//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) =>
//                         _showEditQuantityDialog(itemName, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) => _updateQuantity(itemName, 0),
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text('$itemName x $quantity',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemName, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemName, newQuantity);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Consumer<LocationProvider>(
//                 builder: (context, locationProvider, _) {
//                   return DropdownButtonFormField<String>(
//                     value: _selectedLocation,
//                     decoration: InputDecoration(
//                       labelText: 'Delivery Location',
//                       border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(15)),
//                       prefixIcon: Icon(Icons.location_on),
//                     ),
//                     items: locationProvider.locations
//                         .map((location) => DropdownMenuItem(
//                             value: location, child: Text(location)))
//                         .toList(),
//                     onChanged: (value) =>
//                         setState(() => _selectedLocation = value!),
//                   );
//                 },
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Name',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.person),
//                 ),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerContactController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Contact Number',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.phone),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.contacts),
//                     onPressed: _pickContact,
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 maxLength: 10,
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _noteController,
//                 decoration: InputDecoration(
//                   labelText: 'Optional Note',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.note),
//                 ),
//                 maxLines: 3,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => _submitRequest(context),
//             child: Text('Submit'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones?.firstWhere(
//             (phone) => phone.value != null,
//             orElse: () => Item(label: 'mobile', value: ''),
//           );
//           setState(() {
//             _pickerNameController.text = contact.displayName ?? '';
//             _pickerContactController.text =
//                 _formatPhoneNumber(phone?.value ?? '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print("Error picking contact: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text("Unable to pick contact. Please enter details manually.")),
//       );
//     }
//   }

//   String _formatPhoneNumber(String phoneNumber) {
//     String digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
//     }
//     return digitsOnly;
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail;

//     if (currentUserEmail == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('User email not available. Please log in again.'),
//         ),
//       );
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       final requestProvider =
//           Provider.of<RequestProvider>(context, listen: false);
//       final inventoryProvider =
//           Provider.of<InventoryProvider>(context, listen: false);

//       List<Map<String, dynamic>> items = _selectedItems.entries.map((entry) {
//         final itemData = inventoryProvider.items
//             .firstWhere((item) => item['name'] == entry.key);
//         return {
//           'name': entry.key,
//           'quantity': entry.value,
//           'unit': itemData['unit'],
//         };
//       }).toList();

//       await requestProvider.addRequest(
//         items,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Request created successfully')),
//       );

//       Navigator.of(context).pop(); // Close the dialog
//       Navigator.of(context).pop(); // Go back to the previous screen
//     } catch (e) {
//       print("Error creating request: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error creating request: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInventoryItems());
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//         elevation: 0,
//         backgroundColor: Colors.blue.shade700,
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 _buildHeader(),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildSearchBar(),
//                           SizedBox(height: 16),
//                           _buildCategoryList(),
//                           SizedBox(height: 16),
//                           _buildInventoryList(),
//                           SizedBox(height: 16),
//                           _buildSelectedItemsList(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade700,
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(30),
//           bottomRight: Radius.circular(30),
//         ),
//       ),
//       child: Text(
//         'What items do you need?',
//         style: TextStyle(
//           color: Colors.white,
//           fontSize: 24,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Items',
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//         ),
//         prefixIcon: Icon(Icons.search),
//         filled: true,
//         fillColor: Colors.grey.shade200,
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                   selectedColor: Colors.blue.shade200,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: filteredItems.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> item = filteredItems[index];
//             return Card(
//               elevation: 2,
//               margin: EdgeInsets.symmetric(vertical: 8),
//               child: ListTile(
//                 leading: CircleAvatar(
//                   child: Icon(Icons.inventory, color: Colors.white),
//                   backgroundColor: Colors.blue.shade700,
//                 ),
//                 title: Text(item['name'],
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 subtitle: Text(item['category']),
//                 trailing: _buildQuantityControls(item),
//               ),
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
//           icon: Icon(Icons.remove_circle_outline),
//           onPressed: quantity > 0
//               ? () => _updateQuantity(item['name'], quantity - 1)
//               : null,
//         ),
//         Text('$quantity ${item['unit']}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         IconButton(
//           icon: Icon(Icons.add_circle_outline),
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
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Selected Items',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         SizedBox(height: 8),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: _selectedItems.length,
//           itemBuilder: (context, index) {
//             String itemName = _selectedItems.keys.elementAt(index);
//             int quantity = _selectedItems[itemName]!;
//             return Slidable(
//               endActionPane: ActionPane(
//                 motion: ScrollMotion(),
//                 children: [
//                   SlidableAction(
//                     onPressed: (_) =>
//                         _showEditQuantityDialog(itemName, quantity),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     icon: Icons.edit,
//                     label: 'Edit',
//                   ),
//                   SlidableAction(
//                     onPressed: (_) => _updateQuantity(itemName, 0),
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     icon: Icons.delete,
//                     label: 'Delete',
//                   ),
//                 ],
//               ),
//               child: Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     child: Icon(Icons.shopping_cart, color: Colors.white),
//                     backgroundColor: Colors.green,
//                   ),
//                   title: Text('$itemName x $quantity',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: Icon(Icons.swipe_left, color: Colors.grey),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemName, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemName, newQuantity);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request', style: TextStyle(fontSize: 18)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blue.shade700,
//           padding: EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               DropdownButtonFormField<String>(
//                 value: _selectedLocation,
//                 decoration: InputDecoration(
//                   labelText: 'Delivery Location',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.location_on),
//                 ),
//                 items: _locations
//                     .map((location) => DropdownMenuItem(
//                         value: location, child: Text(location)))
//                     .toList(),
//                 onChanged: (value) =>
//                     setState(() => _selectedLocation = value!),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Name',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.person),
//                 ),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerContactController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Contact Number',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.phone),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.contacts),
//                     onPressed: _pickContact,
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 maxLength: 10,
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _noteController,
//                 decoration: InputDecoration(
//                   labelText: 'Optional Note',
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(15)),
//                   prefixIcon: Icon(Icons.note),
//                 ),
//                 maxLines: 3,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => _submitRequest(context),
//             child: Text('Submit'),
//             style:
//                 ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
//           ),
//         ],
//       ),
//     );
//   }



//   Future<void> _pickContact() async {
//     try {
//       final PermissionStatus permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones
//                   ?.firstWhere((p) => p.value != null,
//                       orElse: () => Item(value: ''))
//                   .value ??
//               '';
//           setState(() {
//             _pickerContactController.text = phone.replaceAll(RegExp(r'\D'), '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print('Error picking contact: $e');
//     }
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     List<Map<String, dynamic>> requestItems =
//         _selectedItems.entries.map((entry) {
//       final item = Provider.of<InventoryProvider>(context, listen: false)
//           .items
//           .firstWhere((item) => item['name'] == entry.key);
//       return {
//         'id': item['id'],
//         'name': entry.key,
//         'quantity': entry.value,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }).toList();

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail!;
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     try {
//       await requestProvider.addRequest(
//         requestItems,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
//         ),
//       );

//       setState(() {
//         _selectedItems.clear();
//         _selectedLocation = 'Default Location';
//         _pickerNameController.clear();
//         _pickerContactController.clear();
//         _noteController.clear();
//       });

//       Navigator.of(context).pop();
//       Navigator.of(context).pop(); // Close the dialog and the screen
//     } catch (error) {
//       print("Error creating request: $error");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating request: $error'),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInventoryItems());
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Create New Request')),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildSearchBar(),
//                           SizedBox(height: 16),
//                           Text('Categories',
//                               style: Theme.of(context).textTheme.titleLarge),
//                           SizedBox(height: 8),
//                           _buildCategoryList(),
//                           SizedBox(height: 16),
//                           Text('Inventory List',
//                               style: Theme.of(context).textTheme.titleLarge),
//                           SizedBox(height: 8),
//                           _buildInventoryList(),
//                           SizedBox(height: 16),
//                           Text('Selected Items',
//                               style: Theme.of(context).textTheme.titleLarge),
//                           SizedBox(height: 8),
//                           _buildSelectedItemsList(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 _buildSendRequestButton(),
//               ],
//             ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return SizedBox(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return SizedBox(
//           height: 200,
//           child: ListView.builder(
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 child: ListTile(
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text(item['name'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildQuantityControls(item),
//                 ),
//               );
//             },
//           ),
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
//         Text('$quantity ${item['unit']}'),
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
//     return SizedBox(
//       height: 200,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return Card(
//             child: ListTile(
//               leading: CircleAvatar(child: Icon(Icons.inventory)),
//               title: Text('$itemName x $quantity'),
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.edit),
//                     onPressed: () =>
//                         _showEditQuantityDialog(itemName, quantity),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.delete, color: Colors.red),
//                     onPressed: () => _updateQuantity(itemName, 0),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemName, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemName, newQuantity);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request'),
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(vertical: 16),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               DropdownButtonFormField<String>(
//                 value: _selectedLocation,
//                 decoration: InputDecoration(
//                   labelText: 'Delivery Location',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.location_on),
//                 ),
//                 items: _locations
//                     .map((location) => DropdownMenuItem(
//                         value: location, child: Text(location)))
//                     .toList(),
//                 onChanged: (value) =>
//                     setState(() => _selectedLocation = value!),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Name',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.person),
//                 ),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerContactController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Contact Number',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.phone),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.contacts),
//                     onPressed: _pickContact,
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 maxLength: 10,
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _noteController,
//                 decoration: InputDecoration(
//                   labelText: 'Optional Note',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.note),
//                 ),
//                 maxLines: 3,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => _submitRequest(context),
//             child: Text('Submit'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final PermissionStatus permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones
//                   ?.firstWhere((p) => p.value != null,
//                       orElse: () => Item(value: ''))
//                   .value ??
//               '';
//           setState(() {
//             _pickerContactController.text = phone.replaceAll(RegExp(r'\D'), '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print('Error picking contact: $e');
//     }
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     List<Map<String, dynamic>> requestItems =
//         _selectedItems.entries.map((entry) {
//       final item = Provider.of<InventoryProvider>(context, listen: false)
//           .items
//           .firstWhere((item) => item['name'] == entry.key);
//       return {
//         'id': item['id'],
//         'name': entry.key,
//         'quantity': entry.value,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }).toList();

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail!;
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     try {
//       await requestProvider.addRequest(
//         requestItems,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
//         ),
//       );

//       setState(() {
//         _selectedItems.clear();
//         _selectedLocation = 'Default Location';
//         _pickerNameController.clear();
//         _pickerContactController.clear();
//         _noteController.clear();
//       });

//       Navigator.of(context).pop();
//       Navigator.of(context).pop(); // Close the dialog and the screen
//     } catch (error) {
//       print("Error creating request: $error");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating request: $error'),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInventoryItems());
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Create New Request')),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildSearchBar(),
//                     SizedBox(height: 16),
//                     Text('Categories',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildCategoryList(),
//                     SizedBox(height: 16),
//                     Text('Inventory List',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildInventoryList(),
//                     SizedBox(height: 16),
//                     Text('Selected Items',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildSelectedItemsList(),
//                     SizedBox(height: 16),
//                     _buildSendRequestButton(),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return SizedBox(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return SizedBox(
//           height: 200,
//           child: ListView.builder(
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 child: ListTile(
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text(item['name'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildQuantityControls(item),
//                 ),
//               );
//             },
//           ),
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
//         Text('$quantity ${item['unit']}'),
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
//     return SizedBox(
//       height: 200,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return Card(
//             child: ListTile(
//               leading: CircleAvatar(child: Icon(Icons.inventory)),
//               title: Text('$itemName x $quantity'),
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.edit),
//                     onPressed: () =>
//                         _showEditQuantityDialog(itemName, quantity),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.delete, color: Colors.red),
//                     onPressed: () => _updateQuantity(itemName, 0),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Future<void> _showEditQuantityDialog(
//       String itemName, int currentQuantity) async {
//     final TextEditingController controller =
//         TextEditingController(text: currentQuantity.toString());
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Edit Quantity'),
//         content: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(labelText: 'Quantity'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               int newQuantity =
//                   int.tryParse(controller.text) ?? currentQuantity;
//               _updateQuantity(itemName, newQuantity);
//               Navigator.of(context).pop();
//             },
//             child: Text('Update'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Center(
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request'),
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               DropdownButtonFormField<String>(
//                 value: _selectedLocation,
//                 decoration: InputDecoration(
//                   labelText: 'Delivery Location',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.location_on),
//                 ),
//                 items: _locations
//                     .map((location) => DropdownMenuItem(
//                         value: location, child: Text(location)))
//                     .toList(),
//                 onChanged: (value) =>
//                     setState(() => _selectedLocation = value!),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Name',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.person),
//                 ),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerContactController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Contact Number',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.phone),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.contacts),
//                     onPressed: _pickContact,
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 maxLength: 10,
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _noteController,
//                 decoration: InputDecoration(
//                   labelText: 'Optional Note',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.note),
//                 ),
//                 maxLines: 3,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => _submitRequest(context),
//             child: Text('Submit'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final PermissionStatus permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones
//                   ?.firstWhere((p) => p.value != null,
//                       orElse: () => Item(value: ''))
//                   .value ??
//               '';
//           setState(() {
//             _pickerContactController.text = phone.replaceAll(RegExp(r'\D'), '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print('Error picking contact: $e');
//     }
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     List<Map<String, dynamic>> requestItems =
//         _selectedItems.entries.map((entry) {
//       final item = Provider.of<InventoryProvider>(context, listen: false)
//           .items
//           .firstWhere((item) => item['name'] == entry.key);
//       return {
//         'id': item['id'],
//         'name': entry.key,
//         'quantity': entry.value,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }).toList();

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail!;
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     try {
//       await requestProvider.addRequest(
//         requestItems,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
//         ),
//       );

//       setState(() {
//         _selectedItems.clear();
//         _selectedLocation = 'Default Location';
//         _pickerNameController.clear();
//         _pickerContactController.clear();
//         _noteController.clear();
//       });

//       Navigator.of(context).pop();
//       Navigator.of(context).pop(); // Close the dialog and the screen
//     } catch (error) {
//       print("Error creating request: $error");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating request: $error'),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:contacts_service/contacts_service.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   final Map<String, int> _selectedItems = {};
//   final TextEditingController _searchController = TextEditingController();
//   final TextEditingController _pickerNameController = TextEditingController();
//   final TextEditingController _pickerContactController =
//       TextEditingController();
//   final TextEditingController _noteController = TextEditingController();

//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     setState(() => _isLoading = true);
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching inventory items: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Create New Request')),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildSearchBar(),
//                     SizedBox(height: 16),
//                     Text('Categories',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildCategoryList(),
//                     SizedBox(height: 16),
//                     Text('Inventory List',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildInventoryList(),
//                     SizedBox(height: 16),
//                     Text('Selected Items',
//                         style: Theme.of(context).textTheme.titleLarge),
//                     SizedBox(height: 8),
//                     _buildSelectedItemsList(),
//                     SizedBox(height: 16),
//                     _buildSendRequestButton(),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (_) => setState(() {}),
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         Set<String> categories = {
//           'All',
//           ...inventoryProvider.items.map((item) => item['category'] as String)
//         };
//         return SizedBox(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories.elementAt(index);
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: ChoiceChip(
//                   label: Text(category),
//                   selected: _selectedCategory == category,
//                   onSelected: (_) =>
//                       setState(() => _selectedCategory = category),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, _) {
//         List<Map<String, dynamic>> filteredItems = inventoryProvider.items
//             .where((item) =>
//                 (_selectedCategory == 'All' ||
//                     item['category'] == _selectedCategory) &&
//                 item['name']
//                     .toLowerCase()
//                     .contains(_searchController.text.toLowerCase()))
//             .toList();

//         return SizedBox(
//           height: 200,
//           child: ListView.builder(
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 child: ListTile(
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text(item['name'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildQuantityControls(item),
//                 ),
//               );
//             },
//           ),
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
//         Text('$quantity ${item['unit']}'),
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
//     return SizedBox(
//       height: 200,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return Card(
//             child: ListTile(
//               leading: CircleAvatar(child: Icon(Icons.inventory)),
//               title: Text('$itemName x $quantity'),
//               trailing: IconButton(
//                 icon: Icon(Icons.delete, color: Colors.red),
//                 onPressed: () => _updateQuantity(itemName, 0),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Center(
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () => _showRequestDetailsDialog(context),
//         child: Text('Send Request'),
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//         ),
//       ),
//     );
//   }

//   Future<void> _showRequestDetailsDialog(BuildContext context) async {
//     return showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Enter Request Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               DropdownButtonFormField<String>(
//                 value: _selectedLocation,
//                 decoration: InputDecoration(
//                   labelText: 'Delivery Location',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.location_on),
//                 ),
//                 items: _locations
//                     .map((location) => DropdownMenuItem(
//                         value: location, child: Text(location)))
//                     .toList(),
//                 onChanged: (value) =>
//                     setState(() => _selectedLocation = value!),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerNameController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Name',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.person),
//                 ),
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _pickerContactController,
//                 decoration: InputDecoration(
//                   labelText: 'Picker Contact Number',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.phone),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.contacts),
//                     onPressed: _pickContact,
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 maxLength: 10,
//               ),
//               SizedBox(height: 16),
//               TextField(
//                 controller: _noteController,
//                 decoration: InputDecoration(
//                   labelText: 'Optional Note',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.note),
//                 ),
//                 maxLines: 3,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => _submitRequest(context),
//             child: Text('Submit'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickContact() async {
//     try {
//       final PermissionStatus permissionStatus = await _getContactPermission();
//       if (permissionStatus == PermissionStatus.granted) {
//         final Contact? contact =
//             await ContactsService.openDeviceContactPicker();
//         if (contact != null) {
//           final phone = contact.phones
//                   ?.firstWhere((p) => p.value != null,
//                       orElse: () => Item(value: ''))
//                   .value ??
//               '';
//           setState(() {
//             _pickerContactController.text = phone.replaceAll(RegExp(r'\D'), '');
//           });
//         }
//       } else {
//         _handleInvalidPermissions(permissionStatus);
//       }
//     } catch (e) {
//       print('Error picking contact: $e');
//     }
//   }

//   Future<PermissionStatus> _getContactPermission() async {
//     PermissionStatus permission = await Permission.contacts.status;
//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.permanentlyDenied) {
//       PermissionStatus permissionStatus = await Permission.contacts.request();
//       return permissionStatus;
//     } else {
//       return permission;
//     }
//   }

//   void _handleInvalidPermissions(PermissionStatus permissionStatus) {
//     if (permissionStatus == PermissionStatus.denied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Access to contact data denied')),
//       );
//     } else if (permissionStatus == PermissionStatus.permanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Contact data not available on device')),
//       );
//     }
//   }

//   Future<void> _submitRequest(BuildContext context) async {
//     if (_pickerNameController.text.isEmpty ||
//         _pickerContactController.text.isEmpty ||
//         _pickerContactController.text.length != 10 ||
//         _selectedLocation.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Please fill all required fields with valid data.'),
//         ),
//       );
//       return;
//     }

//     List<Map<String, dynamic>> requestItems =
//         _selectedItems.entries.map((entry) {
//       final item = Provider.of<InventoryProvider>(context, listen: false)
//           .items
//           .firstWhere((item) => item['name'] == entry.key);
//       return {
//         'id': item['id'],
//         'name': entry.key,
//         'quantity': entry.value,
//         'unit': item['unit'] ?? 'pcs',
//       };
//     }).toList();

//     final currentUserEmail =
//         Provider.of<AuthProvider>(context, listen: false).currentUserEmail!;
//     final inventoryProvider =
//         Provider.of<InventoryProvider>(context, listen: false);
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     try {
//       await requestProvider.addRequest(
//         requestItems,
//         _selectedLocation,
//         _pickerNameController.text,
//         _pickerContactController.text,
//         _noteController.text,
//         currentUserEmail,
//         inventoryProvider,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
//         ),
//       );

//       setState(() {
//         _selectedItems.clear();
//         _selectedLocation = 'Default Location';
//         _pickerNameController.clear();
//         _pickerContactController.clear();
//         _noteController.clear();
//       });

//       Navigator.of(context).pop();
//       Navigator.of(context).pop(); // Close the dialog and the screen
//     } catch (error) {
//       print("Error creating request: $error");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error creating request: $error'),
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _pickerNameController.dispose();
//     _pickerContactController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/inventory_provider.dart';
// import '../../providers/auth_provider.dart';

// class CreateUserRequestScreen extends StatefulWidget {
//   @override
//   _CreateUserRequestScreenState createState() =>
//       _CreateUserRequestScreenState();
// }

// class _CreateUserRequestScreenState extends State<CreateUserRequestScreen> {
//   Map<String, int> _selectedItems = {};
//   String _searchQuery = '';
//   String _selectedLocation = 'Default Location';
//   String _selectedCategory = 'All';
//   List<String> _locations = ['Default Location', 'Location 1', 'Location 2'];
//   TextEditingController _pickerNameController = TextEditingController();
//   TextEditingController _pickerContactController = TextEditingController();
//   TextEditingController _noteController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchInventoryItems();
//     });
//   }

//   Future<void> _fetchInventoryItems() async {
//     try {
//       await Provider.of<InventoryProvider>(context, listen: false).fetchItems();
//       print("Inventory items fetched successfully");
//     } catch (e) {
//       print("Error fetching inventory items: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create New Request'),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: <Widget>[
//               _buildSearchBar(),
//               SizedBox(height: 16),
//               Text('Categories',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildCategoryList(),
//               SizedBox(height: 16),
//               Text('Inventory List',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildInventoryList(),
//               SizedBox(height: 16),
//               Text('Selected Items',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               SizedBox(height: 8),
//               _buildSelectedItemsList(),
//               SizedBox(height: 16),
//               _buildSendRequestButton(),
//               SizedBox(height: 16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       decoration: InputDecoration(
//         labelText: 'Search',
//         border: OutlineInputBorder(),
//         prefixIcon: Icon(Icons.search),
//       ),
//       onChanged: (value) {
//         setState(() {
//           _searchQuery = value;
//         });
//       },
//     );
//   }

//   Widget _buildCategoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         List<String> categories = inventoryProvider.items
//             .map((item) => item['category'] as String)
//             .toSet()
//             .toList();
//         categories.insert(0, 'All');

//         return Container(
//           height: 50,
//           child: ListView.builder(
//             scrollDirection: Axis.horizontal,
//             itemCount: categories.length,
//             itemBuilder: (context, index) {
//               String category = categories[index];
//               return GestureDetector(
//                 onTap: () {
//                   setState(() {
//                     _selectedCategory = category;
//                   });
//                 },
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   margin: EdgeInsets.symmetric(horizontal: 8),
//                   decoration: BoxDecoration(
//                     color: _selectedCategory == category
//                         ? Colors.blue
//                         : Colors.grey,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Center(
//                     child: Text(
//                       category,
//                       style: TextStyle(
//                           color: Colors.white, fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildInventoryList() {
//     return Consumer<InventoryProvider>(
//       builder: (context, inventoryProvider, child) {
//         if (inventoryProvider.items.isEmpty) {
//           return Center(child: CircularProgressIndicator());
//         }

//         List<Map<String, dynamic>> filteredItems = inventoryProvider
//             .getItemsByCategory(_selectedCategory)
//             .where((item) =>
//                 item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
//             .toList();

//         return Container(
//           height: 200,
//           child: ListView.builder(
//             itemCount: filteredItems.length,
//             itemBuilder: (context, index) {
//               Map<String, dynamic> item = filteredItems[index];
//               return Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   contentPadding: EdgeInsets.all(16),
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text(item['name'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildQuantityControls(item),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildQuantityControls(Map<String, dynamic> item) {
//     return _selectedItems.containsKey(item['name'])
//         ? Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove),
//                 onPressed: () {
//                   setState(() {
//                     if (_selectedItems[item['name']] == 1) {
//                       _selectedItems.remove(item['name']);
//                     } else {
//                       _selectedItems[item['name']] =
//                           _selectedItems[item['name']]! - 1;
//                     }
//                   });
//                 },
//               ),
//               Text('${_selectedItems[item['name']]} ${item['unit']}'),
//               IconButton(
//                 icon: Icon(Icons.add),
//                 onPressed: () {
//                   setState(() {
//                     _selectedItems[item['name']] =
//                         _selectedItems[item['name']]! + 1;
//                   });
//                 },
//               ),
//             ],
//           )
//         : IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () {
//               setState(() {
//                 _selectedItems[item['name']] = 1;
//               });
//             },
//           );
//   }

//   Widget _buildSelectedItemsList() {
//     return Container(
//       height: 200,
//       child: ListView.builder(
//         itemCount: _selectedItems.length,
//         itemBuilder: (context, index) {
//           String itemName = _selectedItems.keys.elementAt(index);
//           int quantity = _selectedItems[itemName]!;
//           return Consumer<InventoryProvider>(
//             builder: (context, inventoryProvider, child) {
//               Map<String, dynamic> item = inventoryProvider.items
//                   .firstWhere((element) => element['name'] == itemName);
//               return Card(
//                 elevation: 2,
//                 margin: EdgeInsets.symmetric(vertical: 8),
//                 child: ListTile(
//                   contentPadding: EdgeInsets.all(16),
//                   leading: CircleAvatar(child: Icon(Icons.inventory)),
//                   title: Text('$itemName x$quantity ${item['unit']}',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   trailing: _buildSelectedQuantityControls(itemName),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildSelectedQuantityControls(String itemName) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           icon: Icon(Icons.remove),
//           onPressed: () {
//             setState(() {
//               if (_selectedItems[itemName] == 1) {
//                 _selectedItems.remove(itemName);
//               } else {
//                 _selectedItems[itemName] = _selectedItems[itemName]! - 1;
//               }
//             });
//           },
//         ),
//         Container(
//           width: 40,
//           child: TextField(
//             keyboardType: TextInputType.number,
//             onChanged: (value) {
//               setState(() {
//                 _selectedItems[itemName] = int.tryParse(value) ?? 1;
//               });
//             },
//             decoration: InputDecoration(
//               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//               isDense: true,
//               border: OutlineInputBorder(),
//             ),
//             controller: TextEditingController()
//               ..text = _selectedItems[itemName].toString(),
//           ),
//         ),
//         IconButton(
//           icon: Icon(Icons.add),
//           onPressed: () {
//             setState(() {
//               _selectedItems[itemName] = _selectedItems[itemName]! + 1;
//             });
//           },
//         ),
//         IconButton(
//           icon: Icon(Icons.remove_circle, color: Colors.red),
//           onPressed: () {
//             setState(() {
//               _selectedItems.remove(itemName);
//             });
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildSendRequestButton() {
//     return Center(
//       child: ElevatedButton(
//         onPressed: _selectedItems.isEmpty
//             ? null
//             : () {
//                 _showRequestDetailsDialog(context);
//               },
//         child: Text('Send Request'),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _selectedItems.isEmpty ? Colors.grey : Colors.blue,
//           padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//         ),
//       ),
//     );
//   }

//   void _showRequestDetailsDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Enter Request Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 DropdownButtonFormField<String>(
//                   value: _selectedLocation,
//                   decoration: InputDecoration(
//                     labelText: 'Delivery Location',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.location_on),
//                   ),
//                   items: _locations.map((location) {
//                     return DropdownMenuItem(
//                       value: location,
//                       child: Text(location),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedLocation = value!;
//                     });
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerNameController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Name',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.person),
//                   ),
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _pickerContactController,
//                   decoration: InputDecoration(
//                     labelText: 'Picker Contact Number',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.phone),
//                   ),
//                   keyboardType: TextInputType.phone,
//                   maxLength: 10,
//                 ),
//                 SizedBox(height: 16),
//                 TextField(
//                   controller: _noteController,
//                   decoration: InputDecoration(
//                     labelText: 'Optional Note',
//                     border: OutlineInputBorder(),
//                     prefixIcon: Icon(Icons.note),
//                   ),
//                   maxLines: 3,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 if (_pickerNameController.text.isEmpty ||
//                     _pickerContactController.text.isEmpty ||
//                     _pickerContactController.text.length != 10 ||
//                     _selectedLocation.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                           'Please fill all the required fields (Picker Name, Contact Number, Location) with valid data.'),
//                     ),
//                   );
//                   return;
//                 }

//                 List<Map<String, dynamic>> requestItems =
//                     _selectedItems.entries.map((entry) {
//                   final item =
//                       Provider.of<InventoryProvider>(context, listen: false)
//                           .items
//                           .firstWhere((item) => item['name'] == entry.key);
//                   return {
//                     'id': item['id'],
//                     'name': entry.key,
//                     'quantity': entry.value,
//                     'unit': item['unit'] ?? 'pcs',
//                   };
//                 }).toList();

//                 String location = _selectedLocation;
//                 String pickerName = _pickerNameController.text;
//                 String pickerContact = _pickerContactController.text;
//                 String note = _noteController.text;
//                 final currentUserEmail =
//                     Provider.of<AuthProvider>(context, listen: false)
//                         .currentUserEmail!;
//                 final inventoryProvider =
//                     Provider.of<InventoryProvider>(context, listen: false);
//                 final requestProvider =
//                     Provider.of<RequestProvider>(context, listen: false);

//                 try {
//                   await requestProvider.addRequest(
//                     requestItems,
//                     location,
//                     pickerName,
//                     pickerContact,
//                     note,
//                     currentUserEmail,
//                     inventoryProvider,
//                   );

//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                           'Request added successfully. Some items may be partially fulfilled due to inventory levels.'),
//                     ),
//                   );

//                   setState(() {
//                     _selectedItems.clear();
//                     _selectedLocation = 'Default Location';
//                     _pickerNameController.clear();
//                     _pickerContactController.clear();
//                     _noteController.clear();
//                   });

//                   Navigator.of(context).pop();
//                   Navigator.of(context)
//                       .pop(); // Close the dialog and the screen
//                 } catch (error) {
//                   print("Error creating request: $error");
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Error creating request: $error'),
//                     ),
//                   );
//                 }
//               },
//               child: Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
