import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'dashboard.dart';
import 'business_navigation.dart';
import 'records_screen.dart';
import 'budgets_screen.dart';
import 'groups_screen.dart';
import 'categories_screen.dart';
import 'wallets_screen.dart';
import 'export_screen.dart';
import 'providers/transaction_provider.dart';

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

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onSeeAll: () => setState(() => _currentIndex = 1));
      case 1:
        return const RecordsScreen();
      case 2:
        return const BudgetsScreen();
      case 3:
        return const GroupsScreen();
      case 4:
        return const CategoriesScreen();
      default:
        return DashboardScreen(onSeeAll: () => setState(() => _currentIndex = 1));
    }
  }

  Widget _buildUserAvatar(String photoBase64, bool isDarkMode, {double radius = 18}) {
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
    final alerts = txProvider.activeAlerts;
    final bool isWideWebLayout = MediaQuery.of(context).size.width >= 800;

    final appBarActions = [
      // 1. 1-TAP BENGALI / ENGLISH SWITCHER
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => txProvider.toggleLanguage(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            alignment: Alignment.center,
            child: Text(
              txProvider.isBengali ? 'EN' : 'বাংলা',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),

      // 2. CLOUD & GOOGLE DRIVE SYNC BUTTON
      IconButton(
        tooltip: txProvider.tr('Google Drive Backup & Restore', 'গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর'),
        icon: txProvider.isSyncing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
        )
            : const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8)),
        onPressed: () => ProfileScreen.showCloudSyncSheet(context),
      ),

      // 3. NOTIFICATION BELL
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: txProvider.tr('Notifications', 'নোটিফিকেশন'),
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () => ProfileScreen.showNotificationsSheet(context),
          ),
          if (alerts.isNotEmpty)
            Positioned(
              right: 8,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: Text(
                  '${alerts.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),

      // 4. DARK / LIGHT THEME TOGGLE
      IconButton(
        tooltip: txProvider.tr('Switch Theme', 'থিম পরিবর্তন'),
        icon: Icon(
          txProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: const Color(0xFF38BDF8),
        ),
        onPressed: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
      ),

      // 5. PROFILE AVATAR
      Padding(
        padding: const EdgeInsets.only(right: 16.0, left: 4.0),
        child: GestureDetector(
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
          child: _buildUserAvatar(txProvider.userPhotoBase64, txProvider.isDarkMode, radius: 18),
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
              const Icon(Icons.account_balance_rounded, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 10),
              Text(
                txProvider.tr('FinBlend Financial Suite', 'ফিনব্লেন্ড ফিন্যান্সিয়াল সুইট'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${txProvider.cloudStatus} • ${txProvider.cloudEmail}',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          actions: appBarActions,
        ),
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1050,
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              selectedIconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
              unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
              selectedLabelTextStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Color(0xFF94A3B8)),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.storefront, size: 18),
                  label: Text(
                    txProvider.tr('Business POS', 'বিজনেস পিওএস'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                  label: Text(txProvider.tr('Transactions', 'লেনদেন')),
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
                  label: Text(txProvider.tr('Categories', 'ক্যাটাগরি')),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF334155)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
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
        title: const Text('FinBlend', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        actions: appBarActions,
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: Color(0xFF38BDF8)),
            label: txProvider.tr('Home', 'হোম'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long, color: Color(0xFF38BDF8)),
            label: txProvider.tr('Records', 'লেনদেন'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart, color: Color(0xFF38BDF8)),
            label: txProvider.tr('Budgets', 'বাজেট'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group, color: Color(0xFF38BDF8)),
            label: txProvider.tr('Groups', 'গ্রুপ'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category, color: Color(0xFF38BDF8)),
            label: txProvider.tr('Labels', 'ক্যাটাগরি'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE & SETTINGS SCREEN (MANUAL GOOGLE DRIVE PERMISSION + PERMANENT DELETE)
// =============================================================================
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({super.key, required this.userName, required this.userEmail});

  static void showCloudSyncSheet(BuildContext context) {
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, txProvider, _) => Padding(
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
                      child: Row(
                        children: [
                          const Icon(Icons.add_to_drive_rounded, color: Color(0xFF38BDF8), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              txProvider.tr('Google Drive Backup & Restore', 'গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর'),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${txProvider.tr("Google Drive", "গুগল ড্রাইভ")}: ${txProvider.connectedGoogleEmail}',
                        style: TextStyle(
                          color: txProvider.isGoogleConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${txProvider.tr("Last Backup", "সর্বশেষ ব্যাকআপ")}: ${txProvider.lastGoogleDriveBackupAt}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // DIRECT GOOGLE DRIVE BACKUP & RESTORE (WITH DEVICE GOOGLE PERMISSION)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: txProvider.isSyncing
                            ? null
                            : () async {
                          final res = await txProvider.backupFullAccountToGoogleDrive();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text(res['message']?.toString() ?? ''),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                        label: Text(
                          txProvider.tr('Backup to Drive', 'ড্রাইভে ব্যাকআপ'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: txProvider.isSyncing
                            ? null
                            : () async {
                          final res = await txProvider.restoreFullAccountFromGoogleDrive(
                            preserveCurrentAccountEmail: true,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text(res['message']?.toString() ?? ''),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: Text(
                          txProvider.tr('Restore from Drive', 'ড্রাইভ থেকে রিস্টোর'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // EXPORT .JSON FILE & COPY BACKUP JSON
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => txProvider.downloadFullAccountBackupFile(),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: Text(
                          txProvider.tr('Export .json File', 'ফাইল ডাউনলোড (.json)'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txProvider.generateFullAccountBackupString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: Color(0xFF10B981), content: Text('Backup JSON copied to clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(
                          txProvider.tr('Copy Backup JSON', 'ব্যাকআপ কপি'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // PASTE BACKUP JSON TO IMPORT INTO CURRENT ACCOUNT
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: txProvider.tr('Paste Backup JSON to import...', 'ইমপোর্ট করতে ব্যাকআপ পেস্ট করুন...'),
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
                      onPressed: () async {
                        if (codeCtrl.text.trim().isNotEmpty) {
                          final res = await txProvider.restoreAccountFromBackupPayload(
                            codeCtrl.text,
                            preserveCurrentAccountEmail: true,
                          );
                          if (ctx.mounted && res['success'] == true) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                content: Text(res['message']?.toString() ?? ''),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(txProvider.tr('Import', 'ইমপোর্ট'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      provider.tr('Notifications & Alerts', 'নোটিফিকেশন ও সতর্কতা'),
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
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
                      provider.tr('All caught up! No active alerts.', 'কোনো নতুন সতর্কবার্তা নেই।'),
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
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active_outlined, color: color),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 3),
                                    Text(a['body']?.toString() ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
            radius: 40,
            backgroundColor: const Color(0xFF0EA5E9),
            backgroundImage: MemoryImage(bytes),
          ),
        );
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 40,
      backgroundColor: Color(0xFF0EA5E9),
      child: Icon(Icons.person, size: 44, color: Colors.white),
    );
  }

  // ===========================================================================
  // PERMANENT ACCOUNT DELETION (100% MANUAL BACKUP POLICY)
  // ===========================================================================
  void _showDeleteAccountConfirmationDialog(BuildContext context, TransactionProvider provider) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.tr('Delete Account Permanently?', 'অ্যাকাউন্ট স্থায়ীভাবে ডিলিট করবেন?'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            provider.tr(
              'Deleting your account will permanently erase all active transactions, wallets, budgets, and groups. No automatic backup will be created. If you want a backup, please export or back up to Google Drive manually before deleting.',
              'অ্যাকাউন্ট ডিলিট করলে আপনার সকল লেনদেন, ওয়ালেট, বাজেট এবং গ্রুপ স্থায়ীভাবে মুছে যাবে। কোনো স্বয়ংক্রিয় ব্যাকআপ রাখা হবে না।',
            ),
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(provider.tr('Cancel', 'বাতিল'), style: const TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                setDialogState(() => isDeleting = true);
                await provider.deleteFullAccount(backupToDriveFirst: false);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFFEF4444),
                      content: Text(
                        provider.tr(
                          'Account and all active data permanently deleted.',
                          'অ্যাকাউন্ট এবং সকল ডাটা স্থায়ীভাবে মুছে ফেলা হয়েছে।',
                        ),
                      ),
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: Text(
                isDeleting
                    ? provider.tr('Deleting...', 'ডিলিট হচ্ছে...')
                    : provider.tr('Delete Permanently', 'স্থায়ীভাবে ডিলিট'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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
        title: Text(txProvider.tr('Account & Settings', 'অ্যাকাউন্ট ও সেটিংস'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // BUSINESS MODE SWITCHER
              GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const BusinessNavigationScreen()),
                        (route) => false,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: Color(0xFF0EA5E9), child: Icon(Icons.storefront, color: Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txProvider.tr('Switch to Business POS Mode', 'বিজনেস পিওএস মোডে যান'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              txProvider.tr('Manage sales, stock inventory, and customer dues', 'বিক্রয়, স্টক ইনভেন্টরি এবং কাস্টমার বাকি পরিচালনা করুন'),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF38BDF8), size: 16),
                    ],
                  ),
                ),
              ),

              // PROFILE CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildProfileAvatar(txProvider.userPhotoBase64, txProvider.isDarkMode),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(txProvider.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(txProvider.cloudEmail, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                'Google Drive: ${txProvider.connectedGoogleEmail}',
                                style: TextStyle(
                                  color: txProvider.isGoogleConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (txProvider.userOccupation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(txProvider.userOccupation, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: Text(txProvider.tr('Edit', 'এডিট'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (txProvider.userPhone.isNotEmpty || txProvider.userAddress.isNotEmpty || txProvider.userDob.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Color(0xFF334155), height: 1),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (txProvider.userPhone.isNotEmpty)
                            Text('📞 ${txProvider.userPhone}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          if (txProvider.userDob.isNotEmpty)
                            Text('🎂 ${txProvider.userDob}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          if (txProvider.userAddress.isNotEmpty)
                            Text('📍 ${txProvider.userAddress}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader(txProvider.tr('Full Account Backup & Google Drive', 'সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ ও গুগল ড্রাইভ')),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.add_to_drive_rounded,
                  txProvider.tr('Google Drive Direct Backup & Restore', 'সরাসরি গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর'),
                  trailingText: txProvider.connectedGoogleEmail,
                  onTap: () => ProfileScreen.showCloudSyncSheet(context),
                ),
                _buildSettingsTile(
                  Icons.import_export,
                  txProvider.tr('Full Account Export (.json, PDF, PNG, JPG)', 'সম্পূর্ণ অ্যাকাউন্ট এক্সপোর্ট ও ইমপোর্ট'),
                  trailingText: txProvider.tr('Backup / Import', 'ব্যাকআপ'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExportScreen(userName: txProvider.userName, userEmail: txProvider.cloudEmail)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(txProvider.tr('Preferences & Language', 'পছন্দসমূহ এবং ভাষা')),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.translate_rounded,
                  txProvider.tr('App Language / ভাষা', 'অ্যাপের ভাষা (Language)'),
                  trailingText: txProvider.isBengali ? 'বাংলা (Bengali)' : 'English',
                  onTap: () => _showLanguageSheet(context),
                ),
                _buildSettingsTile(
                  Icons.palette_outlined,
                  txProvider.tr('Appearance', 'থিম ও কালার'),
                  trailingText: txProvider.isDarkMode ? txProvider.tr('Dark Mode', 'ডার্ক মোড') : txProvider.tr('Light Mode', 'লাইট মোড'),
                  onTap: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
                ),
                _buildSettingsTile(
                  Icons.notifications_active_outlined,
                  txProvider.tr('Notifications & Alerts', 'নোটিফিকেশন ও সতর্কতা'),
                  trailingText: '${txProvider.activeAlerts.length}',
                  onTap: () => ProfileScreen.showNotificationsSheet(context),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(txProvider.tr('Financial Modules', 'আর্থিক ব্যবস্থাপনা')),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.account_balance_wallet_outlined,
                  txProvider.tr('Wallets & Bank Accounts', 'ওয়ালেট ও ব্যাংক অ্যাকাউন্ট'),
                  trailingText: '${txProvider.wallets.length}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                ),
                _buildSettingsTile(
                  Icons.update,
                  txProvider.tr('Scheduled Bills & Reminders', 'নির্ধারিত বিল ও রিমাইন্ডার'),
                  trailingText: '${txProvider.scheduledTxs.length}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledTransactionsScreen())),
                ),
                _buildSettingsTile(
                  Icons.calculate_outlined,
                  txProvider.tr('CalcBox Financial Calculator', 'ক্যালকবক্স ক্যালকুলেটর'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalcBoxScreen())),
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader(txProvider.tr('Help & Support', 'সহায়তা ও সাপোর্ট')),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.help_outline,
                  txProvider.tr('Help Center & User Guide', 'হেল্প সেন্টার ও গাইড'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
                ),
                _buildSettingsTile(
                  Icons.mail_outline_rounded,
                  txProvider.tr('Contact Support', 'সাপোর্টে যোগাযোগ করুন'),
                  trailingText: 'corps.rifat@outlook.com',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                ),
                _buildSettingsTile(
                  Icons.description_outlined,
                  txProvider.tr('Terms and Policies', 'শর্তাবলী ও গোপনীয়তা নীতি'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPoliciesScreen())),
                ),
              ]),
              const SizedBox(height: 28),

              // SIGN OUT & DELETE ACCOUNT BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await txProvider.clearSessionOnLogout();
                        await AuthService.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                        }
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(txProvider.tr('Sign Out', 'লগ আউট'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => _showDeleteAccountConfirmationDialog(context, txProvider),
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(txProvider.tr('Delete Account', 'অ্যাকাউন্ট ডিলিট'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.tr('Select Application Language', 'অ্যাপের ভাষা নির্বাচন করুন'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  !provider.isBengali ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: const Color(0xFF38BDF8),
                ),
                title: const Text('English (Default)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  provider.setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  provider.isBengali ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: const Color(0xFF38BDF8),
                ),
                title: const Text('বাংলা (Bengali)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
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
          int index = entry.key;
          Widget tile = entry.value;
          if (index != tiles.length - 1) {
            return Column(
              children: [
                tile,
                const Divider(color: Color(0xFF334155), height: 1, indent: 52, endIndent: 16),
              ],
            );
          }
          return tile;
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {String? trailingText, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF38BDF8), size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
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
// EDIT PROFILE SCREEN WITH LINKEDIN-STYLE CROPPER
// =============================================================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _organizationCtrl;
  late TextEditingController _addressCtrl;
  String _selectedGender = 'Male';
  String _photoBase64 = '';
  Uint8List? _originalPhotoBytes;
  bool _isSaving = false;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    final p = context.read<TransactionProvider>();
    _nameCtrl = TextEditingController(text: p.userName);
    _phoneCtrl = TextEditingController(text: p.userPhone);
    _emailCtrl = TextEditingController(text: p.cloudEmail == 'Not signed in' ? '' : p.cloudEmail);
    _dobCtrl = TextEditingController(text: p.userDob);
    _occupationCtrl = TextEditingController(text: p.userOccupation);
    _organizationCtrl = TextEditingController(text: p.userOrganization);
    _addressCtrl = TextEditingController(text: p.userAddress);
    _selectedGender = _genderOptions.contains(p.userGender) ? p.userGender : 'Male';
    _photoBase64 = p.userPhotoBase64;
    if (_photoBase64.isNotEmpty) {
      try {
        _originalPhotoBytes = base64Decode(_photoBase64);
      } catch (_) {}
    }
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 90);
      if (picked == null) return;

      final Uint8List rawBytes = await picked.readAsBytes();
      _originalPhotoBytes = rawBytes;

      if (!mounted) return;
      await _openCropDialog(rawBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  Future<void> _openCropDialog(Uint8List sourceBytes) async {
    final String? croppedBase64 = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LinkedInPhotoCropperDialog(imageBytes: sourceBytes),
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dobCtrl.text = '${picked.day} ${months[picked.month - 1]} ${picked.year}';
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
        title: Text(provider.tr('Edit Profile', 'প্রোফাইল এডিট করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                          child: avatarImg == null ? const Icon(Icons.person, size: 54, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                            onPressed: () => _pickAndCropImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: Text(provider.tr('Upload Photo', 'ছবি আপলোড'), style: const TextStyle(fontSize: 12)),
                          ),
                          if (_originalPhotoBytes != null)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF38BDF8)),
                              onPressed: () => _openCropDialog(_originalPhotoBytes!),
                              icon: const Icon(Icons.crop_rotate, size: 16),
                              label: Text(provider.tr('Crop Photo', 'ক্রপ করুন'), style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildField(_nameCtrl, provider.tr('Full Name', 'পুরো নাম'), Icons.person_outline),
                const SizedBox(height: 12),
                _buildField(_phoneCtrl, provider.tr('Phone Number', 'ফোন নম্বর'), Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(_emailCtrl, provider.tr('Email Address', 'ইমেইল ঠিকানা'), Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: _dobCtrl,
                  readOnly: true,
                  onTap: _selectDob,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: provider.tr('Date of Birth', 'জন্ম তারিখ'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                _buildField(_occupationCtrl, provider.tr('Occupation', 'পেশা'), Icons.work_outline),
                const SizedBox(height: 12),
                _buildField(_organizationCtrl, provider.tr('Organization / Company', 'প্রতিষ্ঠান'), Icons.business_outlined),
                const SizedBox(height: 12),
                _buildField(_addressCtrl, provider.tr('Full Address', 'ঠিকানা'), Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                    setState(() => _isSaving = true);
                    await context.read<TransactionProvider>().updateUserProfile(
                      name: _nameCtrl.text,
                      email: _emailCtrl.text,
                      phone: _phoneCtrl.text,
                      dob: _dobCtrl.text,
                      gender: _selectedGender,
                      occupation: _occupationCtrl.text,
                      organization: _organizationCtrl.text,
                      address: _addressCtrl.text,
                      photoBase64: _photoBase64,
                    );
                    if (context.mounted) {
                      setState(() => _isSaving = false);
                      Navigator.pop(context);
                    }
                  },
                  child: Text(provider.tr('Save Changes', 'পরিবর্তন সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class LinkedInPhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const LinkedInPhotoCropperDialog({super.key, required this.imageBytes});

  @override
  State<LinkedInPhotoCropperDialog> createState() => _LinkedInPhotoCropperDialogState();
}

class _LinkedInPhotoCropperDialogState extends State<LinkedInPhotoCropperDialog> {
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
      final int startX = (centerX - cropSize ~/ 2).clamp(0, math.max(0, decoded.width - cropSize));
      final int startY = (centerY - cropSize ~/ 2).clamp(0, math.max(0, decoded.height - cropSize));

      final img.Image cropped = img.copyCrop(decoded, x: startX, y: startY, width: cropSize, height: cropSize);
      final img.Image resized = img.copyResize(cropped, width: 240, height: 240);
      final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));

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
              const Text('Crop & Adjust Photo', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                    _panOffset = Offset(_panOffset.dx.clamp(-120.0, 120.0), _panOffset.dy.clamp(-120.0, 120.0));
                  });
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF38BDF8), width: 2),
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
                            child: Image.memory(widget.imageBytes, fit: BoxFit.cover, width: 220, height: 220),
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
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns - 1) % 4),
                    icon: const Icon(Icons.rotate_left, size: 18),
                    label: const Text('Rotate'),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _applyCrop,
                    child: const Text('Apply Photo', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
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
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), title: Text(p.tr('Help Center', 'হেল্প সেন্টার'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: Text(p.tr('1. Manual Google Drive Backup & Restore', '১. গুগল ড্রাইভ ব্যাকআপ ও রিস্টোর'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(p.tr('All backups and restores are 100% manual. When you tap Drive Backup or Restore from Drive, Google will ask you to select a device Google account and grant permission.', 'সকল ব্যাকআপ ও রিস্টোর সম্পূর্ণ ম্যানুয়াল। ড্রাইভ ব্যাকআপ বা রিস্টোর বাটনে ট্যাপ করলে ডিভাইসের গুগল অ্যাকাউন্ট নির্বাচন ও অনুমতি চাওয়া হবে।'), style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          ListTile(
            title: Text(p.tr('2. Permanent Account Deletion', '২. স্থায়ীভাবে অ্যাকাউন্ট ডিলিট'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(p.tr('Deleting your account permanently wipes all active data. If you sign back in later, your account starts empty unless you manually restore a previous backup.', 'অ্যাকাউন্ট ডিলিট করলে সকল সক্রিয় ডাটা মুছে যায়। পরবর্তীতে লগইন করলে অ্যাকাউন্টটি সম্পূর্ণ খালি থাকবে যতক্ষণ না আপনি ম্যানুয়ালি রিস্টোর করেন।'), style: const TextStyle(color: Color(0xFF94A3B8))),
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
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendDirectEmail(TransactionProvider provider) async {
    final subject = _subjectCtrl.text.trim().isEmpty ? 'FinBlend Support Request' : _subjectCtrl.text.trim();
    final body = '${_messageCtrl.text.trim()}\n\nUser: ${provider.userName} (${provider.cloudEmail})';
    setState(() => _isSending = true);
    try {
      await http.post(Uri.parse('https://ntfy.sh/finblend_support_corps_rifat'), headers: {'Title': subject}, body: body).timeout(const Duration(seconds: 5));
    } catch (_) {}
    final Uri mailUri = Uri(scheme: 'mailto', path: supportEmail, query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    try {
      await launchUrl(mailUri);
    } catch (_) {}
    if (mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF10B981), content: Text('Prepared message for corps.rifat@outlook.com')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), title: Text(provider.tr('Contact Support', 'সাপোর্টে যোগাযোগ'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SelectableText('Direct Support: corps.rifat@outlook.com', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: _subjectCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Subject', 'বিষয়'), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: _messageCtrl, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Message', 'বার্তা'), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _isSending ? null : () => _sendDirectEmail(provider),
              icon: const Icon(Icons.send_rounded),
              label: Text(provider.tr('Send to corps.rifat@outlook.com', 'corps.rifat@outlook.com এ পাঠান')),
            ),
          ],
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
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), title: Text(p.tr('Terms & Policies', 'শর্তাবলী ও নীতিমালা'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          p.tr(
            'All financial records, receipts, memos, and full account backups are encrypted and synchronized with your personal FinBlend Cloud ID and authorized Google Drive.',
            'সকল আর্থিক তথ্য, রসিদ, মেমো এবং সম্পূর্ণ অ্যাকাউন্ট ব্যাকআপ আপনার ব্যক্তিগত ফিনব্লেন্ড ক্লাউড আইডি ও অনুমোদিত গুগল ড্রাইভে নিরাপদে সংরক্ষিত থাকে।',
          ),
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}