import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/calendar_logo.dart';
import 'home_shell.dart';
import 'login_page.dart';

/// Decides on app start whether to show the login flow or the main app,
/// based on the locally persisted login state and the bdapps subscription
/// check (matching bdapps/lib/main.dart's _AuthGate).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  bool _goHome = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    final phone = await AuthService.instance.phone();

    var goHome = false;
    if (loggedIn && phone != null && phone.isNotEmpty) {
      goHome = await AuthService.instance.checkSubscription(phone);
      if (!goHome) {
        // Subscription is gone — clear local creds and force re-login.
        await AuthService.instance.logout();
      }
    }

    if (!mounted) return;
    setState(() {
      _goHome = goHome;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _AuthSplash();
    return _goHome ? const HomeShell() : const LoginPage();
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appGradient(context)),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CalendarLogo(size: 120),
              SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}