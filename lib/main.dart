import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/request_provider.dart';
import 'providers/user_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/manage_inventory_screen.dart';
import 'screens/admin/manage_requests_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/common/login_screen.dart';
import 'screens/manager/manager_create_request_screen.dart';
import 'screens/user/user_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/manager/manager_inventory_screen.dart';
import 'screens/manager/manager_pending_requests_screen.dart';
import 'screens/manager/manager_approved_requests_screen.dart';
import 'screens/manager/manager_completed_requests_screen.dart';
import 'screens/manager/manager_statistics_screen.dart';
import 'screens/gateman/gate_man_dashboard.dart';
import 'screens/common/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
              '/': (context) =>
                  auth.user == null ? LoginScreen() : HomeScreen(),
              '/user_dashboard': (context) => UserDashboard(),
              '/admin_dashboard': (context) => AdminDashboardScreen(),
              '/manager_dashboard': (context) => ManagerDashboard(),
              '/manage_requests': (context) => ManageRequestsScreen(),
              '/manage_inventory': (context) => ManageInventoryScreen(),
              '/user_management': (context) => UserManagementScreen(),
              '/reports': (context) => ReportsScreen(),
              '/settings': (context) => SettingsScreen(),
              '/gate_man_dashboard': (context) => GateManDashboard(),
              '/manager_create_request': (context) =>
                  CreateManagerRequestScreen(),
              '/manager_inventory': (context) => ManagerInventoryScreen(),
              '/manager_pending_requests': (context) =>
                  ManagerPendingRequestsScreen(),
              '/manager_approved_requests': (context) =>
                  ManagerApprovedRequestsScreen(),
              '/manager_completed_requests': (context) =>
                  ManagerCompletedRequestsScreen(),
              '/manager_statistics': (context) => ManagerStatisticsScreen(),
            },
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.role) {
      case 'Admin':
        return AdminDashboardScreen();
      case 'Manager':
        return ManagerDashboard();
      case 'Gate Man':
        return GateManDashboard();
      default:
        return UserDashboard();
    }
  }
}

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: MyHomePage(),
//     );
//   }
// }

// class MyHomePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Firebase Initialization Example'),
//       ),
//       body: Center(
//         child: Text('Firebase Initialized Successfully!'),
//       ),
//     );
//   }
// }



// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'providers/user_provider.dart';

// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/manager/manager_create_request_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'screens/manager/manager_inventory_screen.dart';
// import 'screens/manager/manager_pending_requests_screen.dart';
// import 'screens/manager/manager_approved_requests_screen.dart';
// import 'screens/manager/manager_completed_requests_screen.dart';
// import 'screens/manager/manager_statistics_screen.dart';
// import 'screens/gateman/gate_man_dashboard.dart';

