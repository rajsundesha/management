import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dhavla_road_project/providers/location_provider.dart';
import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:dhavla_road_project/screens/admin/account_deletion_requests_screen.dart';
import 'package:dhavla_road_project/screens/admin/manage_location_screen.dart';
import 'package:dhavla_road_project/screens/common/Notification_test_screen.dart';
import 'package:dhavla_road_project/screens/common/global_keys.dart';
import 'package:dhavla_road_project/screens/common/listener_manager.dart';
import 'package:dhavla_road_project/screens/common/request_details_screen.dart';
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
import 'screens/manager/manager_approved_requests_screen.dart';
import 'screens/manager/manager_completed_requests_screen.dart';
import 'screens/manager/manager_statistics_screen.dart';
import 'screens/gateman/gate_man_dashboard.dart';
import 'screens/common/loading_screen.dart';
import 'providers/auth_provider.dart' as app_auth;
// import 'providers/notification_provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase Core initialized successfully');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _initializeFirebaseMessaging();
    FirebaseFunctions.instanceFor(region: 'asia-south1');

    // Initialize the ListenerManager first
    final listenerManager = ListenerManager();
    final authProvider = app_auth.AuthProvider(listenerManager);
    final notificationProvider = NotificationProvider();

// Now, pass the ListenerManager to the InventoryProvider
    final inventoryProvider = InventoryProvider(listenerManager);
    // final inventoryProvider = InventoryProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider<NotificationProvider>.value(
              value: notificationProvider),
          ChangeNotifierProvider<app_auth.AuthProvider>.value(
              value: authProvider),
          ChangeNotifierProvider<InventoryProvider>.value(
              value: inventoryProvider),
          ChangeNotifierProvider<RequestProvider>(
            create: (context) => RequestProvider(
              notificationProvider,
              inventoryProvider,
            ),
          ),
        ],
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('An error occurred during app initialization: $error'),
        ),
      ),
    );
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add this line
      title: 'Inventory Management',
      debugShowCheckedModeBanner: false, // Add this line
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
        // '/manager_pending_requests': (context) =>
        //     ManagerPendingRequestsScreen(),
        '/manager_approved_requests': (context) =>
            ManagerApprovedRequestsScreen(),
        '/manager_completed_requests': (context) =>
            ManagerCompletedRequestsScreen(),
        '/manager_statistics': (context) => ManagerStatisticsScreen(),
        '/admin_manage_stock_requests': (context) =>
            AdminManageStockRequestsScreen(),
        '/edit_profile': (context) => EditProfileScreen(),
        '/manager_stock_request': (context) => ManagerStockRequestScreen(),
        '/notification_test': (context) => NotificationTestScreen(),
        '/request_details': (context) => RequestDetailsScreen(
              requestId: ModalRoute.of(context)!.settings.arguments as String,
              isStockRequest:
                  false, // You might need to determine this based on the notification data
            ),
        '/account_deletion_requests': (context) =>
            AccountDeletionRequestsScreen(),
        '/manage_locations': (context) => ManageLocationsScreen(),
      },
    );
  }
}

Future<void> _initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationTap(initialMessage.data);
  }

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

    String? token = await messaging.getToken();
    print('FCM Token: $token');

    if (token != null) {
      await _saveTokenToDatabase(token);
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Handle incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Handling a foreground message: ${message.messageId}");
      // Show a local notification or update the UI
    });

    // Handle notification taps when the app is in the background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification tapped: ${message.messageId}");
      // Navigate to the appropriate screen based on the notification data
      _handleNotificationTap(message.data);
    });

    // Check if the app was opened from a notification when it was terminated
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }
  } catch (e) {
    print('Error initializing Firebase Messaging: $e');
  }
}

void _handleNotificationTap(Map<String, dynamic> messageData) {
  print("Handling notification tap with data: $messageData");
  if (messageData['requestId'] != null) {
    final bool isStockRequest = messageData['isStockRequest'] == 'true';
    navigatorKey.currentState?.pushNamed(
      '/request_details',
      arguments: {
        'requestId': messageData['requestId'],
        'isStockRequest': isStockRequest,
      },
    );
  } else if (messageData['notificationType'] != null) {
    switch (messageData['notificationType']) {
      case 'newRequest':
        navigatorKey.currentState?.pushNamed('/manage_requests');
        break;
      case 'inventoryUpdate':
        navigatorKey.currentState?.pushNamed('/manage_inventory');
        break;
      // Add more cases as needed for different notification types
      default:
        print("Unknown notification type: ${messageData['notificationType']}");
    }
  } else {
    print("No specific action for this notification");
  }
}

Future<void> _saveTokenToDatabase(String token) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
    print('FCM Token saved to database for user: $userId');
  }
}

class InitialAuthCheckScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<app_auth.AuthProvider>(context, listen: false)
          .signOutIfUnauthorized(context), // Pass the context here
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen(); // Show loading screen while waiting
        }
        // After the check, navigate to AuthWrapper
        return AuthWrapper();
      },
    );
  }
}

// class InitialAuthCheckScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: Provider.of<app_auth.AuthProvider>(context, listen: false)
//           .signOutIfUnauthorized(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return LoadingScreen();
//         }
//         // After the check, navigate to AuthWrapper
//         return AuthWrapper();
//       },
//     );
//   }
// }

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

    Widget dashboard;
    switch (role) {
      case 'Admin':
        dashboard = AdminDashboardScreen();
        break;
      case 'Manager':
        dashboard = ManagerDashboard();
        break;
      case 'Gate Man':
        dashboard = GateManDashboard();
        break;
      case 'User':
        dashboard = UserDashboard();
        break;
      default:
        dashboard = _buildUnexpectedRoleScreen(role);
    }

    return Scaffold(
      body: dashboard,
    );
  }

  Widget _buildUnexpectedRoleScreen(String? role) {
    return Scaffold(
      body: Center(
        child: Text('Unexpected role: $role. Please contact support.'),
      ),
    );
  }
}
