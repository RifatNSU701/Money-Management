import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/app_validators.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

typedef StringMap = Map<String, String>;

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

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness:
      isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

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
          error: Color(0xFFF87171),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final themedChild = isDark
            ? content
            : ColorFiltered(
          colorFilter: const ColorFilter.matrix(lightModeMatrix),
          child: content,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: themedChild,
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
      Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.41,
        size.width * 0.46,
        stroke * 0.88,
      ),
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
  static String _recoveryPinKey(String email) =>
      'recovery_pin_hash_${email.trim().toLowerCase()}';

  static String hashRecoveryPin(String email, String pin) {
    return base64Encode(
      utf8.encode('fb_pin_${email.trim().toLowerCase()}_${pin.trim()}'),
    );
  }

  static Future<void> saveRecoveryPin(String email, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recoveryPinKey(email), hashRecoveryPin(email, pin));
  }

  static Future<String?> getRecoveryPinHash(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recoveryPinKey(email));
  }

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

  static Future<StringMap> getCurrentUser() async {
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
        ),
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
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loginWithPhone = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _obscurePin = true;
  bool _showOptionalProfile = false;
  bool _submittedOnce = false;

  String _selectedCountryCode = '+880';
  static const List<StringMap> _countryCodes = [
    {'code': '+880', 'short': '🇧🇩 +880', 'label': '🇧🇩 BD (+880)'},
    {'code': '+1', 'short': '🇺🇸 +1', 'label': '🇺🇸 US/CA (+1)'},
    {'code': '+44', 'short': '🇬🇧 +44', 'label': '🇬🇧 UK (+44)'},
    {'code': '+91', 'short': '🇮🇳 +91', 'label': '🇮🇳 IN (+91)'},
    {'code': '+966', 'short': '🇸🇦 +966', 'label': '🇸🇦 SA (+966)'},
    {'code': '+971', 'short': '🇦🇪 +971', 'label': '🇦🇪 UAE (+971)'},
    {'code': '+60', 'short': '🇲🇾 +60', 'label': '🇲🇾 MY (+60)'},
    {'code': '+65', 'short': '🇸🇬 +65', 'label': '🇸🇬 SG (+65)'},
    {'code': '+61', 'short': '🇦🇺 +61', 'label': '🇦🇺 AU (+61)'},
    {'code': '+49', 'short': '🇩🇪 +49', 'label': '🇩🇪 DE (+49)'},
    {'code': '+33', 'short': '🇫🇷 +33', 'label': '🇫🇷 FR (+33)'},
    {'code': '+81', 'short': '🇯🇵 +81', 'label': '🇯🇵 JP (+81)'},
  ];

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _recoveryPinCtrl = TextEditingController();

  String? _selectedGender;
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _occupationCtrl.dispose();
    _addressCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _recoveryPinCtrl.dispose();
    super.dispose();
  }

  void _switchAuthMode(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _submittedOnce = false;
      _formKey.currentState?.reset();
    });
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
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      setState(() {
        _dobCtrl.text =
        '${picked.day} ${months[picked.month - 1]} ${picked.year}';
      });
    }
  }

  void _showBanner(String msg, {required bool isError}) {
    final isDark = context.read<TransactionProvider>().isDarkMode;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          content: buildTrueColorWrapper(
            isDarkMode: isDark,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFC62828)
                    : const Color(0xFF047857),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  // ===========================================================================
  // OFFICIAL GOOGLE_SIGN_IN SDK (ANDROID PLAY SERVICES / WEB OAUTH)
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
      _showBanner(
        res['message']?.toString() ?? 'Signed in with Google!',
        isError: false,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else if (res['needsConfig'] == true) {
      _showOAuthConfigDialog(context, res['message']?.toString() ?? '');
    } else {
      _showBanner(
        res['message']?.toString() ?? 'Google Sign-In failed.',
        isError: true,
      );
    }
  }

  void _showOAuthConfigDialog(BuildContext context, String errorReason) {
    final provider = context.read<TransactionProvider>();
    final clientIdCtrl =
    TextEditingController(text: provider.customGoogleWebClientId);

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
                provider.tr(
                  'Google OAuth Client Setup',
                  'গুগল OAuth ক্লায়েন্ট সেটআপ',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  height: 1.4,
                ),
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
                  hintStyle:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              provider.tr('Close', 'বন্ধ করুন'),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await provider.setGoogleWebClientId(clientIdCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              await _handleNativeGoogleSignIn();
            },
            child: Text(
              provider.tr('Save & Retry Google Sign-In', 'সেভ ও পুনরায় চেষ্টা করুন'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final provider = context.read<TransactionProvider>();
    setState(() => _submittedOnce = true);

    if (!(_formKey.currentState?.validate() ?? false)) {
      _showBanner(
        provider.tr(
          'Please fix the highlighted fields above.',
          'অনুগ্রহ করে লাল চিহ্নিত ঘরগুলো সঠিকভাবে পূরণ করুন।',
        ),
        isError: true,
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final emailInput = _emailCtrl.text.trim().toLowerCase();
    final rawPhoneDigits = _phoneCtrl.text.trim();
    final fullPhoneWithCode =
    rawPhoneDigits.isEmpty ? '' : '$_selectedCountryCode$rawPhoneDigits';
    final dob = _dobCtrl.text.trim();
    final occupation = _occupationCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final recoveryPin = _recoveryPinCtrl.text.trim();

    setState(() => _isLoading = true);

    final String authIdentifier =
    (_isLogin && _loginWithPhone) ? fullPhoneWithCode : emailInput;

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
      await AuthService.saveRecoveryPin(emailInput, recoveryPin);
      await provider.updateUserProfile(
        name: name,
        email: emailInput,
        phone: fullPhoneWithCode,
        dob: dob,
        gender: _selectedGender ?? '',
        occupation: occupation,
        organization: '',
        address: address,
        photoBase64: provider.userPhotoBase64,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showBanner(
        result['message']?.toString() ?? 'Signed in successfully.',
        isError: false,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      _showBanner(
        result['message']?.toString() ?? 'Authentication failed.',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // VERIFIED PASSWORD RESET (REQUIRES 6-DIGIT RECOVERY PIN)
  // ===========================================================================
  void _showForgotPasswordDialog(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final resetFormKey = GlobalKey<FormState>();
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final resetPinCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmNewCtrl = TextEditingController();
    bool isResetting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF38BDF8),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.tr('Verify & Reset Password', 'পাসওয়ার্ড যাচাই ও রিসেট'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    provider.tr(
                      'Enter your registered email and 6-digit Recovery PIN. Google Sign-In users should reset their password via Google Account Recovery.',
                      'আপনার নিবন্ধিত ইমেইল এবং ৬-সংখ্যার রিকভারি পিন দিন। Google ব্যবহারকারীরা Google Account থেকে পাসওয়ার্ড রিসেট করুন।',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    validator: AppValidators.email,
                    decoration: _inputDecoration(
                      label: provider.tr('Registered Email *', 'নিবন্ধিত ইমেইল *'),
                      hint: 'name@example.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: resetPinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    validator: (val) {
                      final v = val?.trim() ?? '';
                      if (v.length != 6) {
                        return provider.tr(
                          'Enter your 6-digit Recovery PIN',
                          '৬-সংখ্যার রিকভারি পিন দিন',
                        );
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      label: provider.tr(
                        '6-Digit Recovery PIN *',
                        '৬-সংখ্যার রিকভারি পিন *',
                      ),
                      hint: '••••••',
                      icon: Icons.pin_outlined,
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    validator: AppValidators.password,
                    decoration: _inputDecoration(
                      label: provider.tr(
                        'New Password (Min. 6 chars) *',
                        'নতুন পাসওয়ার্ড *',
                      ),
                      hint: '••••••',
                      icon: Icons.lock_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: confirmNewCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    validator: (val) =>
                        AppValidators.confirmPassword(val, newPassCtrl.text),
                    decoration: _inputDecoration(
                      label: provider.tr(
                        'Confirm New Password *',
                        'পাসওয়ার্ড নিশ্চিত করুন *',
                      ),
                      hint: '••••••',
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: Text(
                provider.tr('Cancel', 'বাতিল'),
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              onPressed: isResetting
                  ? null
                  : () async {
                if (!(resetFormKey.currentState?.validate() ?? false)) {
                  return;
                }

                final email = resetEmailCtrl.text.trim().toLowerCase();
                final enteredPin = resetPinCtrl.text.trim();
                final newPass = newPassCtrl.text.trim();

                setDialogState(() {
                  isResetting = true;
                  dialogError = null;
                });

                await provider.syncOnLogin(email);
                final Map stateMap =
                Map.from(provider.exportFullStateMap());
                final expectedLocalHash =
                await AuthService.getRecoveryPinHash(email);
                final expectedCloudHash =
                stateMap['recoveryPinHash']?.toString();
                final storedHash = (expectedCloudHash != null &&
                    expectedCloudHash.isNotEmpty)
                    ? expectedCloudHash
                    : expectedLocalHash;

                final enteredHash =
                AuthService.hashRecoveryPin(email, enteredPin);

                if (storedHash == null || storedHash != enteredHash) {
                  if (!ctx.mounted) return;
                  setDialogState(() {
                    isResetting = false;
                    dialogError = provider.tr(
                      'Recovery PIN verification failed. Password was not changed.',
                      'রিকভারি পিন মেলেনি। পাসওয়ার্ড পরিবর্তন করা হয়নি।',
                    );
                  });
                  return;
                }

                stateMap['email'] = email;
                stateMap['passwordHash'] =
                    base64Encode(utf8.encode('fb_salt_$newPass'));
                stateMap['recoveryPinHash'] = storedHash;
                stateMap['updatedAt'] =
                    DateTime.now().millisecondsSinceEpoch;

                final String updatedSyncCode =
                base64Encode(utf8.encode(jsonEncode(stateMap)));
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
                  _showBanner(
                    provider.tr(
                      'Password updated after PIN verification.',
                      'পিন যাচাইয়ের পর পাসওয়ার্ড আপডেট হয়েছে।',
                    ),
                    isError: false,
                  );
                }
              },
              child: isResetting
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(provider.tr('Update Password', 'পাসওয়ার্ড আপডেট')),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0F172A),
      errorMaxLines: 2,
      errorStyle: const TextStyle(
        color: Color(0xFFFCA5A5),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  Widget _buildPhoneWithCountryCodeField(
      TransactionProvider provider, {
        required bool required,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountryCode,
              dropdownColor: const Color(0xFF1E293B),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF38BDF8),
                size: 16,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
              selectedItemBuilder: (_) => _countryCodes
                  .map(
                    (item) => Center(
                  child: Text(
                    item['short'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
                  .toList(),
              items: _countryCodes
                  .map(
                    (item) => DropdownMenuItem<String>(
                  value: item['code'],
                  child: Text(item['label'] ?? ''),
                ),
              )
                  .toList(),
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
          child: TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: AppValidators.digitsAndPlusOnly,
            validator: (val) =>
                AppValidators.phoneNumber(val, required: required),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              label: required
                  ? provider.tr('Phone Number *', 'ফোন নম্বর *')
                  : provider.tr('Phone Number (Optional)', 'ফোন নম্বর (ঐচ্ছিক)'),
              hint: '17XXXXXXXX',
              icon: Icons.phone_outlined,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 32.0 : 20.0,
              vertical: isLandscape ? 12.0 : 20.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 540 : 460),
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 20 : 24),
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submittedOnce
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: Color(0xFF0EA5E9),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'FinBlend',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => provider.toggleLanguage(),
                            icon: const Icon(Icons.translate_rounded, size: 16),
                            label: Text(
                              provider.isBengali ? 'English' : 'বাংলা',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLandscape ? 12 : 18),

                      Text(
                        provider.tr(
                          'Log in or sign up',
                          'লগইন অথবা নিবন্ধন করুন',
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLandscape ? 20 : 23,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.tr(
                          'Manage personal finance, group budgets, receipts, and business POS in one place.',
                          'ব্যক্তিগত হিসাব, গ্রুপ বাজেট, রসিদ এবং বিজনেস পিওএস এক জায়গায় পরিচালনা করুন।',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isLandscape ? 14 : 18),

                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Color(0xFF475569),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleNativeGoogleSignIn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogoWidget(size: 20),
                            const SizedBox(width: 12),
                            Text(
                              provider.tr(
                                'Continue with Google',
                                'Google দিয়ে চালিয়ে যান',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Color(0xFF334155))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFF334155))),
                          ],
                        ),
                      ),

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
                                onTap: () => _switchAuthMode(true),
                                child: Container(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isLogin
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    provider.tr('Sign In', 'লগইন'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isLogin
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchAuthMode(false),
                                child: Container(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isLogin
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    provider.tr(
                                      'Register Account',
                                      'নিবন্ধন করুন',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isLogin
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
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
                      const SizedBox(height: 14),

                      if (_isLogin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    provider.tr('Email Login', 'ইমেইল লগইন'),
                                    style: TextStyle(
                                      color: !_loginWithPhone
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                selected: !_loginWithPhone,
                                selectedColor: const Color(0xFF1D4ED8),
                                backgroundColor: const Color(0xFF0F172A),
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  _loginWithPhone = false;
                                  _formKey.currentState?.reset();
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    provider.tr(
                                      'Phone + Password',
                                      'ফোন + পাসওয়ার্ড',
                                    ),
                                    style: TextStyle(
                                      color: _loginWithPhone
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                selected: _loginWithPhone,
                                selectedColor: const Color(0xFF1D4ED8),
                                backgroundColor: const Color(0xFF0F172A),
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  _loginWithPhone = true;
                                  _formKey.currentState?.reset();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loginWithPhone)
                          _buildPhoneWithCountryCodeField(
                            provider,
                            required: true,
                          )
                        else
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: AppValidators.email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: _inputDecoration(
                              label: provider.tr(
                                'Email address *',
                                'ইমেইল ঠিকানা *',
                              ),
                              hint: 'name@example.com',
                              icon: Icons.email_outlined,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextFormField(
                          controller: _nameCtrl,
                          validator: (v) => AppValidators.requiredText(
                            v,
                            provider.tr('Full Name', 'পুরো নাম'),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration(
                            label: provider.tr('Full Name *', 'পুরো নাম *'),
                            hint: provider.tr('e.g., Rifat Khan', 'যেমন: রিফাত খান'),
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration(
                            label: provider.tr(
                              'Email Address *',
                              'ইমেইল ঠিকানা *',
                            ),
                            hint: 'name@example.com',
                            icon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        validator: AppValidators.password,
                        style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration(
                          label: _isLogin
                              ? provider.tr('Password *', 'পাসওয়ার্ড *')
                              : provider.tr(
                            'Create Password (Min. 6 chars) *',
                            'পাসওয়ার্ড তৈরি করুন (ন্যূনতম ৬ অক্ষর) *',
                          ),
                          hint: '••••••',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                      ),

                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(context),
                            child: Text(
                              provider.tr(
                                'Forgot Password? Reset with PIN',
                                'পাসওয়ার্ড ভুলে গেছেন? পিন দিয়ে রিসেট করুন',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      if (!_isLogin) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscureConfirm,
                          validator: (v) =>
                              AppValidators.confirmPassword(v, _passCtrl.text),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration(
                            label: provider.tr(
                              'Confirm Password *',
                              'পাসওয়ার্ড নিশ্চিত করুন *',
                            ),
                            hint: '••••••',
                            icon: Icons.verified_user_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _recoveryPinCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: _obscurePin,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final pin = v?.trim() ?? '';
                            if (pin.length != 6) {
                              return provider.tr(
                                'Set a 6-digit Recovery PIN for password resets',
                                'পাসওয়ার্ড রিসেটের জন্য ৬-সংখ্যার পিন সেট করুন',
                              );
                            }
                            return null;
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: _inputDecoration(
                            label: provider.tr(
                              '6-Digit Recovery PIN *',
                              '৬-সংখ্যার রিকভারি পিন *',
                            ),
                            hint: provider.tr(
                              'Used to verify password resets',
                              'পাসওয়ার্ড রিসেট যাচাইয়ের জন্য',
                            ),
                            icon: Icons.pin_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                          ).copyWith(counterText: ''),
                        ),
                        const SizedBox(height: 8),

                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            initiallyExpanded: _showOptionalProfile,
                            onExpansionChanged: (expanded) =>
                                setState(() => _showOptionalProfile = expanded),
                            title: Text(
                              provider.tr(
                                'Optional Profile Details (Phone, DOB, Address)',
                                'ঐচ্ছিক প্রোফাইল তথ্য (ফোন, জন্ম তারিখ, ঠিকানা)',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: const Color(0xFF38BDF8),
                            collapsedIconColor: const Color(0xFF94A3B8),
                            children: [
                              const SizedBox(height: 8),
                              _buildPhoneWithCountryCodeField(
                                provider,
                                required: false,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _dobCtrl,
                                readOnly: true,
                                onTap: _pickRegistrationDob,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: _inputDecoration(
                                  label: provider.tr(
                                    'Date of Birth (Optional)',
                                    'জন্ম তারিখ (ঐচ্ছিক)',
                                  ),
                                  hint: provider.tr(
                                    'Tap to select from calendar',
                                    'ক্যালেন্ডার থেকে নির্বাচন করুন',
                                  ),
                                  icon: Icons.cake_outlined,
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                      color: Color(0xFF38BDF8),
                                      size: 18,
                                    ),
                                    onPressed: _pickRegistrationDob,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  provider.tr(
                                    'Gender (Optional)',
                                    'লিঙ্গ (ঐচ্ছিক)',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: _genderOptions.map((g) {
                                  final isSel = _selectedGender == g;
                                  final label = g == 'Male'
                                      ? provider.tr('Male', 'পুরুষ')
                                      : (g == 'Female'
                                      ? provider.tr('Female', 'নারী')
                                      : provider.tr('Other', 'অন্যান্য'));
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: ChoiceChip(
                                        label: Center(
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        selected: isSel,
                                        selectedColor: const Color(0xFF0EA5E9),
                                        backgroundColor:
                                        const Color(0xFF0F172A),
                                        showCheckmark: false,
                                        onSelected: (_) => setState(() {
                                          _selectedGender = isSel ? null : g;
                                        }),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _occupationCtrl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: _inputDecoration(
                                  label: provider.tr(
                                    'Occupation (Optional)',
                                    'পেশা (ঐচ্ছিক)',
                                  ),
                                  hint: provider.tr(
                                    'e.g., Student / Engineer',
                                    'যেমন: শিক্ষার্থী / ব্যবসায়ী',
                                  ),
                                  icon: Icons.work_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressCtrl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: _inputDecoration(
                                  label: provider.tr(
                                    'Address (Optional)',
                                    'ঠিকানা (ঐচ্ছিক)',
                                  ),
                                  hint: provider.tr(
                                    'Area, City, Country',
                                    'এলাকা, শহর, দেশ',
                                  ),
                                  icon: Icons.location_on_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              provider.tr(
                                'Verifying & Syncing...',
                                'যাচাই ও সিঙ্ক হচ্ছে...',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        )
                            : Text(
                          _isLogin
                              ? provider.tr('Continue', 'চালিয়ে যান')
                              : provider.tr(
                            'Create Account',
                            'অ্যাকাউন্ট তৈরি করুন',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}