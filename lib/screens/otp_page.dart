import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'profile_setup_page.dart';

/// Verifies the OTP sent by the bdapps backend. On success, persists the
/// login state and either prompts for a name (first signup) or jumps to
/// HomeShell (returning user).
class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.phone, required this.referenceNo});

  final String phone;
  final String referenceNo;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _ctrl = TextEditingController();
  final _auth = AuthService.instance;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _ctrl.text.trim();
    if (otp.length < 4) {
      _snack('Enter the full code');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _auth.verifyOtp(
        phone: widget.phone,
        otp: otp,
        referenceNo: widget.referenceNo,
      );
      if (!mounted) return;

      final ok = data['statusCode']?.toString().trim().toUpperCase() == 'S1000';
      if (!ok) {
        _snack(data['message']?.toString() ?? 'Invalid code');
        return;
      }

      // OTP accepted — save login, then poll the subscription until the
      // backend reports REGISTERED (same as bdapps).
      await _auth.setLoggedIn(widget.phone);
      final synced = await _auth.waitForSubscriptionSync(widget.phone);
      if (!mounted) return;

      if (!synced) {
        _snack('Subscription is processing. Please try again shortly.');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }

      // First-time signup → ask for name. Returning user → home.
      final existingName = await _auth.name();
      if (!mounted) return;
      if (existingName == null || existingName.trim().isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      }
    } catch (_) {
      _snack('Network problem. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = true}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: error ? scheme.error : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed:
                          _loading ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'We sent a 6-digit code to your number',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(text: 'A 6-digit code was sent to '),
                              TextSpan(
                                text: widget.phone,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verification code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          enabled: !_loading,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 14,
                            color: scheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withOpacity(0.5),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ref: ${widget.referenceNo}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _verify,
                            child: _loading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Verify'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              'Wrong number? Go back',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
