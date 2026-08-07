import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'reset_success_screen.dart';

/// "Create new password 🔒" — password + confirm behind an eye toggle, then a
/// Remember me checkbox. Continue raises the success modal over this screen,
/// which is how ProScan ends the reset flow.
class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _passwordController = TextEditingController(text: 'docflow1234');
  final _confirmController = TextEditingController(text: 'docflow1234');
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mismatch = _confirmController.text.isNotEmpty &&
        _confirmController.text != _passwordController.text;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Create new password 🔒',
                      style: theme.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your new password. If you forget it, then you '
                      'have to do forgot password.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    Text('Password', style: theme.textTheme.labelLarge),
                    _PasswordField(
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      onToggle: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 24),
                    Text('Confirm Password', style: theme.textTheme.labelLarge),
                    _PasswordField(
                      controller: _confirmController,
                      obscure: _obscureConfirm,
                      errorText: mismatch ? 'Passwords do not match' : null,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                        const SizedBox(width: 8),
                        Text('Remember me', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: ElevatedButton(
                onPressed: _canSubmit
                    ? () => showResetSuccessDialog(context)
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.errorText,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
      decoration: InputDecoration(
        errorText: errorText,
        suffixIcon: IconButton(
          onPressed: onToggle,
          // ProScan tints the toggle primary rather than grey.
          icon: Icon(
            obscure ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
