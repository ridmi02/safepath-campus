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
    print("=== REGISTRATION STEP 1: Starting registration ===");
    // ignore: avoid_print
    print("Name: $fullName, Email: $email, SLIIT ID: $sliitId");

    _setLoading(true);
    _setError(null);

    try {
      // 1. Create the Firebase Auth account
      // ignore: avoid_print
      print("=== REGISTRATION STEP 2: Creating Auth account ===");
      final User user = await _authService.registerWithEmail(email, password);
      // ignore: avoid_print
      print("=== REGISTRATION STEP 3: Auth account created. UID: ${user.uid} ===");

      // 2. Upload ID card image — optional: if Storage is not enabled, continue anyway
      // ignore: avoid_print
      print("=== REGISTRATION STEP 4: Uploading ID card image ===");
      String imageUrl = '';
      String? uploadWarning;
      try {
        imageUrl = await _storageService.uploadIdCardImage(user.uid, idCardImage);
        // ignore: avoid_print
        print("=== REGISTRATION STEP 5: Image uploaded. URL: $imageUrl ===");
      } catch (uploadError) {
        // ignore: avoid_print
        print("=== REGISTRATION WARNING: Image upload failed ===");
        // ignore: avoid_print
        print("Upload error: $uploadError");
        // ignore: avoid_print
        print("Upload error type: ${uploadError.runtimeType}");
        // ignore: avoid_print
        print("=== Continuing registration without image URL ===");
        imageUrl = '';
        uploadWarning = 'Account created but ID card upload failed. You can re-upload later.';
      }

      // 3. Create user document in Firestore
      // ignore: avoid_print
      print("=== REGISTRATION STEP 6: Creating Firestore document ===");
      // ignore: avoid_print
      print("Creating doc for UID: ${user.uid}");
      final UserModel userModel = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email,
        sliitId: sliitId,
        verificationStatus: 'pending',
        idCardImageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createUserDocument(userModel);
      // ignore: avoid_print
      print("=== REGISTRATION STEP 7: Firestore document created successfully ===");
      _userModel = userModel;

      if (uploadWarning != null) {
        _setError(uploadWarning);
      }

      _setLoading(false);
      return true;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print("=== REGISTRATION ERROR ===");
      // ignore: avoid_print
      print("Error: $e");
      // ignore: avoid_print
      print("Error type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Stack trace: $stackTrace");
      // ignore: avoid_print
      print("=== END REGISTRATION ERROR ===");
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
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
