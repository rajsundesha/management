import 'package:dhavla_road_project/providers/inventory_provider.dart';
import 'package:dhavla_road_project/providers/request_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/item_request_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/approval_detail_screen.dart';
import 'screens/manager_dashboard.dart';
import 'screens/distribution_detail_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'models/item_request.dart';
import 'models/approved_request.dart';
import 'providers/auth_provider.dart';
import 'providers/item_request_provider.dart';
import 'providers/approved_request_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
        ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
          ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Inventory Management',
            theme: ThemeData(
              primarySwatch: Colors.blue,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => LoginScreen(),
              '/user_dashboard': (context) => UserDashboard(),
              '/item_request': (context) => ItemRequestScreen(),
              '/admin_dashboard': (context) => AdminDashboard(),
              '/approval_detail': (context) => ApprovalDetailScreen(
                    request: ModalRoute.of(context)!.settings.arguments
                        as ItemRequest,
                  ),
              '/manager_dashboard': (context) => ManagerDashboard(),
              '/distribution_detail': (context) => DistributionDetailScreen(
                    request: ModalRoute.of(context)!.settings.arguments
                        as ApprovedRequest,
                  ),
              '/otp_verification': (context) => OTPVerificationScreen(),
            },
          );
        },
      ),
    );
  }
}
