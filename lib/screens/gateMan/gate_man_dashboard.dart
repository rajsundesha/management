import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/common/notification_screen.dart';

class GateManDashboard extends StatefulWidget {
  @override
  _GateManDashboardState createState() => _GateManDashboardState();
}

class _GateManDashboardState extends State<GateManDashboard> {
  DateTime _selectedDate = DateTime.now();
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

        return Scaffold(
          appBar: AppBar(
            title: Text('Gate Man Dashboard'),
            actions: [
              if (_currentIndex == 2)
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    Provider.of<RequestProvider>(context, listen: false)
                        .refreshFulfilledRequests();
                  },
                ),
              _buildNotificationIcon(),
              _buildLogoutButton(context, authProvider),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildOverviewTab(),
              _buildApprovedRequestsTab(),
              _buildRecentRequestsTab(),
              _buildStockRequestsTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard), label: 'Overview'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle), label: 'Approved'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history), label: 'Recent'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.inventory), label: 'Stock'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        final userId = authProvider.user?.uid ?? '';
        final userRole = authProvider.role ?? 'Gate Man';
        return ValueListenableBuilder<int>(
          valueListenable: ValueNotifier<int>(notificationProvider
              .getUnreadNotificationsCount(userId, userRole)),
          builder: (context, unreadCount, child) {
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () async {
                    try {
                      await notificationProvider.fetchNotifications(
                          userId, userRole);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationsScreen()),
                      ).then((_) => setState(() {}));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Error loading notifications. Please try again.')),
                      );
                    }
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
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
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

  // Widget _buildOverviewTab() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       final todayRequests = requestProvider.getTodayRequests();
  //       final approvedRequests = todayRequests
  //           .where((request) => request['status'] == 'approved')
  //           .length;
  //       final fulfilledRequests = todayRequests
  //           .where((request) => request['status'] == 'fulfilled')
  //           .length;
  //       final pendingRequests = todayRequests
  //           .where((request) => request['status'] == 'pending')
  //           .length;

  //       return SingleChildScrollView(
  //         child: Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               _buildHeaderSection(),
  //               SizedBox(height: 24),
  //               _buildStatisticsSection(todayRequests.length, approvedRequests,
  //                   fulfilledRequests, pendingRequests),
  //               SizedBox(height: 24),
  //               _buildChartSection(
  //                   approvedRequests, fulfilledRequests, pendingRequests),
  //               SizedBox(height: 24),
  //               _buildRecentActivitySection(requestProvider),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _buildHeaderSection() {
  //   return Container(
  //     padding: EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Theme.of(context).primaryColor,
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Welcome, Gate Man',
  //               style: TextStyle(
  //                   fontSize: 24,
  //                   fontWeight: FontWeight.bold,
  //                   color: Colors.white),
  //             ),
  //             SizedBox(height: 8),
  //             Text(
  //               DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
  //               style: TextStyle(fontSize: 16, color: Colors.white70),
  //             ),
  //           ],
  //         ),
  //         Icon(Icons.account_circle, size: 48, color: Colors.white),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildStatisticsSection(
  //     int total, int approved, int fulfilled, int pending) {
  //   return GridView.count(
  //     crossAxisCount: 2,
  //     crossAxisSpacing: 16,
  //     mainAxisSpacing: 16,
  //     shrinkWrap: true,
  //     physics: NeverScrollableScrollPhysics(),
  //     children: [
  //       _buildStatCard('Total Requests', total, Icons.list_alt, Colors.blue),
  //       _buildStatCard('Approved', approved, Icons.check_circle, Colors.green),
  //       _buildStatCard('Fulfilled', fulfilled, Icons.done_all, Colors.orange),
  //       _buildStatCard('Pending', pending, Icons.hourglass_empty, Colors.red),
  //     ],
  //   );
  // }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            SizedBox(height: 24),
            _buildDateSelector(),
            SizedBox(height: 24),
            _buildStatisticsSection(),
            SizedBox(height: 24),
            _buildChartSection(),
            SizedBox(height: 24),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Gate Man',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
          Icon(Icons.account_circle, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton(
          onPressed: () => _selectDate(context),
          child: Text('Change Date'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildStatisticsSection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<Map<String, int>>(
          stream: requestProvider.getDashboardStats(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final stats = snapshot.data ?? {};
            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Total Requests', stats['total'] ?? 0,
                    Icons.list_alt, Colors.blue),
                _buildStatCard('Pending', stats['pending'] ?? 0,
                    Icons.hourglass_empty, Colors.red),
                _buildStatCard('Approved', stats['approved'] ?? 0,
                    Icons.check_circle, Colors.green),
                _buildStatCard('Fulfilled', stats['fulfilled'] ?? 0,
                    Icons.done_all, Colors.orange),
              ],
            );
          },
        );
      },
    );
  }
  // Widget _buildStatisticsSection() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       return StreamBuilder<Map<String, int>>(
  //         stream: requestProvider.getDashboardStats(_selectedDate),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return Center(child: CircularProgressIndicator());
  //           }
  //           if (snapshot.hasError) {
  //             return Text('Error: ${snapshot.error}');
  //           }
  //           final stats = snapshot.data ?? {};
  //           return GridView.count(
  //             crossAxisCount: 2,
  //             crossAxisSpacing: 16,
  //             mainAxisSpacing: 16,
  //             shrinkWrap: true,
  //             physics: NeverScrollableScrollPhysics(),
  //             children: [
  //               _buildStatCard('Total Requests', stats['total'] ?? 0, Icons.list_alt, Colors.blue),
  //               _buildStatCard('Pending', stats['pending'] ?? 0, Icons.hourglass_empty, Colors.red),
  //               _buildStatCard('Approved', stats['approved'] ?? 0, Icons.check_circle, Colors.green),
  //               _buildStatCard('Fulfilled', stats['fulfilled'] ?? 0, Icons.done_all, Colors.orange),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _buildChartSection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<Map<String, int>>(
          stream: requestProvider.getDashboardStats(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final stats = snapshot.data ?? {};
            return Container(
              height: 260,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Status Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 10,
                        sections: [
                          PieChartSectionData(
                            color: Colors.green,
                            value: (stats['approved'] ?? 0).toDouble(),
                            title: '${stats['approved'] ?? 0}',
                            radius: 80,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            titlePositionPercentageOffset: 0.55,
                          ),
                          PieChartSectionData(
                            color: Colors.orange,
                            value: (stats['fulfilled'] ?? 0).toDouble(),
                            title: '${stats['fulfilled'] ?? 0}',
                            radius: 80,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            titlePositionPercentageOffset: 0.55,
                          ),
                          PieChartSectionData(
                            color: Colors.red,
                            value: (stats['pending'] ?? 0).toDouble(),
                            title: '${stats['pending'] ?? 0}',
                            radius: 80,
                            titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            titlePositionPercentageOffset: 0.55,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Approved', Colors.green),
                      SizedBox(width: 16),
                      _buildLegendItem('Fulfilled', Colors.orange),
                      SizedBox(width: 16),
                      _buildLegendItem('Pending', Colors.red),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
  // Widget _buildChartSection() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       return StreamBuilder<Map<String, int>>(
  //         stream: requestProvider.getDashboardStats(_selectedDate),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return Center(child: CircularProgressIndicator());
  //           }
  //           if (snapshot.hasError) {
  //             return Text('Error: ${snapshot.error}');
  //           }
  //           final stats = snapshot.data ?? {};
  //           return Container(
  //             height: 300,
  //             padding: EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.grey.withOpacity(0.1),
  //                   spreadRadius: 2,
  //                   blurRadius: 4,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'Request Status Overview',
  //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //                 SizedBox(height: 16),
  //                 Expanded(
  //                   child: PieChart(
  //                     PieChartData(
  //                       sectionsSpace: 0,
  //                       centerSpaceRadius: 40,
  //                       sections: [
  //                         PieChartSectionData(
  //                           color: Colors.green,
  //                           value: (stats['approved'] ?? 0).toDouble(),
  //                           title: 'Approved',
  //                           radius: 100,
  //                           titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
  //                         ),
  //                         PieChartSectionData(
  //                           color: Colors.orange,
  //                           value: (stats['fulfilled'] ?? 0).toDouble(),
  //                           title: 'Fulfilled',
  //                           radius: 100,
  //                           titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
  //                         ),
  //                         PieChartSectionData(
  //                           color: Colors.red,
  //                           value: (stats['pending'] ?? 0).toDouble(),
  //                           title: 'Pending',
  //                           radius: 100,
  //                           titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _buildRecentActivitySection() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestProvider.getRecentActivityStream(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            final recentActivity = snapshot.data ?? [];
            return Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (recentActivity.isEmpty) Text('No recent activity'),
                  if (recentActivity.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: recentActivity.length,
                      itemBuilder: (context, index) {
                        final activity = recentActivity[index];
                        return ListTile(
                          leading: _getStatusIcon(activity['status']),
                          title: Text(
                              '${activity['type']} Request #${activity['id']}'),
                          subtitle: Text('Status: ${activity['status']}'),
                          trailing: Text(DateFormat('HH:mm')
                              .format(activity['timestamp'].toDate())),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget _buildOverviewTab() {
  //   return SingleChildScrollView(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           _buildHeaderSection(),
  //           SizedBox(height: 24),
  //           _buildStatisticsSection(),
  //           SizedBox(height: 24),
  //           _buildChartSection(),
  //           SizedBox(height: 24),
  //           _buildRecentActivitySection(),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildStatisticsSection() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       return StreamBuilder<Map<String, int>>(
  //         stream: requestProvider.getDashboardStats(),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return Center(child: CircularProgressIndicator());
  //           }
  //           if (snapshot.hasError) {
  //             return Text('Error: ${snapshot.error}');
  //           }
  //           final stats = snapshot.data ?? {};
  //           return GridView.count(
  //             crossAxisCount: 2,
  //             crossAxisSpacing: 16,
  //             mainAxisSpacing: 16,
  //             shrinkWrap: true,
  //             physics: NeverScrollableScrollPhysics(),
  //             children: [
  //               _buildStatCard('Total Requests', stats['total'] ?? 0,
  //                   Icons.list_alt, Colors.blue),
  //               _buildStatCard('Pending', stats['pending'] ?? 0,
  //                   Icons.hourglass_empty, Colors.red),
  //               _buildStatCard('Approved', stats['approved'] ?? 0,
  //                   Icons.check_circle, Colors.green),
  //               _buildStatCard('Fulfilled', stats['fulfilled'] ?? 0,
  //                   Icons.done_all, Colors.orange),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  // Widget _buildChartSection() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       return StreamBuilder<Map<String, int>>(
  //         stream: requestProvider.getDashboardStats(),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return Center(child: CircularProgressIndicator());
  //           }
  //           if (snapshot.hasError) {
  //             return Text('Error: ${snapshot.error}');
  //           }
  //           final stats = snapshot.data ?? {};
  //           return Container(
  //             height: 300,
  //             padding: EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.grey.withOpacity(0.1),
  //                   spreadRadius: 2,
  //                   blurRadius: 4,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'Request Status Overview',
  //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //                 SizedBox(height: 16),
  //                 Expanded(
  //                   child: PieChart(
  //                     PieChartData(
  //                       sectionsSpace: 0,
  //                       centerSpaceRadius: 40,
  //                       sections: [
  //                         PieChartSectionData(
  //                           color: Colors.green,
  //                           value: (stats['approved'] ?? 0).toDouble(),
  //                           title: 'Approved',
  //                           radius: 100,
  //                           titleStyle: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.white),
  //                         ),
  //                         PieChartSectionData(
  //                           color: Colors.orange,
  //                           value: (stats['fulfilled'] ?? 0).toDouble(),
  //                           title: 'Fulfilled',
  //                           radius: 100,
  //                           titleStyle: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.white),
  //                         ),
  //                         PieChartSectionData(
  //                           color: Colors.red,
  //                           value: (stats['pending'] ?? 0).toDouble(),
  //                           title: 'Pending',
  //                           radius: 100,
  //                           titleStyle: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.white),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  // Widget _buildRecentActivitySection() {
  //   return Consumer<RequestProvider>(
  //     builder: (context, requestProvider, _) {
  //       return StreamBuilder<List<Map<String, dynamic>>>(
  //         stream: requestProvider.getRecentActivityStream(),
  //         builder: (context, snapshot) {
  //           if (snapshot.connectionState == ConnectionState.waiting) {
  //             return Center(child: CircularProgressIndicator());
  //           }
  //           if (snapshot.hasError) {
  //             return Text('Error: ${snapshot.error}');
  //           }
  //           final recentActivity = snapshot.data ?? [];
  //           return Container(
  //             padding: EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.grey.withOpacity(0.1),
  //                   spreadRadius: 2,
  //                   blurRadius: 4,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'Recent Activity',
  //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //                 SizedBox(height: 16),
  //                 if (recentActivity.isEmpty) Text('No recent activity'),
  //                 if (recentActivity.isNotEmpty)
  //                   ListView.builder(
  //                     shrinkWrap: true,
  //                     physics: NeverScrollableScrollPhysics(),
  //                     itemCount: recentActivity.length,
  //                     itemBuilder: (context, index) {
  //                       final activity = recentActivity[index];
  //                       return ListTile(
  //                         leading: _getStatusIcon(activity['status']),
  //                         title: Text(
  //                             '${activity['type']} Request #${activity['id']}'),
  //                         subtitle: Text('Status: ${activity['status']}'),
  //                         trailing: Text(DateFormat('MMM d, HH:mm')
  //                             .format(activity['timestamp'].toDate())),
  //                       );
  //                     },
  //                   ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icon(Icons.check_circle, color: Colors.green);
      case 'fulfilled':
        return Icon(Icons.done_all, color: Colors.orange);
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.red);
      default:
        return Icon(Icons.info, color: Colors.grey);
    }
  }

  Widget _buildOverviewSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatistics(),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: _buildRequestStatusChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatisticCard('Total', todayRequests.length),
            _buildStatisticCard('Approved', approvedRequests),
            _buildStatisticCard('Fulfilled', fulfilledRequests),
          ],
        );
      },
    );
  }

  Widget _buildStatisticCard(String title, int count) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStatusChart() {
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

        return SfCircularChart(
          legend: Legend(isVisible: true),
          series: <CircularSeries>[
            PieSeries<RequestStatus, String>(
              dataSource: data,
              xValueMapper: (RequestStatus data, _) => data.status,
              yValueMapper: (RequestStatus data, _) => data.count,
              pointColorMapper: (RequestStatus data, _) => data.color,
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovedRequestsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSearchBar(),
        ),
        Expanded(
          child: _buildApprovedRequestsList(),
        ),
      ],
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
            return _buildApprovedRequestCard(context, request);
          },
        );
      },
    );
  }

  Widget _buildApprovedRequestCard(
      BuildContext context, Map<String, dynamic> request) {
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
        leading: Icon(Icons.request_page, color: Colors.green),
        trailing: IconButton(
          icon: Icon(Icons.verified, color: Colors.blue),
          onPressed: () => _verifyCodeDialog(context, request['uniqueCode']),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
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

    final requestProvider =
        Provider.of<RequestProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      bool isValid = await requestProvider.checkCodeValidity(enteredCode);

      Navigator.of(context).pop();

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid code. Please check and try again.'),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: () => _verifyCodeDialog(context, uniqueCode),
            ),
          ),
        );
        return;
      }

      await requestProvider.fulfillRequestByCode(enteredCode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Code verified! Request fulfilled successfully.')),
      );

      setState(() {});
    } catch (e) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error: ${e.toString()}. Please check the code and try again.'),
          action: SnackBarAction(
            label: 'Try Again',
            onPressed: () => _verifyCodeDialog(context, uniqueCode),
          ),
        ),
      );
    }
  }

  Widget _buildRecentRequestsTab() {
    return FutureBuilder(
      future: Provider.of<RequestProvider>(context, listen: false)
          .refreshFulfilledRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        return Consumer<RequestProvider>(
          builder: (context, requestProvider, _) {
            final requests = requestProvider.fulfilledRequests;
            if (requests.isEmpty) {
              return _buildEmptyWidget(requestProvider);
            }
            return _buildRequestList(requests);
          },
        );
      },
    );
  }

  Widget _buildEmptyWidget(RequestProvider requestProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('No recent fulfilled requests found',
              style: TextStyle(fontSize: 18)),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => requestProvider.refreshFulfilledRequests(),
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests) {
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRecentRequestCard(request);
      },
    );
  }

  Widget _buildRecentRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          'Request ID: ${request['id']}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
            SizedBox(height: 4),
            Text('Picker: ${request['pickerName']}'),
            SizedBox(height: 4),
            Text('Items: ${_formatItems(request['items'])}'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () => _showRequestDetails(request),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Request Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('ID', request['id']),
                _buildDetailRow('Status', request['status']),
                _buildDetailRow(
                    'Approved At', _formatTimestamp(request['approvedAt'])),
                _buildDetailRow(
                    'Fulfilled At', _formatTimestamp(request['fulfilledAt'])),
                _buildDetailRow('Location', request['location']),
                _buildDetailRow('Picker Name', request['pickerName']),
                _buildDetailRow('Picker Contact', request['pickerContact']),
                _buildDetailRow('Note', request['note']),
                SizedBox(height: 16),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...request['items'].map<Widget>((item) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Text('${item['quantity']} x ${item['name']}'),
                    )),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child:
                Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStockRequestsTab() {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestProvider.getActiveStockRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final stockRequests = snapshot.data ?? [];
            if (stockRequests.isEmpty) {
              return Center(child: Text('No active stock requests found.'));
            }
            return ListView.builder(
              itemCount: stockRequests.length,
              itemBuilder: (context, index) {
                final request = stockRequests[index];
                return _buildStockRequestCard(request);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStockRequestCard(Map<String, dynamic> request) {
    return Card(
      child: ListTile(
        title: Text('Stock Request #${request['id']}'),
        subtitle: Text('Status: ${request['status']}'),
        trailing: ElevatedButton(
          child: Text('Receive'),
          onPressed: () => _showReceiveDialog(context, request),
        ),
      ),
    );
  }

  void _showReceiveDialog(BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => ReceiveStockDialog(
          request: request,
          gateManId:
              Provider.of<AuthProvider>(context, listen: false).user?.uid),
    );
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
            'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
            'remainingQuantity':
                (item['remainingQuantity'] as num?)?.toDouble() ??
                    (item['quantity'] as num?)?.toDouble() ??
                    0.0,
            'receivedQuantity': 0.0,
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
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: '/ ${item['remainingQuantity'].toStringAsFixed(2)}',
            ),
            onChanged: (value) {
              setState(() {
                item['receivedQuantity'] = double.tryParse(value) ?? 0.0;
              });
            },
          ),
        ),
      ],
    );
  }

  void _confirmReceive(BuildContext context) {
    bool isValid = _receivedItems.every((item) {
      double receivedQuantity = item['receivedQuantity'] ?? 0.0;
      double remainingQuantity = item['remainingQuantity'] ?? 0.0;
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
      double receivedQuantity = item['receivedQuantity'] ?? 0.0;
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

class RequestStatus {
  final String status;
  final int count;
  final Color color;

  RequestStatus(this.status, this.count, this.color);
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return 'N/A';
  if (timestamp is Timestamp) {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
  }
  if (timestamp is DateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  }
  return timestamp.toString();
}

String _formatItems(List<dynamic>? items) {
  if (items == null || items.isEmpty) return 'No items';
  return items
      .map((item) => '${item['quantity']} x ${item['name']}')
      .join(', ');
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../screens/common/notification_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   int _currentIndex = 0;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return Scaffold(
//           appBar: AppBar(
//             title: Text('Gate Man Dashboard'),
//             actions: [
//               if (_currentIndex == 2) // Show refresh button only in Recent tab
//                 IconButton(
//                   icon: Icon(Icons.refresh),
//                   onPressed: () {
//                     Provider.of<RequestProvider>(context, listen: false)
//                         .refreshFulfilledRequests();
//                   },
//                 ),
//               _buildNotificationIcon(),
//               _buildLogoutButton(context, authProvider),
//             ],
//           ),
//           body: IndexedStack(
//             index: _currentIndex,
//             children: [
//               _buildOverviewTab(),
//               _buildApprovedRequestsTab(),
//               _buildRecentRequestsTab(),
//               _buildStockRequestsTab(),
//             ],
//           ),
//           bottomNavigationBar: BottomNavigationBar(
//             currentIndex: _currentIndex,
//             onTap: (index) => setState(() => _currentIndex = index),
//             type: BottomNavigationBarType.fixed,
//             items: [
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.dashboard), label: 'Overview'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.check_circle), label: 'Approved'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.history), label: 'Recent'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.inventory), label: 'Stock'),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {});
//                       });
//                     } catch (e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }

