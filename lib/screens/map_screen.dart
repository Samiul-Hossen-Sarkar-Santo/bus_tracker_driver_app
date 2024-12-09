import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:bus_tracker_driver_app/screens/home_screen.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Location _locationService = Location();
  LatLng? _currentLocation;
  GoogleMapController? _mapController;

  bool _isSharingLocation = false;
  late DatabaseReference _locationRef;
  StreamSubscription<LocationData>? _locationSubscription;

  String? getBusId(String selectedRoute) {
    switch (selectedRoute) {
      case "BUP-Uttara":
        print("busId1");
        return "busID1";
      case "BUP-JFP-Kakrail":
        print("busId2");
        return "busID2";
      case "BUP-Maghbazar-Kakrail":
        print("busId3");
        return "busID3";
      case "BUP-Shahbagh":
        print("busId4");
        return "busID4";
      case "BUP-Khamar Bari Mor":
        print("busId5");
        return "busID5";
      case "BUP-Asad Gate":
        print("busId6");
        return "busID6";
      case "BUP-City College":
        print("busId7");
        return "busID7";
      default:
        print("Bus id not found on line 40");
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    String? busId = getBusId(selectedRoute);
    _locationRef =
        FirebaseDatabase.instance.ref().child('Buses/$busId/location');
    _getUserLocation();
  }

  // Fetch the user's current location
  Future<void> _getUserLocation() async {
    try {
      bool _serviceEnabled = await _locationService.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _locationService.requestService();
        if (!_serviceEnabled) return;
      }

      PermissionStatus _permissionGranted =
          await _locationService.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _locationService.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await _locationService.getLocation();
      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation!,
              zoom: 14.0,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error retrieving location: $e");
    }
  }

  // Method to handle location sharing toggle   ------- eita dekhte hbe abr ittu
  void _toggleLocationSharing() {
    setState(() {
      _isSharingLocation = !_isSharingLocation;
    });
    if (_isSharingLocation) {
      _startLocationUpdates(); // Start sharing the location
    } else {
      _showStopSharingDialog(); // Show confirmation dialog before stopping
      _stopLocationUpdates();
      setState(() {
        _isSharingLocation = !_isSharingLocation;
      });
    }
  }

  // Start sending location updates continuously
  void _startLocationUpdates() {
    _locationSubscription =
        _locationService.onLocationChanged.listen((locationData) {
      if (_isSharingLocation) {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _sendLocationToFirebase();
      }
    });
  }

  // Stop sending location updates
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
  }

  // Send current location to Firebase Realtime Database
  void _sendLocationToFirebase() {
    if (_currentLocation != null) {
      _locationRef.update({
        'lat': _currentLocation!.latitude,
        'long': _currentLocation!.longitude,
      });
    }
  }

  // Confirmation dialog for stopping location sharing
  void _showStopSharingDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black, // Dark theme for dialog
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Stop sharing location',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Are you sure you want to stop sharing your location?',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSharingLocation = false;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Yes',
                        style:
                            TextStyle(color: Colors.green[200], fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'No',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up the location subscription when the widget is disposed
    _stopLocationUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Map',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[900],
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white, // Back button color
        ),
      ),
      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 14.0,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
          Positioned(
            bottom: 16, // Adjust this value to move the button up/down
            left: 16, // Adjust left value for horizontal positioning
            right: 16, // Ensure button is centered horizontally
            child: InkWell(
              onTap: null, // Handle tap event
              splashColor: Colors.black.withOpacity(0.8), // Light splash effect
              borderRadius:
                  BorderRadius.circular(20), // Match button's border radius
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 35),
                child: ElevatedButton(
                  onPressed: _toggleLocationSharing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSharingLocation ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    _isSharingLocation ? 'Stop Sharing' : 'Start Sharing',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
