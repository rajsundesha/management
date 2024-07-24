import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import 'edit_admin_request_bottom_sheet.dart';

class AdminManageRequestsScreen extends StatefulWidget {
  @override
  _AdminManageRequestsScreenState createState() =>
      _AdminManageRequestsScreenState();
}

class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _filterLocation = 'All';
  DateTimeRange? _dateRange;
  final List<String> _locations = [
    'All',
    'Location1',
    'Location2',
    'Location3'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Requests'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            SizedBox(height: 16),
            _buildFilterRow(),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<RequestProvider>(context, listen: false)
                    .getRequestsStream('admin@example.com', 'Admin', 'All'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final allRequests = snapshot.data ?? [];
                  print("Total unfiltered requests: ${allRequests.length}");

                  final requests = allRequests.where((request) {
                    final requestDate = request['timestamp'] as DateTime?;
                    final matchesDate = _dateRange == null ||
                        (requestDate != null &&
                            requestDate.isAfter(_dateRange!.start) &&
                            requestDate.isBefore(
                                _dateRange!.end.add(Duration(days: 1))));
                    final matchesSearch = (request['createdBy'] as String?)
                            ?.toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ??
                        false;
                    final matchesFilter = _filterStatus == 'All' ||
                            (request['status'] as String?)!
                                .toLowerCase()
                                .contains(_filterStatus.toLowerCase()) ??
                        false;
                    final matchesLocation = _filterLocation == 'All' ||
                        request['location'] == _filterLocation;

                    final matchesAll = matchesDate &&
                        matchesSearch &&
                        matchesFilter &&
                        matchesLocation;
                    print(
                        "Request ${request['id']} matches filters: $matchesAll");
                    return matchesAll;
                  }).toList();
                  print("Filtered requests: ${requests.length}");

                  if (requests.isEmpty) {
                    return Center(child: Text('No requests found.'));
                  }

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final requestDate = request['timestamp'] as DateTime?;

                      // return Card(
                      //   child: ExpansionTile(
                      //     title: Text(
                      //       'Request by: ${request['createdBy'] ?? 'N/A'}',
                      //       style: TextStyle(
                      //           fontWeight: FontWeight.bold, fontSize: 16),
                      //     ),
                      //     subtitle: Text(
                      //       'Created on: ${requestDate != null ? DateFormat('yyyy-MM-dd').format(requestDate) : 'N/A'} at ${requestDate != null ? DateFormat('hh:mm a').format(requestDate) : 'N/A'}\n'
                      //       'Status: ${_capitalize((request['status'] ?? 'N/A').toString())}',
                      //     ),
                      return Card(
                        child: ExpansionTile(
                          title: Text(
                            'Request by: ${request['createdByName'] ?? request['createdByEmail'] ?? 'Unknown User'}',
                            // request['name'] != null &&
                            //         request['name'].isNotEmpty
                            //     ? request['name']
                            //     : 'Request #${index + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            // 'Created by: ${request['createdBy'] ?? 'N/A'}\n'
                            'Created on: ${requestDate != null ? DateFormat('yyyy-MM-dd').format(requestDate) : 'N/A'} at ${requestDate != null ? DateFormat('hh:mm a').format(requestDate) : 'N/A'}\n'
                            'Status: ${_capitalize((request['status'] ?? 'N/A').toString())}',
                          ),
                          leading: Icon(
                            Icons.request_page,
                            color: request['status'] == 'pending'
                                ? Colors.orange
                                : request['status'] == 'approved'
                                    ? Colors.blue
                                    : request['status'] == 'fulfilled'
                                        ? Colors.green
                                        : Colors.red,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('Picker:',
                                      request['pickerName'] ?? 'N/A'),
                                  _buildInfoRow('Location:',
                                      request['location'] ?? 'N/A'),
                                  _buildInfoRow('Contact:',
                                      request['pickerContact'] ?? 'N/A'),
                                  _buildInfoRow(
                                      'Items:',
                                      (request['items'] as List<dynamic>?)
                                              ?.map((item) =>
                                                  '${item['quantity']} ${item['unit']} x ${item['name']}')
                                              .join(', ') ??
                                          'No items'),
                                  _buildInfoRow(
                                      'Note:', request['note'] ?? 'N/A'),
                                  // _buildInfoRow(
                                  //     'Created By:', request['createdBy']),
                                  _buildInfoRow('Unique Code:',
                                      request['uniqueCode'] ?? 'N/A'),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children:
                                        _buildActionButtons(context, request),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search by Creator',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFilterRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildFilterDropdown()),
            SizedBox(width: 16),
            Expanded(child: _buildLocationFilterDropdown()),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final selectedRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (selectedRange != null) {
                    setState(() {
                      _dateRange = DateTimeRange(
                        start: DateTime(selectedRange.start.year,
                            selectedRange.start.month, selectedRange.start.day),
                        end: DateTime(
                            selectedRange.end.year,
                            selectedRange.end.month,
                            selectedRange.end.day,
                            23,
                            59,
                            59),
                      );
                    });
                  }
                },
                child: Text('Select Date Range'),
              ),
            ),
            if (_dateRange != null)
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _dateRange = null;
                  });
                },
              ),
          ],
        ),
        if (_dateRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Selected Range: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
              style: TextStyle(fontSize: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Filter by Status',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          onChanged: (newValue) {
            setState(() {
              _filterStatus = newValue!;
            });
          },
          items: ['All', 'Pending', 'Approved', 'Fulfilled', 'Rejected']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(_capitalize(value)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationFilterDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Filter by Location',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterLocation,
          onChanged: (newValue) {
            setState(() {
              _filterLocation = newValue!;
            });
          },
          items: _locations.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
      BuildContext context, Map<String, dynamic> request) {
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);
    List<Widget> buttons = [];

    if (request['status'] == 'pending') {
      buttons.add(_buildActionButton(
        Icons.check,
        'Approve',
        Colors.green,
        () {
          requestProvider.updateRequestStatus(request['id'], 'approved');
        },
      ));
      buttons.add(SizedBox(width: 8));
      buttons.add(_buildActionButton(
        Icons.close,
        'Reject',
        Colors.red,
        () {
          requestProvider.updateRequestStatus(request['id'], 'rejected');
        },
      ));
    } else if (request['status'] == 'approved') {
      buttons.add(_buildActionButton(
        Icons.check_circle,
        'Fulfill',
        Colors.blue,
        () {
          _showCodeDialog(context, requestProvider, request['id']);
        },
      ));
      buttons.add(SizedBox(width: 8));
      buttons.add(_buildActionButton(
        Icons.close,
        'Reject',
        Colors.red,
        () {
          requestProvider.updateRequestStatus(request['id'], 'rejected');
        },
      ));
    } else if (request['status'] == 'rejected') {
      buttons.add(_buildActionButton(
        Icons.check,
        'Approve',
        Colors.green,
        () {
          requestProvider.updateRequestStatus(request['id'], 'approved');
        },
      ));
    }

    buttons.add(SizedBox(width: 8));
    buttons.add(_buildActionButton(
      Icons.edit,
      'Edit',
      Colors.blue,
      () {
        _editRequest(context, request['id'], request);
      },
    ));

    return buttons;
  }

  void _showCodeDialog(
      BuildContext context, RequestProvider requestProvider, String requestId) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Unique Code'),
          content: TextField(
            controller: codeController,
            decoration: InputDecoration(hintText: 'Unique Code'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final request = requestProvider.getRequestById(requestId);
                if (request != null &&
                    codeController.text == request['uniqueCode']) {
                  requestProvider.updateRequestStatus(requestId, 'fulfilled');
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid code!')),
                  );
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return Flexible(
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _editRequest(
      BuildContext context, String requestId, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditAdminRequestBottomSheet(
        id: requestId,
        items: List<Map<String, dynamic>>.from(request['items'] ?? []),
        location: request['location'] ?? 'Default Location',
        pickerName: request['pickerName'] ?? '',
        pickerContact: request['pickerContact'] ?? '',
        note: request['note'] ?? '',
      ),
    );
  }

  String _capitalize(String text) {
    return text.isNotEmpty
        ? '${text[0].toUpperCase()}${text.substring(1)}'
        : '';
  }
}
