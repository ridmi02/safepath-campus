import 'package:cloud_firestore/cloud_firestore.dart';

class SosLogModel {
  final String logId;
  final String userId;
  final String triggerMethod; // 'deadman_switch'
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String destination;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final bool contactNotified;

  SosLogModel({
    required this.logId,
    required this.userId,
    this.triggerMethod = 'deadman_switch',
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.destination,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.contactNotified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'userId': userId,
      'triggerMethod': triggerMethod,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'destination': destination,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'contactNotified': contactNotified,
    };
  }

  factory SosLogModel.fromMap(Map<String, dynamic> map) {
    return SosLogModel(
      logId: map['logId'] ?? '',
      userId: map['userId'] ?? '',
      triggerMethod: map['triggerMethod'] ?? 'deadman_switch',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      destination: map['destination'] ?? '',
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyContactPhone: map['emergencyContactPhone'] ?? '',
      contactNotified: map['contactNotified'] ?? false,
    );
  }
}
