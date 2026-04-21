import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the currently signed-in [User], or null.
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Registers a new user with [email] and [password].
  /// Returns the [User] on success, or throws an error message string.
  Future<User> registerWithEmail(String email, String password) async {
    // ignore: avoid_print
    print("=== AUTH: registerWithEmail called for: $email ===");
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        // ignore: avoid_print
        print("=== AUTH: createUserWithEmailAndPassword returned null user ===");
        throw 'Registration failed. Please try again.';
      }
      // ignore: avoid_print
      print("=== AUTH: Auth account created. UID: ${credential.user!.uid} ===");
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print("=== AUTH REGISTRATION FirebaseAuthException ===");
      // ignore: avoid_print
      print("Code: ${e.code}");
      // ignore: avoid_print
      print("Message: ${e.message}");
      // ignore: avoid_print
      print("=== END AUTH REGISTRATION FirebaseAuthException ===");
      throw _mapAuthException(e);
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print("=== AUTH REGISTRATION unexpected error ===");
      // ignore: avoid_print
      print("Error: $e");
      // ignore: avoid_print
      print("Type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Stack: $stackTrace");
      // ignore: avoid_print
      print("=== END AUTH REGISTRATION unexpected error ===");
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Signs in a user with [email] and [password].
  /// Returns the [User] on success, or throws an error message string.
  Future<User> loginWithEmail(String email, String password) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        throw 'Login failed. Please try again.';
      }
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print("=== LOGIN DEBUG ===");
      // ignore: avoid_print
      print("Error type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Error code: ${e.code}");
      // ignore: avoid_print
      print("Error message: ${e.message}");
      // ignore: avoid_print
      print("=== END DEBUG ===");
      throw _mapAuthException(e);
    } catch (e) {
      // ignore: avoid_print
      print("=== LOGIN DEBUG (non-Firebase) ===");
      // ignore: avoid_print
      print("Error type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Error: $e");
      // ignore: avoid_print
      print("=== END DEBUG ===");
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sends a password-reset email to [email].
  /// Throws an error message string on failure.
  /// For security, user-not-found is silently swallowed so callers always
  /// show the same success message regardless of whether the email exists.
  Future<void> sendPasswordReset(String email) async {
    try {
      // ignore: avoid_print
      print("=== AUTH: Sending password reset to $email ===");
      await _auth.sendPasswordResetEmail(email: email.trim());
      // ignore: avoid_print
      print("=== AUTH: Password reset email sent successfully ===");
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print("=== AUTH: Password reset error: ${e.code} ===");
      if (e.code == 'user-not-found') {
        // Do NOT reveal that the email doesn't exist - security measure
        // ignore: avoid_print
        print("=== AUTH: Email not found but showing success anyway (security) ===");
        return;
      } else if (e.code == 'invalid-email') {
        throw 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        throw 'Too many requests. Please try again later.';
      } else {
        throw 'Failed to send reset email. Please try again.';
      }
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  /// Maps [FirebaseAuthException] codes to user-friendly messages.
  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return e.message ?? 'An authentication error occurred. Please try again.';
    }
  }
}
