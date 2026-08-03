import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the email of the last account that successfully signed in, so
/// [LoginScreen] can prefill the field on the next login — purely a local
/// device convenience, not part of the `AuthRepository` port (this never
/// touches Supabase).
class LastEmailStore {
  const LastEmailStore._();

  static const String _key = 'last_signed_in_email';

  static Future<void> save(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, email);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
