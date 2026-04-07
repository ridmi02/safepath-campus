import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String tripId;
  final String userId;
  final String destination;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime startTime;
  final DateTime expectedArrivalTime;
  final String status; // 'active', 'completed', 'alert_triggered', 'cancelled'
  final double? lastKnownLat;
  final double? lastKnownLng;
  final DateTime? lastLocationUpdate;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final bool alertSent;
  final DateTime? alertSentAt;

  TripModel({
    required this.tripId,
    required this.userId,
    required this.destination,
    this.destinationLat,
    this.destinationLng,
    required this.startTime,
    required this.expectedArrivalTime,
    this.status = 'active',
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastLocationUpdate,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.alertSent = false,
    this.alertSentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'userId': userId,
      'destination': destination,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'startTime': Timestamp.fromDate(startTime),
      'expectedArrivalTime': Timestamp.fromDate(expectedArrivalTime),
      'status': status,
      'lastKnownLat': lastKnownLat,
      'lastKnownLng': lastKnownLng,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'alertSent': alertSent,
      'alertSentAt':
          alertSentAt != null ? Timestamp.fromDate(alertSentAt!) : null,
    };
  }

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      tripId: map['tripId'] ?? '',
      userId: map['userId'] ?? '',
      destination: map['destination'] ?? '',
      destinationLat: (map['destinationLat'] as num?)?.toDouble(),
      destinationLng: (map['destinationLng'] as num?)?.toDouble(),
      startTime: (map['startTime'] as Timestamp).toDate(),
      expectedArrivalTime: (map['expectedArrivalTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
      lastKnownLat: (map['lastKnownLat'] as num?)?.toDouble(),
      lastKnownLng: (map['lastKnownLng'] as num?)?.toDouble(),
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? (map['lastLocationUpdate'] as Timestamp).toDate()
          : null,
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyContactPhone: map['emergencyContactPhone'] ?? '',
      alertSent: map['alertSent'] ?? false,
      alertSentAt: map['alertSentAt'] != null
          ? (map['alertSentAt'] as Timestamp).toDate()
          : null,
    );
  }

  TripModel copyWith({
    String? status,
    double? lastKnownLat,
    double? lastKnownLng,
    DateTime? lastLocationUpdate,
    bool? alertSent,
    DateTime? alertSentAt,
    DateTime? expectedArrivalTime,
  }) {
    return TripModel(
      tripId: tripId,
      userId: userId,
      destination: destination,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      startTime: startTime,
      expectedArrivalTime: expectedArrivalTime ?? this.expectedArrivalTime,
      status: status ?? this.status,
      lastKnownLat: lastKnownLat ?? this.lastKnownLat,
      lastKnownLng: lastKnownLng ?? this.lastKnownLng,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      alertSent: alertSent ?? this.alertSent,
      alertSentAt: alertSentAt ?? this.alertSentAt,
    );
  }
}
