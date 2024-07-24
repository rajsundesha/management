import 'package:cloud_functions/cloud_functions.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/inventory_provider.dart';
import 'providers/request_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_manage_inventory_screen.dart';
import 'screens/admin/admin_manage_requests_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/admin_manage_stock_requests_screen.dart';
import 'screens/common/login_screen.dart';
// import 'screens/common/otp_login_screen.dart';
import 'screens/common/signup_screen.dart';
// import 'screens/manager/create_manager_stock_order_screen.dart';
import 'screens/manager/manager_stock_request_screen.dart';
import 'screens/manager/manager_create_request_screen.dart';
import 'screens/user/edit_profile_screen.dart';
import 'screens/user/user_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/manager/manager_inventory_screen.dart';
import 'screens/manager/manager_pending_requests_screen.dart';
import 'screens/manager/manager_approved_requests_screen.dart';
import 'screens/manager/manager_completed_requests_screen.dart';
import 'screens/manager/manager_statistics_screen.dart';
import 'screens/gateman/gate_man_dashboard.dart';
import 'screens/common/loading_screen.dart';
import 'providers/auth_provider.dart' as app_auth;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();

//   final authProvider = app_auth.AuthProvider();

//   User? user = FirebaseAuth.instance.currentUser;
//   if (user != null) {
//     await authProvider.ensureUserDocument();
//   }

//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider<InventoryProvider>(
//             create: (_) => InventoryProvider()),
//         ChangeNotifierProvider<app_auth.AuthProvider>.value(
//             value: authProvider),
//         ChangeNotifierProvider<RequestProvider>(
//             create: (_) => RequestProvider()),
//       ],
//       child: MyApp(),
//     ),
//   );
// }

// Future<void> _initializeFirebase() async {
//   try {
//     await Firebase.initializeApp();
//     print('Firebase initialized successfully');
//   } catch (e) {
//     print('Failed to initialize Firebase: $e');
//   }
// }

// Future<void> _requestNotificationPermissions() async {
//   try {
//     final messaging = FirebaseMessaging.instance;
//     NotificationSettings settings = await messaging.requestPermission(
//       alert: true,
//       announcement: false,
//       badge: true,
//       carPlay: false,
//       criticalAlert: false,
//       provisional: false,
//       sound: true,
//     );
//     print('User granted permission: ${settings.authorizationStatus}');
//   } on PlatformException catch (e) {
//     print(
//         'PlatformException when requesting notification permissions: ${e.message}');
//   } catch (e) {
//     print('Error requesting notification permissions: $e');
//     if (e is MissingPluginException) {
//       print('MissingPluginException details: ${e.message}');
//     }
//   }
// }
// Future<void> _requestNotificationPermissions() async {
//   try {
//     final messaging = FirebaseMessaging.instance;
//     await messaging.requestPermission();
//     print('Notification permissions granted');
//   } catch (e) {
//     print('Failed to request notification permissions: $e');
//   }
// }
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase Core initialized successfully');

    final messaging = FirebaseMessaging.instance;
    print('FirebaseMessaging instance created');

    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }

    try {
      String? fcmToken = await messaging.getToken();
      print('FCM Token: $fcmToken');
    } catch (e) {
      print('Error getting FCM token: $e');
    }

    // Set the Firebase Functions instance to use the asia-south1 region
    FirebaseFunctions.instanceFor(region: 'asia-south1');

    final authProvider = app_auth.AuthProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationProvider>(
            create: (context) => NotificationProvider(),
          ),
          ChangeNotifierProvider<InventoryProvider>(
              create: (_) => InventoryProvider()),
          ChangeNotifierProvider<app_auth.AuthProvider>.value(
              value: authProvider),
          ChangeNotifierProvider<RequestProvider>(
            create: (context) {
              final provider = RequestProvider();
              provider.setContext(context);
              return provider;
            },
          ),
        ],
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
  }
}

