import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/settings_row.dart';
import 'create_password_screen.dart';

/// Sign-in protection: session, biometrics, two-factor, devices, and a tinted
/// Change Password button below the list.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _rememberMe = true;
  bool _biometricId = false;
  bool _faceId = false;
  bool _smsAuth = false;
  bool _googleAuth = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('Security', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            _Toggle(
              label: 'Remember me',
              value: _rememberMe,
              onChanged: (v) => setState(() => _rememberMe = v),
            ),
            _Toggle(
              label: 'Biometric ID',
              value: _biometricId,
              onChanged: (v) => setState(() => _biometricId = v),
            ),
            _Toggle(
              label: 'Face ID',
              value: _faceId,
              onChanged: (v) => setState(() => _faceId = v),
            ),
            _Toggle(
              label: 'SMS Authenticator',
              value: _smsAuth,
              onChanged: (v) => setState(() => _smsAuth = v),
            ),
            _Toggle(
              label: 'Google Authenticator',
              value: _googleAuth,
              onChanged: (v) => setState(() => _googleAuth = v),
            ),
            SettingsRow(
              label: 'Device Management',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('1 device signed in')),
              ),
            ),
            const SizedBox(height: 20),
            // Tinted rather than solid — it is a secondary action here.
            SizedBox(
              height: 60,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryTint,
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreatePasswordScreen(
                      email: 'andrew.ainsley@yourdomain.com',
                      code: '',
                    ),
                  ),
                ),
                child: const Text('Change Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
