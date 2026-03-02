import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  StreamSubscription<Position>? _locSub;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt user to enable location services
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever; cannot request.
      return;
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
    });

    _locSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10)).listen((p) {
      setState(() {
        _currentLocation = LatLng(p.latitude, p.longitude);
      });
    });
  }

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _setDestination(LatLng point) async {
    setState(() {
      _destination = point;
      _loadingRoute = true;
      _routePoints = [];
    });

    if (_currentLocation == null) {
      setState(() {
        _loadingRoute = false;
      });
      return;
    }

    try {
      final src = '${_currentLocation!.longitude},${_currentLocation!.latitude}';
      final dst = '${_destination!.longitude},${_destination!.latitude}';
      // Use OSRM public demo server with geojson geometry
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$src;$dst?overview=full&geometries=geojson');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body) as Map<String, dynamic>;
        if (jsonRes['routes'] != null && (jsonRes['routes'] as List).isNotEmpty) {
          final geom = jsonRes['routes'][0]['geometry'];
          if (geom != null && geom['coordinates'] != null) {
            final coords = geom['coordinates'] as List;
            final pts = coords
                .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
            setState(() {
              _routePoints = pts;
            });
            // zoom map to fit
            if (pts.isNotEmpty) {
              _mapController.fitBounds(LatLngBounds.fromPoints(pts), options: const FitBoundsOptions(padding: EdgeInsets.all(40)));
            }
          }
        }
      }
    } catch (e) {
      // ignore errors for now
    }

    setState(() {
      _loadingRoute = false;
    });
  }

  void _centerOnUser() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_currentLocation != null) {
      markers.add(Marker(
        point: _currentLocation!,
        width: 48,
        height: 48,
        builder: (ctx) => const Icon(Icons.my_location, color: Colors.blueAccent, size: 32),
      ));
    }
    if (_destination != null) {
      markers.add(Marker(
        point: _destination!,
        width: 48,
        height: 48,
        builder: (ctx) => const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
      ));
    }

    final polylines = <Polyline>[];
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(points: _routePoints, strokeWidth: 6.0, color: Colors.redAccent));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: _currentLocation ?? LatLng(0, 0),
          zoom: 15.0,
          onTap: (tapPos, point) {
            _setDestination(point);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination set')));
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'org.safepath.campus',
          ),
          PolylineLayer(polylines: polylines),
          MarkerLayer(markers: markers),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _centerOnUser,
            mini: true,
            tooltip: 'Center on me',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          if (_destination != null)
            FloatingActionButton(
              onPressed: () {
                if (_routePoints.isNotEmpty) {
                  setState(() {
                    _destination = null;
                    _routePoints = [];
                  });
                }
              },
              mini: true,
              tooltip: 'Clear destination',
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}
