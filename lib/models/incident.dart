import 'package:latlong2/latlong.dart';

enum IncidentType {
  harassment,
  theft,
  accident,
  suspiciousActivity,
  other,
}

extension IncidentTypeLabel on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.harassment:
        return 'Harassment';
      case IncidentType.theft:
        return 'Theft';
      case IncidentType.accident:
        return 'Accident';
      case IncidentType.suspiciousActivity:
        return 'Suspicious';
      case IncidentType.other:
        return 'Other';
    }
  }
}

enum IncidentSeverity { low, medium, high }

class Incident {
  final String id;
  final IncidentType type;
  final IncidentSeverity severity;
  final LatLng location;
  final DateTime timestamp;
  final String? description;
  final bool verified;

  const Incident({
    required this.id,
    required this.type,
    required this.severity,
    required this.location,
    required this.timestamp,
    this.description,
    this.verified = false,
  });
}

