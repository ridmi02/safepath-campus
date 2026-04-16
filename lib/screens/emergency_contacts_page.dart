import 'package:flutter/material.dart';
import 'package:safepath_campus/services/emergency_alarm_service.dart';
import 'package:safepath_campus/services/app_theme.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final list = await _alertService.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = list;
        _isLoading = false;
      });
    }
  }

  void _showContactForm({Map<String, dynamic>? contact}) {
    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?['name'] ?? '');
    final phoneController = TextEditingController(text: contact?['phone'] ?? '');
    final relationController = TextEditingController(text: contact?['relation'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 10,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumGray.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit Contact' : 'Add Emergency Contact',
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: AppTheme.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.mediumGray)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  filled: true,
                  fillColor: AppTheme.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.mediumGray)),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: relationController,
                decoration: InputDecoration(
                  labelText: 'Relationship (e.g. Parent, Friend)',
                  filled: true,
                  fillColor: AppTheme.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.mediumGray)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (isEditing) {
                        await _alertService.removeEmergencyContact(contact['phone']);
                      }
                      await _alertService.addEmergencyContact(
                        nameController.text.trim(),
                        phoneController.text.trim(),
                        relationController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                      _loadContacts();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: AppTheme.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Add Contact'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      appBar: AppBar(
        title: const Text('Emergency Contacts', 
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState()
              : _buildContactList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactForm(),
        backgroundColor: AppTheme.darkPurple,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppTheme.primaryPurple.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          const Text(
            'No contacts added yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your contacts will be notified during SOS alerts',
            style: TextStyle(color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final name = contact['name'] ?? 'Unknown';
        final phone = contact['phone'] ?? '';
        final relation = contact['relation'] ?? 'Contact';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.mediumGray, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryPurple, AppTheme.darkPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            title: Text(
              name, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone, style: const TextStyle(color: AppTheme.textLight)),
                const SizedBox(height: 4),
                Text(relation, style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 22, color: AppTheme.primaryPurple),
                  onPressed: () => _showContactForm(contact: contact),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.warningRed, size: 22),
                  onPressed: () => _confirmDelete(phone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact'),
        content: const Text('Are you sure you want to remove this person from your emergency contacts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _alertService.removeEmergencyContact(phone);
              if (context.mounted) Navigator.pop(context);
              _loadContacts();
            },
            child: const Text('Remove', style: TextStyle(color: AppTheme.warningRed)),
          ),
        ],
      ),
    );
  }
}