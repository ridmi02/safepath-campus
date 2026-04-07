import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all students (exclude admin accounts)
  // Sorted client-side to avoid requiring a composite Firestore index
  Stream<List<UserModel>> getAllStudents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return users;
        });
  }

  // Get students filtered by verification status
  // Sorted client-side to avoid requiring a composite Firestore index
  Stream<List<UserModel>> getStudentsByStatus(String status) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('verificationStatus', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return users;
        });
  }

  // Approve a student
  Future<void> approveStudent(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'verificationStatus': 'verified',
      'rejectionReason': '',
    });
  }

  // Reject a student with reason
  Future<void> rejectStudent(String uid, String reason) async {
    await _firestore.collection('users').doc(uid).update({
      'verificationStatus': 'rejected',
      'rejectionReason': reason,
    });
  }
}
