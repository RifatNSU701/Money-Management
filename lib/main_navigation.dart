import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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

// Mathematical involution matrix: applying this a second time on photos in Light Mode
// cancels out the global Light Mode inversion and restores 100% true photo colors.
const List<double> kTrueColorPhotoMatrix = <double>[
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
            backgroundColor: Colors.teal,
            backgroundImage: MemoryImage(bytes),
          ),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.teal,
      child: Icon(Icons.person, size: radius * 1.1, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final alerts = txProvider.activeAlerts;
    final bool isWideWebLayout = MediaQuery.of(context).size.width >= 800;

    final appBarActions = [
      IconButton(
        tooltip: 'Cloud Sync (${txProvider.cloudStatus})',
        icon: txProvider.isSyncing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
        )
            : const Icon(Icons.cloud_done_outlined, color: Colors.tealAccent),
        onPressed: () => ProfileScreen.showCloudSyncSheet(context),
      ),
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Notifications & Alerts',
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () => ProfileScreen.showNotificationsSheet(context),
          ),
          if (alerts.isNotEmpty)
            Positioned(
              right: 8,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: Text(
                  '${alerts.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      IconButton(
        tooltip: 'Switch Dark / Light Mode',
        icon: Icon(
          txProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: Colors.tealAccent,
        ),
        onPressed: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
      ),
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
        backgroundColor: const Color(0xFF0E0E0E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141414),
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.tealAccent),
              const SizedBox(width: 10),
              const Text('FinBlend Web', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${txProvider.cloudStatus} • ${txProvider.cloudEmail}',
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600),
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
              backgroundColor: const Color(0xFF141414),
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              indicatorColor: Colors.tealAccent.withValues(alpha: 0.2),
              selectedIconTheme: const IconThemeData(color: Colors.tealAccent),
              unselectedIconTheme: const IconThemeData(color: Colors.grey),
              selectedLabelTextStyle: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F3A3D),
                    foregroundColor: Colors.tealAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.storefront, size: 18),
                  label: const Text('Business POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Records')),
                NavigationRailDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: Text('Budgets')),
                NavigationRailDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: Text('Groups & Split')),
                NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Labels')),
              ],
            ),
            const VerticalDivider(width: 1, color: Colors.white10),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: _buildPage(_currentIndex),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('FinBlend', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: appBarActions,
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF161616),
        indicatorColor: Colors.tealAccent.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: Colors.tealAccent), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Colors.tealAccent), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart, color: Colors.tealAccent), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group, color: Colors.tealAccent), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category, color: Colors.tealAccent), label: 'Labels'),
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE SCREEN
// =============================================================================
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({super.key, required this.userName, required this.userEmail});

  static void showCloudSyncSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final urlCtrl = TextEditingController(text: provider.customCloudUrl);
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                    const Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, color: Colors.tealAccent, size: 26),
                        SizedBox(width: 10),
                        Text('Cloud Sync & Cross-Device Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cloud Account ID: ${txProvider.cloudEmail}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Status: ${txProvider.cloudStatus}', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('Last Synced: ${txProvider.lastSyncedAt}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: txProvider.isSyncing
                            ? null
                            : () async {
                          final ok = await txProvider.pushToCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: ok ? Colors.teal : Colors.orange,
                                content: Text(ok ? '☁️ Account synced to Cloud!' : 'Saved locally (Check internet connection)'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: const Text('Push to Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          side: const BorderSide(color: Colors.tealAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: txProvider.isSyncing
                            ? null
                            : () async {
                          final ok = await txProvider.pullFromCloud(forceApply: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: ok ? Colors.teal : Colors.orange,
                                content: Text(ok ? '☁️ Latest Cloud data loaded!' : 'No newer cloud snapshot found for this email.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: const Text('Pull from Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),
                const Text('Optional: Custom Firebase Realtime Database URL', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Leave blank for FinBlend Global Cloud, or paste Firebase URL',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                      onPressed: () {
                        txProvider.setCustomCloudUrl(urlCtrl.text);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud Server URL updated!')));
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Manual Cross-Device Sync Token:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () {
                        final token = txProvider.generateSyncCode();
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync Token copied to clipboard!')));
                      },
                      icon: const Icon(Icons.copy, size: 14, color: Colors.tealAccent),
                      label: const Text('Copy My Token', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Paste Sync Token from another device to import',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      onPressed: () async {
                        if (codeCtrl.text.trim().isNotEmpty) {
                          final ok = await txProvider.importFromSyncCode(codeCtrl.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Account state restored successfully!' : 'Invalid Sync Token')),
                            );
                          }
                        }
                      },
                      child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                    const Text('Notification Center', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Switch(
                      activeThumbColor: Colors.tealAccent,
                      value: provider.notificationsEnabled,
                      onChanged: (v) => provider.toggleNotifications(v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!provider.notificationsEnabled)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Notifications are currently muted.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                  )
                else if (alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('🎉 All caught up!', style: TextStyle(color: Colors.tealAccent), textAlign: TextAlign.center),
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
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active, color: color),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 3),
                                    Text(a['body'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
            backgroundColor: Colors.teal,
            backgroundImage: MemoryImage(bytes),
          ),
        );
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 40,
      backgroundColor: Colors.teal,
      child: Icon(Icons.person, size: 44, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Account & Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const BusinessNavigationScreen()),
                        (route) => false,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.tealAccent, child: Icon(Icons.storefront, color: Colors.black)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Switch to Business Mode', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Manage sales, stock, and customers', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.tealAccent, size: 16),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            _buildProfileAvatar(txProvider.userPhotoBase64, txProvider.isDarkMode),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(txProvider.userName, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(txProvider.cloudEmail, style: const TextStyle(color: Colors.tealAccent, fontSize: 13)),
                              if (txProvider.userOccupation.isNotEmpty || txProvider.userOrganization.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${txProvider.userOccupation}${txProvider.userOccupation.isNotEmpty && txProvider.userOrganization.isNotEmpty ? " at " : ""}${txProvider.userOrganization}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (txProvider.userPhone.isNotEmpty ||
                        txProvider.userDob.isNotEmpty ||
                        txProvider.userGender.isNotEmpty ||
                        txProvider.userAddress.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (txProvider.userPhone.isNotEmpty) _buildProfileBadge(Icons.phone_outlined, txProvider.userPhone),
                          if (txProvider.userDob.isNotEmpty) _buildProfileBadge(Icons.cake_outlined, txProvider.userDob),
                          if (txProvider.userGender.isNotEmpty) _buildProfileBadge(Icons.person_pin_outlined, txProvider.userGender),
                          if (txProvider.userAddress.isNotEmpty) _buildProfileBadge(Icons.location_on_outlined, txProvider.userAddress),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionHeader('Finances'),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.account_balance_wallet_outlined,
                  'Wallets & Accounts',
                  trailingText: '${txProvider.wallets.length}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                ),
                _buildSettingsTile(
                  Icons.category_outlined,
                  'Categories & Labels',
                  trailingText: '${txProvider.expenseCategories.length + txProvider.incomeCategories.length}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: const Color(0xFF121212),
                        appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text('Categories & Labels')),
                        body: const CategoriesScreen(),
                      ),
                    ),
                  ),
                ),
                _buildSettingsTile(
                  Icons.update,
                  'Scheduled Transactions',
                  trailingText: '${txProvider.scheduledTxs.length}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduledTransactionsScreen())),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('Preferences'),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.palette_outlined,
                  'Appearance',
                  trailingText: txProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  onTap: () => _showAppearanceSheet(context),
                ),
                _buildSettingsTile(
                  Icons.notifications_active_outlined,
                  'Notifications & Alerts',
                  trailingText: txProvider.notificationsEnabled ? '${txProvider.activeAlerts.length} Active' : 'Muted',
                  onTap: () => ProfileScreen.showNotificationsSheet(context),
                ),
                _buildSettingsTile(
                  Icons.admin_panel_settings_outlined,
                  'Permissions & Security',
                  trailingText: txProvider.permissionsGranted ? 'All Granted' : 'Restricted',
                  onTap: () => _showPermissionsSheet(context),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('Cloud & Data Tools'),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.cloud_sync_outlined,
                  'Cloud Sync & Multi-Device',
                  trailingText: txProvider.cloudStatus,
                  onTap: () => ProfileScreen.showCloudSyncSheet(context),
                ),
                _buildSettingsTile(
                  Icons.import_export,
                  'Export Data (PDF, PNG, JPG)',
                  trailingText: 'Export',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportScreen(userName: txProvider.userName, userEmail: txProvider.cloudEmail),
                    ),
                  ),
                ),
                _buildSettingsTile(
                  Icons.calculate_outlined,
                  'CalcBox Calculator',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalcBoxScreen())),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader('Help & Support'),
              _buildSettingsGroup([
                _buildSettingsTile(
                  Icons.help_outline,
                  'Help Center',
                  trailingText: 'Guides & FAQ',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
                ),
                _buildSettingsTile(
                  Icons.mail_outline_rounded,
                  'Contact Support',
                  trailingText: 'corps.rifat@outlook.com',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                ),
                _buildSettingsTile(
                  Icons.description_outlined,
                  'Terms and Policies',
                  trailingText: 'Legal & Privacy',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPoliciesScreen())),
                ),
              ]),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () async {
                  await txProvider.clearSessionOnLogout();
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.tealAccent, size: 14),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Appearance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(provider.isDarkMode ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.tealAccent),
                title: const Text('Premium Dark Mode (OLED)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  provider.toggleDarkMode(true);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(!provider.isDarkMode ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.tealAccent),
                title: const Text('Daylight Mode (Light)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  provider.toggleDarkMode(false);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('App Permissions & Security', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SwitchListTile(
                activeThumbColor: Colors.tealAccent,
                title: const Text('Push & Local Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                value: provider.notificationsEnabled,
                onChanged: (v) => provider.toggleNotifications(v),
              ),
              SwitchListTile(
                activeThumbColor: Colors.tealAccent,
                title: const Text('Storage & File Export Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                value: provider.permissionsGranted,
                onChanged: (v) => provider.updatePermissions(v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          int index = entry.key;
          Widget tile = entry.value;
          if (index != tiles.length - 1) {
            return Column(
              children: [
                tile,
                const Divider(color: Colors.white10, height: 1, indent: 56, endIndent: 16),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Colors.white70, size: 26),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          if (trailingText != null) const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

// =============================================================================
// EDIT PROFILE SCREEN WITH LINKEDIN-STYLE INTERACTIVE CROPPER (WEB + MOBILE)
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
      final XFile? picked = await picker.pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 92);
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
    final isDarkMode = context.watch<TransactionProvider>().isDarkMode;
    ImageProvider? avatarImg;
    if (_photoBase64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(_photoBase64));
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Edit Profile & Photo', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          radius: 56,
                          backgroundColor: Colors.teal,
                          backgroundImage: avatarImg,
                          child: avatarImg == null ? const Icon(Icons.person, size: 58, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickAndCropImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Upload Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.tealAccent,
                              side: const BorderSide(color: Colors.tealAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickAndCropImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          if (_originalPhotoBytes != null)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                side: const BorderSide(color: Colors.amberAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _openCropDialog(_originalPhotoBytes!),
                              icon: const Icon(Icons.crop_rotate, size: 16),
                              label: const Text('Crop / Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          if (_photoBase64.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                _photoBase64 = '';
                                _originalPhotoBytes = null;
                              }),
                              child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildField(_nameCtrl, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _buildField(_phoneCtrl, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(_emailCtrl, 'Email Address (Cloud ID)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: _dobCtrl,
                  readOnly: true,
                  onTap: _selectDob,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.cake_outlined, color: Colors.tealAccent),
                    suffixIcon: IconButton(icon: const Icon(Icons.calendar_month, color: Colors.tealAccent), onPressed: _selectDob),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Gender', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genderOptions.map((g) {
                    final isSel = _selectedGender == g;
                    return ChoiceChip(
                      label: Text(g, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      selected: isSel,
                      selectedColor: Colors.tealAccent,
                      backgroundColor: const Color(0xFF1E1E1E),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedGender = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildField(_occupationCtrl, 'Occupation / Designation', Icons.work_outline),
                const SizedBox(height: 12),
                _buildField(_organizationCtrl, 'Organization / Company', Icons.business_outlined),
                const SizedBox(height: 12),
                _buildField(_addressCtrl, 'Full Address', Icons.location_on_outlined, maxLines: 2),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.teal, content: Text('Profile updated and synced to Cloud!')),
                      );
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(_isSaving ? 'Saving & Syncing...' : 'Save Profile & Sync to Cloud', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

// =============================================================================
// LINKEDIN-STYLE PHOTO CROPPER & ROTATOR DIALOG (100% WEB & MOBILE COMPATIBLE)
// =============================================================================
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

      // Map pan offset from the 240px viewport to image pixel coordinates
      final double normX = (-_panOffset.dx / 120.0).clamp(-1.0, 1.0);
      final double normY = (-_panOffset.dy / 120.0).clamp(-1.0, 1.0);

      final int maxOffsetX = math.max(0, (decoded.width - cropSize) ~/ 2);
      final int maxOffsetY = math.max(0, (decoded.height - cropSize) ~/ 2);

      final int centerX = decoded.width ~/ 2 + (normX * maxOffsetX).round();
      final int centerY = decoded.height ~/ 2 + (normY * maxOffsetY).round();

      final int startX = (centerX - cropSize ~/ 2).clamp(0, math.max(0, decoded.width - cropSize));
      final int startY = (centerY - cropSize ~/ 2).clamp(0, math.max(0, decoded.height - cropSize));

      final img.Image cropped = img.copyCrop(
        decoded,
        x: startX,
        y: startY,
        width: cropSize,
        height: cropSize,
      );

      final img.Image resized = img.copyResize(cropped, width: 240, height: 240);
      final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));

      if (mounted) {
        Navigator.pop(context, base64Encode(jpgBytes));
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, base64Encode(widget.imageBytes));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<TransactionProvider>().isDarkMode;

    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Crop & Adjust Photo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Drag to reposition • Use slider to zoom', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),

              // CIRCULAR LINKEDIN-STYLE CROP VIEWPORT
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
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.tealAccent, width: 2.5),
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
                              width: 240,
                              height: 240,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ZOOM SLIDER
              Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.grey, size: 20),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: 1.0,
                      max: 3.5,
                      activeColor: Colors.tealAccent,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => setState(() => _zoom = v),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.tealAccent, size: 20),
                ],
              ),

              // ROTATE & RESET CONTROLS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns - 1) % 4),
                    icon: const Icon(Icons.rotate_left, color: Colors.white70, size: 18),
                    label: const Text('Rotate Left', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                    icon: const Icon(Icons.rotate_right, color: Colors.white70, size: 18),
                    label: const Text('Rotate Right', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _zoom = 1.0;
                      _panOffset = Offset.zero;
                      _quarterTurns = 0;
                    }),
                    child: const Text('Reset', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // APPLY BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isProcessing ? null : _applyCrop,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_isProcessing ? 'Processing...' : 'Apply Photo', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HELP CENTER, CONTACT SUPPORT & TERMS SCREENS
// =============================================================================
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How does Cloud Sync & Multi-Device Access work?',
        'a': 'FinBlend links your entire financial database to your Email Address and Password. When you sign in on any Android phone or Web browser anywhere in the world, your Personal Transactions, Wallets, Group Splits, Profile Photo, and Business POS records automatically download and sync.',
      },
      {
        'q': 'How do I split a Trip or Group Budget with friends?',
        'a': 'Go to the Groups tab and tap "Create Trip / Split". Enter your total target budget and add or select members from your Saved Members Directory. FinBlend calculates each person\'s required share, tracks how much each member has given, enforces budget guardrails, and computes exact peer-to-peer settlements.',
      },
      {
        'q': 'How do I export my records as PDF, PNG, or JPG?',
        'a': 'Go to Account -> Export Data (PDF, PNG, JPG). Tap PDF for a multi-page printable statement, or tap PNG / JPG to save a high-resolution visual snapshot.',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Help Center & User Guide', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to FinBlend Support', style: TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Browse the interactive guides below to master Personal Finance, Group Splitting, Business POS, and Cloud Sync.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...faqs.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: ExpansionTile(
              iconColor: Colors.tealAccent,
              collapsedIconColor: Colors.grey,
              title: Text(item['q']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(item['a']!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              ],
            ),
          )),
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
  static const List<String> _topics = ['General Inquiry', 'Bug Report', 'Cloud Sync Issue', 'Feature Request', 'Account Help'];
  String _selectedTopic = 'General Inquiry';
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendDirectEmail(TransactionProvider provider) async {
    final subject = _subjectCtrl.text.trim().isEmpty
        ? '[FinBlend $_selectedTopic] Support Request'
        : '[FinBlend $_selectedTopic] ${_subjectCtrl.text.trim()}';
    final body = '${_messageCtrl.text.trim()}\n\n--- User Account Info ---\nName: ${provider.userName}\nEmail: ${provider.cloudEmail}\nPhone: ${provider.userPhone}';

    setState(() => _isSending = true);

    try {
      await http
          .post(
        Uri.parse('https://ntfy.sh/finblend_support_corps_rifat'),
        headers: {'Title': subject},
        body: body,
      )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}

    final Uri mailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(mailUri);
    } catch (_) {}

    if (mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.teal, content: Text('Message prepared for corps.rifat@outlook.com!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text('Contact Support')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Direct Developer Support', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SelectableText(supportEmail, style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: supportEmail));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied corps.rifat@outlook.com to clipboard!')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 15, color: Colors.white),
                            label: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Select Topic', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _topics.map((t) {
                    final isSel = _selectedTopic == t;
                    return ChoiceChip(
                      label: Text(t, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: Colors.tealAccent,
                      backgroundColor: const Color(0xFF1E1E1E),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedTopic = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSending ? null : () => _sendDirectEmail(provider),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Message to corps.rifat@outlook.com', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text('Terms and Policies')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPolicyCard(
            '1. Terms of Service',
            'FinBlend provides dual-mode Personal Finance, Group Budget Splitting, and Business POS management across Android and Web platforms.',
          ),
          _buildPolicyCard(
            '2. Cloud Sync & Data Privacy',
            'Your financial records, profile details, wallets, and group split ledgers are isolated under your personal email account and synced securely.',
          ),
          _buildPolicyCard(
            '3. Contact & Support',
            'For account inquiries or technical support, message corps.rifat@outlook.com directly via the Contact Support screen.',
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}