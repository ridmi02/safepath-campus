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
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        throw 'Registration failed. Please try again.';
      }
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
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
      throw _mapAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sends a password-reset email to [email].
  /// Throws an error message string on failure.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
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
