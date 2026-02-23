import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String sliitId;
  final String verificationStatus; // 'pending', 'verified', 'rejected'
  final String? rejectionReason;
  final String idCardImageUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.sliitId,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    required this.idCardImageUrl,
    required this.createdAt,
  });

  /// Converts the [UserModel] to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'sliitId': sliitId,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'idCardImageUrl': idCardImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a [UserModel] from a Firestore document map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      sliitId: map['sliitId'] as String,
      verificationStatus: map['verificationStatus'] as String? ?? 'pending',
      rejectionReason: map['rejectionReason'] as String?,
      idCardImageUrl: map['idCardImageUrl'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Creates a copy of this [UserModel] with the given fields replaced.
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? sliitId,
    String? verificationStatus,
    String? rejectionReason,
    String? idCardImageUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      sliitId: sliitId ?? this.sliitId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      idCardImageUrl: idCardImageUrl ?? this.idCardImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
