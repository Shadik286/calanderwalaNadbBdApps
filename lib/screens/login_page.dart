import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/calendar_logo.dart';
import 'home_shell.dart';
import 'otp_page.dart';

/// Phone entry screen. Reuses the exact bdapps flow:
/// 1. Validate Robi/Airtel number.
/// 2. Check subscription — if REGISTERED, jump straight to home.
/// 3. Otherwise call send_otp.php and push the OTP page.
/// UI uses the Reminder 24 purple gradient language.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _ctrl = TextEditingController();
  final _auth = AuthService.instance;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final phone = _ctrl.text.trim();
    if (phone.isEmpty) {
      _snack('Please enter your mobile number');
      return;
    }
    if (!_auth.isValidBanglalinkNumber(phone)) {
      _snack('Enter a valid Robi or Airtel number');
      return;
    }

    setState(() => _loading = true);
    try {
      // Already subscribed? Go straight home (no name capture needed — name
      // was set on a previous signup).
      if (await _auth.checkSubscription(phone)) {
        await _auth.setLoggedIn(phone);
        if (!mounted) return;
        _snack('Welcome back!', error: false);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
        return;
      }

      // Not subscribed — request OTP.
      final data = await _auth.sendOtp(phone);
      if (!mounted) return;

      final refNo =
          (data['referenceNo'] ??
                  data['reference_no'] ??
                  data['referenceID'] ??
                  data['reference_id'])
              ?.toString()
              .trim() ??
              '';
      final code = data['statusCode']?.toString().trim() ?? '';
      final msg = data['message']?.toString() ?? '';

      if (data['success'] == true && refNo.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(phone: phone, referenceNo: refNo),
          ),
        );
      } else if (code == 'E1351' ||
          msg.toLowerCase().contains('already registered')) {
        await _auth.setLoggedIn(phone);
        _snack('Logging you in...', error: false);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      } else {
        _snack(msg.isNotEmpty ? msg : 'Could not send OTP');
      }
    } catch (e) {
      debugPrint('Login network error: $e');
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        const CalendarLogo(size: 96),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome to Reminder 24',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in with your Robi or Airtel number',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mobile number',
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
                                  keyboardType: TextInputType.phone,
                                  enabled: !_loading,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '01XXXXXXXXX',
                                    hintStyle: TextStyle(
                                      color: scheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.phone_iphone_rounded,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _onContinue,
                                    child: _loading
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: scheme.onPrimary,
                                            ),
                                          )
                                        : const Text('Continue'),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer
                                        .withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          size: 18, color: scheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Only Robi (016) and Airtel (018) numbers are supported.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}