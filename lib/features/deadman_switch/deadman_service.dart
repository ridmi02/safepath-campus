import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/trip_model.dart';
import '../../models/sos_log_model.dart';

class DeadmanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new trip
  Future<TripModel> createTrip(TripModel trip) async {
    final docRef = _firestore.collection('trips').doc();
    final tripWithId = TripModel(
      tripId: docRef.id,
      userId: trip.userId,
      destination: trip.destination,
      destinationLat: trip.destinationLat,
      destinationLng: trip.destinationLng,
      startTime: trip.startTime,
      expectedArrivalTime: trip.expectedArrivalTime,
      emergencyContactName: trip.emergencyContactName,
      emergencyContactPhone: trip.emergencyContactPhone,
    );
    await docRef.set(tripWithId.toMap());
    print("=== DEADMAN: Trip created with ID: ${docRef.id} ===");
    return tripWithId;
  }

  // Update trip status
  Future<void> updateTripStatus(String tripId, String status) async {
    await _firestore.collection('trips').doc(tripId).update({
      'status': status,
    });
    print("=== DEADMAN: Trip $tripId status updated to $status ===");
  }

  // Update last known location
  Future<void> updateTripLocation(String tripId, double lat, double lng) async {
    await _firestore.collection('trips').doc(tripId).update({
      'lastKnownLat': lat,
      'lastKnownLng': lng,
      'lastLocationUpdate': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Extend trip time
  Future<void> extendTripTime(String tripId, int additionalMinutes) async {
    final doc = await _firestore.collection('trips').doc(tripId).get();
    if (doc.exists) {
      final currentArrival =
          (doc.data()!['expectedArrivalTime'] as Timestamp).toDate();
      final newArrival =
          currentArrival.add(Duration(minutes: additionalMinutes));
      await _firestore.collection('trips').doc(tripId).update({
        'expectedArrivalTime': Timestamp.fromDate(newArrival),
      });
      print("=== DEADMAN: Trip extended by $additionalMinutes minutes ===");
    }
  }

  // Mark alert as sent
  Future<void> markAlertSent(String tripId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'alertSent': true,
      'alertSentAt': Timestamp.fromDate(DateTime.now()),
      'status': 'alert_triggered',
    });
    print("=== DEADMAN: Alert marked as sent for trip $tripId ===");
  }

  // Create SOS log entry
  Future<void> createSosLog(SosLogModel log) async {
    final docRef = _firestore.collection('sos_logs').doc();
    final logWithId = SosLogModel(
      logId: docRef.id,
      userId: log.userId,
      triggerMethod: log.triggerMethod,
      latitude: log.latitude,
      longitude: log.longitude,
      timestamp: log.timestamp,
      destination: log.destination,
      emergencyContactName: log.emergencyContactName,
      emergencyContactPhone: log.emergencyContactPhone,
      contactNotified: log.contactNotified,
    );
    await docRef.set(logWithId.toMap());
    print("=== DEADMAN: SOS log created with ID: ${docRef.id} ===");
  }

  // Get active trip for a user
  Future<TripModel?> getActiveTrip(String userId) async {
    final snapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return TripModel.fromMap(snapshot.docs.first.data());
  }

  // Get trip history for a user
  Stream<List<TripModel>> getTripHistory(String userId) {
    return _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TripModel.fromMap(doc.data())).toList());
  }

  // Get all SOS logs (for admin)
  Stream<List<SosLogModel>> getAllSosLogs() {
    return _firestore
        .collection('sos_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SosLogModel.fromMap(doc.data()))
            .toList());
  }
}
