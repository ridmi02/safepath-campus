import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:safepath_campus/models/incident.dart';
import 'package:safepath_campus/services/incident_service.dart';
import 'package:safepath_campus/services/location_service.dart';

class _RouteChoice {
  const _RouteChoice({
    required this.displayPoints,
    this.baselinePoints,
    required this.displayIncidentCount,
    required this.fastIncidentCount,
    required this.riskScore,
    required this.label,
    required this.showGreenRoute,
    this.messageToUser,
  });

  final List<LatLng> displayPoints;
  final List<LatLng>? baselinePoints;
  final int displayIncidentCount;
  final int fastIncidentCount;
  final double riskScore;
  final String label;
  final bool showGreenRoute;
  final String? messageToUser;
}

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  static const String _nominatimHost = 'nominatim.openstreetmap.org';
  static const String _slViewbox = '79.521,9.836,81.879,5.918';

  /// Before GPS is ready, show Sri Lanka instead of (0,0) so tiles are meaningful.
  static const LatLng _fallbackMapCenter = LatLng(7.8731, 80.7718);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounceTimer;
  Timer? _mapThemeTimer;

  final IncidentService _incidentService = const IncidentService();
  List<Incident> _allIncidents = [];
  StreamSubscription<List<Incident>>? _incidentsSubscription;
  StreamSubscription<List<SafePoint>>? _safePointsSubscription;
  StreamSubscription<RiskProfile>? _riskProfileSubscription;
  bool _receivedIncidentsSnapshot = false;
  List<SafePoint> _safePoints = const [];
  RiskProfile _riskProfile = RiskProfile.defaults;

  Set<IncidentType> _selectedIncidentTypes = IncidentType.values.toSet();
  _IncidentTimeFilter _timeFilter = _IncidentTimeFilter.last7Days;

  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _locationSubscription;

  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  /// When Safe route is on, OSRM primary (fastest) path for comparison (grey underlay).
  List<LatLng> _fastRoutePoints = [];
  bool _loadingRoute = false;
  double? _routeDistanceKm;
  double? _routeRiskScore;
  String _routeModeLabel = 'Fastest';
  int? _incidentsOnDisplayedRoute;
  int? _incidentsOnFastRoute;
  bool _showGreenRouteLine = false;
  bool _useNightTiles = false;
  bool _safeRouteMode = false;
  bool _showHeatmap = false;
  bool _showCrowdOverlay = false;
  bool _accessibilityRouting = false;
  bool _showTimeAwareRisk = true;

  static const List<SafePoint> _fallbackSafePoints = [
    SafePoint(
      id: 'sp_1',
      name: 'Police Station - Campus Gate',
      location: LatLng(6.9271, 79.8612),
    ),
    SafePoint(
      id: 'sp_2',
      name: 'Police Post - Main Road',
      location: LatLng(6.9262, 79.8624),
    ),
    SafePoint(
      id: 'sp_3',
      name: 'Main Gate Post',
      location: LatLng(6.9280, 79.8599),
    ),
  ];

  /// True after we moved the camera to the user once (matches FAB behavior).
  bool _hasAutoCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    _initMapThemeCycle();
    _initIncidents();
    _initSafePoints();
    _initRiskProfile();
    _initLocation();
  }

  void _initIncidents() {
    _incidentsSubscription = _incidentService.watchIncidents().listen(
      (incidents) {
        if (!mounted) return;
        setState(() {
          _receivedIncidentsSnapshot = true;
          _allIncidents = incidents;
        });
      },
      onError: (_) {
        // Keep existing incidents (e.g., mock fallback) if Firestore fails.
        _receivedIncidentsSnapshot = true;
      },
    );
  }

  void _initSafePoints() {
    _safePoints = _fallbackSafePoints;
    _safePointsSubscription = _incidentService.watchSafePoints().listen(
      (points) {
        if (!mounted || points.isEmpty) return;
        setState(() {
          _safePoints = points;
        });
      },
      onError: (_) {
        // Keep fallback safe points if Firestore read fails.
      },
    );
  }

  void _initRiskProfile() {
    _riskProfileSubscription = _incidentService.watchRiskProfile().listen(
      (profile) {
        if (!mounted) return;
        setState(() {
          _riskProfile = profile;
        });
      },
      onError: (_) {
        // Use defaults when config can't be loaded.
      },
    );
  }

  void _initMapThemeCycle() {
    _useNightTiles = _isNightNow();
    _mapThemeTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      final nightNow = _isNightNow();
      if (nightNow != _useNightTiles) {
        setState(() {
          _useNightTiles = nightNow;
        });
      }
    });
  }

  bool _isNightNow() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  void _scheduleAutoCenterOnUser(LatLng location) {
    if (_hasAutoCenteredOnUser) return;
    _hasAutoCenteredOnUser = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(location, 16);
    });
  }

  Future<void> _initLocation() async {
    await _locationService.init();

    setState(() {
      _currentLocation = _locationService.currentLocation;
      if (!_receivedIncidentsSnapshot &&
          _currentLocation != null &&
          _allIncidents.isEmpty) {
        _allIncidents =
            _incidentService.buildMockIncidents(around: _currentLocation!);
      }
    });

    if (_currentLocation != null) {
      _scheduleAutoCenterOnUser(_currentLocation!);
    }

    _locationSubscription =
        _locationService.locationStream.listen((LatLng location) {
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        if (!_receivedIncidentsSnapshot && _allIncidents.isEmpty) {
          _allIncidents = _incidentService.buildMockIncidents(around: location);
        }
      });
      if (!_hasAutoCenteredOnUser) {
        _scheduleAutoCenterOnUser(location);
      }
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
                'Description (required)',
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
                    onPressed: () async {
                      final description = descriptionController.text.trim();
                      final hasAlphaNumeric =
                          RegExp(r'[A-Za-z0-9]').hasMatch(description);

                      if (description.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Description is required.'),
                            ),
                          );
                        }
                        return;
                      }

                      if (description.length < 10) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Description must be at least 10 characters.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      if (!hasAlphaNumeric) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Description cannot contain only symbols or spaces.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final incident = Incident(
                        id: 'user_${now.microsecondsSinceEpoch}',
                        type: selectedType,
                        severity: selectedSeverity,
                        location: point,
                        timestamp: now,
                        description: description,
                        verified: false,
                      );
                      try {
                        await _incidentService.saveIncident(incident);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Incident reported')),
                          );
                        }
                      } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                'Could not save incident (missing permissions).',
                              ),
                          ),
                        );
                        }
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
    _riskProfileSubscription?.cancel();
    _safePointsSubscription?.cancel();
    _incidentsSubscription?.cancel();
    _locationSubscription?.cancel();
    _debounceTimer?.cancel();
    _mapThemeTimer?.cancel();
    _searchController.dispose();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _setDestination(LatLng point) async {
    setState(() {
      _destination = point;
      _loadingRoute = true;
      _routePoints = [];
      _fastRoutePoints = [];
      _routeDistanceKm = null;
      _routeRiskScore = null;
      _incidentsOnDisplayedRoute = null;
      _incidentsOnFastRoute = null;
      _showGreenRouteLine = false;
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
      final profile = _accessibilityRouting ? 'foot' : 'driving';
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/$src;$dst'
        '?overview=full&geometries=geojson&alternatives=true',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body) as Map<String, dynamic>;
        if (jsonRes['routes'] != null &&
            (jsonRes['routes'] as List).isNotEmpty) {
          final routes = (jsonRes['routes'] as List).cast<Map<String, dynamic>>();
          final fastFromServer = _decodeRouteGeometry(routes.first);
          _RouteChoice? choice = _pickRouteChoice(routes);

          if (_safeRouteMode && choice != null) {
            final baseline =
                choice.baselinePoints?.isNotEmpty == true
                    ? choice.baselinePoints!
                    : fastFromServer;
            final sameAsFast =
                baseline.isNotEmpty &&
                !_routesGeometricallyDifferent(baseline, choice.displayPoints);
            if (sameAsFast) {
              final forced = await _buildForcedSafeDetourChoice(
                profile: profile,
                fastPts: baseline,
              );
              if (forced != null) {
                choice = forced;
              }
            }
          }

          if (choice != null) {
            final selectedChoice = choice;
            final routeDistanceKm = _computeRouteDistanceKm(selectedChoice.displayPoints);

            setState(() {
              _routePoints = selectedChoice.displayPoints;
              _fastRoutePoints = selectedChoice.baselinePoints ?? [];
              _routeDistanceKm = routeDistanceKm;
              _routeRiskScore = selectedChoice.riskScore;
              _routeModeLabel = selectedChoice.label;
              _incidentsOnDisplayedRoute = selectedChoice.displayIncidentCount;
              _incidentsOnFastRoute = selectedChoice.fastIncidentCount;
              _showGreenRouteLine = selectedChoice.showGreenRoute;
            });
            if (selectedChoice.messageToUser != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(selectedChoice.messageToUser!)),
              );
            }
            final boundsPoints = <LatLng>[
              ...selectedChoice.displayPoints,
              if (selectedChoice.baselinePoints != null)
                ...selectedChoice.baselinePoints!,
            ];
            if (boundsPoints.isNotEmpty) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(boundsPoints),
                  padding: const EdgeInsets.all(40),
                ),
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

  Future<List<LatLng>> _fetchOsrmRoutePoints({
    required LatLng from,
    required LatLng to,
    required String profile,
  }) async {
    final src = '${from.longitude},${from.latitude}';
    final dst = '${to.longitude},${to.latitude}';
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/$src;$dst'
      '?overview=full&geometries=geojson&alternatives=false',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final jsonRes = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = jsonRes['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return [];
    return _decodeRouteGeometry(routes.first as Map<String, dynamic>);
  }

  Future<_RouteChoice?> _buildForcedSafeDetourChoice({
    required String profile,
    required List<LatLng> fastPts,
  }) async {
    if (_currentLocation == null || _destination == null || _safePoints.isEmpty) {
      return null;
    }

    const distance = Distance();
    final candidates = [..._safePoints]
      ..sort(
        (a, b) => distance(_currentLocation!, a.location)
            .compareTo(distance(_currentLocation!, b.location)),
      );

    for (final safePoint in candidates) {
      // Skip if the safe point is effectively the same destination.
      if (distance(_destination!, safePoint.location) < 60) continue;

      final leg1 = await _fetchOsrmRoutePoints(
        from: _currentLocation!,
        to: safePoint.location,
        profile: profile,
      );
      final leg2 = await _fetchOsrmRoutePoints(
        from: safePoint.location,
        to: _destination!,
        profile: profile,
      );
      if (leg1.length < 2 || leg2.length < 2) continue;

      final combined = <LatLng>[...leg1, ...leg2.skip(1)];
      if (!_routesGeometricallyDifferent(fastPts, combined)) continue;

      final inc = _countDistinctIncidentsNearRoute(combined);
      final fastInc = _countDistinctIncidentsNearRoute(fastPts);
      final risk = _estimateRouteRiskScore(combined);

      return _RouteChoice(
        displayPoints: combined,
        baselinePoints: fastPts,
        displayIncidentCount: inc,
        fastIncidentCount: fastInc,
        riskScore: risk,
        label: 'Safer route',
        showGreenRoute: true,
        messageToUser: 'Safe route adjusted via nearest safe point.',
      );
    }

    return null;
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

  List<LatLng> _decodeRouteGeometry(Map<String, dynamic> route) {
    final geom = route['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List?;
    if (coords == null || coords.isEmpty) return [];
    return coords
        .map<LatLng>((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();
  }

  int _countDistinctIncidentsNearRoute(List<LatLng> points) {
    if (points.isEmpty) return 0;
    final hazardRadius = _riskProfile.routeHazardRadiusMeters;
    const distance = Distance();
    final nearIds = <String>{};
    for (final incident in _allIncidents) {
      for (final p in points) {
        if (distance(p, incident.location) <= hazardRadius) {
          nearIds.add(incident.id);
          break;
        }
      }
    }
    return nearIds.length;
  }

  double _polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += distance(points[i], points[i + 1]);
    }
    return total;
  }

  List<LatLng> _samplePolyline(List<LatLng> points, int maxSamples) {
    if (points.isEmpty) return [];
    if (points.length <= maxSamples) return points;
    final step = (points.length / maxSamples).ceil();
    final out = <LatLng>[];
    for (var i = 0; i < points.length; i += step) {
      out.add(points[i]);
    }
    if (out.last != points.last) {
      out.add(points.last);
    }
    return out;
  }

  bool _routesGeometricallyDifferent(List<LatLng> fast, List<LatLng> other) {
    if (fast.length < 2 || other.length < 2) return false;
    final lenA = _polylineLengthMeters(fast);
    final lenB = _polylineLengthMeters(other);
    final maxL = math.max(lenA, lenB);
    if (maxL > 0 && (lenA - lenB).abs() / maxL > 0.02) {
      return true;
    }
    const distance = Distance();
    final sa = _samplePolyline(fast, 18);
    final sb = _samplePolyline(other, 18);
    var sum = 0.0;
    for (final p in sa) {
      var minD = double.infinity;
      for (final q in sb) {
        final d = distance(p, q);
        if (d < minD) minD = d;
      }
      sum += minD;
    }
    return (sum / sa.length) > 35;
  }

  _RouteChoice? _pickRouteChoice(List<Map<String, dynamic>> routes) {
    if (routes.isEmpty) return null;
    final decoded = <List<LatLng>>[];
    for (final r in routes) {
      decoded.add(_decodeRouteGeometry(r));
    }
    if (decoded.isEmpty || decoded.first.length < 2) return null;

    final fastPts = decoded.first;
    final fastInc = _countDistinctIncidentsNearRoute(fastPts);
    final fastRisk = _estimateRouteRiskScore(fastPts);

    if (!_safeRouteMode) {
      if (!_accessibilityRouting) {
        return _RouteChoice(
          displayPoints: fastPts,
          baselinePoints: null,
          displayIncidentCount: fastInc,
          fastIncidentCount: fastInc,
          riskScore: fastRisk,
          label: 'Fastest',
          showGreenRoute: false,
        );
      }
      var bestIdx = 0;
      var bestScore = double.infinity;
      for (var i = 0; i < decoded.length; i++) {
        final pts = decoded[i];
        if (pts.length < 2) continue;
        final routeRisk = _estimateRouteRiskScore(pts);
        final routeDistance = _computeRouteDistanceKm(pts);
        final score = routeRisk + routeDistance * 0.8;
        if (score < bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      final pts = decoded[bestIdx];
      final inc = _countDistinctIncidentsNearRoute(pts);
      final risk = _estimateRouteRiskScore(pts);
      return _RouteChoice(
        displayPoints: pts,
        baselinePoints: null,
        displayIncidentCount: inc,
        fastIncidentCount: inc,
        riskScore: risk,
        label: 'Accessible',
        showGreenRoute: false,
      );
    }

    if (decoded.length < 2) {
      return _RouteChoice(
        displayPoints: fastPts,
        baselinePoints: fastPts,
        displayIncidentCount: fastInc,
        fastIncidentCount: fastInc,
        riskScore: fastRisk,
        label: 'Fastest',
        showGreenRoute: false,
        messageToUser:
            'Safe route needs alternatives: server returned only one path.',
      );
    }

    final candidates = <({List<LatLng> pts, int inc, double risk})>[];
    for (var i = 1; i < decoded.length; i++) {
      final pts = decoded[i];
      if (pts.length < 2) continue;
      candidates.add((
        pts: pts,
        inc: _countDistinctIncidentsNearRoute(pts),
        risk: _estimateRouteRiskScore(pts),
      ));
    }

    if (candidates.isEmpty) {
      return _RouteChoice(
        displayPoints: fastPts,
        baselinePoints: fastPts,
        displayIncidentCount: fastInc,
        fastIncidentCount: fastInc,
        riskScore: fastRisk,
        label: 'Fastest',
        showGreenRoute: false,
        messageToUser: 'No alternative routes available.',
      );
    }

    final lowerInc = candidates.where((c) => c.inc < fastInc).toList()
      ..sort((a, b) {
        final cmp = a.inc.compareTo(b.inc);
        if (cmp != 0) return cmp;
        return a.risk.compareTo(b.risk);
      });

    if (lowerInc.isNotEmpty) {
      final geometric = lowerInc
          .where((c) => _routesGeometricallyDifferent(fastPts, c.pts))
          .toList();
      final pick =
          geometric.isNotEmpty ? geometric.first : lowerInc.first;
      return _RouteChoice(
        displayPoints: pick.pts,
        baselinePoints: fastPts,
        displayIncidentCount: pick.inc,
        fastIncidentCount: fastInc,
        riskScore: pick.risk,
        label: 'Safer route',
        showGreenRoute: true,
      );
    }

    final lowerRisk = candidates
        .where(
          (c) =>
              c.risk < fastRisk &&
              _routesGeometricallyDifferent(fastPts, c.pts),
        )
        .toList()
      ..sort((a, b) => a.risk.compareTo(b.risk));

    if (lowerRisk.isNotEmpty) {
      final pick = lowerRisk.first;
      return _RouteChoice(
        displayPoints: pick.pts,
        baselinePoints: fastPts,
        displayIncidentCount: pick.inc,
        fastIncidentCount: fastInc,
        riskScore: pick.risk,
        label: 'Safer route',
        showGreenRoute: true,
        messageToUser: pick.inc > fastInc
            ? 'Fewer incidents not available; showing lower-risk alternative.'
            : null,
      );
    }

    return _RouteChoice(
      displayPoints: fastPts,
      baselinePoints: fastPts,
      displayIncidentCount: fastInc,
      fastIncidentCount: fastInc,
      riskScore: fastRisk,
      label: 'Fastest',
      showGreenRoute: false,
      messageToUser:
          'No alternative with fewer incidents nearby. Showing fastest route.',
    );
  }

  double _estimateRouteRiskScore(List<LatLng> points, {DateTime? at}) {
    if (points.isEmpty || _allIncidents.isEmpty) return 0;
    final hourFactor = _hourRiskFactor((at ?? DateTime.now()).hour);
    final hazardRadius = _riskProfile.routeHazardRadiusMeters;
    const distance = Distance();
    double score = 0;
    for (final p in points) {
      for (final incident in _allIncidents) {
        final meters = distance(p, incident.location);
        if (meters > hazardRadius) continue;
        final severityWeight = switch (incident.severity) {
          IncidentSeverity.low => _riskProfile.lowSeverityWeight,
          IncidentSeverity.medium => _riskProfile.mediumSeverityWeight,
          IncidentSeverity.high => _riskProfile.highSeverityWeight,
        };
        final decay = (hazardRadius - meters) / hazardRadius;
        score += severityWeight * decay;
      }
    }
    return (score / points.length) * hourFactor;
  }

  double _hourRiskFactor(int hour) {
    if (hour >= 21 || hour < 5) return _riskProfile.nightRiskFactor;
    if (hour >= 18) return _riskProfile.eveningRiskFactor;
    if (hour >= 7 && hour <= 9) return _riskProfile.rushHourRiskFactor;
    return 1.0;
  }

  bool _isPolicePoint(SafePoint point) {
    final name = point.name.toLowerCase();
    return name.contains('police') || name.contains('station');
  }

  Future<void> _routeToNearestSafePoint() async {
    if (_currentLocation == null) return;

    final policePoints = _safePoints.where(_isPolicePoint).toList();
    if (policePoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No police stations available on the map.'),
          ),
        );
      }
      return;
    }

    const distance = Distance();
    LatLng? nearest;
    double? nearestMeters;
    for (final p in policePoints) {
      final m = distance(_currentLocation!, p.location);
      if (nearestMeters == null || m < nearestMeters) {
        nearestMeters = m;
        nearest = p.location;
      }
    }
    if (nearest != null) {
      await _setDestination(nearest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS route set to nearest police station'),
          ),
        );
      }
    }
  }

  List<CircleMarker> _buildHeatmapCircles() {
    return _filteredIncidents.map((incident) {
      final baseColor = _incidentColor(incident);
      final radius = switch (incident.severity) {
        IncidentSeverity.low => 35.0,
        IncidentSeverity.medium => 55.0,
        IncidentSeverity.high => 75.0,
      };
      return CircleMarker(
        point: incident.location,
        radius: radius,
        useRadiusInMeter: true,
        color: baseColor.withValues(alpha: 0.2),
        borderColor: baseColor.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  List<CircleMarker> _buildCrowdCircles() {
    final now = DateTime.now();
    return _filteredIncidents.map((incident) {
      final ageHours = now.difference(incident.timestamp).inHours.clamp(0, 240);
      final freshness = 1 - (ageHours / 240.0);
      final crowd = (freshness * _hourRiskFactor(now.hour)).clamp(0.2, 1.8);
      final color = Color.lerp(Colors.green, Colors.red, crowd / 2)!;
      return CircleMarker(
        point: incident.location,
        radius: 20 + (crowd * 30),
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.18),
        borderColor: color.withValues(alpha: 0.45),
        borderStrokeWidth: 1,
      );
    }).toList();
  }

  /// Formats a duration given as total minutes (may be fractional).
  /// Examples: `45 min`, `1h 12m`, `2h 0m`.
  String _formatDurationFromMinutes(double totalMinutes) {
    if (totalMinutes.isNaN || totalMinutes.isInfinite || totalMinutes < 0) {
      return '—';
    }
    final rounded = totalMinutes.round();
    final h = rounded ~/ 60;
    final m = rounded % 60;
    if (h == 0) {
      return '$m min';
    }
    if (m == 0) {
      return '${h}h';
    }
    return '${h}h ${m}m';
  }

  Widget _buildTimeAwareRiskMaterial() {
    final now = DateTime.now();
    double riskForHour(int h) {
      final reference = DateTime(now.year, now.month, now.day, h);
      return _estimateRouteRiskScore(
        _routePoints.isNotEmpty ? _routePoints : [_currentLocation ?? _fallbackMapCenter],
        at: reference,
      );
    }

    String level(double s) {
      if (s >= 3.0) return 'High';
      if (s >= 1.5) return 'Medium';
      return 'Low';
    }

    final current = riskForHour(now.hour);
    final next = riskForHour((now.hour + 2) % 24);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          'Risk now: ${level(current)}  •  +2h: ${level(next)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTravelTimeMaterial() {
    if (_routeDistanceKm == null || _routeDistanceKm == 0) {
      return const SizedBox.shrink();
    }

    const walkingSpeedKmh = 5.0;
    const cyclingSpeedKmh = 15.0;
    const drivingSpeedKmh = 40.0;

    final distance = _routeDistanceKm!;
    final walkingMinutes = (distance / walkingSpeedKmh) * 60.0;
    final cyclingMinutes = (distance / cyclingSpeedKmh) * 60.0;
    final drivingMinutes = (distance / drivingSpeedKmh) * 60.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final routeHeader = StringBuffer(
      '$_routeModeLabel route (${distance.toStringAsFixed(1)} km)',
    );
    if (_routeRiskScore != null) {
      routeHeader.write(' • risk ${_routeRiskScore!.toStringAsFixed(1)}');
    }
    if (_safeRouteMode &&
        _incidentsOnDisplayedRoute != null &&
        _incidentsOnFastRoute != null &&
        _fastRoutePoints.isNotEmpty) {
      routeHeader.write(
        ' • incidents near path: $_incidentsOnDisplayedRoute vs '
        '$_incidentsOnFastRoute on fastest',
      );
    }

    return Material(
      elevation: 5,
          borderRadius: BorderRadius.circular(12),
      color: colorScheme.surface.withValues(alpha: 0.96),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
              routeHeader.toString(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                Expanded(
                  child: _TravelModeTime(
                    icon: Icons.directions_walk,
                    label: _formatDurationFromMinutes(walkingMinutes),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TravelModeTime(
                    icon: Icons.directions_bike,
                    label: _formatDurationFromMinutes(cyclingMinutes),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _TravelModeTime(
                    icon: Icons.directions_car,
                    label: _formatDurationFromMinutes(drivingMinutes),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildBottomMapOverlays() {
    final showRisk = _showTimeAwareRisk && !_loadingRoute;
    final showTravel =
        _routeDistanceKm != null && _routeDistanceKm! > 0 && !_loadingRoute;
    if (!showRisk && !showTravel) {
      return const SizedBox.shrink();
    }

    // Align bottom edge with the FAB column (same baseline as Scaffold FABs).
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottom = bottomInset + 16;

    return Positioned(
      left: 16,
      right: 72,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRisk) _buildTimeAwareRiskMaterial(),
          if (showRisk && showTravel) const SizedBox(height: 8),
          if (showTravel) _buildTravelTimeMaterial(),
        ],
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
          _nominatimHost,
          '/search',
          {
            'q': query,
            'format': 'jsonv2',
            'limit': '5',
            'countrycodes': 'lk',
            'addressdetails': '1',
            'bounded': '1',
            'viewbox': _slViewbox,
          },
        );
        final res = await http.get(
          uri,
          headers: const {
            'User-Agent': 'SafePathCampus/1.0 (safepath-campus-app)',
            'Accept-Language': 'en',
          },
        );
        if (res.statusCode == 200 && mounted) {
          final List results = jsonDecode(res.body) as List<dynamic>;
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
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
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
        _nominatimHost,
        '/search',
        {
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
          'countrycodes': 'lk',
          'addressdetails': '1',
          'bounded': '1',
          'viewbox': _slViewbox,
        },
      );
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'SafePathCampus/1.0 (safepath-campus-app)',
          'Accept-Language': 'en',
        },
      );
      if (res.statusCode == 200) {
        final List results = jsonDecode(res.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
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
    for (final safePoint in _safePoints) {
      markers.add(
        Marker(
          point: safePoint.location,
          width: 160,
          height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    safePoint.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    if (_safeRouteMode && _fastRoutePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _fastRoutePoints,
          strokeWidth: 4.0,
          color: Colors.grey.shade600,
          pattern: StrokePattern.dashed(segments: const [12.0, 8.0]),
        ),
      );
    }
    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _routePoints,
          strokeWidth: 6.0,
          color: _showGreenRouteLine ? Colors.green.shade700 : Colors.redAccent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _fallbackMapCenter,
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
                TileLayer(
                  // Use a clean light basemap so labels and streets stay readable.
                  urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'org.safepath.campus',
                  retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
                  // Keep nearby tiles in memory while panning for smoother UX.
                  keepBuffer: 5,
                  tileBuilder: (context, tileWidget, tile) => tileWidget,
                ),
              if (_showHeatmap)
                CircleLayer(circles: _buildHeatmapCircles()),
              if (_showCrowdOverlay)
                CircleLayer(circles: _buildCrowdCircles()),
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
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search destination',
                            hintStyle: TextStyle(color: Colors.black54),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
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
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Safe route'),
                        selected: _safeRouteMode,
                        onSelected: (v) async {
                          setState(() => _safeRouteMode = v);
                          final dest = _destination;
                          if (dest != null && _currentLocation != null) {
                            await _setDestination(dest);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Heatmap'),
                        selected: _showHeatmap,
                        onSelected: (v) => setState(() => _showHeatmap = v),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Crowd overlay'),
                        selected: _showCrowdOverlay,
                        onSelected: (v) => setState(() => _showCrowdOverlay = v),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Accessible'),
                        selected: _accessibilityRouting,
                        onSelected: (v) async {
                          setState(() => _accessibilityRouting = v);
                          final dest = _destination;
                          if (dest != null && _currentLocation != null) {
                            await _setDestination(dest);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Time risk'),
                        selected: _showTimeAwareRisk,
                        onSelected: (v) => setState(() => _showTimeAwareRisk = v),
                      ),
                    ],
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Material(
                    elevation: 4,
                    color: Colors.white,
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
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
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
                color: Colors.white.withAlpha((0.55 * 255).round()),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          _buildBottomMapOverlays(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _routeToNearestSafePoint,
            mini: true,
            tooltip: 'SOS route to nearest police station',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.emergency),
          ),
          const SizedBox(height: 8),
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
                    _fastRoutePoints = [];
                    _routeDistanceKm = null;
                    _routeRiskScore = null;
                    _incidentsOnDisplayedRoute = null;
                    _incidentsOnFastRoute = null;
                    _showGreenRouteLine = false;
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

class _TravelModeTime extends StatelessWidget {
  const _TravelModeTime({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
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
