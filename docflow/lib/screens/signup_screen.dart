import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

/// Sign up. ProScan's two-step registration: create the account, then complete
/// the profile, with the step bar under the app bar. Step changes use the same
/// SharedAxis motion as the rest of the auth flow.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authService = AuthService();

  int _step = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;
  String _gender = 'Male';
  DateTime? _birthday;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step = 0);
    }
  }

  void _next() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _error = null; _step = 1; });
  }

  Future<void> _finish() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.createUserWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: const AppShell(),
              );
            },
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('weak-password')) return 'Password is too weak. Use at least 6 characters.';
    return 'Sign up failed. Please try again.';
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 24),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: _StepBar(step: _step),
            ),
            Expanded(
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder:
                    (child, animation, secondaryAnimation) =>
                        SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: AppColors.background,
                  child: child,
                ),
                child: _step == 0
                    ? _AccountStep(
                        key: const ValueKey('account'),
                        emailController: _emailController,
                        passwordController: _passwordController,
                        confirmController: _confirmController,
                        obscurePassword: _obscurePassword,
                        obscureConfirm: _obscureConfirm,
                        remember: _remember,
                        onTogglePassword: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onToggleConfirm: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        onToggleRemember: (v) => setState(() => _remember = v),
                        onContinue: _next,
                        onSignIn: () => Navigator.of(context).pop(),
                      )
                    : _ProfileStep(
                        key: const ValueKey('profile'),
                        nameController: _nameController,
                        phoneController: _phoneController,
                        gender: _gender,
                        birthday: _birthday,
                        onGenderChanged: (v) => setState(() => _gender = v),
                        onPickBirthday: _pickBirthday,
                        onFinish: _finish,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-segment progress bar above the form, as in ProScan's registration.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: 5,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (i == 0) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.remember,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onToggleRemember,
    required this.onContinue,
    required this.onSignIn,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool remember;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final ValueChanged<bool> onToggleRemember;
  final VoidCallback onContinue;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create an\nAccount 🔐', style: theme.textTheme.displayLarge),
          const SizedBox(height: 12),
          Text(
            'One account for all your documents — convert, organise and scan.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _Label('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              prefixIcon: Icon(LucideIcons.mail, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Create a password',
              prefixIcon: const Icon(LucideIcons.lock, size: 20),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Confirm Password'),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            obscureText: obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(LucideIcons.lock, size: 20),
              suffixIcon: IconButton(
                onPressed: onToggleConfirm,
                icon: Icon(
                  obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: remember,
                  onChanged: (v) => onToggleRemember(v ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Text('Remember me', style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: theme.textTheme.bodyMedium),
              GestureDetector(
                onTap: onSignIn,
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.gender,
    required this.birthday,
    required this.onGenderChanged,
    required this.onPickBirthday,
    required this.onFinish,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String gender;
  final DateTime? birthday;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onPickBirthday;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Complete your\nProfile 📋', style: theme.textTheme.displayLarge),
          const SizedBox(height: 12),
          Text(
            "Don't worry, this stays on your device. Only you can see it.",
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Center(child: _AvatarPicker(onTap: () {})),
          const SizedBox(height: 32),
          _Label('Full Name'),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: Icon(LucideIcons.user, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Phone Number'),
          const SizedBox(height: 8),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+1 000 000 0000',
              prefixIcon: Icon(LucideIcons.phone, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Date of Birth'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickBirthday,
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(
                  text: birthday == null
                      ? ''
                      : '${birthday!.month.toString().padLeft(2, '0')}'
                          '/${birthday!.day.toString().padLeft(2, '0')}'
                          '/${birthday!.year}',
                ),
                decoration: const InputDecoration(
                  hintText: 'MM/DD/YYYY',
                  prefixIcon: Icon(LucideIcons.calendar, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Label('Gender'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in const ['Male', 'Female', 'Other']) ...[
                Expanded(
                  child: _GenderChip(
                    label: option,
                    selected: option == gender,
                    onTap: () => onGenderChanged(option),
                  ),
                ),
                if (option != 'Other') const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onFinish, child: const Text('Finish')),
        ],
      ),
    );
  }
}

/// Circular avatar well with the small edit badge, as in ProScan's profile step.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.user,
                  size: 44, color: AppColors.primarySoft),
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(LucideIcons.pencil,
                    size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    );
  }
}
