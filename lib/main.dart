import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TransactionProvider(),
      child: const FinBlendApp(),
    ),
  );
}

class FinBlendApp extends StatelessWidget {
  const FinBlendApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<TransactionProvider>().isDarkMode;

    const List<double> lightModeMatrix = [
      0.402, -1.174, -0.228, 0, 255,
      -0.598, -0.174, -0.228, 0, 255,
      -0.598, -1.174,  0.772, 0, 255,
      0,      0,      0,     1,   0,
    ];

    return MaterialApp(
      title: 'FinBlend — Personal & Business Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
      ),
      builder: (context, child) {
        if (isDark) return child!;
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(lightModeMatrix),
          child: child,
        );
      },
      home: const AuthGate(),
    );
  }
}

// =============================================================================
// AUTHENTIC 4-COLOR GOOGLE 'G' BRAND LOGO PAINTER
// =============================================================================
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<TransactionProvider>().isDarkMode;
    return buildTrueColorWrapper(
      isDarkMode: isDark,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.22;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.35, 1.55, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.58, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.60, false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 0.90, false, paint);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.50, size.height * 0.41, size.width * 0.46, stroke * 0.88),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// AUTHENTICATION SERVICE & SESSION GATE
// =============================================================================
class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  static Future<void> login(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email.trim().toLowerCase());
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }

  static Future getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? 'FinBlend User',
      'email': prefs.getString('user_email') ?? 'user@finblend.app',
    };
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await AuthService.isLoggedIn();
    if (mounted) setState(() => _loggedIn = status);
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
      );
    }
    return _loggedIn! ? const MainNavigationScreen() : const LoginScreen();
  }
}

