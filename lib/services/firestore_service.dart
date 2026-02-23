import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to the 'users' collection.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Creates a new user document in Firestore using the user's [uid] as the document ID.
  Future<void> createUserDocument(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw 'Failed to create user profile. Please try again.';
    }
  }

  /// Retrieves a [UserModel] by [uid]. Returns null if the document doesn't exist.
  Future<UserModel?> getUserDocument(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _usersCollection.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw 'Failed to retrieve user profile. Please try again.';
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
