import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/transaction_provider.dart';
import 'main_navigation.dart';

// =============================================================================
// STRICT AUTHENTICATION & SESSION SERVICE
// =============================================================================
class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserPassword = 'user_password';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<Map<String, String>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? 'Guest User',
      'email': prefs.getString(_keyUserEmail) ?? 'Not logged in',
    };
  }

  static Future<String?> register({required String name, required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPassword, password);
    await prefs.setBool(_keyIsLoggedIn, true);
    return null;
  }

  static Future<String?> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyUserEmail);
    final storedPassword = prefs.getString(_keyUserPassword);

    if (storedEmail == null || storedEmail.isEmpty) return 'No account found. Please sign up first.';
    if (storedEmail != email) return 'Email does not match our records.';
    if (storedPassword != password) return 'Incorrect password. Please try again.';

    await prefs.setBool(_keyIsLoggedIn, true);
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final loggedIn = await AuthService.isLoggedIn();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TransactionProvider(),
      child: FinanceApp(startLoggedIn: loggedIn),
    ),
  );
}

class FinanceApp extends StatelessWidget {
  final bool startLoggedIn;
  const FinanceApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<TransactionProvider>().isDarkMode;

    // Hue-preserving luminance inversion matrix for crisp Light Mode across all custom cards
    const List<double> lightModeMatrix = <double>[
      0.402, -1.174, -0.228, 0, 255,
      -0.598, -0.174, -0.228, 0, 255,
      -0.598, -1.174,  0.772, 0, 255,
      0,      0,      0,     1,   0,
    ];

    return MaterialApp(
      title: 'FinBlend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
        ),
      ),
      builder: (context, child) {
        if (isDark) return child!;
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(lightModeMatrix),
          child: child,
        );
      },
      home: const LoginScreen(), // Keep your existing home widget name here (e.g., AuthGate or LoginScreen)
    );
  }
}

// =============================================================================
// AUTHENTICATION SCREENS
// =============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final errorMessage = await AuthService.login(email: _emailController.text.trim(), password: _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 64, color: Colors.tealAccent),
                  const SizedBox(height: 16),
                  const Text('Welcome to FinBlend', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Log in to manage your finances', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined, color: Colors.tealAccent), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    validator: (val) => (val == null || val.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: Colors.teal.shade900),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)) : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())), child: const Text('Sign Up', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final errorMessage = await AuthService.register(name: _nameController.text.trim(), email: _emailController.text.trim(), password: _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                TextFormField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline, color: Colors.tealAccent), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter your full name' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _emailController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined, color: Colors.tealAccent), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter your email' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _passwordController, style: const TextStyle(color: Colors.white), obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), validator: (val) => (val == null || val.isEmpty) ? 'Enter a password' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _confirmPasswordController, style: const TextStyle(color: Colors.white), obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_reset, color: Colors.tealAccent), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), validator: (val) => (val != _passwordController.text) ? 'Passwords do not match' : null),
                const SizedBox(height: 28),
                ElevatedButton(onPressed: _isLoading ? null : _handleRegister, style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}