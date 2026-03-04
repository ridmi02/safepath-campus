import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all students (exclude admin accounts)
  Stream<List<UserModel>> getAllStudents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList());
  }

  // Get students filtered by verification status
  Stream<List<UserModel>> getStudentsByStatus(String status) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('verificationStatus', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList());
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
