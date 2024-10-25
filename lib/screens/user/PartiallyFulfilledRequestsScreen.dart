import 'package:dhavla_road_project/screens/user/GenericRequestListScreen.dart';
import 'package:flutter/material.dart';


class PartiallyFulfilledRequestsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GenericRequestListScreen(
      title: 'Partially Fulfilled Requests',
      status: 'partially_fulfilled',
      headerColor: Colors.amber,
    );
  }
}