//   Widget _buildOverviewTab() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildOverviewSection(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOverviewSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Dashboard Overview',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildStatistics(),
//             SizedBox(height: 16),
//             Container(
//               height: 200,
//               child: _buildRequestStatusChart(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatistics() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildStatisticCard('Total', todayRequests.length),
//             _buildStatisticCard('Approved', approvedRequests),
//             _buildStatisticCard('Fulfilled', fulfilledRequests),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 4),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return SfCircularChart(
//           legend: Legend(isVisible: true),
//           series: <CircularSeries>[
//             PieSeries<RequestStatus, String>(
//               dataSource: data,
//               xValueMapper: (RequestStatus data, _) => data.status,
//               yValueMapper: (RequestStatus data, _) => data.count,
//               pointColorMapper: (RequestStatus data, _) => data.color,
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildApprovedRequestsTab() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: _buildSearchBar(),
//         ),
//         Expanded(
//           child: _buildApprovedRequestsList(),
//         ),
//       ],
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildApprovedRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildApprovedRequestCard(
//       BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 _verifyCodeDialog(context, uniqueCode);
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Code verified! Request fulfilled successfully.')),
//       );

//       setState(() {});
//     } catch (e) {
//       Navigator.of(context).pop();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               _verifyCodeDialog(context, uniqueCode);
//             },
//           ),
//         ),
//       );
//     }
//   }

//   Widget _buildRecentRequestsTab() {
//     return FutureBuilder(
//       future: Provider.of<RequestProvider>(context, listen: false)
//           .refreshFulfilledRequests(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }
//         return Consumer<RequestProvider>(
//           builder: (context, requestProvider, _) {
//             final requests = requestProvider.fulfilledRequests;
//             if (requests.isEmpty) {
//               return _buildEmptyWidget(requestProvider);
//             }
//             return _buildRequestList(requests);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildEmptyWidget(RequestProvider requestProvider) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.inbox, size: 60, color: Colors.grey),
//           SizedBox(height: 16),
//           Text('No recent fulfilled requests found',
//               style: TextStyle(fontSize: 18)),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () => requestProvider.refreshFulfilledRequests(),
//             child: Text('Refresh'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRequestList(List<Map<String, dynamic>> requests) {
//     return ListView.builder(
//       itemCount: requests.length,
//       itemBuilder: (context, index) {
//         final request = requests[index];
//         return _buildRecentRequestCard(request);
//       },
//     );
//   }

//   Widget _buildRecentRequestCard(Map<String, dynamic> request) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       elevation: 4,
//       child: ListTile(
//         contentPadding: EdgeInsets.all(16),
//         title: Text(
//           'Request ID: ${request['id']}',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SizedBox(height: 8),
//             Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             SizedBox(height: 4),
//             Text('Picker: ${request['pickerName']}'),
//             SizedBox(height: 4),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: Icon(Icons.arrow_forward_ios),
//         onTap: () => _showRequestDetails(request),
//       ),
//     );
//   }

//   void _showRequestDetails(Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 _buildDetailRow('ID', request['id']),
//                 _buildDetailRow('Status', request['status']),
//                 _buildDetailRow(
//                     'Approved At', _formatTimestamp(request['approvedAt'])),
//                 _buildDetailRow(
//                     'Fulfilled At', _formatTimestamp(request['fulfilledAt'])),
//                 _buildDetailRow('Location', request['location']),
//                 _buildDetailRow('Picker Name', request['pickerName']),
//                 _buildDetailRow('Picker Contact', request['pickerContact']),
//                 _buildDetailRow('Note', request['note']),
//                 SizedBox(height: 16),
//                 Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16, top: 8),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child:
//                 Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   Widget _buildStockRequestsTab() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return _buildStockRequestCard(request);
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildStockRequestCard(Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id']}'),
//         subtitle: Text('Status: ${request['status']}'),
//         trailing: ElevatedButton(
//           child: Text('View Details'),
//           onPressed: () {
//             _showStockRequestDetails(request);
//           },
//         ),
//       ),
//     );
//   }

//   void _showStockRequestDetails(Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Stock Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Created At: ${_formatTimestamp(request['createdAt'])}'),
//                 Text('Created By: ${request['createdBy']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                       padding: const EdgeInsets.only(left: 16.0),
//                       child: Text('${item['quantity']} x ${item['name']}'),
//                     )),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill Request'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showFulfillmentDialog(request);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // void _showFulfillmentDialog(Map<String, dynamic> request) {
//   //   final _formKey = GlobalKey<FormState>();
//   //   final Map<String, TextEditingController> controllers = {};

//   //   for (var item in request['items']) {
//   //     controllers[item['id']] = TextEditingController();
//   //   }

//   //   showDialog(
//   //     context: context,
//   //     builder: (BuildContext context) {
//   //       return AlertDialog(
//   //         title: Text('Fulfill Stock Request'),
//   //         content: Form(
//   //           key: _formKey,
//   //           child: SingleChildScrollView(
//   //             child: ListBody(
//   //               children: request['items'].map<Widget>((item) {
//   //                 return TextFormField(
//   //                   controller: controllers[item['id']],
//   //                   decoration: InputDecoration(
//   //                     labelText: '${item['name']} (Max: ${item['quantity']})',
//   //                   ),
//   //                   keyboardType: TextInputType.number,
//   //                   validator: (value) {
//   //                     if (value == null || value.isEmpty) {
//   //                       return 'Please enter a quantity';
//   //                     }
//   //                     int? quantity = int.tryParse(value);
//   //                     if (quantity == null ||
//   //                         quantity < 0 ||
//   //                         quantity > item['quantity']) {
//   //                       return 'Please enter a valid quantity';
//   //                     }
//   //                     return null;
//   //                   },
//   //                 );
//   //               }).toList(),
//   //             ),
//   //           ),
//   //         ),
//   //         actions: <Widget>[
//   //           TextButton(
//   //             child: Text('Cancel'),
//   //             onPressed: () {
//   //               Navigator.of(context).pop();
//   //             },
//   //           ),
//   //           ElevatedButton(
//   //             child: Text('Fulfill'),
//   //             onPressed: () {
//   //               if (_formKey.currentState!.validate()) {
//   //                 _fulfillStockRequest(request, controllers);
//   //               }
//   //             },
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }

