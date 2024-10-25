// listener_manager.dart
import 'dart:async';

class ListenerManager {
  final List<StreamSubscription> _activeListeners = [];

  // Add listener to the list
  void addListener(StreamSubscription subscription) {
    _activeListeners.add(subscription);
  }

  // Cancel all listeners
  Future<void> cancelAllListeners() async {
    for (StreamSubscription listener in _activeListeners) {
      await listener.cancel();
    }
    _activeListeners.clear(); // Clear after cancellation
    print("All Firestore listeners canceled.");
  }
}
