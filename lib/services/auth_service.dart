import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';

  // Check initial login status on app startup
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Handle user registration
  static Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Persist registration details locally
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString('user_password', password);
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  // Handle user login
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyUserEmail);
    final storedPassword = prefs.getString('user_password');

    // If matching stored credentials or demo entry
    if (storedEmail != null && storedEmail == email && storedPassword == password) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return true;
    } else if (email.isNotEmpty && password.length >= 6) {
      // Allow seamless login for prototype testing
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserEmail, email);
      return true;
    }
    return false;
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}