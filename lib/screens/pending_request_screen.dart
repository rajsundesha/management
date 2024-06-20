import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/request_provider.dart';
import 'edit_request_bottom_sheet.dart';

class PendingRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Requests'),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          return ListView.builder(
            itemCount: requestProvider.requests.length,
            itemBuilder: (context, index) {
              if (requestProvider.requests[index]['status'] != 'pending') {
                return Container();
              }
              return Card(
                child: ListTile(
                  title: Text(
                    'Items: ${requestProvider.requests[index]['items'].map((item) => '${item['quantity']} x ${item['name']}').join(', ')}',
                  ),
                  subtitle: Text(
                    'Location: ${requestProvider.requests[index]['location']}\n'
                    'Picker: ${requestProvider.requests[index]['pickerName']}\n'
                    'Contact: ${requestProvider.requests[index]['pickerContact']}\n'
                    'Status: ${requestProvider.requests[index]['status']}',
                  ),
                  leading: Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                  onTap: () => _showRequestOptions(
                    context,
                    index,
                    List<Map<String, dynamic>>.from(
                        requestProvider.requests[index]['items']),
                    requestProvider.requests[index]['location'] ??
                        'Default Location',
                    requestProvider.requests[index]['pickerName'] ?? '',
                    requestProvider.requests[index]['pickerContact'] ?? '',
                    requestProvider.requests[index]['note'] ?? '',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRequestOptions(
    BuildContext context,
    int index,
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Request Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                ...items.map((item) => ListTile(
                      title: Text('${item['name']} x${item['quantity']}'),
                    )),
                SizedBox(height: 16),
                if (note.isNotEmpty) ...[
                  Text(
                    'Note:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(note),
                  SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editRequest(
                      context,
                      index,
                      items,
                      location,
                      pickerName,
                      pickerContact,
                      note,
                    );
                  },
                  child: Text('Edit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Consistent button color
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteRequest(context, index);
                  },
                  child: Text('Delete Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Consistent button color
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editRequest(
    BuildContext context,
    int index,
    List<Map<String, dynamic>> items,
    String location,
    String pickerName,
    String pickerContact,
    String note,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EditRequestBottomSheet(
        index: index,
        items: items,
        location: location,
        pickerName: pickerName,
        pickerContact: pickerContact,
        note: note,
      ),
    );
  }

  void _deleteRequest(BuildContext context, int index) {
    Provider.of<RequestProvider>(context, listen: false).cancelRequest(index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request deleted')),
    );
  }
}
