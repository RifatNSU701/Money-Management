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
// PROFESSIONAL REGISTRATION, LOGIN, GOOGLE SIGN-IN & ACCOUNT RESTORE SCREEN
// =============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

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
  // 1. GOOGLE SIGN-IN & AUTOMATIC GOOGLE DRIVE RESTORE MODAL
  // ===========================================================================
  void _showGoogleSignInSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final googleEmailCtrl = TextEditingController(
      text: provider.deviceGoogleAccounts.isNotEmpty ? provider.deviceGoogleAccounts.first : '',
    );
    final googleNameCtrl = TextEditingController();
    final oauthTokenCtrl = TextEditingController();
    bool showAdvancedToken = false;
    bool isSigningIn = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(color: Color(0xFF4285F4), fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.tr('Sign in with Google', 'গুগল অ্যাকাউন্ট দিয়ে লগইন'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            provider.tr(
                              'Continue to FinBlend & enable direct Google Drive Backup',
                              'ফিনব্লেন্ডে প্রবেশ করুন এবং সরাসরি গুগল ড্রাইভ ব্যাকআপ চালু করুন',
                            ),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),

                // SAVED GOOGLE ACCOUNTS ON THIS DEVICE
                if (provider.deviceGoogleAccounts.isNotEmpty) ...[
                  Text(
                    provider.tr('Choose a Google Account on this device:', 'এই ডিভাইসে লগইন থাকা গুগল অ্যাকাউন্ট নির্বাচন করুন:'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...provider.deviceGoogleAccounts.map((acc) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: googleEmailCtrl.text.trim().toLowerCase() == acc
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4285F4),
                        child: Text(acc[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      title: Text(acc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        provider.tr('Google Account • Drive Sync Enabled', 'গুগল অ্যাকাউন্ট • ড্রাইভ সিঙ্ক সক্রিয়'),
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF38BDF8)),
                      onTap: () async {
                        setSheetState(() => isSigningIn = true);
                        final res = await provider.signInWithGoogleAccount(
                          googleEmail: acc,
                          displayName: acc.split('@').first,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted && res['success'] == true) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(res['message']?.toString() ?? 'Signed in with Google')),
                          );
                          Navigator.pushReplacement(
                            this.context,
                            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                          );
                        }
                      },
                    ),
                  )),
                  const Divider(color: Color(0xFF334155), height: 22),
                ],

                Text(
                  provider.tr('Or sign in with another Google Account:', 'অথবা অন্য গুগল অ্যাকাউন্ট দিয়ে লগইন করুন:'),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: googleEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: provider.tr('Google Email (e.g., yourname@gmail.com) *', 'গুগল ইমেইল (yourname@gmail.com) *'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: googleNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: provider.tr('Display Name (Optional)', 'আপনার নাম (ঐচ্ছিক)'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheetState(() => showAdvancedToken = !showAdvancedToken),
                    icon: Icon(showAdvancedToken ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFF94A3B8)),
                    label: Text(
                      provider.tr('Optional: Google OAuth2 Drive API Access Token', 'ঐচ্ছিক: গুগল ড্রাইভ এপিআই অ্যাক্সেস টোকেন'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ),
                ),
                if (showAdvancedToken) ...[
                  TextField(
                    controller: oauthTokenCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'ya29.a0AfH6SM...',
                      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSigningIn
                      ? null
                      : () async {
                    final gEmail = googleEmailCtrl.text.trim().toLowerCase();
                    if (!_isValidEmail(gEmail)) {
                      _showError(provider.tr('Please enter a valid Google email.', 'সঠিক গুগল ইমেইল লিখুন।'));
                      return;
                    }
                    setSheetState(() => isSigningIn = true);
                    final res = await provider.signInWithGoogleAccount(
                      googleEmail: gEmail,
                      displayName: googleNameCtrl.text.trim(),
                      accessToken: oauthTokenCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted && res['success'] == true) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(res['message']?.toString() ?? 'Signed in!')),
                      );
                      Navigator.pushReplacement(
                        this.context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    isSigningIn
                        ? provider.tr('Connecting Google Account...', 'গুগলে সংযুক্ত হচ্ছে...')
                        : provider.tr('Continue with Google & Sync Drive', 'গুগল দিয়ে লগইন ও ড্রাইভ সিঙ্ক করুন'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
  // 2. RESTORE DELETED ACCOUNT (FROM GOOGLE DRIVE OR EXPORTED BACKUP FILE)
  // ===========================================================================
  void _showRestoreDeletedAccountDialog(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final driveEmailCtrl = TextEditingController(
      text: provider.deviceGoogleAccounts.isNotEmpty ? provider.deviceGoogleAccounts.first : _emailCtrl.text.trim(),
    );
    final backupPayloadCtrl = TextEditingController();
    bool isRestoring = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr('Restore Full Account Backup', 'ডিলিট হওয়া বা পূর্বের অ্যাকাউন্ট রিস্টোর করুন'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  provider.tr(
                    'Deleted your account earlier? Restore 100% of your data directly from Google Drive or paste your exported Full Account Backup file (.json) below.',
                    'পূর্বে অ্যাকাউন্ট ডিলিট করেছিলেন? সরাসরি গুগল ড্রাইভ থেকে অথবা আপনার এক্সপোর্ট করা ব্যাকআপ ফাইল (.json) দিয়ে সম্পূর্ণ ডাটা ফিরিয়ে আনুন।',
                  ),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),

                // OPTION A: 1-TAP RESTORE DIRECTLY FROM GOOGLE DRIVE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.tr('Option 1: Restore Directly from Google Drive', 'বিকল্প ১: সরাসরি গুগল ড্রাইভ থেকে রিস্টোর করুন'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: driveEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: provider.tr('Enter Google Account Email...', 'গুগল ইমেইল লিখুন...'),
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isRestoring
                            ? null
                            : () async {
                          setSheetState(() => isRestoring = true);
                          final res = await provider.restoreFullAccountFromGoogleDrive(
                            googleEmail: driveEmailCtrl.text.trim(),
                          );
                          setSheetState(() => isRestoring = false);
                          if (res['success'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(res['message']?.toString() ?? 'Restored!')),
                              );
                              Navigator.pushReplacement(
                                this.context,
                                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                              );
                            }
                          } else {
                            _showError(res['message']?.toString() ?? 'No backup found.');
                          }
                        },
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: Text(
                          provider.tr('Restore from Google Drive & Sign In', 'গুগল ড্রাইভ থেকে রিস্টোর ও লগইন করুন'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // OPTION B: UPLOAD / PASTE EXPORTED BACKUP FILE (.JSON / KEY)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.upload_file_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.tr('Option 2: Upload / Paste Exported Account Backup (.json)', 'বিকল্প ২: এক্সপোর্ট করা ব্যাকআপ ডাটা (.json) পেস্ট করুন'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: backupPayloadCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: provider.tr(
                            'Paste contents of FinBlend_Full_Account_Backup.json or Backup Key here...',
                            'এক্সপোর্ট করা ব্যাকআপ ফাইল বা ব্যাকআপ কোড এখানে পেস্ট করুন...',
                          ),
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isRestoring
                            ? null
                            : () async {
                          setSheetState(() => isRestoring = true);
                          final res = await provider.restoreAccountFromBackupPayload(backupPayloadCtrl.text);
                          setSheetState(() => isRestoring = false);
                          if (res['success'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(res['message']?.toString() ?? 'Restored!')),
                              );
                              Navigator.pushReplacement(
                                this.context,
                                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                              );
                            }
                          } else {
                            _showError(res['message']?.toString() ?? 'Invalid backup payload.');
                          }
                        },
                        icon: const Icon(Icons.restore_page_outlined, size: 18),
                        label: Text(
                          provider.tr('Upload Backup & Continue Account', 'ব্যাকআপ আপলোড করে অ্যাকাউন্টে প্রবেশ করুন'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final provider = context.read<TransactionProvider>();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.trim();
    final dob = _dobCtrl.text.trim();
    final occupation = _occupationCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (!_isValidEmail(email)) {
      _showError(provider.tr('Please enter a valid email address (e.g., name@domain.com).', 'অনুগ্রহ করে একটি সঠিক ইমেইল ঠিকানা দিন।'));
      return;
    }

    if (pass.length.clamp(0, 5) == pass.length) {
      _showError(provider.tr('Password must be at least 6 characters long.', 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।'));
      return;
    }

    if (!_isLogin) {
      if (name.isEmpty) {
        _showError(provider.tr('Full Name is required for registration.', 'নিবন্ধনের জন্য পুরো নাম আবশ্যক।'));
        return;
      }
      if (phone.length.clamp(0, 6) == phone.length) {
        _showError(provider.tr('Please enter a valid phone number.', 'অনুগ্রহ করে সঠিক ফোন নম্বর দিন।'));
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
        _showError(provider.tr('Please enter your Residential / Office Address.', 'অনুগ্রহ করে আপনার ঠিকানা লিখুন।'));
        return;
      }
      if (pass != confirmPass) {
        _showError(provider.tr('Passwords do not match. Please check Confirm Password.', 'পাসওয়ার্ড দুটি মেলেনি। পুনরায় যাচাই করুন।'));
        return;
      }
    }

    setState(() => _isLoading = true);

    final result = await provider.authenticateCloudAccount(
      name: name,
      email: email,
      password: pass,
      isSignUp: !_isLogin,
      phone: phone,
      occupation: occupation,
      address: address,
    );

    if (result['success'] == true && !_isLogin) {
      await provider.updateUserProfile(
        name: name,
        email: email,
        phone: phone,
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER & LANGUAGE TOGGLE
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
                    const SizedBox(height: 20),

                    Text(
                      _isLogin
                          ? provider.tr('Sign In to Your Account', 'আপনার অ্যাকাউন্টে লগইন করুন')
                          : provider.tr('Create Official FinBlend Account', 'নতুন ফিনব্লেন্ড অ্যাকাউন্ট তৈরি করুন'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? provider.tr(
                        'Sign in with Email, Continue with Google, or restore a previously exported account.',
                        'ইমেইল, গুগল অ্যাকাউন্ট অথবা পূর্বের ব্যাকআপ ফাইল থেকে আপনার অ্যাকাউন্টে প্রবেশ করুন।',
                      )
                          : provider.tr(
                        'Complete all fields below or register in 1 tap using your Google Account.',
                        'নিচের তথ্যগুলো পূরণ করুন অথবা ১ ট্যাপেই গুগল অ্যাকাউন্ট দিয়ে নিবন্ধন করুন।',
                      ),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 18),

                    // =========================================================
                    // REQUIREMENT #2: CONTINUE WITH GOOGLE BUTTON
                    // =========================================================
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _showGoogleSignInSheet(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              provider.tr('Continue with Google (Auto Drive Sync)', 'Google দিয়ে লগইন করুন (ড্রাইভ সিঙ্ক)'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // =========================================================
                    // REQUIREMENT #1: RESTORE DELETED ACCOUNT FROM BACKUP / DRIVE
                    // =========================================================
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showRestoreDeletedAccountDialog(context),
                      icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                      label: Text(
                        provider.tr(
                          'Restore Deleted Account (Google Drive / Backup File)',
                          'পূর্বের অ্যাকাউন্ট রিস্টোর (গুগল ড্রাইভ / ব্যাকআপ ফাইল)',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF334155))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text('OR EMAIL ACCOUNT', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: Color(0xFF334155))),
                        ],
                      ),
                    ),

                    // SIGN IN / REGISTER SWITCHER
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

                    if (!_isLogin) ...[
                      _buildInput(
                        controller: _nameCtrl,
                        label: provider.tr('Full Name *', 'পুরো নাম *'),
                        hint: provider.tr('e.g., Md. Rifat Khan', 'যেমন: মোঃ রিফাত খান'),
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    _buildInput(
                      controller: _emailCtrl,
                      label: provider.tr('Valid Email Address *', 'সঠিক ইমেইল ঠিকানা *'),
                      hint: 'name@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    if (!_isLogin) ...[
                      _buildInput(
                        controller: _phoneCtrl,
                        label: provider.tr('Mobile / Phone Number *', 'মোবাইল নম্বর *'),
                        hint: '+880 17XXXXXXXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
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
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 12),
                          Text(
                            provider.tr('Verifying & Syncing...', 'যাচাই ও সিঙ্ক হচ্ছে...'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                          : Text(
                        _isLogin
                            ? provider.tr('Sign In to FinBlend', 'লগইন করুন')
                            : provider.tr('Complete Registration', 'নিবন্ধন সম্পন্ন করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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