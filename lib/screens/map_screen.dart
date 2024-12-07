import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  Location _location = Location();
  late StreamSubscription<LocationData> _locationSubscription;
  DatabaseReference _dbRef = FirebaseDatabase.instance.ref("drivers/driver1");

  LatLng _currentLatLng =
      const LatLng(23.780573, 90.407805); // Default location

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _startLocationUpdates();
  }

  void _requestLocationPermission() async {
    bool _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) return;
    }

    PermissionStatus _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }
  }

  void _startLocationUpdates() {
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLatLng = LatLng(
            currentLocation.latitude ?? 0.0, currentLocation.longitude ?? 0.0);
        _mapController.animateCamera(CameraUpdate.newLatLng(_currentLatLng));
        _updateLocationInFirebase(_currentLatLng);
      });
    });
  }

  void _updateLocationInFirebase(LatLng latLng) {
    _dbRef.set({
      "latitude": latLng.latitude,
      "longitude": latLng.longitude,
    });
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver App"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLatLng,
          zoom: 15.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
