import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationProvider with ChangeNotifier {
  List<String> _locations = [];
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<String> get locations => _locations;
  List<Map<String, dynamic>> get locationSuggestions => _locationSuggestions;
  bool get isLoading => _isLoading;

  LocationProvider() {
    print("LocationProvider initialized");
    fetchLocations();
    // fetchLocationSuggestions();
  }

  Future<void> fetchLocations() async {
    print("Fetching locations from Firestore");
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('locations').get();
      _locations =
          querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      print("Fetched locations: $_locations");
    } catch (e) {
      print('Error loading locations from Firestore: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(String oldLocation, String newLocation) async {
    print("Updating location in Firestore: $oldLocation to $newLocation");
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('locations')
          .where('name', isEqualTo: oldLocation)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'name': newLocation});
      }

      int index = _locations.indexOf(oldLocation);
      if (index != -1) {
        _locations[index] = newLocation;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating location in Firestore: $e');
      throw e;
    }
  }

  Future<String> addLocation(String location) async {
    print("Adding location to Firestore: $location");
    if (!_locations.contains(location)) {
      try {
        DocumentReference docRef =
            await _firestore.collection('locations').add({'name': location});
        _locations.add(location);
        notifyListeners();
        return docRef.id;
      } catch (e) {
        print('Error adding location to Firestore: $e');
        throw e;
      }
    }
    return ''; // Return empty string if location already exists
  }

  Future<void> deleteLocation(String location) async {
    print("Deleting location from Firestore: $location");
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('locations')
          .where('name', isEqualTo: location)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      _locations.remove(location);
      notifyListeners();
    } catch (e) {
      print('Error deleting location from Firestore: $e');
    }
  }
}
