import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to the 'users' collection.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Creates a new user document in Firestore using the user's [uid] as the document ID.
  Future<void> createUserDocument(UserModel user) async {
    // ignore: avoid_print
    print("=== FIRESTORE: createUserDocument called for UID: ${user.uid} ===");
    // ignore: avoid_print
    print("=== FIRESTORE: Data to write: ${user.toMap()} ===");
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
      // ignore: avoid_print
      print("=== FIRESTORE: Document written successfully for UID: ${user.uid} ===");
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print("=== FIRESTORE createUserDocument ERROR ===");
      // ignore: avoid_print
      print("Error: $e");
      // ignore: avoid_print
      print("Type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Stack: $stackTrace");
      // ignore: avoid_print
      print("=== END FIRESTORE createUserDocument ERROR ===");
      throw 'Failed to create user profile: $e';
    }
  }

  /// Retrieves a [UserModel] by [uid]. Returns null if the document doesn't exist.
  Future<UserModel?> getUserDocument(String uid) async {
    try {
      // ignore: avoid_print
      print("=== FIRESTORE: Fetching document for UID: $uid ===");
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      // ignore: avoid_print
      print("=== FIRESTORE: Document exists: ${doc.exists} ===");

      if (!doc.exists || doc.data() == null) {
        // ignore: avoid_print
        print("=== FIRESTORE: No document found for this user ===");
        return null;
      }

      // ignore: avoid_print
      print("=== FIRESTORE: Document data: ${doc.data()} ===");
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      // ignore: avoid_print
      print("=== FIRESTORE ERROR: $e ===");
      // ignore: avoid_print
      print("=== FIRESTORE ERROR TYPE: ${e.runtimeType} ===");
      rethrow;
    }
  }

  /// Updates the verification status of a user document.
  ///
  /// [uid] – the user's document ID.
  /// [status] – one of 'pending', 'verified', or 'rejected'.
  /// [rejectionReason] – optional reason when status is 'rejected'.
  Future<void> updateVerificationStatus(
    String uid,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'verificationStatus': status,
      };

      if (status == 'rejected' && rejectionReason != null) {
        data['rejectionReason'] = rejectionReason;
      } else if (status != 'rejected') {
        // Clear any previous rejection reason when status changes away from rejected
        data['rejectionReason'] = null;
      }

      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      throw 'Failed to update verification status. Please try again.';
    }
  }
}
