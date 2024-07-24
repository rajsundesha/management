import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:dhavla_road_project/screens/common/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/gateMan/gateman_stock_request_screen.dart';
import '../../providers/notification_provider.dart' as custom_notification;

class GateManDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.user == null || authProvider.role != 'Gate Man') {
          return Scaffold(
            body: Center(
              child: Text('You do not have permission to access this page.'),
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Gate Man Dashboard'),
              actions: [
                _buildNotificationIcon(),
                _buildLogoutButton(context, authProvider),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Approved Requests'),
                  Tab(text: 'Stock Requests'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                SingleChildScrollView(child: _OverviewTab()),
                _ApprovedRequestsTab(),
                GatemanStockRequestScreen(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer<custom_notification.NotificationProvider>(
      builder: (context, notificationProvider, child) {
        int unreadCount = notificationProvider.unreadNotificationsCount;
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NotificationsScreen()),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await authProvider.logout();
          Navigator.of(context).pushReplacementNamed('/login');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out. Please try again.')),
          );
        }
      },
      child: Text('Logout'),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildStatistics(context),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: _buildRequestStatusChart(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        final todayRequests = requestProvider.getTodayRequests();
        final approvedRequests = todayRequests
            .where((request) => request['status'] == 'approved')
            .length;
        final fulfilledRequests = todayRequests
            .where((request) => request['status'] == 'fulfilled')
            .length;
        final pendingRequests = todayRequests
            .where((request) => request['status'] == 'pending')
            .length;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatisticCard('Total', todayRequests.length),
                _buildStatisticCard('Approved', approvedRequests),
                _buildStatisticCard('Fulfilled', fulfilledRequests),
              ],
            ),
            SizedBox(height: 16),
            _buildRequestStatusChart(context),
          ],
        );
      },
    );
  }

  Widget _buildStatisticCard(String title, int count) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusChart(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        final todayRequests = requestProvider.getTodayRequests();
        final pendingRequests = todayRequests
            .where((request) => request['status'] == 'pending')
            .length;
        final approvedRequests = todayRequests
            .where((request) => request['status'] == 'approved')
            .length;
        final fulfilledRequests = todayRequests
            .where((request) => request['status'] == 'fulfilled')
            .length;

        final data = [
          RequestStatus('Pending', pendingRequests, Colors.orange),
          RequestStatus('Approved', approvedRequests, Colors.green),
          RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
        ];

        return Container(
          height: 200,
          child: SfCircularChart(
            legend: Legend(isVisible: true),
            series: <CircularSeries>[
              PieSeries<RequestStatus, String>(
                dataSource: data,
                xValueMapper: (RequestStatus data, _) => data.status,
                yValueMapper: (RequestStatus data, _) => data.count,
                pointColorMapper: (RequestStatus data, _) => data.color,
              ),
            ],
          ),
        );
      },
    );
  }
}

class RequestStatus {
  final String status;
  final int count;
  final Color color;

  RequestStatus(this.status, this.count, this.color);
}

class _ApprovedRequestsTab extends StatefulWidget {
  @override
  _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
}

class _ApprovedRequestsTabState extends State<_ApprovedRequestsTab> {
  bool _shouldShowVerificationDialog = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _pendingUniqueCode;

  @override
  Widget build(BuildContext context) {
    if (_shouldShowVerificationDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _shouldShowVerificationDialog = false;
        });
        if (_pendingUniqueCode != null) {
          _verifyCodeDialog(context, _pendingUniqueCode!);
          _pendingUniqueCode = null;
        }
      });
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          SizedBox(height: 16),
          Expanded(
            child: _buildApprovedRequestsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Requests by Picker Name or Contact',
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

  Widget _buildApprovedRequestsList() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        final approvedRequests =
            requestProvider.getApprovedRequests(_searchQuery);

        if (approvedRequests.isEmpty) {
          return Center(child: Text('No approved requests found.'));
        }

        return ListView.builder(
          itemCount: approvedRequests.length,
          itemBuilder: (context, index) {
            final request = approvedRequests[index];
            return _buildRequestCard(context, request);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    return Card(
      child: ListTile(
        title: Text(
          'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
        ),
        subtitle: Text(
          'Location: ${request['location']}\n'
          'Picker: ${request['pickerName']}\n'
          'Contact: ${request['pickerContact']}\n'
          'Status: ${request['status']}\n'
          'Unique Code: ${request['uniqueCode']}',
        ),
        leading: Icon(
          Icons.request_page,
          color: Colors.green,
        ),
        trailing: IconButton(
          icon: Icon(Icons.verified, color: Colors.blue),
          onPressed: () {
            _verifyCodeDialog(context, request['uniqueCode']);
          },
        ),
      ),
    );
  }

  void _verifyCodeDialog(BuildContext context, String uniqueCode) {
    final TextEditingController _codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Verify Unique Code'),
          content: TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Enter 6-digit Unique Code',
              hintText: '000000',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_codeController.text.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a 6-digit code')),
                  );
                } else {
                  Navigator.of(dialogContext).pop();
                  _verifyCode(context, _codeController.text, uniqueCode);
                }
              },
              child: Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void _verifyCode(
      BuildContext context, String enteredCode, String uniqueCode) async {
    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a 6-digit code')),
      );
      return;
    }

    print("Verifying code: $enteredCode");
    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      bool isValid = await requestProvider.checkCodeValidity(enteredCode);

      // Dismiss loading indicator
      Navigator.of(context).pop();

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid code. Please check and try again.'),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: () {
                setState(() {
                  _shouldShowVerificationDialog = true;
                  _pendingUniqueCode = uniqueCode;
                });
              },
            ),
          ),
        );
        return;
      }

      await requestProvider.fulfillRequestByCode(enteredCode);

      print("Code verification successful");

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code verified! Items can be collected.')),
      );

      // Refresh the list
      setState(() {});
    } catch (e) {
      // Dismiss loading indicator if it's still showing
      Navigator.of(context).popUntil((route) => route.isFirst);

      print("Error during code verification: $e");

      // Show error message with option to try again
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error: ${e.toString()}. Please check the code and try again.'),
          action: SnackBarAction(
            label: 'Try Again',
            onPressed: () {
              setState(() {
                _shouldShowVerificationDialog = true;
                _pendingUniqueCode = uniqueCode;
              });
            },
          ),
        ),
      );
    }
  }
}
