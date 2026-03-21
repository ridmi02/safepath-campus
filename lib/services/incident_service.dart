import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:safepath_campus/models/incident.dart';

class IncidentService {
  const IncidentService();

  CollectionReference<Map<String, dynamic>> get _incidentsCollection =>
      FirebaseFirestore.instance.collection('incidents');

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
    try {
      await _incidentsCollection.add({
        'type': incident.type.name,
        'severity': incident.severity.name,
        'lat': incident.location.latitude,
        'lng': incident.location.longitude,
        'timestamp': Timestamp.fromDate(incident.timestamp),
        'description': incident.description,
        'verified': incident.verified,
      });
    } catch (_) {
      // ignore Firestore write failures for now
    }
  }
}

