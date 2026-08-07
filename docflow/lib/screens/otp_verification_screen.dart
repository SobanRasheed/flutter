import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import 'create_password_screen.dart';

/// "You've got mail 📩" — four-digit OTP entry. A single hidden field drives
/// the boxes so the OS numeric keyboard does the input, as in ProScan.
class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  static const _length = 4;
  static const _resendSeconds = 55;
  static const _boxHeight = 60.0;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  int _remaining = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  void _resend() {
    _controller.clear();
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code resent to ${widget.email}')),
    );
  }

  void _confirm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePasswordScreen(
          email: widget.email,
          code: _controller.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = _controller.text;
    final complete = code.length == _length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text("You've got mail 📩", style: theme.textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'We have sent the OTP verification code to your email address. '
                'Check your email and enter the code below.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              // The boxes are decoration; a transparent field laid over them
              // takes the real input, so the OS numeric keyboard drives entry
              // and a tap anywhere on the row focuses it.
              SizedBox(
                height: _boxHeight,
                child: Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _length; i++)
                          _DigitBox(
                            value: i < code.length ? code[i] : '',
                            focused: i == code.length,
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: _length,
                        showCursor: false,
                        cursorColor: Colors.transparent,
                        style: const TextStyle(color: Colors.transparent),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),
              Center(
                child: Text(
                  "Didn't receive email?",
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: _remaining > 0
                    ? Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textPrimary),
                          children: [
                            const TextSpan(text: 'You can resend code in '),
                            TextSpan(
                              text: '$_remaining',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const TextSpan(text: ' s'),
                          ],
                        ),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend code'),
                      ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: complete ? _confirm : null,
                child: const Text('Confirm'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// One OTP cell: muted fill when idle, primary ring plus tint when it is the
/// next box to receive a digit.
class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.value, required this.focused});

  final String value;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: _OTPVerificationScreenState._boxHeight,
      decoration: BoxDecoration(
        color: focused ? AppColors.primaryTint : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: focused ? Border.all(color: AppColors.primary) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