//     void _showFulfillmentDialog(Map<String, dynamic> request) {
//     final _formKey = GlobalKey<FormState>();
//     final Map<String, TextEditingController> controllers = {};

//     for (var item in request['items']) {
//       controllers[item['id']] = TextEditingController();
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Stock Request'),
//           content: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: ListBody(
//                 children: request['items'].map<Widget>((item) {
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('${item['name']}:'),
//                       Text('Remaining: ${item['remainingQuantity']}'),
//                       TextFormField(
//                         controller: controllers[item['id']],
//                         decoration: InputDecoration(
//                           labelText: 'Received Quantity',
//                         ),
//                         keyboardType: TextInputType.number,
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Please enter a quantity';
//                           }
//                           int? quantity = int.tryParse(value);
//                           if (quantity == null ||
//                               quantity < 0 ||
//                               quantity > item['remainingQuantity']) {
//                             return 'Please enter a valid quantity';
//                           }
//                           return null;
//                         },
//                       ),
//                       SizedBox(height: 16),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   _fulfillCollectionRequest(request, controllers);
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // void _fulfillCollectionRequest(Map<String, dynamic> request,
//   //     Map<String, TextEditingController> controllers) {
//   //   final requestProvider =
//   //       Provider.of<RequestProvider>(context, listen: false);
//   //   final authProvider = Provider.of<AuthProvider>(context, listen: false);

//   //   List<Map<String, dynamic>> fulfilledItems =
//   //       request['items'].map<Map<String, dynamic>>((item) {
//   //     return {
//   //       'id': item['id'],
//   //       'name': item['name'],
//   //       'receivedQuantity': int.parse(controllers[item['id']]!.text),
//   //       'remainingQuantity': item['remainingQuantity'] -
//   //           int.parse(controllers[item['id']]!.text),
//   //     };
//   //   }).toList();

//   //   requestProvider
//   //       .fulfillCollectionRequest(
//   //           request['id'], fulfilledItems, authProvider.user!.uid)
//   //       .then((_) {
//   //     Navigator.of(context).pop();
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Stock request fulfilled successfully')),
//   //     );
//   //   }).catchError((error) {
//   //     Navigator.of(context).pop();
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text('Error fulfilling stock request: $error')),
//   //     );
//   //   });
//   // }



// void _fulfillStockRequest(Map<String, dynamic> request,
//       Map<String, TextEditingController> controllers) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     List<Map<String, dynamic>> fulfilledItems =
//         request['items'].map<Map<String, dynamic>>((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'receivedQuantity': int.parse(controllers[item['id']]!.text),
//         'remainingQuantity': item['remainingQuantity'] -
//             int.parse(controllers[item['id']]!.text),
//       };
//     }).toList();

//     requestProvider
//         .fulfillStockRequest(
//             request['id'], fulfilledItems, authProvider.user!.uid)
//         .then((_) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request fulfilled successfully')),
//       );
//     }).catchError((error) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fulfilling stock request: $error')),
//       );
//     });
//   }
// }


// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// String _formatTimestamp(dynamic timestamp) {
//   if (timestamp == null) return 'N/A';
//   if (timestamp is Timestamp) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//   }
//   if (timestamp is DateTime) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//   }
//   return timestamp.toString();
// }

// String _formatItems(List<dynamic>? items) {
//   if (items == null || items.isEmpty) return 'No items';
//   return items
//       .map((item) => '${item['quantity']} x ${item['name']}')
//       .join(', ');
// }

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../screens/common/notification_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   int _currentIndex = 0;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return Scaffold(
//           appBar: AppBar(
//             title: Text('Gate Man Dashboard'),
//             actions: [
//               _buildNotificationIcon(),
//               _buildLogoutButton(context, authProvider),
//             ],
//           ),
//           body: IndexedStack(
//             index: _currentIndex,
//             children: [
//               _buildOverviewTab(),
//               _buildApprovedRequestsTab(),
//               _buildRecentRequestsTab(),
//               _buildStockRequestsTab(),
//             ],
//           ),
//           bottomNavigationBar: BottomNavigationBar(
//             currentIndex: _currentIndex,
//             onTap: (index) => setState(() => _currentIndex = index),
//             type: BottomNavigationBarType.fixed,
//             items: [
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.dashboard), label: 'Overview'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.check_circle), label: 'Approved'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.history), label: 'Recent'),
//               BottomNavigationBarItem(
//                   icon: Icon(Icons.inventory), label: 'Stock'),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {});
//                       });
//                     } catch (e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }

//   Widget _buildOverviewTab() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildOverviewSection(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildApprovedRequestsTab() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: _buildSearchBar(),
//         ),
//         Expanded(
//           child: _buildApprovedRequestsList(),
//         ),
//       ],
//     );
//   }

//   Widget _buildRecentRequestsTab() {
//     return _buildRecentRequestsList();
//   }

//   Widget _buildStockRequestsTab() {
//     return _buildStockRequestsList();
//   }

//   Widget _buildOverviewSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Dashboard Overview',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildStatistics(),
//             SizedBox(height: 16),
//             Container(
//               height: 200,
//               child: _buildRequestStatusChart(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatistics() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildStatisticCard('Total', todayRequests.length),
//             _buildStatisticCard('Approved', approvedRequests),
//             _buildStatisticCard('Fulfilled', fulfilledRequests),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 4),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return SfCircularChart(
//           legend: Legend(isVisible: true),
//           series: <CircularSeries>[
//             PieSeries<RequestStatus, String>(
//               dataSource: data,
//               xValueMapper: (RequestStatus data, _) => data.status,
//               yValueMapper: (RequestStatus data, _) => data.count,
//               pointColorMapper: (RequestStatus data, _) => data.color,
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildApprovedRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildApprovedRequestCard(
//       BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 _verifyCodeDialog(context, uniqueCode);
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Code verified! Request fulfilled successfully.')),
//       );

//       setState(() {});
//     } catch (e) {
//       Navigator.of(context).pop();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               _verifyCodeDialog(context, uniqueCode);
//             },
//           ),
//         ),
//       );
//     }
//   }

//   Widget _buildRecentRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getRecentApprovedAndFulfilledRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final requests = snapshot.data ?? [];
//             if (requests.isEmpty) {
//               return Center(
//                 child: Text('No recent approved or fulfilled requests found.'),
//               );
//             }
//             return RefreshIndicator(
//               onRefresh: () => requestProvider.refreshFulfilledRequests(),
//               child: ListView.builder(
//                 itemCount: requests.length,
//                 itemBuilder: (context, index) {
//                   final request = requests[index];
//                   return _buildRecentRequestCard(
//                       context, request, requestProvider);
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRecentRequestCard(BuildContext context,
//       Map<String, dynamic> request, RequestProvider requestProvider) {
//     final bool isFulfilled = request['status'] == 'fulfilled';
//     final Color cardColor =
//         isFulfilled ? Colors.green[100]! : Colors.blue[100]!;

//     return Card(
//       color: cardColor,
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ListTile(
//         title: Text('Request ID: ${request['id']}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Status: ${request['status']}'),
//             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//             if (isFulfilled)
//               Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: isFulfilled
//             ? Icon(Icons.check_circle, color: Colors.green)
//             : ElevatedButton(
//                 child: Text('Fulfill'),
//                 onPressed: () =>
//                     _fulfillRequest(context, request['id'], requestProvider),
//               ),
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   void _fulfillRequest(
//       BuildContext context, String requestId, RequestProvider requestProvider) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Request'),
//           content: Text('Are you sure you want to fulfill this request?'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 try {
//                   await requestProvider.fulfillRequest(requestId);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Request fulfilled successfully')),
//                   );
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error fulfilling request: $e')),
//                   );
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 if (request['status'] == 'fulfilled')
//                   Text(
//                       'Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                       padding: const EdgeInsets.only(left: 16.0),
//                       child: Text('${item['quantity']} x ${item['name']}'),
//                     )),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStockRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return _buildStockRequestCard(context, request);
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildStockRequestCard(
//       BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id']}'),
//         subtitle: Text('Status: ${request['status']}'),
//         trailing: ElevatedButton(
//           child: Text('View Details'),
//           onPressed: () {
//             _showStockRequestDetails(context, request);
//           },
//         ),
//       ),
//     );
//   }

//   void _showStockRequestDetails(
//       BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Stock Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Created At: ${_formatTimestamp(request['createdAt'])}'),
//                 Text('Created By: ${request['createdBy']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                       padding: const EdgeInsets.only(left: 16.0),
//                       child: Text('${item['quantity']} x ${item['name']}'),
//                     )),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill Request'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showFulfillmentDialog(context, request);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showFulfillmentDialog(
//       BuildContext context, Map<String, dynamic> request) {
//     final _formKey = GlobalKey<FormState>();
//     final Map<String, TextEditingController> controllers = {};

//     for (var item in request['items']) {
//       controllers[item['id']] = TextEditingController();
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Stock Request'),
//           content: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: ListBody(
//                 children: request['items'].map<Widget>((item) {
//                   return TextFormField(
//                     controller: controllers[item['id']],
//                     decoration: InputDecoration(
//                       labelText: '${item['name']} (Max: ${item['quantity']})',
//                     ),
//                     keyboardType: TextInputType.number,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter a quantity';
//                       }
//                       int? quantity = int.tryParse(value);
//                       if (quantity == null ||
//                           quantity < 0 ||
//                           quantity > item['quantity']) {
//                         return 'Please enter a valid quantity';
//                       }
//                       return null;
//                     },
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   _fulfillStockRequest(context, request, controllers);
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _fulfillStockRequest(BuildContext context, Map<String, dynamic> request,
//       Map<String, TextEditingController> controllers) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     List<Map<String, dynamic>> fulfilledItems =
//         request['items'].map<Map<String, dynamic>>((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'receivedQuantity': int.parse(controllers[item['id']]!.text),
//       };
//     }).toList();

//     requestProvider
//         .fulfillStockRequest(
//             request['id'], fulfilledItems, authProvider.user!.uid)
//         .then((_) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request fulfilled successfully')),
//       );
//     }).catchError((error) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fulfilling stock request: $error')),
//       );
//     });
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// String _formatTimestamp(dynamic timestamp) {
//   if (timestamp == null) return 'N/A';
//   if (timestamp is Timestamp) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//   }
//   if (timestamp is DateTime) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//   }
//   return timestamp.toString();
// }

// String _formatItems(List<dynamic>? items) {
//   if (items == null || items.isEmpty) return 'No items';
//   return items
//       .map((item) => '${item['quantity']} x ${item['name']}')
//       .join(', ');
// }
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../screens/common/notification_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return Scaffold(
//           appBar: AppBar(
//             title: Text('Gate Man Dashboard'),
//             actions: [
//               _buildNotificationIcon(),
//               _buildLogoutButton(context, authProvider),
//             ],
//           ),
//           body: SingleChildScrollView(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildOverviewSection(),
//                   SizedBox(height: 24),
//                   _buildApprovedRequestsSection(),
//                   SizedBox(height: 24),
//                   _buildRecentRequestsSection(),
//                   SizedBox(height: 24),
//                   _buildStockRequestsSection(),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {});
//                       });
//                     } catch (e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }

//   Widget _buildOverviewSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Dashboard Overview',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildStatistics(),
//             SizedBox(height: 16),
//             Container(
//               height: 200,
//               child: _buildRequestStatusChart(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatistics() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildStatisticCard('Total', todayRequests.length),
//             _buildStatisticCard('Approved', approvedRequests),
//             _buildStatisticCard('Fulfilled', fulfilledRequests),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 4),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return SfCircularChart(
//           legend: Legend(isVisible: true),
//           series: <CircularSeries>[
//             PieSeries<RequestStatus, String>(
//               dataSource: data,
//               xValueMapper: (RequestStatus data, _) => data.status,
//               yValueMapper: (RequestStatus data, _) => data.count,
//               pointColorMapper: (RequestStatus data, _) => data.color,
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildApprovedRequestsSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Approved Requests',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildSearchBar(),
//             SizedBox(height: 16),
//             _buildApprovedRequestsList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: NeverScrollableScrollPhysics(),
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildApprovedRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildApprovedRequestCard(
//       BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 _verifyCodeDialog(context, uniqueCode);
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Code verified! Request fulfilled successfully.')),
//       );

//       setState(() {});
//     } catch (e) {
//       Navigator.of(context).pop();

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               _verifyCodeDialog(context, uniqueCode);
//             },
//           ),
//         ),
//       );
//     }
//   }

//   Widget _buildRecentRequestsSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Recent Requests',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildRecentRequestsList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRecentRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getRecentApprovedAndFulfilledRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final requests = snapshot.data ?? [];
//             if (requests.isEmpty) {
//               return Center(
//                 child: Text('No recent approved or fulfilled requests found.'),
//               );
//             }
//             return RefreshIndicator(
//               onRefresh: () => requestProvider.refreshFulfilledRequests(),
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 physics: AlwaysScrollableScrollPhysics(),
//                 itemCount: requests.length,
//                 itemBuilder: (context, index) {
//                   final request = requests[index];
//                   return _buildRecentRequestCard(
//                       context, request, requestProvider);
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRecentRequestCard(BuildContext context,
//       Map<String, dynamic> request, RequestProvider requestProvider) {
//     final bool isFulfilled = request['status'] == 'fulfilled';
//     final Color cardColor =
//         isFulfilled ? Colors.green[100]! : Colors.blue[100]!;

//     return Card(
//       color: cardColor,
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ListTile(
//         title: Text('Request ID: ${request['id']}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Status: ${request['status']}'),
//             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//             if (isFulfilled)
//               Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: isFulfilled
//             ? Icon(Icons.check_circle, color: Colors.green)
//             : ElevatedButton(
//                 child: Text('Fulfill'),
//                 onPressed: () =>
//                     _fulfillRequest(context, request['id'], requestProvider),
//               ),
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   void _fulfillRequest(
//       BuildContext context, String requestId, RequestProvider requestProvider) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Request'),
//           content: Text('Are you sure you want to fulfill this request?'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 try {
//                   await requestProvider.fulfillRequest(requestId);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Request fulfilled successfully')),
//                   );
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error fulfilling request: $e')),
//                   );
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 if (request['status'] == 'fulfilled')
//                   Text(
//                       'Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                       padding: const EdgeInsets.only(left: 16.0),
//                       child: Text('${item['quantity']} x ${item['name']}'),
//                     )),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStockRequestsSection() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Active Stock Requests',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             _buildStockRequestsList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStockRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return _buildStockRequestCard(context, request);
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildStockRequestCard(
//       BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text('Stock Request #${request['id']}'),
//         subtitle: Text('Status: ${request['status']}'),
//         trailing: ElevatedButton(
//           child: Text('View Details'),
//           onPressed: () {
//             _showStockRequestDetails(context, request);
//           },
//         ),
//       ),
//     );
//   }

//   void _showStockRequestDetails(
//       BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Stock Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Created At: ${_formatTimestamp(request['createdAt'])}'),
//                 Text('Created By: ${request['createdBy']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                       padding: const EdgeInsets.only(left: 16.0),
//                       child: Text('${item['quantity']} x ${item['name']}'),
//                     )),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill Request'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showFulfillmentDialog(context, request);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showFulfillmentDialog(
//       BuildContext context, Map<String, dynamic> request) {
//     final _formKey = GlobalKey<FormState>();
//     final Map<String, TextEditingController> controllers = {};

//     for (var item in request['items']) {
//       controllers[item['id']] = TextEditingController();
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Stock Request'),
//           content: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: ListBody(
//                 children: request['items'].map<Widget>((item) {
//                   return TextFormField(
//                     controller: controllers[item['id']],
//                     decoration: InputDecoration(
//                       labelText: '${item['name']} (Max: ${item['quantity']})',
//                     ),
//                     keyboardType: TextInputType.number,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter a quantity';
//                       }
//                       int? quantity = int.tryParse(value);
//                       if (quantity == null ||
//                           quantity < 0 ||
//                           quantity > item['quantity']) {
//                         return 'Please enter a valid quantity';
//                       }
//                       return null;
//                     },
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   _fulfillStockRequest(context, request, controllers);
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _fulfillStockRequest(BuildContext context, Map<String, dynamic> request,
//       Map<String, TextEditingController> controllers) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     List<Map<String, dynamic>> fulfilledItems =
//         request['items'].map<Map<String, dynamic>>((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'receivedQuantity': int.parse(controllers[item['id']]!.text),
//       };
//     }).toList();

//     requestProvider
//         .fulfillStockRequest(
//             request['id'], fulfilledItems, authProvider.user!.uid)
//         .then((_) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request fulfilled successfully')),
//       );
//     }).catchError((error) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fulfilling stock request: $error')),
//       );
//     });
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// String _formatTimestamp(dynamic timestamp) {
//   if (timestamp == null) return 'N/A';
//   if (timestamp is Timestamp) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//   }
//   if (timestamp is DateTime) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//   }
//   return timestamp.toString();
// }

// String _formatItems(List<dynamic>? items) {
//   if (items == null || items.isEmpty) return 'No items';
//   return items
//       .map((item) => '${item['quantity']} x ${item['name']}')
//       .join(', ');
// }
// import 'package:dhavla_road_project/screens/gateMan/recent_fullfilled_request_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../screens/common/notification_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return DefaultTabController(
//           length: 4,
//           child: Scaffold(
//             appBar: AppBar(
//               title: Text('Gate Man Dashboard'),
//               actions: [
//                 _buildNotificationIcon(),
//                 _buildLogoutButton(context, authProvider),
//               ],
//               bottom: TabBar(
//                 tabs: [
//                   Tab(text: 'Overview'),
//                   Tab(text: 'Approved Requests'),
//                   Tab(text: 'Recent Requests'),
//                   Tab(text: 'Stock Requests'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 SingleChildScrollView(child: _OverviewTab()),
//                 _ApprovedRequestsTab(),
//                 _RecentApprovedRequestsTab(),
//                 GatemanStockRequestScreen(),
//               ],
//             ),
//             // floatingActionButton: FloatingActionButton.extended(
//             //   onPressed: () {
//             //     Navigator.of(context).push(MaterialPageRoute(
//             //       builder: (context) => RecentFulfilledRequestsScreen(),
//             //     ));
//             //   },
//             //   label: Text('Recent Fulfilled'),
//             //   icon: Icon(Icons.check_circle_outline),
//             // ),
//             floatingActionButton: FloatingActionButton.extended(
//               onPressed: () async {
//                 // Refresh the fulfilled requests before navigating
//                 await Provider.of<RequestProvider>(context, listen: false)
//                     .refreshFulfilledRequests();
//                 Navigator.of(context).push(MaterialPageRoute(
//                   builder: (context) => RecentFulfilledRequestsScreen(),
//                 ));
//               },
//               label: Text('Recent Fulfilled'),
//               icon: Icon(Icons.check_circle_outline),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {});
//                       });
//                     } catch (e) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }
// }

// class _OverviewTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Dashboard Overview',
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 16),
//           _buildStatistics(context),
//           SizedBox(height: 16),
//           Container(
//             height: 200,
//             child: _buildRequestStatusChart(context),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatistics(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _buildStatisticCard('Total', todayRequests.length),
//                 _buildStatisticCard('Approved', approvedRequests),
//                 _buildStatisticCard('Fulfilled', fulfilledRequests),
//               ],
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return SfCircularChart(
//           legend: Legend(isVisible: true),
//           series: <CircularSeries>[
//             PieSeries<RequestStatus, String>(
//               dataSource: data,
//               xValueMapper: (RequestStatus data, _) => data.status,
//               yValueMapper: (RequestStatus data, _) => data.count,
//               pointColorMapper: (RequestStatus data, _) => data.color,
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// class _ApprovedRequestsTab extends StatefulWidget {
//   @override
//   _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
// }

// class _ApprovedRequestsTabState extends State<_ApprovedRequestsTab> {
//   bool _shouldShowVerificationDialog = false;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   String? _pendingUniqueCode;

//   @override
//   Widget build(BuildContext context) {
//     if (_shouldShowVerificationDialog) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         setState(() {
//           _shouldShowVerificationDialog = false;
//         });
//         if (_pendingUniqueCode != null) {
//           _verifyCodeDialog(context, _pendingUniqueCode!);
//           _pendingUniqueCode = null;
//         }
//       });
//     }
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildSearchBar(),
//           SizedBox(height: 16),
//           Expanded(
//             child: _buildApprovedRequestsList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 setState(() {
//                   _shouldShowVerificationDialog = true;
//                   _pendingUniqueCode = uniqueCode;
//                 });
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Code verified! Request fulfilled successfully.')),
//       );

//       setState(() {});
//     } catch (e) {
//       Navigator.of(context).popUntil((route) => route.isFirst);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               setState(() {
//                 _shouldShowVerificationDialog = true;
//                 _pendingUniqueCode = uniqueCode;
//               });
//             },
//           ),
//         ),
//       );
//     }
//   }
// }

// // class _RecentApprovedRequestsTab extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     return Consumer<RequestProvider>(
// //       builder: (context, requestProvider, _) {
// //         return StreamBuilder<List<Map<String, dynamic>>>(
// //           stream: requestProvider.getRecentApprovedAndFulfilledRequestsStream(),
// //           builder: (context, snapshot) {
// //             if (snapshot.connectionState == ConnectionState.waiting) {
// //               return Center(child: CircularProgressIndicator());
// //             }
// //             if (snapshot.hasError) {
// //               return Center(child: Text('Error: ${snapshot.error}'));
// //             }
// //             final requests = snapshot.data ?? [];
// //             if (requests.isEmpty) {
// //               return Center(
// //                   child:
// //                       Text('No recent approved or fulfilled requests found.'));
// //             }
// //             return ListView.builder(
// //               itemCount: requests.length,
// //               itemBuilder: (context, index) {
// //                 final request = requests[index];
// //                 return _buildRequestCard(context, request, requestProvider);
// //               },
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }
// class _RecentApprovedRequestsTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getRecentApprovedAndFulfilledRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final requests = snapshot.data ?? [];
//             if (requests.isEmpty) {
//               return Center(
//                 child: Text('No recent approved or fulfilled requests found.'),
//               );
//             }
//             return RefreshIndicator(
//               onRefresh: () => requestProvider.refreshFulfilledRequests(),
//               child: ListView.builder(
//                 itemCount: requests.length,
//                 itemBuilder: (context, index) {
//                   final request = requests[index];
//                   return _buildRequestCard(context, request, requestProvider);
//                 },
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request,
//       RequestProvider requestProvider) {
//     final bool isFulfilled = request['status'] == 'fulfilled';
//     final Color cardColor =
//         isFulfilled ? Colors.green[100]! : Colors.blue[100]!;

//     return Card(
//       color: cardColor,
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ListTile(
//         title: Text('Request ID: ${request['id']}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Status: ${request['status']}'),
//             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//             if (isFulfilled)
//               Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: isFulfilled
//             ? Icon(Icons.check_circle, color: Colors.green)
//             : ElevatedButton(
//                 child: Text('Fulfill'),
//                 onPressed: () =>
//                     _fulfillRequest(context, request['id'], requestProvider),
//               ),
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   void _fulfillRequest(
//       BuildContext context, String requestId, RequestProvider requestProvider) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Request'),
//           content: Text('Are you sure you want to fulfill this request?'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 try {
//                   await requestProvider.fulfillRequest(requestId);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Request fulfilled successfully')),
//                   );
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error fulfilling request: $e')),
//                   );
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 if (request['status'] == 'fulfilled')
//                   Text(
//                       'Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16.0),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// // Helper functions
// String _formatTimestamp(dynamic timestamp) {
//   if (timestamp == null) return 'N/A';
//   if (timestamp is Timestamp) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//   }
//   if (timestamp is DateTime) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//   }
//   return timestamp.toString();
// }

// String _formatItems(List<dynamic>? items) {
//   if (items == null || items.isEmpty) return 'No items';
//   return items
//       .map((item) => '${item['quantity']} x ${item['name']}')
//       .join(', ');
// }
// // class _RecentApprovedRequestsTab extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     return Consumer<RequestProvider>(
// //       builder: (context, requestProvider, _) {
// //         return StreamBuilder<List<Map<String, dynamic>>>(
// //           stream: requestProvider.getRecentApprovedAndFulfilledRequestsStream(),
// //           builder: (context, snapshot) {
// //             if (snapshot.connectionState == ConnectionState.waiting) {
// //               return Center(child: CircularProgressIndicator());
// //             }
// //             if (snapshot.hasError) {
// //               return Center(child: Text('Error: ${snapshot.error}'));
// //             }
// //             final requests = snapshot.data ?? [];
// //             if (requests.isEmpty) {
// //               return Center(
// //                   child:
// //                       Text('No recent approved or fulfilled requests found.'));
// //             }
// //             return RefreshIndicator(
// //               onRefresh: () => requestProvider.refreshFulfilledRequests(),
// //               child: ListView.builder(
// //                 itemCount: requests.length,
// //                 itemBuilder: (context, index) {
// //                   final request = requests[index];
// //                   return _buildRequestCard(context, request, requestProvider);
// //                 },
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request,
// //       RequestProvider requestProvider) {
// //     final bool isFulfilled = request['status'] == 'fulfilled';
// //     final Color cardColor =
// //         isFulfilled ? Colors.green[100]! : Colors.blue[100]!;

// //     return Card(
// //       color: cardColor,
// //       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
// //       child: ListTile(
// //         title: Text('Request ID: ${request['id']}'),
// //         subtitle: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text('Status: ${request['status']}'),
// //             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
// //             if (isFulfilled)
// //               Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
// //             Text('Items: ${_formatItems(request['items'])}'),
// //           ],
// //         ),
// //         trailing: isFulfilled
// //             ? Icon(Icons.check_circle, color: Colors.green)
// //             : ElevatedButton(
// //                 child: Text('Fulfill'),
// //                 onPressed: () =>
// //                     _fulfillRequest(context, request['id'], requestProvider),
// //               ),
// //         onTap: () => _showRequestDetails(context, request),
// //       ),
// //     );
// //   }

// //   void _fulfillRequest(
// //       BuildContext context, String requestId, RequestProvider requestProvider) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           title: Text('Fulfill Request'),
// //           content: Text('Are you sure you want to fulfill this request?'),
// //           actions: <Widget>[
// //             TextButton(
// //               child: Text('Cancel'),
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //             ),
// //             ElevatedButton(
// //               child: Text('Fulfill'),
// //               onPressed: () async {
// //                 Navigator.of(context).pop();
// //                 try {
// //                   await requestProvider.fulfillRequest(requestId);
// //                   ScaffoldMessenger.of(context).showSnackBar(
// //                     SnackBar(content: Text('Request fulfilled successfully')),
// //                   );
// //                 } catch (e) {
// //                   ScaffoldMessenger.of(context).showSnackBar(
// //                     SnackBar(content: Text('Error fulfilling request: $e')),
// //                   );
// //                 }
// //               },
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           title: Text('Request Details'),
// //           content: SingleChildScrollView(
// //             child: ListBody(
// //               children: <Widget>[
// //                 Text('ID: ${request['id']}'),
// //                 Text('Status: ${request['status']}'),
// //                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
// //                 if (request['status'] == 'fulfilled')
// //                   Text(
// //                       'Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
// //                 Text('Location: ${request['location']}'),
// //                 Text('Picker Name: ${request['pickerName']}'),
// //                 Text('Picker Contact: ${request['pickerContact']}'),
// //                 Text('Note: ${request['note']}'),
// //                 Text('Items:'),
// //                 ...request['items']
// //                     .map<Widget>((item) => Padding(
// //                           padding: const EdgeInsets.only(left: 16.0),
// //                           child: Text('${item['quantity']} x ${item['name']}'),
// //                         ))
// //                     .toList(),
// //               ],
// //             ),
// //           ),
// //           actions: <Widget>[
// //             TextButton(
// //               child: Text('Close'),
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }
// // }

// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return Card(
//                   child: ListTile(
//                     title: Text('Stock Request #${request['id']}'),
//                     subtitle: Text('Status: ${request['status']}'),
//                     trailing: ElevatedButton(
//                       child: Text('View Details'),
//                       onPressed: () {
//                         _showStockRequestDetails(context, request);
//                       },
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showStockRequestDetails(
//       BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Stock Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Created At: ${_formatTimestamp(request['createdAt'])}'),
//                 Text('Created By: ${request['createdBy']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16.0),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill Request'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showFulfillmentDialog(context, request);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showFulfillmentDialog(
//       BuildContext context, Map<String, dynamic> request) {
//     final _formKey = GlobalKey<FormState>();
//     final Map<String, TextEditingController> controllers = {};

//     for (var item in request['items']) {
//       controllers[item['id']] = TextEditingController();
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Stock Request'),
//           content: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: ListBody(
//                 children: request['items'].map<Widget>((item) {
//                   return TextFormField(
//                     controller: controllers[item['id']],
//                     decoration: InputDecoration(
//                       labelText: '${item['name']} (Max: ${item['quantity']})',
//                     ),
//                     keyboardType: TextInputType.number,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter a quantity';
//                       }
//                       int? quantity = int.tryParse(value);
//                       if (quantity == null ||
//                           quantity < 0 ||
//                           quantity > item['quantity']) {
//                         return 'Please enter a valid quantity';
//                       }
//                       return null;
//                     },
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   _fulfillStockRequest(context, request, controllers);
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _fulfillStockRequest(BuildContext context, Map<String, dynamic> request,
//       Map<String, TextEditingController> controllers) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     List<Map<String, dynamic>> fulfilledItems =
//         request['items'].map<Map<String, dynamic>>((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'receivedQuantity': int.parse(controllers[item['id']]!.text),
//       };
//     }).toList();

//     requestProvider
//         .fulfillStockRequest(
//             request['id'], fulfilledItems, authProvider.user!.uid)
//         .then((_) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request fulfilled successfully')),
//       );
//     }).catchError((error) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fulfilling stock request: $error')),
//       );
//     });
//   }
// }

// String _formatTimestamp(dynamic timestamp) {
//   if (timestamp == null) return 'N/A';
//   if (timestamp is Timestamp) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
//   }
//   if (timestamp is DateTime) {
//     return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
//   }
//   return timestamp.toString();
// }

// String _formatItems(List<dynamic>? items) {
//   if (items == null || items.isEmpty) return 'No items';
//   return items
//       .map((item) => '${item['quantity']} x ${item['name']}')
//       .join(', ');
// }
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/notification_provider.dart';
// import '../../screens/common/notification_screen.dart';
// import '../../screens/gateMan/gateman_stock_request_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return DefaultTabController(
//           length: 4,
//           child: Scaffold(
//             appBar: AppBar(
//               title: Text('Gate Man Dashboard'),
//               actions: [
//                 _buildNotificationIcon(),
//                 _buildLogoutButton(context, authProvider),
//               ],
//               bottom: TabBar(
//                 tabs: [
//                   Tab(text: 'Overview'),
//                   Tab(text: 'Approved Requests'),
//                   Tab(text: 'Recent Requests'),
//                   Tab(text: 'Stock Requests'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 SingleChildScrollView(child: _OverviewTab()),
//                 _ApprovedRequestsTab(),
//                 _RecentApprovedRequestsTab(),
//                 GatemanStockRequestScreen(),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         print("Building notification icon for user: $userId, role: $userRole");

//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             print("Unread notifications count: $unreadCount");

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     print("Notification icon pressed");
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       print("Notifications fetched successfully");

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {}); // Trigger a rebuild of the widget
//                       });
//                     } catch (e) {
//                       print("Error fetching notifications: $e");
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }
// }

// class _OverviewTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Dashboard Overview',
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 16),
//           _buildStatistics(context),
//           SizedBox(height: 16),
//           Container(
//             height: 200,
//             child: _buildRequestStatusChart(context),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatistics(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _buildStatisticCard('Total', todayRequests.length),
//                 _buildStatisticCard('Approved', approvedRequests),
//                 _buildStatisticCard('Fulfilled', fulfilledRequests),
//               ],
//             ),
//             SizedBox(height: 16),
//             _buildRequestStatusChart(context),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return Container(
//           height: 200,
//           child: SfCircularChart(
//             legend: Legend(isVisible: true),
//             series: <CircularSeries>[
//               PieSeries<RequestStatus, String>(
//                 dataSource: data,
//                 xValueMapper: (RequestStatus data, _) => data.status,
//                 yValueMapper: (RequestStatus data, _) => data.count,
//                 pointColorMapper: (RequestStatus data, _) => data.color,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// class _ApprovedRequestsTab extends StatefulWidget {
//   @override
//   _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
// }

// class _ApprovedRequestsTabState extends State<_ApprovedRequestsTab> {
//   bool _shouldShowVerificationDialog = false;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   String? _pendingUniqueCode;

//   @override
//   Widget build(BuildContext context) {
//     if (_shouldShowVerificationDialog) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         setState(() {
//           _shouldShowVerificationDialog = false;
//         });
//         if (_pendingUniqueCode != null) {
//           _verifyCodeDialog(context, _pendingUniqueCode!);
//           _pendingUniqueCode = null;
//         }
//       });
//     }
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildSearchBar(),
//           SizedBox(height: 16),
//           Expanded(
//             child: _buildApprovedRequestsList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     print("Verifying code: $enteredCode");
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final notificationProvider =
//         Provider.of<NotificationProvider>(context, listen: false);

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       // Dismiss loading indicator
//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 setState(() {
//                   _shouldShowVerificationDialog = true;
//                   _pendingUniqueCode = uniqueCode;
//                 });
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       print("Code verification successful");

//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Code verified! Items can be collected.')),
//       );

//       // Refresh the list
//       setState(() {});
//     } catch (e) {
//       // Dismiss loading indicator if it's still showing
//       Navigator.of(context).popUntil((route) => route.isFirst);

//    print("Error during code verification: $e");

//       // Show error message with option to try again
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               setState(() {
//                 _shouldShowVerificationDialog = true;
//                 _pendingUniqueCode = uniqueCode;
//               });
//             },
//           ),
//         ),
//       );
//     }
//   }
// }


//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request, RequestProvider requestProvider) {
//     return Card(
//       child: ListTile(
//         title: Text('Request ID: ${request['id']}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Status: ${request['status']}'),
//             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//             if (request['status'] == 'fulfilled')
//               Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//             Text('Items: ${_formatItems(request['items'])}'),
//           ],
//         ),
//         trailing: request['status'] == 'approved'
//             ? ElevatedButton(
//                 child: Text('Fulfill'),
//                 onPressed: () => _fulfillRequest(context, request['id'], requestProvider),
//               )
//             : null,
//         onTap: () => _showRequestDetails(context, request),
//       ),
//     );
//   }

//   String _formatTimestamp(DateTime? timestamp) {
//     if (timestamp == null) return 'N/A';
//     return timestamp.toString();
//   }

//   String _formatItems(List<dynamic>? items) {
//     if (items == null || items.isEmpty) return 'No items';
//     return items.map((item) => '${item['quantity']} x ${item['name']}').join(', ');
//   }

//   void _fulfillRequest(BuildContext context, String requestId, RequestProvider requestProvider) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Request'),
//           content: Text('Are you sure you want to fulfill this request?'),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 try {
//                   await requestProvider.fulfillRequest(requestId);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Request fulfilled successfully')),
//                   );
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Error fulfilling request: $e')),
//                   );
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 if (request['status'] == 'fulfilled')
//                   Text('Fulfilled At: ${_formatTimestamp(request['fulfilledAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items'].map<Widget>((item) => Padding(
//                   padding: const EdgeInsets.only(left: 16.0),
//                   child: Text('${item['quantity']} x ${item['name']}'),
//                 )).toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

// // class _RecentApprovedRequestsTab extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     return Consumer<RequestProvider>(
// //       builder: (context, requestProvider, _) {
// //         return StreamBuilder<List<Map<String, dynamic>>>(
// //           stream: requestProvider.getRecentApprovedRequestsStream(),
// //           builder: (context, snapshot) {
// //             if (snapshot.connectionState == ConnectionState.waiting) {
// //               return Center(child: CircularProgressIndicator());
// //             }
// //             if (snapshot.hasError) {
// //               return Center(child: Text('Error: ${snapshot.error}'));
// //             }
// //             final requests = snapshot.data ?? [];
// //             if (requests.isEmpty) {
// //               return Center(child: Text('No recent approved requests found.'));
// //             }
// //             return ListView.builder(
// //               itemCount: requests.length,
// //               itemBuilder: (context, index) {
// //                 final request = requests[index];
// //                 return _buildRequestCard(context, request);
// //               },
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }
// // class _RecentApprovedRequestsTab extends StatelessWidget {
// //   @override
// //   Widget build(BuildContext context) {
// //     return Consumer<RequestProvider>(
// //       builder: (context, requestProvider, _) {
// //         return StreamBuilder<List<Map<String, dynamic>>>(
// //           stream: requestProvider.getRecentApprovedRequestsStream(),
// //           builder: (context, snapshot) {
// //             if (snapshot.connectionState == ConnectionState.waiting) {
// //               return Center(child: CircularProgressIndicator());
// //             }
// //             if (snapshot.hasError) {
// //               return Center(child: Text('Error: ${snapshot.error}'));
// //             }
// //             final requests = snapshot.data ?? [];
// //             if (requests.isEmpty) {
// //               return Center(
// //                   child:
// //                       Text('No recent approved or fulfilled requests found.'));
// //             }
// //             return ListView.builder(
// //               itemCount: requests.length,
// //               itemBuilder: (context, index) {
// //                 final request = requests[index];
// //                 return _buildRequestCard(context, request, requestProvider);
// //               },
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }


// //   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
// //     return Card(
// //       child: ListTile(
// //         title: Text('Request ID: ${request['id']}'),
// //         subtitle: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text('Status: ${request['status']}'),
// //             Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
// //             Text('Items: ${_formatItems(request['items'])}'),
// //           ],
// //         ),
// //         trailing: IconButton(
// //           icon: Icon(Icons.info_outline),
// //           onPressed: () => _showRequestDetails(context, request),
// //         ),
// //       ),
// //     );
// //   }

// //   String _formatTimestamp(Timestamp? timestamp) {
// //     if (timestamp == null) return 'N/A';
// //     return timestamp.toDate().toString();
// //   }

// //   String _formatItems(List<dynamic>? items) {
// //     if (items == null || items.isEmpty) return 'No items';
// //     return items
// //         .map((item) => '${item['quantity']} x ${item['name']}')
// //         .join(', ');
// //   }

//   void _showRequestDetails(BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Approved At: ${_formatTimestamp(request['approvedAt'])}'),
//                 Text('Location: ${request['location']}'),
//                 Text('Picker Name: ${request['pickerName']}'),
//                 Text('Picker Contact: ${request['pickerContact']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16.0),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return Card(
//                   child: ListTile(
//                     title: Text('Stock Request #${request['id']}'),
//                     subtitle: Text('Status: ${request['status']}'),
//                     trailing: ElevatedButton(
//                       child: Text('View Details'),
//                       onPressed: () {
//                         _showStockRequestDetails(context, request);
//                       },
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showStockRequestDetails(
//       BuildContext context, Map<String, dynamic> request) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Stock Request Details'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('ID: ${request['id']}'),
//                 Text('Status: ${request['status']}'),
//                 Text('Created At: ${_formatTimestamp(request['createdAt'])}'),
//                 Text('Created By: ${request['createdBy']}'),
//                 Text('Note: ${request['note']}'),
//                 Text('Items:'),
//                 ...request['items']
//                     .map<Widget>((item) => Padding(
//                           padding: const EdgeInsets.only(left: 16.0),
//                           child: Text('${item['quantity']} x ${item['name']}'),
//                         ))
//                     .toList(),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill Request'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showFulfillmentDialog(context, request);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showFulfillmentDialog(
//       BuildContext context, Map<String, dynamic> request) {
//     final _formKey = GlobalKey<FormState>();
//     final Map<String, TextEditingController> controllers = {};

//     for (var item in request['items']) {
//       controllers[item['id']] = TextEditingController();
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Fulfill Stock Request'),
//           content: Form(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: ListBody(
//                 children: request['items'].map<Widget>((item) {
//                   return TextFormField(
//                     controller: controllers[item['id']],
//                     decoration: InputDecoration(
//                       labelText: '${item['name']} (Max: ${item['quantity']})',
//                     ),
//                     keyboardType: TextInputType.number,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'Please enter a quantity';
//                       }
//                       int? quantity = int.tryParse(value);
//                       if (quantity == null ||
//                           quantity < 0 ||
//                           quantity > item['quantity']) {
//                         return 'Please enter a valid quantity';
//                       }
//                       return null;
//                     },
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: Text('Fulfill'),
//               onPressed: () {
//                 if (_formKey.currentState!.validate()) {
//                   _fulfillStockRequest(context, request, controllers);
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _fulfillStockRequest(BuildContext context, Map<String, dynamic> request,
//       Map<String, TextEditingController> controllers) {
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     List<Map<String, dynamic>> fulfilledItems =
//         request['items'].map<Map<String, dynamic>>((item) {
//       return {
//         'id': item['id'],
//         'name': item['name'],
//         'receivedQuantity': int.parse(controllers[item['id']]!.text),
//       };
//     }).toList();

//     requestProvider
//         .fulfillStockRequest(
//             request['id'], fulfilledItems, authProvider.user!.uid)
//         .then((_) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Stock request fulfilled successfully')),
//       );
//     }).catchError((error) {
//       Navigator.of(context).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fulfilling stock request: $error')),
//       );
//     });
//   }

//   String _formatTimestamp(Timestamp? timestamp) {
//     if (timestamp == null) return 'N/A';
//     return timestamp.toDate().toString();
//   }
// }


// import 'package:dhavla_road_project/providers/notification_provider.dart';
// import 'package:dhavla_road_project/screens/common/notification_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../screens/gateMan/gateman_stock_request_screen.dart';

// class GateManDashboard extends StatefulWidget {
//   @override
//   _GateManDashboardState createState() => _GateManDashboardState();
// }

// class _GateManDashboardState extends State<GateManDashboard> {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return DefaultTabController(
//           length: 3,
//           child: Scaffold(
//             appBar: AppBar(
//               title: Text('Gate Man Dashboard'),
//               actions: [
//                 _buildNotificationIcon(),
//                 _buildLogoutButton(context, authProvider),
//               ],
//               bottom: TabBar(
//                 tabs: [
//                   Tab(text: 'Overview'),
//                   Tab(text: 'Approved Requests'),
//                   Tab(text: 'Stock Requests'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 SingleChildScrollView(child: _OverviewTab()),
//                 _ApprovedRequestsTab(),
//                 GatemanStockRequestScreen(),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         print("Building notification icon for user: $userId, role: $userRole");

//         return ValueListenableBuilder<int>(
//           valueListenable: ValueNotifier<int>(notificationProvider
//               .getUnreadNotificationsCount(userId, userRole)),
//           builder: (context, unreadCount, child) {
//             print("Unread notifications count: $unreadCount");

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     print("Notification icon pressed");
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       print("Notifications fetched successfully");

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {}); // Trigger a rebuild of the widget
//                       });
//                     } catch (e) {
//                       print("Error fetching notifications: $e");
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }
// }

// class _OverviewTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Dashboard Overview',
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 16),
//           _buildStatistics(context),
//           SizedBox(height: 16),
//           Container(
//             height: 200,
//             child: _buildRequestStatusChart(context),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatistics(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _buildStatisticCard('Total', todayRequests.length),
//                 _buildStatisticCard('Approved', approvedRequests),
//                 _buildStatisticCard('Fulfilled', fulfilledRequests),
//               ],
//             ),
//             SizedBox(height: 16),
//             _buildRequestStatusChart(context),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return Container(
//           height: 200,
//           child: SfCircularChart(
//             legend: Legend(isVisible: true),
//             series: <CircularSeries>[
//               PieSeries<RequestStatus, String>(
//                 dataSource: data,
//                 xValueMapper: (RequestStatus data, _) => data.status,
//                 yValueMapper: (RequestStatus data, _) => data.count,
//                 pointColorMapper: (RequestStatus data, _) => data.color,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// class _ApprovedRequestsTab extends StatefulWidget {
//   @override
//   _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
// }

// class _ApprovedRequestsTabState extends State<_ApprovedRequestsTab> {
//   bool _shouldShowVerificationDialog = false;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   String? _pendingUniqueCode;

//   @override
//   Widget build(BuildContext context) {
//     if (_shouldShowVerificationDialog) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         setState(() {
//           _shouldShowVerificationDialog = false;
//         });
//         if (_pendingUniqueCode != null) {
//           _verifyCodeDialog(context, _pendingUniqueCode!);
//           _pendingUniqueCode = null;
//         }
//       });
//     }
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildSearchBar(),
//           SizedBox(height: 16),
//           Expanded(
//             child: _buildApprovedRequestsList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     print("Verifying code: $enteredCode");
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final notificationProvider =
//         Provider.of<NotificationProvider>(context, listen: false);

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       // Dismiss loading indicator
//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 setState(() {
//                   _shouldShowVerificationDialog = true;
//                   _pendingUniqueCode = uniqueCode;
//                 });
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       print("Code verification successful");

//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Code verified! Items can be collected.')),
//       );

//       // Refresh the list
//       setState(() {});
//     } catch (e) {
//       // Dismiss loading indicator if it's still showing
//       Navigator.of(context).popUntil((route) => route.isFirst);

//       print("Error during code verification: $e");

// // Show error message with option to try again
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               setState(() {
//                 _shouldShowVerificationDialog = true;
//                 _pendingUniqueCode = uniqueCode;
//               });
//             },
//           ),
//         ),
//       );
//     }
//   }
// }

// class GatemanStockRequestScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         return StreamBuilder<List<Map<String, dynamic>>>(
//           stream: requestProvider.getActiveStockRequestsStream(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }
//             final stockRequests = snapshot.data ?? [];
//             if (stockRequests.isEmpty) {
//               return Center(child: Text('No active stock requests found.'));
//             }
//             return ListView.builder(
//               itemCount: stockRequests.length,
//               itemBuilder: (context, index) {
//                 final request = stockRequests[index];
//                 return Card(
//                   child: ListTile(
//                     title: Text('Stock Request #${request['id']}'),
//                     subtitle: Text('Status: ${request['status']}'),
//                     trailing: ElevatedButton(
//                       child: Text('View Details'),
//                       onPressed: () {
//                         // Navigate to stock request details screen
//                         // You'll need to implement this navigation
//                       },
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// import 'package:dhavla_road_project/providers/notification_provider.dart';
// import 'package:dhavla_road_project/screens/common/notification_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import '../../providers/request_provider.dart';
// import '../../providers/auth_provider.dart';
// import '../../screens/gateMan/gateman_stock_request_screen.dart';
// import '../../providers/notification_provider.dart' as custom_notification;

// class GateManDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthProvider>(
//       builder: (context, authProvider, _) {
//         if (authProvider.user == null || authProvider.role != 'Gate Man') {
//           return Scaffold(
//             body: Center(
//               child: Text('You do not have permission to access this page.'),
//             ),
//           );
//         }

//         return DefaultTabController(
//           length: 3,
//           child: Scaffold(
//             appBar: AppBar(
//               title: Text('Gate Man Dashboard'),
//               actions: [
//                 _buildNotificationIcon(),
//                 _buildLogoutButton(context, authProvider),
//               ],
//               bottom: TabBar(
//                 tabs: [
//                   Tab(text: 'Overview'),
//                   Tab(text: 'Approved Requests'),
//                   Tab(text: 'Stock Requests'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 SingleChildScrollView(child: _OverviewTab()),
//                 _ApprovedRequestsTab(),
//                 GatemanStockRequestScreen(),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

 

//   Widget _buildNotificationIcon() {
//     return Consumer2<AuthProvider, NotificationProvider>(
//       builder: (context, authProvider, notificationProvider, child) {
//         final userId = authProvider.user?.uid ?? '';
//         final userRole = authProvider.role ?? 'Gate Man';
//         print("Building notification icon for user: $userId, role: $userRole");

//         return FutureBuilder<int>(
//           future: notificationProvider.getUnreadNotificationsCount(
//               userId, userRole),
//           builder: (context, snapshot) {
//             int unreadCount = snapshot.data ?? 0;
//             print("Unread notifications count: $unreadCount");

//             return Stack(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.notifications),
//                   onPressed: () async {
//                     print("Notification icon pressed");
//                     try {
//                       await notificationProvider.fetchNotifications(
//                           userId, userRole);
//                       print("Notifications fetched successfully");

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => NotificationsScreen(),
//                         ),
//                       ).then((_) {
//                         setState(() {}); // Trigger a rebuild of the widget
//                       });
//                     } catch (e) {
//                       print("Error fetching notifications: $e");
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                             content: Text(
//                                 'Error loading notifications. Please try again.')),
//                       );
//                     }
//                   },
//                 ),
//                 if (unreadCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         '$unreadCount',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
//     return ElevatedButton(
//       onPressed: () async {
//         try {
//           await authProvider.logout();
//           Navigator.of(context).pushReplacementNamed('/login');
//         } catch (e) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error logging out. Please try again.')),
//           );
//         }
//       },
//       child: Text('Logout'),
//     );
//   }
// }

// class _OverviewTab extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Dashboard Overview',
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 16),
//           _buildStatistics(context),
//           SizedBox(height: 16),
//           Container(
//             height: 200,
//             child: _buildRequestStatusChart(context),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatistics(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;

//         return Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _buildStatisticCard('Total', todayRequests.length),
//                 _buildStatisticCard('Approved', approvedRequests),
//                 _buildStatisticCard('Fulfilled', fulfilledRequests),
//               ],
//             ),
//             SizedBox(height: 16),
//             _buildRequestStatusChart(context),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatisticCard(String title, int count) {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestStatusChart(BuildContext context) {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final todayRequests = requestProvider.getTodayRequests();
//         final pendingRequests = todayRequests
//             .where((request) => request['status'] == 'pending')
//             .length;
//         final approvedRequests = todayRequests
//             .where((request) => request['status'] == 'approved')
//             .length;
//         final fulfilledRequests = todayRequests
//             .where((request) => request['status'] == 'fulfilled')
//             .length;

//         final data = [
//           RequestStatus('Pending', pendingRequests, Colors.orange),
//           RequestStatus('Approved', approvedRequests, Colors.green),
//           RequestStatus('Fulfilled', fulfilledRequests, Colors.blue),
//         ];

//         return Container(
//           height: 200,
//           child: SfCircularChart(
//             legend: Legend(isVisible: true),
//             series: <CircularSeries>[
//               PieSeries<RequestStatus, String>(
//                 dataSource: data,
//                 xValueMapper: (RequestStatus data, _) => data.status,
//                 yValueMapper: (RequestStatus data, _) => data.count,
//                 pointColorMapper: (RequestStatus data, _) => data.color,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class RequestStatus {
//   final String status;
//   final int count;
//   final Color color;

//   RequestStatus(this.status, this.count, this.color);
// }

// class _ApprovedRequestsTab extends StatefulWidget {
//   @override
//   _ApprovedRequestsTabState createState() => _ApprovedRequestsTabState();
// }

// class _ApprovedRequestsTabState extends State<_ApprovedRequestsTab> {
//   bool _shouldShowVerificationDialog = false;
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   String? _pendingUniqueCode;

//   @override
//   Widget build(BuildContext context) {
//     if (_shouldShowVerificationDialog) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         setState(() {
//           _shouldShowVerificationDialog = false;
//         });
//         if (_pendingUniqueCode != null) {
//           _verifyCodeDialog(context, _pendingUniqueCode!);
//           _pendingUniqueCode = null;
//         }
//       });
//     }
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildSearchBar(),
//           SizedBox(height: 16),
//           Expanded(
//             child: _buildApprovedRequestsList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return TextField(
//       controller: _searchController,
//       decoration: InputDecoration(
//         labelText: 'Search Requests by Picker Name or Contact',
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

//   Widget _buildApprovedRequestsList() {
//     return Consumer<RequestProvider>(
//       builder: (context, requestProvider, _) {
//         final approvedRequests =
//             requestProvider.getApprovedRequests(_searchQuery);

//         if (approvedRequests.isEmpty) {
//           return Center(child: Text('No approved requests found.'));
//         }

//         return ListView.builder(
//           itemCount: approvedRequests.length,
//           itemBuilder: (context, index) {
//             final request = approvedRequests[index];
//             return _buildRequestCard(context, request);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
//     return Card(
//       child: ListTile(
//         title: Text(
//           'Items: ${request['items'].map((item) => '${item['quantity']} ${item['unit']} x ${item['name']}').join(', ')}',
//         ),
//         subtitle: Text(
//           'Location: ${request['location']}\n'
//           'Picker: ${request['pickerName']}\n'
//           'Contact: ${request['pickerContact']}\n'
//           'Status: ${request['status']}\n'
//           'Unique Code: ${request['uniqueCode']}',
//         ),
//         leading: Icon(
//           Icons.request_page,
//           color: Colors.green,
//         ),
//         trailing: IconButton(
//           icon: Icon(Icons.verified, color: Colors.blue),
//           onPressed: () {
//             _verifyCodeDialog(context, request['uniqueCode']);
//           },
//         ),
//       ),
//     );
//   }

//   void _verifyCodeDialog(BuildContext context, String uniqueCode) {
//     final TextEditingController _codeController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text('Verify Unique Code'),
//           content: TextField(
//             controller: _codeController,
//             decoration: InputDecoration(
//               labelText: 'Enter 6-digit Unique Code',
//               hintText: '000000',
//             ),
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               LengthLimitingTextInputFormatter(6),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_codeController.text.length != 6) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Please enter a 6-digit code')),
//                   );
//                 } else {
//                   Navigator.of(dialogContext).pop();
//                   _verifyCode(context, _codeController.text, uniqueCode);
//                 }
//               },
//               child: Text('Verify'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     print("Verifying code: $enteredCode");
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);
//     final notificationProvider =
//         Provider.of<NotificationProvider>(context, listen: false);

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       // Dismiss loading indicator
//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 setState(() {
//                   _shouldShowVerificationDialog = true;
//                   _pendingUniqueCode = uniqueCode;
//                 });
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       print("Code verification successful");

//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Code verified! Items can be collected.')),
//       );

//       // Refresh the list
//       setState(() {});
//     } catch (e) {
//       // Dismiss loading indicator if it's still showing
//       Navigator.of(context).popUntil((route) => route.isFirst);

//       print("Error during code verification: $e");

//       // Show error message with option to try again
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               setState(() {
//                 _shouldShowVerificationDialog = true;
//                 _pendingUniqueCode = uniqueCode;
//               });
//             },
//           ),
//         ),
//       );
//     }
//   }
// }

//   void _verifyCode(
//       BuildContext context, String enteredCode, String uniqueCode) async {
//     if (enteredCode.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a 6-digit code')),
//       );
//       return;
//     }

//     print("Verifying code: $enteredCode");
//     final requestProvider =
//         Provider.of<RequestProvider>(context, listen: false);

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       bool isValid = await requestProvider.checkCodeValidity(enteredCode);

//       // Dismiss loading indicator
//       Navigator.of(context).pop();

//       if (!isValid) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invalid code. Please check and try again.'),
//             action: SnackBarAction(
//               label: 'Try Again',
//               onPressed: () {
//                 setState(() {
//                   _shouldShowVerificationDialog = true;
//                   _pendingUniqueCode = uniqueCode;
//                 });
//               },
//             ),
//           ),
//         );
//         return;
//       }

//       await requestProvider.fulfillRequestByCode(enteredCode);

//       print("Code verification successful");

//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Code verified! Items can be collected.')),
//       );

//       // Refresh the list
//       setState(() {});
//     } catch (e) {
//       // Dismiss loading indicator if it's still showing
//       Navigator.of(context).popUntil((route) => route.isFirst);

//       print("Error during code verification: $e");

//       // Show error message with option to try again
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Error: ${e.toString()}. Please check the code and try again.'),
//           action: SnackBarAction(
//             label: 'Try Again',
//             onPressed: () {
//               setState(() {
//                 _shouldShowVerificationDialog = true;
//                 _pendingUniqueCode = uniqueCode;
//               });
//             },
//           ),
//         ),
//       );
//     }
//   }
// }
