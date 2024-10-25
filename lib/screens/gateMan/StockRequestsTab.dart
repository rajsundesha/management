import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import 'dart:math' as math;

class StockRequestsTab extends StatefulWidget {
  @override
  _StockRequestsTabState createState() => _StockRequestsTabState();
}

class _StockRequestsTabState extends State<StockRequestsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();
    _tabController.addListener(() {
      _pageController.animateToPage(
        _tabController.index,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCustomTabBar(),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              _tabController.animateTo(index);
            },
            children: [
              _ActiveRequestsTab(),
              _CompletedRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        tabs: [
          Tab(text: 'Active'),
          Tab(text: 'Completed'),
        ],
        labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ActiveRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestProvider.getActiveStockRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final activeStockRequests = snapshot.data ?? [];

            return Column(
              children: [
                _buildSummaryCard(activeStockRequests.length),
                Expanded(
                  child: activeStockRequests.isEmpty
                      ? Center(child: Text('No active stock requests found.'))
                      : ListView.builder(
                          itemCount: activeStockRequests.length,
                          itemBuilder: (context, index) {
                            final request = activeStockRequests[index];
                            return _buildStockRequestCard(context, request);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(int count) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueAccent,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.white, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Active Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockRequestCard(
      BuildContext context, Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.inventory, color: Colors.blueAccent),
        title: Text(
          'Request #${request['id']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${request['status']}',
          style: TextStyle(color: _getStatusColor(request['status'])),
        ),
        children: [
          Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildStockItemsList(request['items']),
                SizedBox(height: 10),
                _buildActionButtons(context, request),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, Map<String, dynamic> request) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        icon: Icon(Icons.check_circle_outline),
        label: Text('Confirm Receipt'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onPressed: () => _showReceiveDialog(context, request),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'partially_fulfilled':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  List<Widget> _buildStockItemsList(List<dynamic>? items) {
    if (items == null || items.isEmpty) return [Text('No items')];
    return items.map((item) {
      double totalQuantity = (item['quantity'] as num).toDouble();
      double receivedQuantity =
          (item['receivedQuantity'] as num? ?? 0).toDouble();
      double remainingQuantity =
          math.max<double>(0.0, totalQuantity - receivedQuantity);

      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                item['name'],
                style: TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                '${receivedQuantity.toStringAsFixed(2)} / ${totalQuantity.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                '(${remainingQuantity.toStringAsFixed(2)} left)',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showReceiveDialog(BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => ReceiveStockDialog(
        request: request,
        gateManId: Provider.of<AuthProvider>(context, listen: false).user?.uid,
      ),
    );
  }
}

class _CompletedRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: requestProvider.getCompletedStockRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final completedStockRequests = snapshot.data ?? [];

            return Column(
              children: [
                _buildSummaryCard(completedStockRequests.length),
                Expanded(
                  child: completedStockRequests.isEmpty
                      ? Center(
                          child: Text('No completed stock requests found.'))
                      : ListView.builder(
                          itemCount: completedStockRequests.length,
                          itemBuilder: (context, index) {
                            final request = completedStockRequests[index];
                            return _buildCompletedRequestCard(context, request);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(int count) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Completed Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedRequestCard(
      BuildContext context, Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.inventory, color: Colors.green),
        title: Text(
          'Request #${request['id']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Completed on: ${_formatDate(request['fulfilledAt'])}',
          style: TextStyle(color: Colors.black54),
        ),
        children: [
          Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildStockItemsList(request['items']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'N/A';
  }

  List<Widget> _buildStockItemsList(List<dynamic>? items) {
    if (items == null || items.isEmpty) return [Text('No items')];
    return items.map((item) {
      final receivedQuantity =
          (item['receivedQuantity'] as num?)?.toDouble() ?? 0.0;
      final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;

      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                item['name'] ?? 'Unknown Item',
                style: TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                '${receivedQuantity.toStringAsFixed(2)} / ${totalQuantity.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }).toList();
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
  bool _isLoading = false;
  bool _allowOverReceipt = false;

  @override
  void initState() {
    super.initState();
    _initializeReceivedItems();
  }

  void _initializeReceivedItems() {
    _receivedItems = (widget.request['items'] as List? ?? []).map((item) {
      double totalQuantity = (item['quantity'] as num).toDouble();
      double receivedQuantity =
          (item['receivedQuantity'] as num? ?? 0).toDouble();
      double remainingQuantity =
          math.max<double>(0.0, totalQuantity - receivedQuantity);
      return {
        'id': item['id'],
        'name': item['name'],
        'totalQuantity': totalQuantity,
        'receivedQuantity': receivedQuantity,
        'remainingQuantity': remainingQuantity,
        'newReceivedQuantity': 0.0,
        'isPipe': item['isPipe'] ?? false,
        'unit': item['unit'] ?? 'N/A',
        'pipeLength': (item['pipeLength'] as num? ?? 20.0).toDouble(),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    bool hasValidNewQuantities = _receivedItems.any((item) =>
        item['newReceivedQuantity'] > 0 &&
        (item['newReceivedQuantity'] <= item['remainingQuantity'] ||
            _allowOverReceipt));

    return AlertDialog(
      title: Text(
        'Receive Stock Items',
        style: TextStyle(color: Theme.of(context).primaryColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._receivedItems.map((item) => _buildItemReceiveRow(item)),
            SizedBox(height: 16),
            _buildTotalReceivedInfo(),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('Allow Over-Receipt'),
              value: _allowOverReceipt,
              onChanged: (bool? value) {
                setState(() {
                  _allowOverReceipt = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel', style: TextStyle(color: Colors.black54)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white))
              : Text('Confirm Receipt'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: (!_isLoading && hasValidNewQuantities)
              ? () => _confirmReceive(context)
              : null,
        ),
      ],
    );
  }

  Widget _buildItemReceiveRow(Map<String, dynamic> item) {
    bool itemFullyReceived = item['remainingQuantity'] == 0;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Added flexibility to prevent overflow
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (itemFullyReceived)
                  Chip(
                    label: Text('Fully Received'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoText(
                          'Total Ordered', item['totalQuantity'], item['unit']),
                      _buildInfoText('Previously Received',
                          item['receivedQuantity'], item['unit']),
                      _buildInfoText(
                          'Remaining', item['remainingQuantity'], item['unit'],
                          isHighlighted: !itemFullyReceived),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: '0',
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Receive',
                      border: OutlineInputBorder(),
                      suffixText: item['unit'],
                    ),
                    enabled: !itemFullyReceived || _allowOverReceipt,
                    onChanged: (value) {
                      setState(() {
                        double newReceivedQuantity =
                            double.tryParse(value) ?? 0.0;
                        _updateReceivedQuantity(item, newReceivedQuantity);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String label, double value, String unit,
      {bool isHighlighted = false}) {
    return Text(
      '$label: ${value.toStringAsFixed(2)} $unit',
      style: TextStyle(
        color: isHighlighted ? Colors.red : Colors.black87,
        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTotalReceivedInfo() {
    double totalReceived = _receivedItems.fold(
        0, (sum, item) => sum + (item['newReceivedQuantity'] as double));
    return Card(
      color: Colors.blueAccent.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total New Received:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${totalReceived.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _updateReceivedQuantity(
      Map<String, dynamic> item, double newReceivedQuantity) {
    setState(() {
      item['newReceivedQuantity'] = newReceivedQuantity;
    });
  }

  void _confirmReceive(BuildContext context) {
    if (!_validateInputs()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please check the received quantities or enable over-receipt')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Only include items where new quantities are entered
    List<Map<String, dynamic>> itemsToUpdate = _receivedItems
        .where((item) => item['newReceivedQuantity'] > 0)
        .map((item) {
      return {
        'id': item['id'],
        'name': item['name'],
        'receivedQuantity': item['newReceivedQuantity'],
      };
    }).toList();

    if (itemsToUpdate.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No new quantities entered')),
      );
      return;
    }

    Provider.of<RequestProvider>(context, listen: false)
        .fulfillStockRequest(widget.request['id'], itemsToUpdate,
            widget.gateManId!, _allowOverReceipt)
        .then((_) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock request updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating stock request: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  bool _validateInputs() {
    bool isValid = true;
    bool anyNewReceived = false;

    for (var item in _receivedItems) {
      double newReceivedQuantity = item['newReceivedQuantity'] as double;
      double remainingQuantity = item['remainingQuantity'] as double;

      if (newReceivedQuantity < 0) {
        isValid = false;
        break;
      }

      if (newReceivedQuantity > 0) {
        anyNewReceived = true;
        if (!_allowOverReceipt && newReceivedQuantity > remainingQuantity) {
          isValid = false;
          break;
        }
      }
    }

    return isValid && anyNewReceived;
  }
}
