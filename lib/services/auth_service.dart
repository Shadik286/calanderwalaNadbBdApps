import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the bdapps backend contract (same endpoints, same request/response
/// shape) so the login, subscription and unsubscribe flows stay identical.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Same base URL and endpoints as bdapps/lib/login.dart & home_page.dart.
  static const String baseUrl = 'https://androidcontentapp.xyz/SDKreminder24/';

  // Pref keys for locally persisted auth state.
  static const _kIsLoggedIn = 'isLoggedIn';
  static const _kPhone = 'userPhone';
  static const _kName = 'userName';

  // Robi (016) and Airtel (018) numbers only.
  static final RegExp _validPhone = RegExp(r'^01(?:6|8)\d{8}$');

  bool isValidBanglalinkNumber(String p) => _validPhone.hasMatch(p.trim());

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  Future<String?> phone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhone);
  }

  Future<String?> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName);
  }

  /// Returns true if the phone is REGISTERED with the bdapps backend.
  Future<bool> checkSubscription(String phone) async {
    try {
      final res = await http
          .post(
            Uri.parse('${baseUrl}check_subscription.php'),
            body: {'user_mobile': phone},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      return data is Map &&
          data['subscriptionStatus']?.toString().trim().toUpperCase() ==
              'REGISTERED';
    } catch (_) {
      return false;
    }
  }

  /// Sends an OTP to the given number. Returns the decoded response map so
  /// the caller can inspect `success`, `referenceNo`, `statusCode`, and
  /// `message` (same shape as bdapps).
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await http
        .post(
          Uri.parse('${baseUrl}send_otp.php'),
          body: {'user_mobile': phone},
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  /// Verifies the OTP against the bdapps backend.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    required String referenceNo,
  }) async {
    final res = await http.post(
      Uri.parse('${baseUrl}verify_otp.php'),
      body: {
        'Otp': otp,
        'referenceNo': referenceNo,
        'user_mobile': phone,
      },
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  /// Polls checkSubscription until REGISTERED (or times out).
  Future<bool> waitForSubscriptionSync(String phone) async {
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (await checkSubscription(phone)) return true;
    }
    return false;
  }

  /// Persists the login state for [phone].
  Future<void> setLoggedIn(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kPhone, phone);
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kPhone);
    await prefs.remove(_kName);
  }

  /// Calls the bdapps unsubscribe endpoint. Returns the raw decoded map.
  Future<Map<String, dynamic>> unsubscribe(String phone) async {
    final res = await http
        .post(
          Uri.parse('${baseUrl}unsubscribe.php'),
          body: {'user_mobile': phone},
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
