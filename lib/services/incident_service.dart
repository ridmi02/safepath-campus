import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:safepath_campus/models/incident.dart';

class SafePoint {
  final String id;
  final String name;
  final LatLng location;

  const SafePoint({
    required this.id,
    required this.name,
    required this.location,
  });
}

class RiskProfile {
  final double lowSeverityWeight;
  final double mediumSeverityWeight;
  final double highSeverityWeight;
  final double routeHazardRadiusMeters;
  final double nightRiskFactor;
  final double eveningRiskFactor;
  final double rushHourRiskFactor;

  const RiskProfile({
    required this.lowSeverityWeight,
    required this.mediumSeverityWeight,
    required this.highSeverityWeight,
    required this.routeHazardRadiusMeters,
    required this.nightRiskFactor,
    required this.eveningRiskFactor,
    required this.rushHourRiskFactor,
  });

  static const defaults = RiskProfile(
    lowSeverityWeight: 1.0,
    mediumSeverityWeight: 2.0,
    highSeverityWeight: 3.5,
    routeHazardRadiusMeters: 250,
    nightRiskFactor: 1.6,
    eveningRiskFactor: 1.3,
    rushHourRiskFactor: 1.2,
  );
}

class IncidentService {
  const IncidentService();

  CollectionReference<Map<String, dynamic>> get _incidentsCollection =>
      FirebaseFirestore.instance.collection('incidents');
  CollectionReference<Map<String, dynamic>> get _safePointsCollection =>
      FirebaseFirestore.instance.collection('safe_points');
  DocumentReference<Map<String, dynamic>> get _riskProfileDoc =>
      FirebaseFirestore.instance.collection('campus_config').doc('risk_profile');

  Stream<List<Incident>> watchIncidents() {
    return _incidentsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => _docToIncident(d)).toList();
    });
  }

  Stream<List<SafePoint>> watchSafePoints() {
    return _safePointsCollection.snapshots().map((snap) {
      final points = snap.docs
          .map((d) {
            final data = d.data();
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return SafePoint(
              id: d.id,
              name: (data['name'] as String?)?.trim().isNotEmpty == true
                  ? (data['name'] as String).trim()
                  : 'Safe point',
              location: LatLng(lat, lng),
            );
          })
          .whereType<SafePoint>()
          .toList();
      return points;
    });
  }

  Stream<RiskProfile> watchRiskProfile() {
    return _riskProfileDoc.snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return RiskProfile.defaults;
      return RiskProfile(
        lowSeverityWeight:
            (data['lowSeverityWeight'] as num?)?.toDouble() ??
                RiskProfile.defaults.lowSeverityWeight,
        mediumSeverityWeight:
            (data['mediumSeverityWeight'] as num?)?.toDouble() ??
                RiskProfile.defaults.mediumSeverityWeight,
        highSeverityWeight:
            (data['highSeverityWeight'] as num?)?.toDouble() ??
                RiskProfile.defaults.highSeverityWeight,
        routeHazardRadiusMeters:
            (data['routeHazardRadiusMeters'] as num?)?.toDouble() ??
                RiskProfile.defaults.routeHazardRadiusMeters,
        nightRiskFactor:
            (data['nightRiskFactor'] as num?)?.toDouble() ??
                RiskProfile.defaults.nightRiskFactor,
        eveningRiskFactor:
            (data['eveningRiskFactor'] as num?)?.toDouble() ??
                RiskProfile.defaults.eveningRiskFactor,
        rushHourRiskFactor:
            (data['rushHourRiskFactor'] as num?)?.toDouble() ??
                RiskProfile.defaults.rushHourRiskFactor,
      );
    });
  }

  Incident _docToIncident(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final type = _parseIncidentType(data['type']);
    final severity = _parseIncidentSeverity(data['severity']);
    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final ts = data['timestamp'];
    final timestamp =
        ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

    return Incident(
      id: doc.id,
      type: type,
      severity: severity,
      location: LatLng(lat, lng),
      timestamp: timestamp,
      description: (data['description'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['description'] as String?)?.trim(),
      verified: (data['verified'] as bool?) ?? false,
    );
  }

  IncidentType _parseIncidentType(dynamic raw) {
    final v = raw?.toString();
    for (final t in IncidentType.values) {
      if (t.name == v) return t;
    }
    return IncidentType.other;
  }

  IncidentSeverity _parseIncidentSeverity(dynamic raw) {
    final v = raw?.toString();
    for (final s in IncidentSeverity.values) {
      if (s.name == v) return s;
    }
    return IncidentSeverity.low;
  }

  List<Incident> buildMockIncidents({required LatLng around}) {
    final now = DateTime.now();

    LatLng p(double dLat, double dLng) =>
        LatLng(around.latitude + dLat, around.longitude + dLng);

    return [
      Incident(
        id: 'inc_001',
        type: IncidentType.theft,
        severity: IncidentSeverity.medium,
        location: p(0.0012, 0.0008),
        timestamp: now.subtract(const Duration(hours: 3)),
        description: 'Phone snatching reported near walkway.',
        verified: false,
      ),
      Incident(
        id: 'inc_002',
        type: IncidentType.harassment,
        severity: IncidentSeverity.high,
        location: p(-0.0009, 0.0015),
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        description: 'Reported harassment near parking area.',
        verified: true,
      ),
      Incident(
        id: 'inc_003',
        type: IncidentType.accident,
        severity: IncidentSeverity.low,
        location: p(0.0004, -0.0014),
        timestamp: now.subtract(const Duration(days: 4)),
        description: 'Slip and fall reported during rain.',
        verified: false,
      ),
      Incident(
        id: 'inc_004',
        type: IncidentType.suspiciousActivity,
        severity: IncidentSeverity.medium,
        location: p(0.0018, -0.0002),
        timestamp: now.subtract(const Duration(days: 10)),
        description: 'Suspicious activity reported near entrance.',
        verified: false,
      ),
      Incident(
        id: 'inc_005',
        type: IncidentType.other,
        severity: IncidentSeverity.low,
        location: p(-0.0016, -0.0009),
        timestamp: now.subtract(const Duration(days: 20)),
        description: 'Poor lighting reported on pathway.',
        verified: true,
      ),
    ];
  }

  Future<void> saveIncident(Incident incident) async {
    await _incidentsCollection.add({
      'type': incident.type.name,
      'severity': incident.severity.name,
      'lat': incident.location.latitude,
      'lng': incident.location.longitude,
      'timestamp': Timestamp.fromDate(incident.timestamp),
      'description': incident.description,
      'verified': incident.verified,
    });
  }
}

