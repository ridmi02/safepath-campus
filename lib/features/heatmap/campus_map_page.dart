import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:safepath_campus/services/location_service.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounceTimer;

  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _locationSubscription;

  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await _locationService.init();

    setState(() {
      _currentLocation = _locationService.currentLocation;
    });

    _locationSubscription =
        _locationService.locationStream.listen((LatLng location) {
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
      });
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _setDestination(LatLng point) async {
    setState(() {
      _destination = point;
      _loadingRoute = true;
      _routePoints = [];
    });

    if (_currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiting for current location...'),
          ),
        );
      }
      setState(() {
        _loadingRoute = false;
      });
      return;
    }

    try {
      final src =
          '${_currentLocation!.longitude},${_currentLocation!.latitude}';
      final dst =
          '${_destination!.longitude},${_destination!.latitude}';
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$src;$dst?overview=full&geometries=geojson',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body) as Map<String, dynamic>;
        if (jsonRes['routes'] != null &&
            (jsonRes['routes'] as List).isNotEmpty) {
          final geom = jsonRes['routes'][0]['geometry'];
          if (geom != null && geom['coordinates'] != null) {
            final coords = geom['coordinates'] as List;
            final pts = coords
                .map<LatLng>((c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
            setState(() {
              _routePoints = pts;
            });
            if (pts.isNotEmpty) {
              _mapController.fitBounds(
                LatLngBounds.fromPoints(pts),
                options:
                    const FitBoundsOptions(padding: EdgeInsets.all(40)),
              );
            }
          }
        }
      }
    } catch (_) {
      // ignore errors for now
    }

    setState(() {
      _loadingRoute = false;
    });
  }

  Future<void> _centerOnUser() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16);
    }
  }

  void _fetchSuggestions(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
            .replace(queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
        });
        final res = await http.get(uri, headers: {
          'User-Agent': 'SafePathCampus/1.0 (your_email@example.com)'
        });
        if (res.statusCode == 200 && mounted) {
          final List results = jsonDecode(res.body);
          setState(() {
            _suggestions = results.cast<Map<String, dynamic>>();
          });
        }
      } catch (e) {
        debugPrint('suggestions fetch error: $e');
      }
    });
  }

  Future<void> _searchAddress(String query) async {
    query = query.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _suggestions = [];
    });

    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'SafePathCampus/1.0 (your_email@example.com)'
      });
      if (res.statusCode == 200) {
        final List results = jsonDecode(res.body);
        if (results.isNotEmpty) {
          final first = results.first;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final dest = LatLng(lat, lon);
            _setDestination(dest);
            _mapController.move(dest, 16);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Destination set from search'),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address not found')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search error')),
        );
      }
    } finally {
      setState(() {
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 48,
          height: 48,
          builder: (ctx) => const Icon(
            Icons.my_location,
            color: Colors.blueAccent,
            size: 32,
          ),
        ),
      );
    }
    if (_destination != null) {
      markers.add(
        Marker(
          point: _destination!,
          width: 48,
          height: 48,
          builder: (ctx) => const Icon(
            Icons.location_on,
            color: Colors.redAccent,
            size: 40,
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _routePoints,
          strokeWidth: 6.0,
          color: Colors.redAccent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation ?? LatLng(0, 0),
              zoom: 15.0,
              onTap: (tapPos, point) {
                _setDestination(point);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Destination set')),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'org.safepath.campus',
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search destination',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: _fetchSuggestions,
                          onSubmitted: (val) {
                            _searchAddress(val);
                            _searchController.clear();
                          },
                        ),
                      ),
                      _searching
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                _searchAddress(_searchController.text);
                                _searchController.clear();
                              },
                            ),
                    ],
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Material(
                    elevation: 4,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (ctx, idx) {
                          final sugg = _suggestions[idx];
                          final name =
                              sugg['display_name'] as String? ?? 'Unknown';
                          final lat =
                              double.tryParse(sugg['lat']?.toString() ?? '');
                          final lon =
                              double.tryParse(sugg['lon']?.toString() ?? '');
                          return ListTile(
                            leading:
                                const Icon(Icons.location_on, size: 20),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              if (lat != null && lon != null) {
                                final dest = LatLng(lat, lon);
                                _setDestination(dest);
                                _mapController.move(dest, 16);
                                _searchController.clear();
                                setState(() {
                                  _suggestions = [];
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Destination set'),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_loadingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.3 * 255).round()),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
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

