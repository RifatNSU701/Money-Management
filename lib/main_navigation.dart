import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'budgets_screen.dart';
import 'business_navigation.dart';
import 'categories_screen.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'dashboard.dart';
import 'export_screen.dart';
import 'groups_screen.dart';
import 'main.dart';
import 'providers/transaction_provider.dart';
import 'records_screen.dart';
import 'wallets_screen.dart';

const List<double> kTrueColorPhotoMatrix = [
  0.402, -1.174, -0.228, 0, 255,
  -0.598, -0.174, -0.228, 0, 255,
  -0.598, -1.174,  0.772, 0, 255,
  0,      0,      0,     1,   0,
];

Widget buildTrueColorWrapper({required bool isDarkMode, required Widget child}) {
  if (isDarkMode) return child;
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(kTrueColorPhotoMatrix),
    child: child,
  );
}

void _showFloatingNotice(
    BuildContext context,
    String message, {
      required bool isError,
    }) {
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
                    message,
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

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _restoringRoute = true;

  @override
  void initState() {
    super.initState();
    _restoreSavedNavigation();
  }

  Future<void> _restoreSavedNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final bool wasBusinessMode = prefs.getBool('nav_is_business_mode') ?? false;
    final int savedTab =
    (widget.initialIndex ?? prefs.getInt('nav_personal_tab') ?? 0)
        .clamp(0, 4);

    if (!mounted) return;

    // If the user refreshed the web app while inside Business POS, stay in Business POS.
    if (widget.initialIndex == null && wasBusinessMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
      );
      return;
    }

    setState(() {
      _currentIndex = savedTab;
      _restoringRoute = false;
    });
  }

  void _selectTab(int index) {
    final clamped = index.clamp(0, 4);
    if (_currentIndex != clamped) {
      setState(() => _currentIndex = clamped);
    }
    context.read<TransactionProvider>().saveNavigationState(
      personalTabIndex: clamped,
      isBusinessMode: false,
    );
  }

  Future<void> _openBusinessPos() async {
    await context.read<TransactionProvider>().saveNavigationState(
      isBusinessMode: true,
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
          (route) => false,
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onSeeAll: () => _selectTab(1));
      case 1:
        return const RecordsScreen();
      case 2:
        return const BudgetsScreen();
      case 3:
        return const GroupsScreen();
      case 4:
        return const CategoriesScreen();
      default:
        return DashboardScreen(onSeeAll: () => _selectTab(1));
    }
  }

  Widget _buildUserAvatar(
      String photoBase64,
      bool isDarkMode, {
        double radius = 17,
      }) {
    if (photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return buildTrueColorWrapper(
          isDarkMode: isDarkMode,
          child: CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF0EA5E9),
            backgroundImage: MemoryImage(bytes),
          ),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0EA5E9),
      child: Icon(Icons.person, size: radius * 1.1, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    if (_restoringRoute) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
        ),
      );
    }

    if (txProvider.appLockEnabled && !txProvider.isAppUnlocked) {
      return const _AppPinLockGate();
    }

    final alerts = txProvider.activeAlerts;
    final bool isWideWebLayout = MediaQuery.of(context).size.width >= 820;

    final appBarActions = <Widget>[
      // 1. 1-TAP BENGALI / ENGLISH SWITCHER
      Tooltip(
        message: txProvider.tr(
          'Switch Language (English / বাংলা)',
          'ভাষা পরিবর্তন করুন (বাংলা / English)',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => txProvider.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              alignment: Alignment.center,
              child: Text(
                txProvider.isBengali ? 'EN' : 'বাংলা',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),

      // 2. GLOBAL PRIVACY EYE TOGGLE (COVERS HOME, RECORDS, BUDGETS, GROUPS, POS)
      IconButton(
        tooltip: txProvider.hideBalances
            ? txProvider.tr('Show All Balances', 'ব্যালেন্স দেখান')
            : txProvider.tr('Hide All Balances', 'ব্যালেন্স লুকান'),
        icon: Icon(
          txProvider.hideBalances
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: txProvider.hideBalances
              ? const Color(0xFFF59E0B)
              : const Color(0xFF94A3B8),
          size: 21,
        ),
        onPressed: () => txProvider.toggleHideBalances(),
      ),

      // 3. CLOUD & GOOGLE DRIVE SYNC BUTTON
      IconButton(
        tooltip: txProvider.tr(
          'Google Drive Backup & Restore',
          'গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর',
        ),
        icon: txProvider.isSyncing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF38BDF8),
          ),
        )
            : const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8)),
        onPressed: () => ProfileScreen.showCloudSyncSheet(context),
      ),

      // 4. NOTIFICATION BELL
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: txProvider.tr(
              'Notifications & Alerts',
              'নোটিফিকেশন ও সতর্কতা',
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
            onPressed: () => ProfileScreen.showNotificationsSheet(context),
          ),
          if (alerts.isNotEmpty)
            Positioned(
              right: 8,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // 5. DARK / LIGHT THEME TOGGLE
      IconButton(
        tooltip: txProvider.isDarkMode
            ? txProvider.tr('Switch to Light Mode', 'লাইট মোডে যান')
            : txProvider.tr('Switch to Dark Mode', 'ডার্ক মোডে যান'),
        icon: Icon(
          txProvider.isDarkMode
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          color: const Color(0xFF38BDF8),
        ),
        onPressed: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
      ),

      // 6. PROFILE AVATAR
      Padding(
        padding: const EdgeInsets.only(right: 12.0, left: 2.0),
        child: Tooltip(
          message: txProvider.tr('Account & Settings', 'অ্যাকাউন্ট ও সেটিংস'),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userName: txProvider.userName,
                    userEmail: txProvider.cloudEmail,
                  ),
                ),
              );
            },
            child: _buildUserAvatar(
              txProvider.userPhotoBase64,
              txProvider.isDarkMode,
              radius: 17,
            ),
          ),
        ),
      ),
    ];

    if (isWideWebLayout) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Row(
            children: [
              const Icon(
                Icons.account_balance_rounded,
                color: Color(0xFF0EA5E9),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  txProvider.tr(
                    'FinBlend Financial Suite',
                    'ফিনব্লেন্ড ফিন্যান্সিয়াল সুইট',
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${txProvider.cloudStatus} • ${txProvider.cloudEmail}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: appBarActions,
        ),
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1060,
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
              indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              selectedIconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
              unselectedIconTheme: const IconThemeData(
                color: Color(0xFF94A3B8),
              ),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xFF94A3B8),
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 8.0,
                ),
                child: Tooltip(
                  message: txProvider.tr(
                    'Switch to Business POS Mode',
                    'বিজনেস পিওএস মোডে যান',
                  ),
                  child: MediaQuery.of(context).size.width >= 1060
                      ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _openBusinessPos,
                    icon: const Icon(Icons.storefront, size: 18),
                    label: Text(
                      txProvider.tr('Business POS', 'বিজনেস পিওএস'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openBusinessPos,
                    icon: const Icon(Icons.storefront, size: 20),
                  ),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text(txProvider.tr('Overview', 'হোম')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: Text(txProvider.tr('Records', 'লেনদেন')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.pie_chart_outline),
                  selectedIcon: const Icon(Icons.pie_chart),
                  label: Text(txProvider.tr('Budgets', 'বাজেট')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.group_outlined),
                  selectedIcon: const Icon(Icons.group),
                  label: Text(txProvider.tr('Group Split', 'গ্রুপ হিসাব')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.category_outlined),
                  selectedIcon: const Icon(Icons.category),
                  label: Text(txProvider.tr('Labels', 'ক্যাটাগরি')),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF334155)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _buildPage(_currentIndex),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 14,
        title: const Text(
          'FinBlend',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4),
        ),
        actions: appBarActions,
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF38BDF8));
            }
            return const IconThemeData(color: Color(0xFF94A3B8));
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: txProvider.tr('Home', 'হোম'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: txProvider.tr('Records', 'লেনদেন'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: txProvider.tr('Budgets', 'বাজেট'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.group_outlined),
              selectedIcon: const Icon(Icons.group),
              label: txProvider.tr('Groups', 'গ্রুপ'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category),
              label: txProvider.tr('Labels', 'ক্যাটাগরি'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// APP PIN LOCK GATE (PROTECTS BALANCES WHEN APP LOCK IS ENABLED)
// =============================================================================
class _AppPinLockGate extends StatefulWidget {
  const _AppPinLockGate();

  @override
  State<_AppPinLockGate> createState() => _AppPinLockGateState();
}

class _AppPinLockGateState extends State<_AppPinLockGate> {
  final _pinCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final provider = context.read<TransactionProvider>();
    final ok = provider.verifyAndUnlockApp(_pinCtrl.text);
    if (!ok) {
      setState(() {
        _errorText = provider.tr('Incorrect PIN. Try again.', 'ভুল পিন। আবার চেষ্টা করুন।');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF38BDF8),
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.tr('FinBlend Locked', 'ফিনব্লেন্ড লক করা আছে'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.tr(
                        'Enter your App Lock PIN to access your financial dashboard.',
                        'আপনার আর্থিক ড্যাশবোর্ডে প্রবেশ করতে অ্যাপ লক পিন দিন।',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _pinCtrl,
                      obscureText: true,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _tryUnlock(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: const TextStyle(
                          color: Color(0xFF475569),
                          letterSpacing: 8,
                        ),
                        errorText: _errorText,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _tryUnlock,
                      child: Text(
                        provider.tr('Unlock', 'আনলক করুন'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
    );
  }
}

// =============================================================================
// CLOUD BACKUP & RESTORE BOTTOM SHEET (WITH LIVE SPINNER & NO CLIPBOARD LEAK)
// =============================================================================
class _CloudSyncSheetBody extends StatefulWidget {
  const _CloudSyncSheetBody();

  @override
  State<_CloudSyncSheetBody> createState() => _CloudSyncSheetBodyState();
}

class _CloudSyncSheetBodyState extends State<_CloudSyncSheetBody> {
  final _codeCtrl = TextEditingController();
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isImporting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final bool busy = _isBackingUp || _isRestoring || _isImporting || txProvider.isSyncing;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 22,
        right: 22,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_to_drive_rounded,
                        color: Color(0xFF38BDF8),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          txProvider.tr(
                            'Google Drive Backup & Restore',
                            'গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: txProvider.tr('Close', 'বন্ধ করুন'),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: busy ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${txProvider.tr("App Account", "অ্যাপ অ্যাকাউন্ট")}: ${txProvider.cloudEmail}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${txProvider.tr("Google Drive", "গুগল ড্রাইভ")}: ${txProvider.connectedGoogleEmail}',
                    style: TextStyle(
                      color: txProvider.isGoogleConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${txProvider.tr("Last Backup", "সর্বশেষ ব্যাকআপ")}: ${txProvider.lastGoogleDriveBackupAt}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // LIVE LOADING BANNER SO DRIVE BACKUP/RESTORE NEVER APPEARS FROZEN
            if (busy) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isRestoring
                            ? txProvider.tr(
                          'Restoring backup from Google Drive...',
                          'গুগল ড্রাইভ থেকে ব্যাকআপ রিস্টোর হচ্ছে...',
                        )
                            : (_isBackingUp
                            ? txProvider.tr(
                          'Uploading encrypted snapshot to Google Drive...',
                          'গুগল ড্রাইভে ব্যাকআপ আপলোড হচ্ছে...',
                        )
                            : txProvider.cloudStatus),
                        style: const TextStyle(
                          color: Color(0xFFE0F2FE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                      setState(() => _isBackingUp = true);
                      final res = await txProvider
                          .backupFullAccountToGoogleDrive();
                      if (!context.mounted) return;
                      setState(() => _isBackingUp = false);
                      _showFloatingNotice(
                        context,
                        res['message']?.toString() ?? '',
                        isError: res['success'] != true,
                      );
                    },
                    icon: _isBackingUp
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add_to_drive_rounded, size: 18),
                    label: Text(
                      _isBackingUp
                          ? txProvider.tr('Backing up...', 'ব্যাকআপ হচ্ছে...')
                          : txProvider.tr('Backup to Drive', 'ড্রাইভে ব্যাকআপ'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                      setState(() => _isRestoring = true);
                      final res = await txProvider
                          .restoreFullAccountFromGoogleDrive(
                        preserveCurrentAccountEmail: true,
                      );
                      if (!context.mounted) return;
                      setState(() => _isRestoring = false);
                      _showFloatingNotice(
                        context,
                        res['message']?.toString() ?? '',
                        isError: res['success'] != true,
                      );
                    },
                    icon: _isRestoring
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: Text(
                      _isRestoring
                          ? txProvider.tr('Restoring...', 'রিস্টোর হচ্ছে...')
                          : txProvider.tr(
                        'Restore from Drive',
                        'ড্রাইভ থেকে রিস্টোর',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // EXPORT .JSON FILE & OPEN FULL STATEMENT HUB (NO UNENCRYPTED CLIPBOARD COPY)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => txProvider.downloadFullAccountBackupFile(),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: Text(
                      txProvider.tr('Export .JSON File', 'ফাইল ডাউনলোড (.JSON)'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExportScreen(
                            userName: txProvider.userName,
                            userEmail: txProvider.cloudEmail,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assessment_outlined, size: 16),
                    label: Text(
                      txProvider.tr('Statements & CSV', 'স্টেটমেন্ট ও CSV'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // PASTE BACKUP JSON TO IMPORT
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    enabled: !busy,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: txProvider.tr(
                        'Paste Backup JSON to import...',
                        'ইমপোর্ট করতে ব্যাকআপ পেস্ট করুন...',
                      ),
                      hintStyle:
                      const TextStyle(color: Colors.grey, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                    if (_codeCtrl.text.trim().isEmpty) {
                      _showFloatingNotice(
                        context,
                        txProvider.tr(
                          'Paste a valid backup JSON before importing.',
                          'ইমপোর্ট করার আগে সঠিক ব্যাকআপ JSON পেস্ট করুন।',
                        ),
                        isError: true,
                      );
                      return;
                    }
                    setState(() => _isImporting = true);
                    final res =
                    await txProvider.restoreAccountFromBackupPayload(
                      _codeCtrl.text,
                      preserveCurrentAccountEmail: true,
                    );
                    if (!context.mounted) return;
                    setState(() => _isImporting = false);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                    }
                    _showFloatingNotice(
                      context,
                      res['message']?.toString() ?? '',
                      isError: res['success'] != true,
                    );
                  },
                  child: Text(
                    txProvider.tr('Import', 'ইমপোর্ট'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PROFILE & SETTINGS SCREEN
// =============================================================================
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  static void showCloudSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CloudSyncSheetBody(),
    );
  }

  static void showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final alerts = provider.activeAlerts;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.tr(
                        'Notifications & Alerts',
                        'নোটিফিকেশন ও সতর্কতা',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      activeThumbColor: const Color(0xFF0EA5E9),
                      value: provider.notificationsEnabled,
                      onChanged: (v) => provider.toggleNotifications(v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      provider.tr(
                        'All caught up! No active alerts.',
                        'কোনো নতুন সতর্কবার্তা নেই।',
                      ),
                      style: const TextStyle(color: Color(0xFF10B981)),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: alerts.length,
                      itemBuilder: (c, i) {
                        final a = alerts[i];
                        final color = Color(a['color'] as int);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      a['body']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Widget _buildProfileAvatar(String photoBase64, bool isDarkMode) {
    if (photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return buildTrueColorWrapper(
          isDarkMode: isDarkMode,
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF0EA5E9),
            backgroundImage: MemoryImage(bytes),
          ),
        );
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 36,
      backgroundColor: Color(0xFF0EA5E9),
      child: Icon(Icons.person, size: 40, color: Colors.white),
    );
  }

  Future<void> _confirmAndDeleteAccount(
      BuildContext context,
      TransactionProvider provider,
      ) async {
    final confirmed = await AppFeedback.confirmTypedDelete(
      context,
      title: provider.tr(
        'Delete Account Permanently?',
        'অ্যাকাউন্ট স্থায়ীভাবে ডিলিট করবেন?',
      ),
      message: provider.tr(
        'This permanently erases all transactions, wallets, budgets, groups, POS records, and cached Drive status on this device. No automatic backup will be created.',
        'এতে আপনার সকল লেনদেন, ওয়ালেট, বাজেট, গ্রুপ এবং পিওএস ডাটা স্থায়ীভাবে মুছে যাবে। কোনো স্বয়ংক্রিয় ব্যাকআপ তৈরি হবে না।',
      ),
      requiredWord: 'DELETE',
    );
    if (!confirmed || !context.mounted) return;

    await provider.deleteFullAccount(backupToDriveFirst: false);
    if (!context.mounted) return;

    _showFloatingNotice(
      context,
      provider.tr(
        'Account and all active data permanently deleted.',
        'অ্যাকাউন্ট এবং সকল ডাটা স্থায়ীভাবে মুছে ফেলা হয়েছে।',
      ),
      isError: true,
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _showCurrencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                provider.tr('Select Display Currency', 'মুদ্রা নির্বাচন করুন'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...AppCurrency.supportedCurrencies.entries.map((entry) {
                final isSelected = provider.currencyCode == entry.key;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: const Color(0xFF38BDF8),
                  ),
                  title: Text(
                    '${entry.key} (${entry.value})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    provider.setCurrencyCode(entry.key);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppLockDialog(BuildContext context, TransactionProvider provider) {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provider.appLockEnabled
                    ? provider.tr('Manage App PIN Lock', 'অ্যাপ পিন লক পরিচালনা')
                    : provider.tr('Enable App PIN Lock', 'অ্যাপ পিন লক চালু করুন'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  final len = (v?.trim() ?? '').length;
                  if (len < 4 || len > 6) {
                    return provider.tr(
                      'Enter a 4 to 6 digit PIN',
                      '৪ থেকে ৬ সংখ্যার পিন দিন',
                    );
                  }
                  return null;
                },
                decoration: InputDecoration(
                  counterText: '',
                  labelText: provider.tr('New PIN (4–6 digits)', 'নতুন পিন (৪–৬ সংখ্যা)'),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v != pinCtrl.text) {
                    return provider.tr('PINs do not match', 'পিন দুটি মেলেনি');
                  }
                  return null;
                },
                decoration: InputDecoration(
                  counterText: '',
                  labelText: provider.tr('Confirm PIN', 'পিন নিশ্চিত করুন'),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (provider.appLockEnabled)
            TextButton(
              onPressed: () async {
                await provider.disableAppLock();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  _showFloatingNotice(
                    context,
                    provider.tr('App PIN Lock disabled.', 'অ্যাপ পিন লক বন্ধ হয়েছে।'),
                    isError: false,
                  );
                }
              },
              child: Text(
                provider.tr('Disable Lock', 'লক বন্ধ করুন'),
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await provider.setAppLockPin(pinCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                _showFloatingNotice(
                  context,
                  provider.tr('App PIN Lock saved.', 'অ্যাপ পিন লক সেট হয়েছে।'),
                  isError: false,
                );
              }
            },
            child: Text(provider.tr('Save PIN', 'পিন সেভ করুন')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          txProvider.tr('Account & Settings', 'অ্যাকাউন্ট ও সেটিংস'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // BUSINESS MODE SWITCHER
              GestureDetector(
                onTap: () async {
                  await txProvider.saveNavigationState(isBusinessMode: true);
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessNavigationScreen(),
                    ),
                        (route) => false,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF0EA5E9),
                        child: Icon(Icons.storefront, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txProvider.tr(
                                'Switch to Business POS Mode',
                                'বিজনেস পিওএস মোডে যান',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              txProvider.tr(
                                'Manage sales, COGS profit, inventory, and party dues',
                                'বিক্রয়, লাভ-ক্ষতি, স্টক ইনভেন্টরি এবং কাস্টমার বাকি পরিচালনা করুন',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFF38BDF8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // PROFILE CARD (NO MID-WORD EMAIL WRAPPING)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildProfileAvatar(
                          txProvider.userPhotoBase64,
                          txProvider.isDarkMode,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txProvider.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (txProvider.userOccupation.isNotEmpty)
                                Text(
                                  txProvider.userOccupation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: Text(
                            txProvider.tr('Edit', 'এডিট'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Full-width email row prevents awkward mid-word line breaks
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            txProvider.cloudEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.add_to_drive_rounded,
                          size: 14,
                          color: txProvider.isGoogleConnected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Google Drive: ${txProvider.connectedGoogleEmail}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: txProvider.isGoogleConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (txProvider.userPhone.isNotEmpty ||
                        txProvider.userAddress.isNotEmpty ||
                        txProvider.userDob.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (txProvider.userPhone.isNotEmpty)
                            Text(
                              '📞 ${txProvider.userPhone}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          if (txProvider.userDob.isNotEmpty)
                            Text(
                              '🎂 ${txProvider.userDob}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          if (txProvider.userAddress.isNotEmpty)
                            Text(
                              '📍 ${txProvider.userAddress}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              _buildSectionHeader(
                txProvider.tr(
                  'Backup, Statements & Data Export',
                  'ব্যাকআপ, স্টেটমেন্ট ও ডাটা এক্সপোর্ট',
                ),
              ),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.add_to_drive_rounded,
                  txProvider.tr(
                    'Google Drive Direct Backup & Restore',
                    'সরাসরি গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর',
                  ),
                  subtitleText: txProvider.connectedGoogleEmail,
                  onTap: () => ProfileScreen.showCloudSyncSheet(context),
                ),
                _buildSettingsTile(
                  Icons.import_export,
                  txProvider.tr(
                    'Backup & Statement Export (.JSON, CSV, PDF, PNG, JPG)',
                    'স্টেটমেন্ট এক্সপোর্ট ও ইমপোর্ট (.JSON, CSV, PDF, PNG, JPG)',
                  ),
                  trailingText: txProvider.tr('Open Hub', 'খুলুন'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportScreen(
                        userName: txProvider.userName,
                        userEmail: txProvider.cloudEmail,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 22),

              _buildSectionHeader(
                txProvider.tr(
                  'Preferences, Privacy & Security',
                  'পছন্দসমূহ, গোপনীয়তা ও নিরাপত্তা',
                ),
              ),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.currency_exchange_rounded,
                  txProvider.tr('Currency', 'মুদ্রা (Currency)'),
                  trailingText:
                  '${txProvider.currencyCode} (${txProvider.currencySymbol})',
                  onTap: () => _showCurrencySheet(context),
                ),
                _buildSettingsTile(
                  Icons.lock_outline_rounded,
                  txProvider.tr('App PIN Lock', 'অ্যাপ পিন লক'),
                  trailingText: txProvider.appLockEnabled
                      ? txProvider.tr('Enabled', 'চালু')
                      : txProvider.tr('Off', 'বন্ধ'),
                  onTap: () => _showAppLockDialog(context, txProvider),
                ),
                _buildSettingsTile(
                  Icons.visibility_off_outlined,
                  txProvider.tr('Hide All Balances', 'সকল ব্যালেন্স লুকান'),
                  trailingText: txProvider.hideBalances
                      ? txProvider.tr('Hidden', 'লুকানো')
                      : txProvider.tr('Visible', 'দৃশ্যমান'),
                  onTap: () => txProvider.toggleHideBalances(),
                ),
                _buildSettingsTile(
                  Icons.translate_rounded,
                  txProvider.tr('App Language / ভাষা', 'অ্যাপের ভাষা (Language)'),
                  trailingText: txProvider.isBengali ? 'বাংলা' : 'English',
                  onTap: () => _showLanguageSheet(context),
                ),
                _buildSettingsTile(
                  Icons.palette_outlined,
                  txProvider.tr('Appearance', 'থিম ও কালার'),
                  trailingText: txProvider.isDarkMode
                      ? txProvider.tr('Dark Mode', 'ডার্ক মোড')
                      : txProvider.tr('Light Mode', 'লাইট মোড'),
                  onTap: () =>
                      txProvider.toggleDarkMode(!txProvider.isDarkMode),
                ),
                _buildSettingsTile(
                  Icons.notifications_active_outlined,
                  txProvider.tr(
                    'Notifications & Alerts',
                    'নোটিফিকেশন ও সতর্কতা',
                  ),
                  trailingText: '${txProvider.activeAlerts.length}',
                  onTap: () => ProfileScreen.showNotificationsSheet(context),
                ),
              ]),
              const SizedBox(height: 22),

              _buildSectionHeader(
                txProvider.tr('Financial Modules', 'আর্থিক ব্যবস্থাপনা'),
              ),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.account_balance_wallet_outlined,
                  txProvider.tr(
                    'Wallets & Bank Accounts',
                    'ওয়ালেট ও ব্যাংক অ্যাকাউন্ট',
                  ),
                  trailingText: '${txProvider.wallets.length}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletsScreen()),
                  ),
                ),
                _buildSettingsTile(
                  Icons.update,
                  txProvider.tr(
                    'Scheduled Bills & Reminders',
                    'নির্ধারিত বিল ও রিমাইন্ডার',
                  ),
                  trailingText: '${txProvider.scheduledTxs.length}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScheduledTransactionsScreen(),
                    ),
                  ),
                ),
                _buildSettingsTile(
                  Icons.calculate_outlined,
                  txProvider.tr(
                    'CalcBox Financial Calculator',
                    'ক্যালকবক্স ফিন্যান্সিয়াল ক্যালকুলেটর',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalcBoxScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: 22),

              _buildSectionHeader(
                txProvider.tr('Help & Support', 'সহায়তা ও সাপোর্ট'),
              ),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.help_outline,
                  txProvider.tr(
                    'Help Center & User Guide',
                    'হেল্প সেন্টার ও গাইড',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                  ),
                ),
                _buildSettingsTile(
                  Icons.mail_outline_rounded,
                  txProvider.tr('Contact Support', 'সাপোর্টে যোগাযোগ করুন'),
                  subtitleText: 'corps.rifat@outlook.com',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContactSupportScreen(),
                    ),
                  ),
                ),
                _buildSettingsTile(
                  Icons.description_outlined,
                  txProvider.tr(
                    'Terms and Policies',
                    'শর্তাবলী ও গোপনীয়তা নীতি',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsPoliciesScreen(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 26),

              // SIGN OUT & DELETE ACCOUNT BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await txProvider.clearSessionOnLogout();
                        await AuthService.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                                (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(
                        txProvider.tr('Sign Out', 'লগ আউট'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFFEF4444).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () =>
                          _confirmAndDeleteAccount(context, txProvider),
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(
                        txProvider.tr('Delete Account', 'অ্যাকাউন্ট ডিলিট'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.tr(
                  'Select Application Language',
                  'অ্যাপের ভাষা নির্বাচন করুন',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  !provider.isBengali
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF38BDF8),
                ),
                title: const Text(
                  'English (Default)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  provider.setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  provider.isBengali
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF38BDF8),
                ),
                title: const Text(
                  'বাংলা (Bengali)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  provider.setLanguage('bn');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final int index = entry.key;
          final Widget tile = entry.value;
          if (index != tiles.length - 1) {
            return Column(
              children: [
                tile,
                const Divider(
                  color: Color(0xFF334155),
                  height: 1,
                  indent: 52,
                  endIndent: 16,
                ),
              ],
            );
          }
          return tile;
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsTile(
      IconData icon,
      String title, {
        String? subtitleText,
        String? trailingText,
        required VoidCallback onTap,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF38BDF8), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitleText != null
          ? Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                trailingText,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (trailingText != null) const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

// =============================================================================
// EDIT PROFILE SCREEN WITH LINKEDIN-STYLE CROPPER & VALIDATION
// =============================================================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _organizationCtrl;
  late TextEditingController _addressCtrl;
  String? _selectedGender;
  String _photoBase64 = '';
  Uint8List? _originalPhotoBytes;
  bool _isSaving = false;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<TransactionProvider>();
    _nameCtrl = TextEditingController(text: p.userName);
    _phoneCtrl = TextEditingController(text: p.userPhone);
    _emailCtrl = TextEditingController(
      text: p.cloudEmail == 'Not signed in' ? '' : p.cloudEmail,
    );
    _dobCtrl = TextEditingController(text: p.userDob);
    _occupationCtrl = TextEditingController(text: p.userOccupation);
    _organizationCtrl = TextEditingController(text: p.userOrganization);
    _addressCtrl = TextEditingController(text: p.userAddress);
    _selectedGender =
    _genderOptions.contains(p.userGender) ? p.userGender : null;
    _photoBase64 = p.userPhotoBase64;
    if (_photoBase64.isNotEmpty) {
      try {
        _originalPhotoBytes = base64Decode(_photoBase64);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _occupationCtrl.dispose();
    _organizationCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );
      if (picked == null) return;

      final Uint8List rawBytes = await picked.readAsBytes();
      _originalPhotoBytes = rawBytes;

      if (!mounted) return;
      await _openCropDialog(rawBytes);
    } catch (e) {
      if (mounted) {
        _showFloatingNotice(context, 'Could not pick image: $e', isError: true);
      }
    }
  }

  Future<void> _openCropDialog(Uint8List sourceBytes) async {
    final String? croppedBase64 = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LinkedInPhotoCropperDialog(imageBytes: sourceBytes),
    );

    if (croppedBase64 != null && mounted) {
      setState(() => _photoBase64 = croppedBase64);
    }
  }

  Future<void> _selectDob() async {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final isDarkMode = provider.isDarkMode;
    ImageProvider? avatarImg;
    if (_photoBase64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(_photoBase64));
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          provider.tr('Edit Profile', 'প্রোফাইল এডিট করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        buildTrueColorWrapper(
                          isDarkMode: isDarkMode && avatarImg != null,
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFF0EA5E9),
                            backgroundImage: avatarImg,
                            child: avatarImg == null
                                ? const Icon(
                              Icons.person,
                              size: 54,
                              color: Colors.white,
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _pickAndCropImage(ImageSource.gallery),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                              ),
                              label: Text(
                                provider.tr('Upload Photo', 'ছবি আপলোড'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (_originalPhotoBytes != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                ),
                                onPressed: () =>
                                    _openCropDialog(_originalPhotoBytes!),
                                icon: const Icon(Icons.crop_rotate, size: 16),
                                label: Text(
                                  provider.tr('Crop Photo', 'ক্রপ করুন'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildField(
                    _nameCtrl,
                    provider.tr('Full Name *', 'পুরো নাম *'),
                    Icons.person_outline,
                    validator: (v) => AppValidators.requiredText(v, 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _phoneCtrl,
                    provider.tr('Phone Number', 'ফোন নম্বর'),
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: AppValidators.digitsAndPlusOnly,
                    validator: (v) =>
                        AppValidators.phoneNumber(v, required: false),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _emailCtrl,
                    provider.tr('Email Address *', 'ইমেইল ঠিকানা *'),
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: AppValidators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    onTap: _selectDob,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Date of Birth', 'জন্ম তারিখ'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(
                        Icons.cake_outlined,
                        color: Color(0xFF38BDF8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Gender (Optional)', 'লিঙ্গ (ঐচ্ছিক)'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(
                        Icons.wc_outlined,
                        color: Color(0xFF38BDF8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _genderOptions
                        .map(
                          (g) => DropdownMenuItem<String>(
                        value: g,
                        child: Text(g),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGender = v),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _occupationCtrl,
                    provider.tr('Occupation', 'পেশা'),
                    Icons.work_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _organizationCtrl,
                    provider.tr('Organization / Company', 'প্রতিষ্ঠান'),
                    Icons.business_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    _addressCtrl,
                    provider.tr('Full Address', 'ঠিকানা'),
                    Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      setState(() => _isSaving = true);
                      await context
                          .read<TransactionProvider>()
                          .updateUserProfile(
                        name: _nameCtrl.text,
                        email: _emailCtrl.text,
                        phone: _phoneCtrl.text,
                        dob: _dobCtrl.text,
                        gender: _selectedGender ?? '',
                        occupation: _occupationCtrl.text,
                        organization: _organizationCtrl.text,
                        address: _addressCtrl.text,
                        photoBase64: _photoBase64,
                      );
                      if (context.mounted) {
                        setState(() => _isSaving = false);
                        _showFloatingNotice(
                          context,
                          provider.tr(
                            'Profile updated successfully.',
                            'প্রোফাইল সফলভাবে আপডেট হয়েছে।',
                          ),
                          isError: false,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      provider.tr('Save Changes', 'পরিবর্তন সেভ করুন'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class LinkedInPhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const LinkedInPhotoCropperDialog({super.key, required this.imageBytes});

  @override
  State<LinkedInPhotoCropperDialog> createState() =>
      _LinkedInPhotoCropperDialogState();
}

class _LinkedInPhotoCropperDialogState
    extends State<LinkedInPhotoCropperDialog> {
  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;
  int _quarterTurns = 0;
  bool _isProcessing = false;

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);
    try {
      img.Image? decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        if (mounted) Navigator.pop(context, base64Encode(widget.imageBytes));
        return;
      }
      if (_quarterTurns % 4 != 0) {
        decoded = img.copyRotate(decoded, angle: (_quarterTurns % 4) * 90);
      }
      final int minSide = math.min(decoded.width, decoded.height);
      final int cropSize = (minSide / _zoom).round().clamp(40, minSide);
      final double normX = (-_panOffset.dx / 120.0).clamp(-1.0, 1.0);
      final double normY = (-_panOffset.dy / 120.0).clamp(-1.0, 1.0);
      final int maxOffsetX = math.max(0, (decoded.width - cropSize) ~/ 2);
      final int maxOffsetY = math.max(0, (decoded.height - cropSize) ~/ 2);
      final int centerX = decoded.width ~/ 2 + (normX * maxOffsetX).round();
      final int centerY = decoded.height ~/ 2 + (normY * maxOffsetY).round();
      final int startX = (centerX - cropSize ~/ 2)
          .clamp(0, math.max(0, decoded.width - cropSize));
      final int startY = (centerY - cropSize ~/ 2)
          .clamp(0, math.max(0, decoded.height - cropSize));

      final img.Image cropped = img.copyCrop(
        decoded,
        x: startX,
        y: startY,
        width: cropSize,
        height: cropSize,
      );
      final img.Image resized = img.copyResize(cropped, width: 240, height: 240);
      final Uint8List jpgBytes =
      Uint8List.fromList(img.encodeJpg(resized, quality: 88));

      if (mounted) Navigator.pop(context, base64Encode(jpgBytes));
    } catch (_) {
      if (mounted) Navigator.pop(context, base64Encode(widget.imageBytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<TransactionProvider>().isDarkMode;
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Crop & Adjust Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                    _panOffset = Offset(
                      _panOffset.dx.clamp(-120.0, 120.0),
                      _panOffset.dy.clamp(-120.0, 120.0),
                    );
                  });
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: buildTrueColorWrapper(
                      isDarkMode: isDarkMode,
                      child: Transform.translate(
                        offset: _panOffset,
                        child: Transform.scale(
                          scale: _zoom,
                          child: RotatedBox(
                            quarterTurns: _quarterTurns,
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.cover,
                              width: 220,
                              height: 220,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Slider(
                value: _zoom,
                min: 1.0,
                max: 3.5,
                activeColor: const Color(0xFF0EA5E9),
                onChanged: (v) => setState(() => _zoom = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _quarterTurns = (_quarterTurns - 1) % 4),
                    icon: const Icon(Icons.rotate_left, size: 18),
                    label: const Text('Rotate'),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _applyCrop,
                    child: const Text(
                      'Apply Photo',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HELP CENTER, CONTACT SUPPORT & TERMS
// =============================================================================
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(p.tr('Help Center', 'হেল্প সেন্টার')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: Text(
              p.tr(
                '1. Manual Google Drive Backup & Restore',
                '১. গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              p.tr(
                'All backups and restores are 100% manual. Tap Backup to Drive or Restore from Drive to choose your Google account and grant permission.',
                'সকল ব্যাকআপ ও রিস্টোর সম্পূর্ণ ম্যানুয়াল। ড্রাইভ ব্যাকআপ বা রিস্টোর বাটনে ট্যাপ করলে ডিভাইসের গুগল অ্যাকাউন্ট নির্বাচন ও অনুমতি চাওয়া হবে।',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ListTile(
            title: Text(
              p.tr(
                '2. Permanent Account Deletion',
                '২. স্থায়ীভাবে অ্যাকাউন্ট ডিলিট',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              p.tr(
                'Deleting your account requires typing DELETE and permanently wipes all active data and cached session metadata.',
                'অ্যাকাউন্ট ডিলিট করতে DELETE লিখতে হবে এবং সকল সক্রিয় ডাটা স্থায়ীভাবে মুছে যাবে।',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ListTile(
            title: Text(
              p.tr(
                '3. App PIN Lock & Global Privacy Toggle',
                '৩. অ্যাপ পিন লক ও ব্যালেন্স হাইড',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              p.tr(
                'Use the eye icon in the top bar to mask amounts across every tab, or enable a 4–6 digit App PIN Lock in Settings.',
                'উপরের আইকনে ট্যাপ করে সকল ব্যালেন্স লুকাতে পারেন অথবা সেটিংস থেকে অ্যাপ পিন লক চালু করতে পারেন।',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const String supportEmail = 'corps.rifat@outlook.com';
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendDirectEmail(TransactionProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final subject = _subjectCtrl.text.trim();
    final body =
        '${_messageCtrl.text.trim()}\n\nUser: ${provider.userName} (${provider.cloudEmail})';
    setState(() => _isSending = true);
    try {
      await http
          .post(
        Uri.parse('https://ntfy.sh/finblend_support_corps_rifat'),
        headers: {'Title': subject},
        body: body,
      )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    final Uri mailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(mailUri);
    } catch (_) {}
    if (mounted) {
      setState(() => _isSending = false);
      _showFloatingNotice(
        context,
        'Prepared message for $supportEmail',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(provider.tr('Contact Support', 'সাপোর্টে যোগাযোগ')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SelectableText(
                'Direct Support: corps.rifat@outlook.com',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectCtrl,
                validator: (v) => AppValidators.requiredText(v, 'Subject'),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.tr('Subject *', 'বিষয় *'),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                validator: (v) => AppValidators.requiredText(v, 'Message'),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.tr('Message *', 'বার্তা *'),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSending ? null : () => _sendDirectEmail(provider),
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  provider.tr(
                    'Send to corps.rifat@outlook.com',
                    'corps.rifat@outlook.com এ পাঠান',
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

class TermsPoliciesScreen extends StatelessWidget {
  const TermsPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(p.tr('Terms & Policies', 'শর্তাবলী ও নীতিমালা')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          p.tr(
            'All financial records, receipts, memos, and full account backups remain under your control on this device and your authorized Google Drive.',
            'সকল আর্থিক তথ্য, রসিদ, মেমো এবং সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ আপনার ডিভাইস ও অনুমোদিত গুগল ড্রাইভে নিরাপদে সংরক্ষিত থাকে।',
          ),
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}