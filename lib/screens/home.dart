import 'dart:async';

import 'package:awesome_notifications/android_foreground_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:bus_tracker_driver_app/data/bus_catalog.dart';
import 'package:bus_tracker_driver_app/services/share_backend_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as perms;

// Legacy global kept so older screens compile if they still import this file.
String selectedRoute = '';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const Duration _maxShareDuration = Duration(hours: 3);
  static const Duration _locationPushInterval = Duration(seconds: 5);

  final Location _locationService = Location();
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('Buses');

  StreamSubscription<DatabaseEvent>? _busesSubscription;
  StreamSubscription<LocationData>? _locationSubscription;

  Timer? _autoStopTimer;
  Timer? _countdownTimer;

  String? _selectedRouteId;
  BusCatalogItem? _selectedBus;
  BusCatalogItem? _activeBus;
  String? _activeSessionId;

  bool _isStartingSharing = false;
  bool _isStoppingSharing = false;
  bool _isSharingLocation = false;
  bool _isPushingLocation = false;

  DateTime? _shareEndsAt;
  DateTime? _lastPushedLocationAt;
  Duration _remainingDuration = _maxShareDuration;
  LatLng? _currentPreviewLocation;
  GoogleMapController? _previewMapController;

  int _activeUserCount = 0;
  Map<String, bool> _busStatusMap = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenBusStatuses();
    _requestNotificationPermission();
  }

  void _requestNotificationPermission() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  void _listenBusStatuses() {
    _busesSubscription = _busesRef.onValue.listen(
      (event) {
        final statusMap = <String, bool>{};
        var activeCount = 0;

        final raw = event.snapshot.value;
        if (raw is Map<Object?, Object?>) {
          for (final entry in raw.entries) {
            final busId = entry.key.toString();
            final active = _readStatus(entry.value);
            statusMap[busId] = active;
            if (active) activeCount++;
          }
        }

        if (!mounted) return;
        setState(() {
          _busStatusMap = statusMap;
          _activeUserCount = activeCount;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to sync bus status: $error';
        });
      },
    );
  }

  bool _readStatus(Object? busNode) {
    if (busNode is Map<Object?, Object?>) {
      final status = busNode['status'];
      if (status is bool) return status;
    }
    return false;
  }

  List<BusCatalogItem> get _busOptions {
    if (_selectedRouteId == null) return const [];
    return busesForRoute(_selectedRouteId!);
  }

  bool _isBusUnavailable(BusCatalogItem bus) {
    final inUse = _busStatusMap[bus.busId] ?? false;
    if (_isSharingLocation && _activeBus?.busId == bus.busId) {
      return false;
    }
    return inUse;
  }

  Future<void> _confirmAndStartSharing() async {
    if (_selectedBus == null) return;
    final bus = _selectedBus!;

    final shouldStart = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Start sharing?'),
            content: Text(
              'Route: ${bus.routeName}\n'
              'Bus: ${bus.busNumber}\n'
              'Driver: ${bus.driverName}\n\n'
              'This bus will be unavailable for others while sharing is active.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldStart) return;
    await _startSharing(bus);
  }

  Future<void> _startSharing(BusCatalogItem bus) async {
    if (_isSharingLocation || _isStartingSharing) return;

    if (!ShareBackendService.isConfigured) {
      setState(() {
        _errorMessage =
            'Backend URL missing. Set --dart-define=SHARING_API_BASE_URL=...';
      });
      return;
    }

    setState(() {
      _isStartingSharing = true;
      _errorMessage = null;
    });

    ShareSessionStartResult? startResult;

    try {
      if (_isBusUnavailable(bus)) {
        throw Exception('This bus is currently unavailable.');
      }

      final canShare = await _ensureLocationPermissions();
      if (!canShare) {
        throw Exception('Location permission is required to start sharing.');
      }

      final firstLocation = await _locationService.getLocation();
      final latitude = firstLocation.latitude;
      final longitude = firstLocation.longitude;
      if (latitude == null || longitude == null || !_isValidCoordinate(latitude, longitude)) {
        throw Exception('Could not read a valid GPS location. Try again.');
      }

      startResult = await ShareBackendService.startSharing(
        bus: bus,
        latitude: latitude,
        longitude: longitude,
      );

      await _locationService.enableBackgroundMode(enable: true);
      await _locationService.changeNotificationOptions(
        channelName: 'location_tracking',
        title: 'Bus location sharing is running',
        onTapBringToFront: true,
        iconName: 'driver_app_icon',
      );
      _startForegroundNotification(bus);

      await _locationSubscription?.cancel();
      _locationSubscription =
          _locationService.onLocationChanged.listen((locationData) {
        unawaited(_handleLocationUpdate(locationData));
      });

      _startAutoStopCountdown(startResult.expiresAt);

      if (!mounted) return;
      setState(() {
        _isSharingLocation = true;
        _activeBus = bus;
        _activeSessionId = startResult!.sessionId;
        _selectedRouteId = bus.routeId;
        _selectedBus = bus;
        _lastPushedLocationAt = DateTime.now();
        _currentPreviewLocation = LatLng(latitude, longitude);
      });

      _showSnackBar('Sharing started for bus ${bus.busNumber}.');
    } catch (e) {
      // If backend lock started but local setup failed, release it.
      if (startResult != null) {
        try {
          await ShareBackendService.stopSharing(
            busId: bus.busId,
            sessionId: startResult.sessionId,
            reason: 'startup_failed',
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isStartingSharing = false;
      });
    }
  }

  Future<void> _handleLocationUpdate(LocationData locationData) async {
    if (!_isSharingLocation || _isPushingLocation) return;
    final bus = _activeBus;
    final sessionId = _activeSessionId;
    if (bus == null || sessionId == null) return;

    final latitude = locationData.latitude;
    final longitude = locationData.longitude;
    if (latitude == null || longitude == null) return;
    if (!_isValidCoordinate(latitude, longitude)) return;

    _updatePreviewLocation(latitude, longitude);

    final now = DateTime.now();
    if (_lastPushedLocationAt != null &&
        now.difference(_lastPushedLocationAt!) < _locationPushInterval) {
      return;
    }

    _isPushingLocation = true;
    try {
      await ShareBackendService.updateLocation(
        busId: bus.busId,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
      );
      _lastPushedLocationAt = now;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('expired') || message.contains('inactive') || message.contains('session')) {
        await _stopSharing(
          autoStopped: true,
          skipBackendStop: true,
          reason: 'expired_session',
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Location update issue: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      _isPushingLocation = false;
    }
  }

  bool _isValidCoordinate(double lat, double long) {
    return lat >= -90 && lat <= 90 && long >= -180 && long <= 180;
  }

  void _updatePreviewLocation(double latitude, double longitude) {
    final nextLocation = LatLng(latitude, longitude);
    final prevLocation = _currentPreviewLocation;
    final didMove = prevLocation == null ||
        (prevLocation.latitude - latitude).abs() > 0.000001 ||
        (prevLocation.longitude - longitude).abs() > 0.000001;

    if (!didMove) return;

    if (mounted) {
      setState(() {
        _currentPreviewLocation = nextLocation;
      });
    } else {
      _currentPreviewLocation = nextLocation;
    }

    final controller = _previewMapController;
    if (controller != null) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: nextLocation, zoom: 16),
          ),
        ),
      );
    }
  }

  Future<bool> _ensureLocationPermissions() async {
    var serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        _showSnackBar('Please enable location service.');
        return false;
      }
    }

    var permissionStatus = await _locationService.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _locationService.requestPermission();
    }
    if (permissionStatus != PermissionStatus.granted) {
      _showSnackBar('Location permission denied.');
      return false;
    }

    if (!await perms.Permission.locationWhenInUse.isGranted) {
      final whenInUseResult = await perms.Permission.locationWhenInUse.request();
      if (!whenInUseResult.isGranted) {
        _showSnackBar('Location permission denied.');
        return false;
      }
    }

    if (!await perms.Permission.locationAlways.isGranted) {
      final alwaysResult = await perms.Permission.locationAlways.request();
      if (!alwaysResult.isGranted) {
        _showBackgroundPermissionDialog();
        return false;
      }
    }

    return true;
  }

  void _startForegroundNotification(BusCatalogItem bus) {
    AndroidForegroundService.startAndroidForegroundService(
      foregroundStartMode: ForegroundStartMode.stick,
      foregroundServiceType: ForegroundServiceType.location,
      content: NotificationContent(
        id: 10,
        channelKey: 'location_tracking',
        title: 'Location sharing active',
        body: 'Bus ${bus.busNumber} is sharing location.',
        category: NotificationCategory.Service,
      ),
    );
  }

  void _startAutoStopCountdown(DateTime expiresAt) {
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();

    _shareEndsAt = expiresAt;
    final delay = expiresAt.difference(DateTime.now());
    _remainingDuration = delay.isNegative ? Duration.zero : delay;

    _autoStopTimer = Timer(
      _remainingDuration,
      () => _stopSharing(autoStopped: true, reason: 'auto_timeout'),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isSharingLocation || _shareEndsAt == null) {
        timer.cancel();
        return;
      }
      final next = _shareEndsAt!.difference(DateTime.now());
      setState(() {
        _remainingDuration = next.isNegative ? Duration.zero : next;
      });
    });
  }

  Future<void> _confirmAndStopSharing() async {
    final shouldStop = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Stop sharing?'),
            content: const Text('Are you sure you want to stop sharing now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldStop) return;
    await _stopSharing(autoStopped: false, reason: 'manual_stop');
  }

  Future<void> _stopSharing({
    required bool autoStopped,
    required String reason,
    bool skipBackendStop = false,
  }) async {
    if (_isStoppingSharing) return;

    setState(() {
      _isStoppingSharing = true;
    });

    final bus = _activeBus;
    final sessionId = _activeSessionId;

    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _autoStopTimer = null;
    _countdownTimer = null;

    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      await _locationService.enableBackgroundMode(enable: false);
      AwesomeNotifications().cancel(10);

      if (!skipBackendStop && bus != null && sessionId != null) {
        await ShareBackendService.stopSharing(
          busId: bus.busId,
          sessionId: sessionId,
          reason: reason,
        );
      }

      if (!mounted) return;
      setState(() {
        _isSharingLocation = false;
        _activeBus = null;
        _activeSessionId = null;
        _shareEndsAt = null;
        _lastPushedLocationAt = null;
        _remainingDuration = _maxShareDuration;
        _currentPreviewLocation = null;
      });

      _showSnackBar(
        autoStopped
            ? 'Sharing stopped automatically after timeout.'
            : 'Sharing stopped.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to stop sharing: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isStoppingSharing = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<bool> _onBackPressed() async {
    if (!_isSharingLocation) return true;
    await _confirmAndStopSharing();
    return false;
  }

  void _showBackgroundPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Background Location Needed'),
          content: const Text(
            'To keep sharing in background, allow "location all the time" in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await perms.openAppSettings();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    final activeBus = _activeBus;
    final sessionId = _activeSessionId;

    _busesSubscription?.cancel();
    _locationSubscription?.cancel();
    _autoStopTimer?.cancel();
    _countdownTimer?.cancel();
    _previewMapController?.dispose();
    _previewMapController = null;

    unawaited(_locationService.enableBackgroundMode(enable: false));
    AwesomeNotifications().cancel(10);

    if (activeBus != null && sessionId != null) {
      unawaited(
        ShareBackendService.stopSharing(
          busId: activeBus.busId,
          sessionId: sessionId,
          reason: 'app_dispose',
        ),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBusy =
        _selectedBus != null ? _isBusUnavailable(_selectedBus!) : false;
    final canStart = _selectedBus != null &&
        !selectedBusy &&
        !_isSharingLocation &&
        !_isStartingSharing &&
        ShareBackendService.isConfigured;

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bus Location Sharing',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green[900],
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active users (live)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$_activeUserCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Busy buses: $_activeUserCount/${busCatalog.length}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!ShareBackendService.isConfigured)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Set --dart-define=SHARING_API_BASE_URL=https://<region>-<project>.cloudfunctions.net',
                    ),
                  ),
                DropdownButtonFormField<String>(
                  value: _selectedRouteId,
                  decoration: InputDecoration(
                    labelText: 'Route',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: routeCatalog
                      .map(
                        (route) => DropdownMenuItem<String>(
                          value: route.routeId,
                          child: Text(route.routeName),
                        ),
                      )
                      .toList(),
                  onChanged: _isSharingLocation
                      ? null
                      : (routeId) {
                          setState(() {
                            _selectedRouteId = routeId;
                            _selectedBus = null;
                            _errorMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 12),
                if (_selectedRouteId != null)
                  DropdownButtonFormField<BusCatalogItem>(
                    value: _selectedBus,
                    decoration: InputDecoration(
                      labelText: 'Bus No - Driver Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _busOptions.map((bus) {
                      final unavailable = _isBusUnavailable(bus);
                      return DropdownMenuItem<BusCatalogItem>(
                        value: bus,
                        enabled: !unavailable || _activeBus?.busId == bus.busId,
                        child: Text(
                          unavailable
                              ? '${bus.dropdownLabel} (Unavailable)'
                              : bus.dropdownLabel,
                        ),
                      );
                    }).toList(),
                    onChanged: _isSharingLocation
                        ? null
                        : (bus) {
                            setState(() {
                              _selectedBus = bus;
                              _errorMessage = null;
                            });
                          },
                  ),
                if (selectedBusy && !_isSharingLocation) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Selected bus is already being shared by another user.',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_selectedBus != null && !_isSharingLocation)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: canStart ? _confirmAndStartSharing : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                      child: _isStartingSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Start Sharing'),
                    ),
                  ),
                if (_isSharingLocation && _activeBus != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sharing Active',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Route: ${_activeBus!.routeName}'),
                          Text('Bus: ${_activeBus!.busNumber}'),
                          Text('Driver: ${_activeBus!.driverName}'),
                          const SizedBox(height: 10),
                          const Text(
                            'Current Location',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: _currentPreviewLocation == null
                                  ? Container(
                                      color: Colors.white,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Waiting for location...',
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      ),
                                    )
                                  : IgnorePointer(
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: _currentPreviewLocation!,
                                          zoom: 16,
                                        ),
                                        myLocationEnabled: true,
                                        myLocationButtonEnabled: false,
                                        zoomControlsEnabled: false,
                                        mapToolbarEnabled: false,
                                        compassEnabled: false,
                                        scrollGesturesEnabled: false,
                                        zoomGesturesEnabled: false,
                                        rotateGesturesEnabled: false,
                                        tiltGesturesEnabled: false,
                                        markers: {
                                          Marker(
                                            markerId:
                                                const MarkerId('current_bus'),
                                            position: _currentPreviewLocation!,
                                          ),
                                        },
                                        onMapCreated: (controller) {
                                          _previewMapController = controller;
                                        },
                                      ),
                                    ),
                            ),
                          ),
                          if (_currentPreviewLocation != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lat: ${_currentPreviewLocation!.latitude.toStringAsFixed(6)}  '
                              'Lng: ${_currentPreviewLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            'Auto stop in: ${_formatDuration(_remainingDuration)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _isStoppingSharing
                                  ? null
                                  : _confirmAndStopSharing,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                              child: _isStoppingSharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Stop Sharing'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
