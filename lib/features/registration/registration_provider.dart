import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _error;
  UserModel? _userModel;

  // ── Getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  UserModel? get userModel => _userModel;
  User? get currentUser => _authService.getCurrentUser();
  bool get isLoggedIn => currentUser != null;

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Registration ─────────────────────────────────────────────────────────

  /// Full registration flow:
  /// 1. Create Firebase Auth account
  /// 2. Upload ID card image to Storage
  /// 3. Create user document in Firestore
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String sliitId,
    required File idCardImage,
  }) async {
    // ignore: avoid_print
    print("=== REG STEP 1: Starting registration for $email ===");

    _setLoading(true);
    _setError(null);

    // ── Step 2: Create Firebase Auth account (required — stop if fails) ──────
    // ignore: avoid_print
    print("=== REG STEP 2: Creating Auth account for $email ===");
    User? user;
    try {
      user = await _authService.registerWithEmail(email, password);
      // ignore: avoid_print
      print("=== REG STEP 3: Auth SUCCESS. UID: ${user.uid} ===");
    } catch (authError) {
      // ignore: avoid_print
      print("=== REG AUTH ERROR: $authError ===");
      // ignore: avoid_print
      print("=== REG AUTH ERROR TYPE: ${authError.runtimeType} ===");
      _setError(authError.toString());
      _setLoading(false);
      return false;
    }

    // ── Step 4: Upload ID card image (optional — continue if fails) ───────────
    // ignore: avoid_print
    print("=== REG STEP 4: Uploading ID card image ===");
    String imageUrl = '';
    String? uploadWarning;
    try {
      imageUrl = await _storageService.uploadIdCardImage(user.uid, idCardImage);
      // ignore: avoid_print
      print("=== REG STEP 5: Image uploaded. URL: $imageUrl ===");
    } catch (storageError) {
      // ignore: avoid_print
      print("=== REG STORAGE ERROR: $storageError ===");
      // ignore: avoid_print
      print("=== REG STORAGE ERROR TYPE: ${storageError.runtimeType} ===");
      // ignore: avoid_print
      print("=== REG WARNING: Continuing without image ===");
      imageUrl = '';
      uploadWarning = 'Account created but ID card upload failed. You can re-upload later.';
    }

    // ── Step 6: Create Firestore document (required — must run even if image failed)
    // ignore: avoid_print
    print("=== REG STEP 6: Creating Firestore document for UID: ${user.uid} ===");
    final UserModel userModel = UserModel(
      uid: user.uid,
      fullName: fullName,
      email: email,
      sliitId: sliitId,
      verificationStatus: 'pending',
      idCardImageUrl: imageUrl,
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.createUserDocument(userModel);
      // ignore: avoid_print
      print("=== REG STEP 7: Firestore document created SUCCESSFULLY ===");
    } catch (firestoreError) {
      // ignore: avoid_print
      print("=== REG FIRESTORE ERROR: $firestoreError ===");
      // ignore: avoid_print
      print("=== REG FIRESTORE ERROR TYPE: ${firestoreError.runtimeType} ===");
      _setError(firestoreError.toString());
      _setLoading(false);
      return false;
    }

    _userModel = userModel;

    if (uploadWarning != null) {
      _setError(uploadWarning);
    }

    _setLoading(false);
    return true;
  }

  // ── Login ────────────────────────────────────────────────────────────────

  /// Logs in with [email] and [password], then fetches the user profile.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final User user = await _authService.loginWithEmail(email, password);

      // Fetch the user's Firestore profile
      _userModel = await _firestoreService.getUserDocument(user.uid);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ── Forgot Password ─────────────────────────────────────────────────────

  /// Sends a password-reset email to [email].
  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.sendPasswordReset(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  /// Signs out the current user and clears local state.
  Future<void> logout() async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.signOut();
      _userModel = null;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
}
