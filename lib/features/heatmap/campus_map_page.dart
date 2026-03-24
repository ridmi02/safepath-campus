import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:safepath_campus/models/incident.dart';
import 'package:safepath_campus/services/incident_service.dart';
import 'package:safepath_campus/services/location_service.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final String _openCageApiKey = dotenv.env['OPENCAGE_API_KEY'] ?? '';
  final String _mapboxApiKey = dotenv.env['MAPBOX_API_KEY'] ?? '';
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounceTimer;

  final IncidentService _incidentService = const IncidentService();
  List<Incident> _allIncidents = [];

  Set<IncidentType> _selectedIncidentTypes = IncidentType.values.toSet();
  _IncidentTimeFilter _timeFilter = _IncidentTimeFilter.last7Days;

  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _locationSubscription;

  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  double? _routeDistanceKm;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await _locationService.init();

    setState(() {
      _currentLocation = _locationService.currentLocation;
      if (_currentLocation != null && _allIncidents.isEmpty) {
        _allIncidents =
            _incidentService.buildMockIncidents(around: _currentLocation!);
      }
    });

    _locationSubscription =
        _locationService.locationStream.listen((LatLng location) {
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        if (_allIncidents.isEmpty) {
          _allIncidents = _incidentService.buildMockIncidents(around: location);
        }
      });
    });
  }

  List<Incident> get _filteredIncidents {
    final now = DateTime.now();
    final cutoff = _timeFilter.cutoff(now);

    return _allIncidents.where((inc) {
      if (!_selectedIncidentTypes.contains(inc.type)) return false;
      if (cutoff != null && inc.timestamp.isBefore(cutoff)) return false;
      return true;
    }).toList();
  }

  void _openIncidentFilters() {
    final currentTypes = _selectedIncidentTypes;
    final currentTime = _timeFilter;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        var tempTypes = Set<IncidentType>.from(currentTypes);
        var tempTime = currentTime;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Incident filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: IncidentType.values.map((t) {
                      final selected = tempTypes.contains(t);
                      return FilterChip(
                        label: Text(t.label),
                        selected: selected,
                        onSelected: (v) {
                          setModalState(() {
                            if (v) {
                              tempTypes.add(t);
                            } else {
                              tempTypes.remove(t);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _IncidentTimeFilter.values.map((f) {
                      final selected = tempTime == f;
                      return ChoiceChip(
                        label: Text(f.label),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() {
                            tempTime = f;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempTypes = IncidentType.values.toSet();
                            tempTime = _IncidentTimeFilter.last7Days;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedIncidentTypes = tempTypes.isEmpty
                                ? IncidentType.values.toSet()
                                : tempTypes;
                            _timeFilter = tempTime;
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _incidentColor(Incident incident) {
    switch (incident.severity) {
      case IncidentSeverity.low:
        return Colors.amber;
      case IncidentSeverity.medium:
        return Colors.orange;
      case IncidentSeverity.high:
        return Colors.redAccent;
    }
  }

  void _showIncidentDetails(Incident incident) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                incident.type.label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Severity: ${incident.severity.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('Verified: ${incident.verified ? 'Yes' : 'No'}'),
              const SizedBox(height: 4),
              Text('Time: ${incident.timestamp}'),
              if (incident.description != null) ...[
                const SizedBox(height: 12),
                Text(incident.description!),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openReportIncident(LatLng point) {
    final now = DateTime.now();
    IncidentType selectedType = IncidentType.harassment;
    IncidentSeverity selectedSeverity = IncidentSeverity.medium;
    final descriptionController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Report incident',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return DropdownButton<IncidentType>(
                    isExpanded: true,
                    value: selectedType,
                    items: IncidentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() {
                        selectedType = val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Severity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return Wrap(
                    spacing: 8,
                    children: IncidentSeverity.values.map((s) {
                      final selected = selectedSeverity == s;
                      return ChoiceChip(
                        label: Text(s.name),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() {
                            selectedSeverity = s;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Description (optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Briefly describe what happened',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final incident = Incident(
                        id: 'user_${now.microsecondsSinceEpoch}',
                        type: selectedType,
                        severity: selectedSeverity,
                        location: point,
                        timestamp: now,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        verified: false,
                      );
                      setState(() {
                        _allIncidents = [..._allIncidents, incident];
                      });
                      _incidentService.saveIncident(incident);
                      Navigator.of(ctx).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Incident reported'),
                          ),
                        );
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
      _routeDistanceKm = null;
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

            final routeDistanceKm = _computeRouteDistanceKm(pts);

            setState(() {
              _routePoints = pts;
              _routeDistanceKm = routeDistanceKm;
            });
            if (pts.isNotEmpty) {
              _mapController.fitCamera(
                CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(40)),
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

  double _computeRouteDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    double totalMeters = 0;
    for (var i = 0; i < points.length - 1; i++) {
      totalMeters += distance(points[i], points[i + 1]);
    }
    return totalMeters / 1000.0;
  }

  String _formatMinutes(double minutes) {
    final intMinutes = minutes.round();
    return '$intMinutes min';
  }

  Widget _buildTravelTimeCard() {
    if (_routeDistanceKm == null || _routeDistanceKm == 0) {
      return const SizedBox.shrink();
    }

    // simple averages
    const walkingSpeedKmh = 5.0;
    const cyclingSpeedKmh = 15.0;
    const drivingSpeedKmh = 40.0;

    final distance = _routeDistanceKm!;
    final walkingMinutes = (distance / walkingSpeedKmh) * 60.0;
    final cyclingMinutes = (distance / cyclingSpeedKmh) * 60.0;
    final drivingMinutes = (distance / drivingSpeedKmh) * 60.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha((0.9 * 255).round()),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated travel time (${distance.toStringAsFixed(1)} km)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_walk, size: 20),
                        const SizedBox(width: 4),
                        Text(_formatMinutes(walkingMinutes)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_bike, size: 20),
                        const SizedBox(width: 4),
                        Text(_formatMinutes(cyclingMinutes)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 20),
                        const SizedBox(width: 4),
                        Text(_formatMinutes(drivingMinutes)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        final uri = Uri.https(
          'api.opencagedata.com',
          '/geocode/v1/json',
          {
            'key': _openCageApiKey,
            'q': query,
            'limit': '5',
            'no_annotations': '1',
          },
        );
        final res = await http.get(uri);
        if (res.statusCode == 200 && mounted) {
          final Map<String, dynamic> data =
              jsonDecode(res.body) as Map<String, dynamic>;
          final List results =
              (data['results'] as List? ?? <dynamic>[]);
          setState(() {
            _suggestions = results.cast<Map<String, dynamic>>();
          });
        } else {
          debugPrint('suggestions http error: ${res.statusCode}');
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

    // If we already have suggestions for this query, prefer using the first
    // suggestion directly so hitting "Enter" behaves like choosing the top
    // result in the list (similar to Google Maps).
    if (_suggestions.isNotEmpty) {
      final first = _suggestions.first;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final lat = (geometry?['lat'] as num?)?.toDouble();
      final lon = (geometry?['lng'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        final dest = LatLng(lat, lon);
        await _setDestination(dest);
        _mapController.move(dest, 16);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Destination set from search')),
          );
        }
        setState(() {
          _suggestions = [];
        });
        return;
      }
    }
    setState(() {
      _searching = true;
      _suggestions = [];
    });

    try {
      final uri = Uri.https(
        'api.opencagedata.com',
        '/geocode/v1/json',
        {
          'key': _openCageApiKey,
          'q': query,
          'limit': '1',
          'no_annotations': '1',
        },
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(res.body) as Map<String, dynamic>;
        final List results =
            (data['results'] as List? ?? <dynamic>[]);
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final geometry =
              first['geometry'] as Map<String, dynamic>?;
          final lat = (geometry?['lat'] as num?)?.toDouble();
          final lon = (geometry?['lng'] as num?)?.toDouble();
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
          child: const Icon(
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
          child: const Icon(
            Icons.location_on,
            color: Colors.redAccent,
            size: 40,
          ),
        ),
      );
    }
    for (final incident in _filteredIncidents) {
      markers.add(
        Marker(
          point: incident.location,
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () => _showIncidentDetails(incident),
            child: Container(
              decoration: BoxDecoration(
                color: _incidentColor(incident),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.report,
                size: 16,
                color: Colors.white,
              ),
            ),
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
              initialCenter: _currentLocation ?? const LatLng(0, 0),
              initialZoom: 15.0,
              onTap: (tapPos, point) {
                _setDestination(point);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Destination set')),
                );
              },
              onLongPress: (tapPos, point) {
                _openReportIncident(point);
              },
            ),
            children: [
              if (_mapboxApiKey.isNotEmpty)
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                  additionalOptions: {
                    'accessToken': _mapboxApiKey,
                    'id': 'mapbox.streets',
                  },
                  userAgentPackageName: 'org.safepath.campus',
                )
              else
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
                      IconButton(
                        tooltip: 'Incident filters',
                        icon: const Icon(Icons.tune),
                        onPressed: _openIncidentFilters,
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
                              sugg['formatted'] as String? ?? 'Unknown';
                          final geometry = sugg['geometry']
                              as Map<String, dynamic>?;
                          final lat =
                              (geometry?['lat'] as num?)?.toDouble();
                          final lon =
                              (geometry?['lng'] as num?)?.toDouble();
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
          if (_routeDistanceKm != null && !_loadingRoute)
            _buildTravelTimeCard(),
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
enum _IncidentTimeFilter {
  last24Hours,
  last7Days,
  last30Days,
  all,
}

extension _IncidentTimeFilterX on _IncidentTimeFilter {
  String get label {
    switch (this) {
      case _IncidentTimeFilter.last24Hours:
        return '24h';
      case _IncidentTimeFilter.last7Days:
        return '7d';
      case _IncidentTimeFilter.last30Days:
        return '30d';
      case _IncidentTimeFilter.all:
        return 'All';
    }
  }

  DateTime? cutoff(DateTime now) {
    switch (this) {
      case _IncidentTimeFilter.last24Hours:
        return now.subtract(const Duration(hours: 24));
      case _IncidentTimeFilter.last7Days:
        return now.subtract(const Duration(days: 7));
      case _IncidentTimeFilter.last30Days:
        return now.subtract(const Duration(days: 30));
      case _IncidentTimeFilter.all:
        return null;
    }
  }
}