Future<void> _initializeFirebase() async {
  try {
    print('Firebase already initialized in main()');
  } catch (e) {
    print('Error in _initializeFirebase: $e');
  }
}

Future<void> _requestNotificationPermissions() async {
  try {
    final messaging = FirebaseMessaging.instance;
    print('FirebaseMessaging instance created');
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');
  } on PlatformException catch (e) {
    print(
        'PlatformException when requesting notification permissions: ${e.message}');
  } catch (e) {
    print('Error requesting notification permissions: $e');
    if (e is MissingPluginException) {
      print('MissingPluginException details: ${e.message}');
    }
  }
}
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();

//   // Request permission for iOS devices
//   await _initializeFirebase();
//   await _requestNotificationPermissions();
//   // Set the Firebase Functions instance to use the asia-south1 region
//   // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
//   FirebaseFunctions.instanceFor(region: 'asia-south1');

//   final authProvider = app_auth.AuthProvider();

//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider<NotificationProvider>(
//           create: (context) => NotificationProvider(),
//         ),
//         ChangeNotifierProvider<InventoryProvider>(
//             create: (_) => InventoryProvider()),
//         ChangeNotifierProvider<app_auth.AuthProvider>.value(
//             value: authProvider),
//         ChangeNotifierProvider<RequestProvider>(
//           create: (context) {
//             final provider = RequestProvider();
//             provider.setContext(context);
//             return provider;
//           },
//         ),
//         // ChangeNotifierProvider<RequestProvider>(
//         //     create: (_) => RequestProvider()),
//       ],
//       child: MyApp(),
//     ),
//   );
// }

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: InitialAuthCheckScreen(),
      routes: {
        '/login': (context) => LoginScreen(), // Add this line
        '/signup': (context) => SignUpScreen(),
        '/user_dashboard': (context) => UserDashboard(),
        '/admin_dashboard': (context) => AdminDashboardScreen(),
        '/manager_dashboard': (context) => ManagerDashboard(),
        '/manage_requests': (context) => AdminManageRequestsScreen(),
        '/manage_inventory': (context) => ManageInventoryScreen(),
        '/user_management': (context) => UserManagementScreen(),
        '/reports': (context) => ReportsScreen(),
        '/settings': (context) => SettingsScreen(),
        '/gate_man_dashboard': (context) => GateManDashboard(),
        '/manager_create_request': (context) => CreateManagerRequestScreen(),
        '/manager_inventory': (context) => ManagerInventoryScreen(),
        '/manager_pending_requests': (context) =>
            ManagerPendingRequestsScreen(),
        '/manager_approved_requests': (context) =>
            ManagerApprovedRequestsScreen(),
        '/manager_completed_requests': (context) =>
            ManagerCompletedRequestsScreen(),
        '/manager_statistics': (context) => ManagerStatisticsScreen(),
        '/admin_manage_stock_requests': (context) =>
            AdminManageStockRequestsScreen(),
        '/edit_profile': (context) => EditProfileScreen(),
        '/manager_stock_request': (context) => ManagerStockRequestScreen(),
        // '/otp_login': (context) => OTPLoginScreen(),
      },
    );
  }
}

class InitialAuthCheckScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<app_auth.AuthProvider>(context, listen: false)
          .signOutIfUnauthorized(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen();
        }
        // After the check, navigate to AuthWrapper
        return AuthWrapper();
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return LoginScreen();
    }

    return FutureBuilder(
      future: authProvider.refreshUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen();
        }
        return HomeScreen();
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final role = authProvider.role;

    switch (role) {
      case 'Admin':
        return AdminDashboardScreen();
      case 'Manager':
        return ManagerDashboard();
      case 'Gate Man':
        return GateManDashboard();
      case 'User':
        return UserDashboard();
      default:
        // Handle unexpected role or no role assigned
        return Scaffold(
          body: Center(
            child: Text('Unexpected role: $role. Please contact support.'),
          ),
        );
    }
  }
}
