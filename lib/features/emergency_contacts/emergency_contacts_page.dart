import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safepath_campus/services/app_theme.dart';
import 'package:safepath_campus/services/emergency_alarm_service.dart';

enum _RelationFilter { all, family, friend, campus, other }

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final EmergencyAlertService _service = EmergencyAlertService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<String> _relationPresets = [
    'Family',
    'Friend',
    'Campus / Security',
    'Roommate',
    'Other',
  ];

  bool _loading = true;
  String _searchQuery = '';
  _RelationFilter _filter = _RelationFilter.all;
  String _relationPreset = _relationPresets.first;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final contacts = await _service.getEmergencyContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  _RelationFilter _categoryOf(Map<String, dynamic> c) {
    final r = (c['relation'] ?? '').toString().toLowerCase();
    if (r.contains('famil') ||
        r.contains('parent') ||
        r.contains('spouse') ||
        r.contains('sibling') ||
        r.contains('mother') ||
        r.contains('father')) {
      return _RelationFilter.family;
    }
    if (r.contains('friend')) return _RelationFilter.friend;
    if (r.contains('campus') ||
        r.contains('security') ||
        r.contains('staff')) {
      return _RelationFilter.campus;
    }
    return _RelationFilter.other;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _contacts.where((c) {
      if (_filter != _RelationFilter.all && _categoryOf(c) != _filter) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final rel = (c['relation'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || rel.contains(q);
    }).toList();
  }

  String? _validateName(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Name is required';
    if (t.length < 2) return 'Use at least 2 characters';
    if (t.length > 80) return 'Name is too long';
    return null;
  }

  String? _validatePhone(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Phone is required';
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Enter at least 8 digits';
    if (digits.length > 15) return 'Too many digits (max 15)';
    return null;
  }

  Future<void> _deleteContact(String phone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove contact?'),
        content: const Text(
          'They will be removed from this device and your Firestore profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _service.removeEmergencyContact(phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact removed')),
    );
    await _loadContacts();
  }

  Future<void> _openContactSheet({Map<String, dynamic>? existing}) async {
    final originalPhone = (existing?['phone'] ?? '').toString();
    final isEdit = existing != null && originalPhone.isNotEmpty;

    _nameController.text = (existing?['name'] ?? '').toString();
    _phoneController.text = originalPhone;
    final existingRel = (existing?['relation'] ?? '').toString().trim();
    if (existingRel.isNotEmpty && _relationPresets.contains(existingRel)) {
      _relationPreset = existingRel;
      _relationController.clear();
    } else if (existingRel.isNotEmpty) {
      _relationPreset = 'Other';
      _relationController.text = existingRel;
    } else {
      _relationPreset = _relationPresets.first;
      _relationController.clear();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEdit ? 'Edit contact' : 'Add emergency contact',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                      ),
                      Text(
                        'Synced to Firestore under your user document.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textLight,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          hintText: 'e.g. Alex Morgan',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGray,
                        ),
                        validator: _validateName,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(80),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          hintText: '+1 555 123 4567',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGray,
                        ),
                        validator: _validatePhone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d+\s\-().]'),
                          ),
                          LengthLimitingTextInputFormatter(22),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_relationPreset),
                        initialValue: _relationPresets.contains(_relationPreset)
                            ? _relationPreset
                            : 'Other',
                        decoration: InputDecoration(
                          labelText: 'Relationship',
                          prefixIcon: const Icon(Icons.group_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: AppTheme.lightGray,
                        ),
                        items: _relationPresets
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setSheetState(() {
                            _relationPreset = v;
                            if (v != 'Other') _relationController.clear();
                          });
                        },
                      ),
                      if (_relationPreset == 'Other') ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _relationController,
                          decoration: InputDecoration(
                            labelText: 'Describe relationship',
                            hintText: 'e.g. Neighbor',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: AppTheme.lightGray,
                          ),
                          maxLength: 40,
                          validator: (v) {
                            if (_relationPreset != 'Other') return null;
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Please describe the relationship';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final name = _nameController.text.trim();
                          final phone = _phoneController.text.trim();
                          final relation = _relationPreset == 'Other'
                              ? _relationController.text.trim()
                              : _relationPreset;

                          final fresh = await _service.getEmergencyContacts();
                          final ignoreKey = isEdit
                              ? EmergencyAlertService.normalizePhoneKey(
                                  originalPhone,
                                )
                              : null;
                          if (_service.contactPhoneExists(
                            fresh,
                            phone,
                            ignoreNormalizedKey:
                                (ignoreKey == null || ignoreKey.isEmpty)
                                    ? null
                                    : ignoreKey,
                          )) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This number is already in your list',
                                ),
                              ),
                            );
                            return;
                          }

                          if (isEdit) {
                            await _service.removeEmergencyContact(originalPhone);
                          }
                          await _service.addEmergencyContact(
                            name,
                            phone,
                            relation,
                          );

                          if (!mounted) return;
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Contact updated' : 'Contact saved',
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          await _loadContacts();
                        },
                        child: Text(isEdit ? 'Save changes' : 'Save contact'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, _RelationFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppTheme.lightPurple,
        checkmarkColor: AppTheme.primaryPurple,
        labelStyle: TextStyle(
          color: selected ? AppTheme.primaryPurple : AppTheme.textDark,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected ? AppTheme.primaryPurple : AppTheme.mediumGray,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      body: RefreshIndicator(
        color: AppTheme.primaryPurple,
        onRefresh: _loadContacts,
        child: CustomScrollView(
        physics: _loading
            ? const AlwaysScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            expandedHeight: 132,
            pinned: true,
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: AppTheme.white,
            title: const Text('Emergency contacts'),
            actions: [
              IconButton(
                tooltip: 'Add',
                onPressed: () => _openContactSheet(),
                icon: const Icon(Icons.person_add_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    elevation: 0,
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.white,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 280),
                          () {
                            if (mounted) setState(() => _searchQuery = v);
                          },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or relation',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.textLight,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', _RelationFilter.all),
                        _filterChip('Family', _RelationFilter.family),
                        _filterChip('Friends', _RelationFilter.friend),
                        _filterChip('Campus', _RelationFilter.campus),
                        _filterChip('Other', _RelationFilter.other),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: _EmptyContactsState(
                hasContacts: _contacts.isNotEmpty,
                onAdd: () => _openContactSheet(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  final name = (c['name'] ?? 'Unknown').toString();
                  final phone = (c['phone'] ?? '').toString();
                  final relation = (c['relation'] ?? '').toString();
                  final trimmedName = name.trim();
                  final initials = trimmedName.isNotEmpty
                      ? trimmedName[0].toUpperCase()
                      : '?';

                  return Material(
                    color: AppTheme.white,
                    elevation: 0,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openContactSheet(existing: c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.darkPurple,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phone,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textLight,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (relation.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightPurple
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        relation,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: AppTheme.primaryPurple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: AppTheme.primaryPurple,
                              onPressed: () => _openContactSheet(existing: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: AppTheme.warningRed,
                              onPressed: phone.isEmpty
                                  ? null
                                  : () => _deleteContact(phone),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContactSheet(),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add contact'),
      ),
    );
  }
}

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState({
    required this.hasContacts,
    required this.onAdd,
  });

  final bool hasContacts;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.lightPurple.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasContacts ? Icons.search_off_rounded : Icons.contact_phone_rounded,
                size: 56,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasContacts ? 'No matches' : 'No emergency contacts yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasContacts
                  ? 'Try another search or filter.'
                  : 'Add people who should be notified if you trigger an alert. Data is saved on-device and under Users → emergencyContacts in Firestore.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textLight,
                    height: 1.4,
                  ),
            ),
            if (!hasContacts) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add your first contact'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
