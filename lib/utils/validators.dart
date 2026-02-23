class Validators {
  Validators._();

  /// Validates that the name is not empty and at least 2 characters.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Validates email format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password strength (minimum 8 characters, at least one uppercase,
  /// one lowercase, one digit, and one special character).
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one digit';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  /// Validates that the confirm password matches the original password.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates SLIIT ID format: "IT" followed by exactly 8 digits (e.g. IT12345678).
  static String? validateSliitId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'SLIIT ID is required';
    }
    final sliitIdRegex = RegExp(r'^IT\d{8}$');
    if (!sliitIdRegex.hasMatch(value.trim())) {
      return 'SLIIT ID must be in the format IT followed by 8 digits (e.g. IT12345678)';
    }
    return null;
  }
}
