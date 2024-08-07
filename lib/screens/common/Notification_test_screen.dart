import 'package:dhavla_road_project/providers/notification_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';

class NotificationTestScreen extends StatefulWidget {
  @override
  _NotificationTestScreenState createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _resultMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Test')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _runAllTests,
              child: Text('Run All Tests'),
            ),
            ElevatedButton(
              onPressed: _testUserAuthentication,
              child: Text('Test User Authentication'),
            ),
            ElevatedButton(
              onPressed: _testFirestoreDocument,
              child: Text('Test Firestore Document'),
            ),
            ElevatedButton(
              onPressed: _testFCMToken,
              child: Text('Test FCM Token'),
            ),
            ElevatedButton(
              onPressed: _testCloudFunction,
              child: Text('Test Cloud Function'),
            ),
            ElevatedButton(
              onPressed: _testSendNotification,
              child: Text('Test Send Notification'),
            ),
            SizedBox(height: 20),
            Text(_resultMessage, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _resultMessage = 'Running all tests...';
    });

    await _testUserAuthentication();
    await _testFirestoreDocument();
    await _testFCMToken();
    await _testCloudFunction();
    await _testSendNotification();

    setState(() {
      _resultMessage += '\n\nAll tests completed.';
    });
  }

  Future<void> _testUserAuthentication() async {
    setState(() {
      _resultMessage += '\n\nTesting User Authentication...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultMessage += '\nFailed - User is not authenticated';
      });
    } else {
      setState(() {
        _resultMessage += '\nPassed - User ID: ${user.uid}';
      });
    }
  }

  Future<void> _testFirestoreDocument() async {
    setState(() {
      _resultMessage += '\n\nTesting Firestore Document...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultMessage += '\nSkipped - User is not authenticated';
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final fcmToken = userDoc.data()?['fcmToken'];
        setState(() {
          _resultMessage += '\nDocument found'
              '\nFCM Token: ${fcmToken ?? 'Not found'}';
        });
      } else {
        setState(() {
          _resultMessage += '\nDocument not found';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage += '\nError: $e';
      });
    }
  }

  Future<void> _testFCMToken() async {
    setState(() {
      _resultMessage += '\n\nTesting FCM Token...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultMessage += '\nSkipped - User is not authenticated';
      });
      return;
    }

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      setState(() {
        _resultMessage += '\nCurrent FCM Token: $fcmToken';
      });

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String? storedToken = userDoc.get('fcmToken');
        setState(() {
          _resultMessage += '\nStored FCM Token: $storedToken';
        });

        if (fcmToken != storedToken) {
          setState(() {
            _resultMessage += '\nWarning: Tokens do not match';
          });
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': fcmToken}, SetOptions(merge: true));
          setState(() {
            _resultMessage += '\nToken updated in Firestore';
          });
        }
      } else {
        setState(() {
          _resultMessage += '\nError: User document not found in Firestore';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage += '\nError: $e';
      });
    }
  }

  Future<void> _testCloudFunction() async {
    setState(() {
      _resultMessage += '\n\nTesting Cloud Function...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultMessage += '\nSkipped - User is not authenticated';
      });
      return;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('testFunction');

      final result = await callable.call();

      setState(() {
        _resultMessage += '\nSuccess'
            '\nResult: ${result.data}';
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _resultMessage += '\nFailed'
            '\nError: [${e.code}] ${e.message}'
            '\nDetails: ${e.details}';
      });
    } catch (e) {
      setState(() {
        _resultMessage += '\nUnexpected error: $e';
      });
    }
  }

  Future<void> _testSendNotification() async {
    setState(() {
      _resultMessage += '\n\nTesting Send Notification...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultMessage += '\nSkipped - User is not authenticated';
      });
      return;
    }

    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.sendTestNotification(user.uid, 'User');

      setState(() {
        _resultMessage += '\nNotification sent successfully';
      });
    } catch (e) {
      setState(() {
        _resultMessage += '\nError sending notification: $e';
      });
    }
  }
}
