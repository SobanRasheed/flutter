import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/settings_row.dart';

/// The profile behind the account, editable in place. Read-only until the
/// pencil is tapped, matching the kit's view/edit split.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _editing = false;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _gender = 'Male';
  String _country = 'United States';
  DateTime _birthday = DateTime(1995, 12, 27);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _name.text = user?.displayName ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  String get _birthdayLabel {
    final m = _birthday.month.toString().padLeft(2, '0');
    final d = _birthday.day.toString().padLeft(2, '0');
    return '$m/$d/${_birthday.year}';
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _pickGender() async {
    final picked = await _pickOption(
      context,
      title: 'Gender',
      options: const ['Male', 'Female', 'Other'],
      selected: _gender,
    );
    if (picked != null) setState(() => _gender = picked);
  }

  Future<void> _pickCountry() async {
    final picked = await _pickOption(
      context,
      title: 'Country',
      options: const [
        'United States',
        'United Kingdom',
        'Canada',
        'Australia',
        'Germany',
        'France',
        'Pakistan',
        'India',
      ],
      selected: _country,
    );
    if (picked != null) setState(() => _country = picked);
  }

  void _save() {
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('Personal Info', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            onPressed: _editing ? _save : () => setState(() => _editing = true),
            tooltip: _editing ? 'Save' : 'Edit',
            icon: Icon(
              _editing ? LucideIcons.check : LucideIcons.edit2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Center(child: _AvatarPicker(editing: _editing)),
            const SizedBox(height: 32),
            _Field(
              label: 'Full Name',
              controller: _name,
              enabled: _editing,
            ),
            _Field(
              label: 'Email',
              controller: _email,
              enabled: _editing,
              keyboardType: TextInputType.emailAddress,
            ),
            _Field(
              label: 'Phone Number',
              controller: _phone,
              enabled: _editing,
              keyboardType: TextInputType.phone,
            ),
            _PickerField(
              label: 'Gender',
              value: _gender,
              icon: LucideIcons.chevronDown,
              enabled: _editing,
              onTap: _pickGender,
            ),
            _PickerField(
              label: 'Date of Birth',
              value: _birthdayLabel,
              icon: LucideIcons.calendar,
              enabled: _editing,
              onTap: _pickBirthday,
            ),
            _Field(
              label: 'Street Address',
              controller: _address,
              enabled: _editing,
            ),
            _PickerField(
              label: 'Country',
              value: _country,
              icon: LucideIcons.chevronDown,
              enabled: _editing,
              onTap: _pickCountry,
            ),
          ],
        ),
      ),
    );
  }
}

/// 120pt avatar with a primary pencil badge, shown only while editing.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 124,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user,
                size: 52, color: AppColors.primary),
          ),
          if (editing)
            Positioned(
              right: 0,
              bottom: 8,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.pencil,
                    size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label over an underlined value. The underline stays primary either way; the
/// field just stops taking input when not editing.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same shape as [_Field] but the value comes from a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.primary),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(icon, size: 22, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared single-choice sheet for the profile pickers.
Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SettingsRow(
                  label: option,
                  showChevron: false,
                  trailing: option == selected
                      ? const Icon(LucideIcons.check,
                          size: 22, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
