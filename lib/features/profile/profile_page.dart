import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _users = FirebaseFirestore.instance.collection('users');
  final _authService = AuthService();
  bool _saving = false;
  bool _deleting = false;
  bool _signingOut = false;

  Future<void> _openEditForm(_ProfileData profile) async {
    final updated = await showModalBottomSheet<_ProfileData>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditProfileForm(initial: profile),
    );
    if (updated == null) return;

    setState(() => _saving = true);
    try {
      await _users.doc(profile.uid).update({
        'fullName': updated.name,
        'email': updated.email,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount(_ProfileData profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await _users.doc(profile.uid).delete();
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await authUser.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Please log in again and retry delete.'
          : (e.message ?? e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _signingOut = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFFE7EAF2) : colorScheme.surface;
    final mainText = isDark ? const Color(0xFF14213D) : colorScheme.onSurface;
    final mutedText = isDark
        ? const Color(0xFF425466)
        : colorScheme.onSurfaceVariant;
    final iconColor = isDark ? const Color(0xFF3A6EA5) : colorScheme.primary;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('Please sign in to view your profile.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _users.doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load profile: ${snapshot.error}'));
          }
          if (!snapshot.hasData ||
              !snapshot.data!.exists ||
              snapshot.data!.data() == null) {
            return const Center(child: Text('Profile not found.'));
          }

          final profile = _ProfileData.fromDoc(snapshot.data!);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: cardBg,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          _initials(profile.name),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: mainText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: cardBg,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ProfileDetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Student ID',
                        value: profile.studentId,
                        labelColor: mutedText,
                        valueColor: mainText,
                        iconColor: iconColor,
                      ),
                      Divider(
                        height: 20,
                        color: isDark
                            ? const Color(0xFFBAC4D6)
                            : colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      _ProfileDetailRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: profile.name,
                        labelColor: mutedText,
                        valueColor: mainText,
                        iconColor: iconColor,
                      ),
                      Divider(
                        height: 20,
                        color: isDark
                            ? const Color(0xFFBAC4D6)
                            : colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      _ProfileDetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email,
                        labelColor: mutedText,
                        valueColor: mainText,
                        iconColor: iconColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _openEditForm(profile),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit),
                label: Text(_saving ? 'Saving...' : 'Edit Profile'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _deleting ? null : () => _deleteAccount(profile),
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_deleting ? 'Deleting...' : 'Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _signingOut ? null : _logout,
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(_signingOut ? 'Logging out...' : 'Log out'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.initial});

  final _ProfileData initial;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _emailController = TextEditingController(text: widget.initial.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      widget.initial.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.initial.studentId,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Student ID (read-only)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
  });

  factory _ProfileData.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _ProfileData(
      uid: doc.id,
      name: (data['fullName'] ?? data['name'] ?? 'Unknown User').toString(),
      email: (data['email'] ?? '').toString(),
      studentId: (data['sliitId'] ?? data['studentId'] ?? '').toString(),
    );
  }

  final String uid;
  final String name;
  final String email;
  final String studentId;

  _ProfileData copyWith({
    String? name,
    String? email,
  }) {
    return _ProfileData(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId,
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

