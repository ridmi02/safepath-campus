import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../admin/admin_dashboard_screen.dart';
import '../home/home_page.dart';
import '../registration/registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Authenticate with Firebase
      final authService = AuthService();
      final user = await authService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // ignore: avoid_print
      print("=== AUTH SUCCESS ===");
      // ignore: avoid_print
      print("UID: ${user.uid}");
      // ignore: avoid_print
      print("Email: ${user.email}");
      // ignore: avoid_print
      print("=== NOW FETCHING FIRESTORE DOC ===");

      // Step 2: Get user document from Firestore
      final firestoreService = FirestoreService();
      final UserModel? userModel =
          await firestoreService.getUserDocument(user.uid);

      // Step 3: Check verification status and navigate
      if (!mounted) return;

      if (userModel == null) {
        // User authenticated but profile doc wasn't found in known collections.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged in, but profile was not found. Opening home screen.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyHomePage()),
        );
        return;
      }

      // Check if user is admin
      if (userModel.role == 'admin') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen()),
        );
        return;
      }

      // Then continue with existing student verification check...
      if (userModel.verificationStatus == 'verified') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyHomePage()),
        );
        return;
      } else if (userModel.verificationStatus == 'pending') {
        // Navigate to Pending Screen (we will create this next)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account is pending verification.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (userModel.verificationStatus == 'rejected') {
        // Navigate to Rejected Screen (we will create this next)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account has been rejected.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("=== HANDLE LOGIN ERROR ===");
      // ignore: avoid_print
      print("Caught error: $e");
      // ignore: avoid_print
      print("Error type: ${e.runtimeType}");
      // ignore: avoid_print
      print("=== END ERROR ===");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1
                const SizedBox(height: 40),

                // 2
                Text(
                  'SafePath Campus',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),

                // 3
                const Text(
                  'Login to your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                // 4
                const SizedBox(height: 40),

                // 5
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: Validators.validateEmail,
                ),

                // 6
                const SizedBox(height: 16),

                // 7
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),

                // 8
                const SizedBox(height: 8),

                // 9
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),

                // 10
                const SizedBox(height: 24),

                // 11
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                // 12
                const SizedBox(height: 16),

                // 13
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
