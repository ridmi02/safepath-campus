import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Simple service responsible for managing user location.
/// Handles permissions, current position, and a location stream.
class LocationService {
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  StreamSubscription<Position>? _positionSubscription;

  LatLng? _currentLocation;

  LatLng? get currentLocation => _currentLocation;

  Stream<LatLng> get locationStream => _locationController.stream;

  /// Initialize the location service:
  /// - ensure services are enabled
  /// - request permissions
  /// - start listening to updates
  Future<void> init() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {
        // ignore failures, caller can handle missing location
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _updateCurrentPosition(pos);
    } catch (e) {
      // Handle errors (e.g., location services disabled mid-request)
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen(_updateCurrentPosition);
  }

  void _updateCurrentPosition(Position position) {
    _currentLocation = LatLng(position.latitude, position.longitude);
    if (!_locationController.isClosed) {
      _locationController.add(_currentLocation!);
    }
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _locationController.close();
  }
}
