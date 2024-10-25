import 'package:dhavla_road_project/screens/user/GenericRequestListScreen.dart';
import 'package:flutter/material.dart';


class ApprovedRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GenericRequestListScreen(
      title: 'Approved Requests',
      status: 'approved',
      headerColor: Colors.blue,
    );
  }
}