// import 'providers/auth_provider.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     await Firebase.initializeApp();
//     print("Firebase initialized successfully");
//   } catch (e) {
//     print("Firebase initialization failed: $e");
//   }
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//         ChangeNotifierProvider(create: (_) => UserProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//               '/gate_man_dashboard': (context) => GateManDashboard(),
//               '/manager_create_request': (context) =>
//                   CreateManagerRequestScreen(),
//               '/manager_inventory': (context) => ManagerInventoryScreen(),
//               '/manager_pending_requests': (context) =>
//                   ManagerPendingRequestsScreen(),
//               '/manager_approved_requests': (context) =>
//                   ManagerApprovedRequestsScreen(),
//               '/manager_completed_requests': (context) =>
//                   ManagerCompletedRequestsScreen(),
//               '/manager_statistics': (context) => ManagerStatisticsScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'providers/user_provider.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'screens/manager/manager_create_request_screen.dart';
// import 'screens/manager/manager_edit_request_screen.dart';
// import 'screens/manager/manager_inventory_screen.dart';
// import 'screens/manager/manager_statistics_screen.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';
// import 'screens/gateman/gate_man_dashboard.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//         ChangeNotifierProvider(create: (_) => UserProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//               '/gate_man_dashboard': (context) => GateManDashboard(),
//               '/manager_create_request': (context) =>
//                   ManagerCreateRequestScreen(),
//               '/manager_edit_request': (context) => ManagerEditRequestScreen(),
//               '/manager_inventory': (context) => ManagerInventoryScreen(),
//               '/manager_statistics': (context) => ManagerStatisticsScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'providers/user_provider.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// // import 'screens/gateMan/gate_man_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';
// import 'screens/gateman/gate_man_dashboard.dart'; // Add this import

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//         ChangeNotifierProvider(create: (_) => UserProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//               // '/gate_man_screen': (context) => GateManScreen(),
//               '/gate_man_dashboard': (context) =>
//                   GateManDashboard(), // Add this route
//             },
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'providers/user_provider.dart'; // Add this import
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//         ChangeNotifierProvider(
//             create: (_) => UserProvider()), // Add this provider
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/admin/manage_inventory_screen.dart';
// import 'screens/admin/manage_requests_screen.dart';
// import 'screens/admin/reports_screen.dart';
// import 'screens/admin/settings_screen.dart';
// import 'screens/admin/user_management_screen.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// // import 'screens/admin/admin_dashboard_screen.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               '/manage_requests': (context) => ManageRequestsScreen(),
//               '/manage_inventory': (context) => ManageInventoryScreen(),
//               '/user_management': (context) => UserManagementScreen(),
//               '/reports': (context) => ReportsScreen(),
//               '/settings': (context) => SettingsScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:dhavla_road_project/providers/inventory_provider.dart';
// import 'package:dhavla_road_project/providers/request_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/item_request_screen.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/approval_detail_screen.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'screens/distribution_detail_screen.dart';
// import 'screens/otp_verification_screen.dart';
// import 'models/item_request.dart';
// import 'models/approved_request.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//           ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               // '/item_request': (context) => ItemRequestScreen(),
//               // '/admin_dashboard': (context) => AdminDashboard(),
//               // '/approval_detail': (context) => ApprovalDetailScreen(
//               //       request: ModalRoute.of(context)!.settings.arguments
//               //           as ItemRequest,
//               //     ),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               // '/distribution_detail': (context) => DistributionDetailScreen(
//               //       request: ModalRoute.of(context)!.settings.arguments
//               //           as ApprovedRequest,
//               //     ),
//               // '/otp_verification': (context) => OTPVerificationScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/inventory_provider.dart';
// import 'providers/request_provider.dart';
// import 'screens/common/login_screen.dart';
// import 'screens/user/user_dashboard.dart';
// import 'screens/item_request_screen.dart';
// import 'screens/admin/admin_dashboard.dart';
// import 'screens/approval_detail_screen.dart';
// import 'screens/manager/manager_dashboard.dart';
// import 'screens/distribution_detail_screen.dart';
// import 'screens/otp_verification_screen.dart';
// import 'models/item_request.dart';
// import 'models/approved_request.dart';
// import 'providers/auth_provider.dart';
// import 'providers/item_request_provider.dart';
// import 'providers/approved_request_provider.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => AuthProvider()),
//         ChangeNotifierProvider(create: (_) => ItemRequestProvider()),
//         ChangeNotifierProvider(create: (_) => ApprovedRequestProvider()),
//         ChangeNotifierProvider(create: (_) => InventoryProvider()),
//         ChangeNotifierProvider(create: (_) => RequestProvider()),
//       ],
//       child: Consumer<AuthProvider>(
//         builder: (context, auth, _) {
//           return MaterialApp(
//             title: 'Inventory Management',
//             theme: ThemeData(
//               primarySwatch: Colors.blue,
//             ),
//             initialRoute: '/',
//             routes: {
//               '/': (context) => LoginScreen(),
//               '/user_dashboard': (context) => UserDashboard(),
//               // '/item_request': (context) => ItemRequestScreen(),
//               '/admin_dashboard': (context) => AdminDashboardScreen(),
//               // '/approval_detail': (context) => ApprovalDetailScreen(
//               //       request: ModalRoute.of(context)!.settings.arguments
//               //           as ItemRequest,
//               //     ),
//               '/manager_dashboard': (context) => ManagerDashboard(),
//               // '/distribution_detail': (context) => DistributionDetailScreen(
//               //       request: ModalRoute.of(context)!.settings.arguments
//               //           as ApprovedRequest,
//               //     ),
//               // '/otp_verification': (context) => OTPVerificationScreen(),
//             },
//           );
//         },
//       ),
//     );
//   }
// }