// =============================================================================
// ENTERPRISE LOGIN & REGISTRATION SCREEN (OFFICIAL GOOGLE_SIGN_IN SDK)
// =============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loginWithPhone = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  String _selectedCountryCode = '+880';
  static const List _countryCodes = [
    {'code': '+880', 'label': '🇧🇩 BD (+880)'},
    {'code': '+1', 'label': '🇺🇸 US/CA (+1)'},
    {'code': '+44', 'label': '🇬🇧 UK (+44)'},
    {'code': '+91', 'label': '🇮🇳 IN (+91)'},
    {'code': '+966', 'label': '🇸🇦 SA (+966)'},
    {'code': '+971', 'label': '🇦🇪 UAE (+971)'},
    {'code': '+60', 'label': '🇲🇾 MY (+60)'},
    {'code': '+65', 'label': '🇸🇬 SG (+65)'},
    {'code': '+61', 'label': '🇦🇺 AU (+61)'},
    {'code': '+49', 'label': '🇩🇪 DE (+49)'},
    {'code': '+33', 'label': '🇫🇷 FR (+33)'},
    {'code': '+81', 'label': '🇯🇵 JP (+81)'},
  ];

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _selectedGender = 'Male';
  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionProvider>().clearSessionOnLogout();
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _pickRegistrationDob() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dobCtrl.text = '${picked.day} ${months[picked.month - 1]} ${picked.year}';
      });
    }
  }

  // ===========================================================================
  // CALLS OFFICIAL GOOGLE_SIGN_IN SDK (ANDROID PLAY SERVICES / WEB OAUTH)
  // ===========================================================================
  Future<void> _handleNativeGoogleSignIn() async {
    final provider = context.read<TransactionProvider>();
    setState(() => _isLoading = true);

    final Map res = await provider.signInWithNativeGoogleOAuth();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['canceled'] == true) {
      return;
    }

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(res['message']?.toString() ?? 'Signed in with Google!'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else if (res['needsConfig'] == true) {
      _showOAuthConfigDialog(context, res['message']?.toString() ?? '');
    } else {
      _showError(res['message']?.toString() ?? 'Google Sign-In failed.');
    }
  }

  void _showOAuthConfigDialog(BuildContext context, String errorReason) {
    final provider = context.read<TransactionProvider>();
    final clientIdCtrl = TextEditingController(text: provider.customGoogleWebClientId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const GoogleLogoWidget(size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                provider.tr('Google OAuth Client Setup', 'গুগল OAuth ক্লায়েন্ট সেটআপ'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                errorReason,
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                provider.tr(
                  'Paste your Web OAuth Client ID (xxxx.apps.googleusercontent.com) from Google Cloud Console:',
                  'গুগল ক্লাউড কনসোল থেকে আপনার Web OAuth Client ID এখানে পেস্ট করুন:',
                ),
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: clientIdCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '123456789-abc.apps.googleusercontent.com',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.tr('Close', 'বন্ধ করুন'), style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
            onPressed: () async {
              await provider.setGoogleWebClientId(clientIdCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await _handleNativeGoogleSignIn();
            },
            child: Text(provider.tr('Save & Retry Google Sign-In', 'সেভ ও পুনরায় চেষ্টা করুন')),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final provider = context.read<TransactionProvider>();
    final name = _nameCtrl.text.trim();
    final emailInput = _emailCtrl.text.trim().toLowerCase();
    final rawPhoneDigits = _phoneCtrl.text.trim();
    final fullPhoneWithCode = '$_selectedCountryCode$rawPhoneDigits';
    final dob = _dobCtrl.text.trim();
    final occupation = _occupationCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (_isLogin) {
      if (_loginWithPhone) {
        if (rawPhoneDigits.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 5) ==
            rawPhoneDigits.replaceAll(RegExp(r'[^0-9]'), '').length) {
          _showError(
            provider.tr(
              'Please enter a valid phone number with your selected country code.',
              'অনুগ্রহ করে কান্ট্রি কোডসহ সঠিক ফোন নম্বর লিখুন।',
            ),
          );
          return;
        }
      } else {
        if (!_isValidEmail(emailInput)) {
          _showError(
            provider.tr(
              'Please enter a valid email address (e.g., name@domain.com).',
              'অনুগ্রহ করে একটি সঠিক ইমেইল ঠিকানা দিন।',
            ),
          );
          return;
        }
      }
    } else {
      if (name.isEmpty) {
        _showError(provider.tr('Full Name is required for registration.', 'নিবন্ধনের জন্য পুরো নাম আবশ্যক।'));
        return;
      }
      if (!_isValidEmail(emailInput)) {
        _showError(provider.tr('Please enter a valid email address.', 'অনুগ্রহ করে সঠিক ইমেইল ঠিকানা দিন।'));
        return;
      }
      if (rawPhoneDigits.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 5) ==
          rawPhoneDigits.replaceAll(RegExp(r'[^0-9]'), '').length) {
        _showError(provider.tr('Please enter a valid mobile number.', 'অনুগ্রহ করে সঠিক মোবাইল নম্বর দিন।'));
        return;
      }
      if (dob.isEmpty) {
        _showError(provider.tr('Please select your Date of Birth.', 'অনুগ্রহ করে আপনার জন্ম তারিখ নির্বাচন করুন।'));
        return;
      }
      if (occupation.isEmpty) {
        _showError(provider.tr('Please enter your Occupation / Profession.', 'অনুগ্রহ করে আপনার পেশা উল্লেখ করুন।'));
        return;
      }
      if (address.isEmpty) {
        _showError(provider.tr('Please enter your Full Address.', 'অনুগ্রহ করে আপনার ঠিকানা লিখুন।'));
        return;
      }
      if (pass != confirmPass) {
        _showError(provider.tr('Passwords do not match. Please check Confirm Password.', 'পাসওয়ার্ড দুটি মেলেনি। পুনরায় যাচাই করুন।'));
        return;
      }
    }

    if (pass.length.clamp(0, 5) == pass.length) {
      _showError(provider.tr('Password must be at least 6 characters long.', 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।'));
      return;
    }

    setState(() => _isLoading = true);

    final String authIdentifier = (_isLogin && _loginWithPhone) ? fullPhoneWithCode : emailInput;

    final result = await provider.authenticateCloudAccount(
      name: name,
      email: authIdentifier,
      password: pass,
      isSignUp: !_isLogin,
      phone: fullPhoneWithCode,
      occupation: occupation,
      address: address,
    );

    if (result['success'] == true && !_isLogin) {
      await provider.updateUserProfile(
        name: name,
        email: emailInput,
        phone: fullPhoneWithCode,
        dob: dob,
        gender: _selectedGender,
        occupation: occupation,
        organization: '',
        address: address,
        photoBase64: provider.userPhotoBase64,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(result['message']?.toString() ?? 'Success'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      _showError(result['message']?.toString() ?? 'Authentication failed.');
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final newPassCtrl = TextEditingController();
    final confirmNewCtrl = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF38BDF8), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.tr('Reset Account Password', 'পাসওয়ার্ড রিসেট করুন'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: resetEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: provider.tr('Registered Email *', 'নিবন্ধিত ইমেইল *'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: provider.tr('New Password (Min. 6 chars) *', 'নতুন পাসওয়ার্ড *'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmNewCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: provider.tr('Confirm New Password *', 'পাসওয়ার্ড নিশ্চিত করুন *'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: Text(provider.tr('Cancel', 'বাতিল'), style: const TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
              onPressed: isResetting
                  ? null
                  : () async {
                final email = resetEmailCtrl.text.trim().toLowerCase();
                final newPass = newPassCtrl.text.trim();
                final confirmNew = confirmNewCtrl.text.trim();

                if (!_isValidEmail(email) || newPass.length.clamp(0, 5) == newPass.length || newPass != confirmNew) {
                  _showError(provider.tr('Check email and matching passwords.', 'ইমেইল ও পাসওয়ার্ড যাচাই করুন।'));
                  return;
                }

                setDialogState(() => isResetting = true);
                await provider.syncOnLogin(email);
                final Map stateMap = Map.from(provider.exportFullStateMap());
                stateMap['email'] = email;
                stateMap['passwordHash'] = base64Encode(utf8.encode('fb_salt_$newPass'));
                stateMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

                final String updatedSyncCode = base64Encode(utf8.encode(jsonEncode(stateMap)));
                await provider.importFromSyncCode(updatedSyncCode);
                await provider.pushToCloud(silent: false);

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _emailCtrl.text = email;
                    _passCtrl.text = newPass;
                    _isLogin = true;
                    _loginWithPhone = false;
                  });
                }
              },
              child: Text(provider.tr('Update Password', 'পাসওয়ার্ড আপডেট')),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text(msg)),
    );
  }

  Widget _buildPhoneWithCountryCodeField(TransactionProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountryCode,
              dropdownColor: const Color(0xFF1E293B),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF38BDF8), size: 18),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              items: _countryCodes.map((item) {
                return DropdownMenuItem<String>(
                  value: item['code']?.toString(),
                  child: Text(item['label']?.toString() ?? ''),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCountryCode = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: provider.tr('Mobile / Phone Number *', 'মোবাইল নম্বর *'),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              hintText: '17XXXXXXXX',
              hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF38BDF8), size: 20),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0EA5E9), size: 24),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'FinBlend',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => provider.toggleLanguage(),
                          icon: const Icon(Icons.translate_rounded, size: 16),
                          label: Text(
                            provider.isBengali ? 'English' : 'বাংলা',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    Text(
                      provider.tr('Log in or sign up', 'লগইন অথবা নিবন্ধন করুন'),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.tr(
                        'Manage personal finance, group budgets, receipts, and enterprise POS across all your devices.',
                        'আপনার সকল ডিভাইস থেকে ব্যক্তিগত হিসাব, গ্রুপ বাজেট, রসিদ এবং বিজনেস পিওএস পরিচালনা করুন।',
                      ),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),

                    // 1. OFFICIAL CONTINUE WITH GOOGLE BUTTON
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF475569), width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _isLoading ? null : _handleNativeGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const GoogleLogoWidget(size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  provider.tr('Continue with Google', 'Google দিয়ে চালিয়ে যান'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 2. CONTINUE WITH PHONE / EMAIL SWITCHER BUTTON
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF475569), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isLogin = true;
                          _loginWithPhone = !_loginWithPhone;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _loginWithPhone ? Icons.email_outlined : Icons.phone_outlined,
                            color: const Color(0xFF38BDF8),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _loginWithPhone
                                ? provider.tr('Continue with email', 'ইমেইল দিয়ে লগইন করুন')
                                : provider.tr('Continue with phone', 'ফোন নম্বর দিয়ে লগইন করুন'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF334155))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('OR', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: Color(0xFF334155))),
                        ],
                      ),
                    ),

                    // SIGN IN / REGISTER ACCOUNT MODE TABS
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLogin ? const Color(0xFF0EA5E9) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  provider.tr('Sign In', 'লগইন'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isLogin ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isLogin ? const Color(0xFF0EA5E9) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  provider.tr('Register Account', 'নিবন্ধন করুন'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isLogin ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (_isLogin) ...[
                      if (_loginWithPhone)
                        _buildPhoneWithCountryCodeField(provider)
                      else
                        _buildInput(
                          controller: _emailCtrl,
                          label: provider.tr('Email address *', 'ইমেইল ঠিকানা *'),
                          hint: 'name@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      const SizedBox(height: 12),
                    ] else ...[
                      _buildInput(
                        controller: _nameCtrl,
                        label: provider.tr('Full Name *', 'পুরো নাম *'),
                        hint: provider.tr('e.g., Rifat Khan', 'যেমন: রিফাত খান'),
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _emailCtrl,
                        label: provider.tr('Valid Email Address *', 'সঠিক ইমেইল ঠিকানা *'),
                        hint: 'name@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      _buildPhoneWithCountryCodeField(provider),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _dobCtrl,
                        readOnly: true,
                        onTap: _pickRegistrationDob,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: provider.tr('Date of Birth *', 'জন্ম তারিখ *'),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          hintText: provider.tr('Tap to select from calendar', 'ক্যালেন্ডার থেকে নির্বাচন করুন'),
                          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                          prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF38BDF8), size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF38BDF8), size: 18),
                            onPressed: _pickRegistrationDob,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        provider.tr('Gender *', 'লিঙ্গ *'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: _genderOptions.map((g) {
                          final isSel = _selectedGender == g;
                          final label = g == 'Male'
                              ? provider.tr('Male', 'পুরুষ')
                              : (g == 'Female' ? provider.tr('Female', 'নারী') : provider.tr('Other', 'অন্যান্য'));
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSel ? Colors.white : const Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFF0EA5E9),
                                backgroundColor: const Color(0xFF0F172A),
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _selectedGender = g),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      _buildInput(
                        controller: _occupationCtrl,
                        label: provider.tr('Occupation / Profession *', 'পেশা / পদবী *'),
                        hint: provider.tr('e.g., Software Engineer / Business Owner', 'যেমন: সফটওয়্যার ইঞ্জিনিয়ার / ব্যবসায়ী'),
                        icon: Icons.work_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _addressCtrl,
                        label: provider.tr('Full Address *', 'পূর্ণ ঠিকানা *'),
                        hint: provider.tr('Road, Area, City, Country', 'রোড, এলাকা, শহর, দেশ'),
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: _isLogin
                            ? provider.tr('Password *', 'পাসওয়ার্ড *')
                            : provider.tr('Create Password (Min. 6 chars) *', 'পাসওয়ার্ড তৈরি করুন (ন্যূনতম ৬ অক্ষর) *'),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                        ),
                      ),
                    ),

                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordDialog(context),
                          child: Text(
                            provider.tr('Forgot Password? Reset Here', 'পাসওয়ার্ড ভুলে গেছেন? রিসেট করুন'),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    if (!_isLogin) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassCtrl,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: provider.tr('Confirm Password *', 'পাসওয়ার্ড নিশ্চিত করুন *'),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))),
                          const SizedBox(width: 12),
                          Text(
                            provider.tr('Verifying & Syncing...', 'যাচাই ও সিঙ্ক হচ্ছে...'),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      )
                          : Text(
                        _isLogin
                            ? provider.tr('Continue', 'চালিয়ে যান')
                            : provider.tr('Complete Registration', 'নিবন্ধন সম্পন্ন করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
        ),
      ),
    );
  }
}