import 'dart:convert';
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

  Widget _buildUserAvatar(String photoBase64, {double radius = 18}) {
    if (photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.teal,
          backgroundImage: MemoryImage(bytes),
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
      // 1. CLOUD SYNC LIVE BUTTON
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

      // 2. LIVE NOTIFICATION BELL WITH BADGE
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

      // 3. INSTANT DARK / LIGHT MODE TOGGLE
      IconButton(
        tooltip: 'Switch Dark / Light Mode',
        icon: Icon(
          txProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: Colors.tealAccent,
        ),
        onPressed: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
      ),

      // 4. PROFILE AVATAR (SHOWS UPLOADED PHOTO)
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
          child: _buildUserAvatar(txProvider.userPhotoBase64, radius: 18),
        ),
      ),
    ];

    // =========================================================================
    // RESPONSIVE DESKTOP / WEB APPLICATION LAYOUT (WIDTH >= 800px)
    // =========================================================================
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

    // =========================================================================
    // STANDARD MOBILE LAYOUT
    // =========================================================================
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
// FULLY FUNCTIONAL PROFILE, CLOUD SYNC & SETTINGS SCREEN
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
                          if (ctx.mounted) {
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
                          if (ctx.mounted) {
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
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
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
                    child: Text(
                      'Notifications are currently muted. Turn them ON above to receive budget, group, and stock alerts.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      '🎉 All caught up! No budget overruns, low stock, or pending bills.',
                      style: TextStyle(color: Colors.tealAccent),
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
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.teal,
                        content: Text('🔔 FinBlend Live Alert: Notifications & permissions are active!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Test Notification', style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget _buildProfileAvatar(String photoBase64) {
    if (photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return CircleAvatar(
          radius: 40,
          backgroundColor: Colors.teal,
          backgroundImage: MemoryImage(bytes),
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

              // 1. RICH PROFILE CARD WITH PHOTO & DETAILS
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
                            _buildProfileAvatar(txProvider.userPhotoBase64),
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

              // 2. FINANCES GROUP
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

              // 3. PREFERENCES GROUP
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

              // 4. CLOUD & DATA TOOLS GROUP
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

              // 5. COMPLETED HELP & SUPPORT GROUP
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

              // 6. LOGOUT BUTTON
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
                leading: Icon(
                  provider.isDarkMode ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.tealAccent,
                ),
                title: const Text('Premium Dark Mode (OLED)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Deep contrast dark theme', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  provider.toggleDarkMode(true);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  !provider.isDarkMode ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.tealAccent,
                ),
                title: const Text('Daylight Mode (Light)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('High-visibility light theme', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                secondary: const Icon(Icons.notifications_outlined, color: Colors.tealAccent),
                title: const Text('Push & Local Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Allow budget, bill, and stock alerts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: provider.notificationsEnabled,
                onChanged: (v) => provider.toggleNotifications(v),
              ),
              SwitchListTile(
                activeThumbColor: Colors.tealAccent,
                secondary: const Icon(Icons.folder_open_outlined, color: Colors.tealAccent),
                title: const Text('Storage & File Export Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Required for saving PDF, PNG, and JPG reports', style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: provider.permissionsGranted,
                onChanged: (v) => provider.updatePermissions(v),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  provider.toggleNotifications(true);
                  provider.updatePermissions(true);
                  Navigator.pop(ctx);
                },
                child: const Text('Grant All & Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
// 1. COMPLETE EDIT PROFILE SCREEN (ALL 9 FIELDS + PHOTO UPLOAD & CLOUD SYNC)
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
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, maxWidth: 400, maxHeight: 400, imageQuality: 85);
      if (picked == null) return;

      final Uint8List rawBytes = await picked.readAsBytes();
      // Compress & resize to 180x180 JPG so it syncs fast over Cloud
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final resized = img.copyResize(decoded, width: 180);
        final jpgBytes = img.encodeJpg(resized, quality: 80);
        setState(() => _photoBase64 = base64Encode(jpgBytes));
      } else {
        setState(() => _photoBase64 = base64Encode(rawBytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
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
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. PROFILE PHOTO UPLOADER
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.teal,
                        backgroundImage: avatarImg,
                        child: avatarImg == null ? const Icon(Icons.person, size: 54, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Upload Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.tealAccent,
                              side: const BorderSide(color: Colors.tealAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          if (_photoBase64.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() => _photoBase64 = ''),
                              child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. PERSONAL DETAILS FIELDS
                _buildField(_nameCtrl, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _buildField(_phoneCtrl, 'Phone Number (e.g., +880 17...)', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(_emailCtrl, 'Email Address (Cloud Account ID)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),

                // DATE OF BIRTH WITH CALENDAR PICKER
                TextField(
                  controller: _dobCtrl,
                  readOnly: true,
                  onTap: _selectDob,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Tap to pick Date of Birth',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.cake_outlined, color: Colors.tealAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, color: Colors.tealAccent),
                      onPressed: _selectDob,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // GENDER SELECTOR
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

                // OCCUPATION, ORGANIZATION & ADDRESS
                _buildField(_occupationCtrl, 'Occupation / Designation', Icons.work_outline),
                const SizedBox(height: 12),
                _buildField(_organizationCtrl, 'Organization / Company / University', Icons.business_outlined),
                const SizedBox(height: 12),
                _buildField(_addressCtrl, 'Full Address (City, Area, Country)', Icons.location_on_outlined, maxLines: 2),
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
// 2. COMPLETE HELP CENTER SCREEN
// =============================================================================
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How does Cloud Sync & Multi-Device Access work?',
        'a': 'FinBlend links your entire financial database to your Email Address and Password. When you sign in on any Android phone or Web browser anywhere in the world, your Personal Transactions, Wallets, Group Splits, Profile Photo, and Business POS records automatically download and sync every 8 seconds.',
      },
      {
        'q': 'How do I split a Trip or Group Budget with friends?',
        'a': 'Go to the Groups tab and tap "Create Trip / Split". Enter your total target budget (e.g., 25,000 BDT) and add or select members from your Saved Members Directory. FinBlend calculates each person\'s required share, tracks how much each member has given, enforces budget guardrails so spending never exceeds the plan budget, and computes exact peer-to-peer settlements under the "Settle Up" tab.',
      },
      {
        'q': 'How do I manage Mobile Banking (bKash, Nagad, Rocket, Upay) & Bank Accounts?',
        'a': 'Open Account -> Wallets & Accounts. You can add accounts under Mobile Banking (bKash, Nagad, Rocket, Upay, Tap), Bank Accounts (City Bank, BRAC, DBBL, Islami Bank, EBL, etc.), or Physical Cash, and compare all balances on a live bar chart.',
      },
      {
        'q': 'How do I export my records as PDF, PNG, or JPG?',
        'a': 'Go to Account -> Export Data (PDF, PNG, JPG). You will see a live preview of your official FinBlend Financial Statement. Tap PDF for a multi-page printable statement, or tap PNG / JPG to save a high-resolution visual snapshot.',
      },
      {
        'q': 'How does Business POS Mode work?',
        'a': 'Tap "Switch to Business Mode" in your Account screen (or the Business POS button on Web). You can log Sales, Purchases, and Business Expenses, manage Product Stock with low-stock alerts, and track Customer & Supplier Due Ledgers.',
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
                Text(
                  'Browse the interactive guides below to master Personal Finance, Group Splitting, Business POS, and Cloud Sync.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
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

// =============================================================================
// 3. COMPLETE CONTACT SUPPORT SCREEN (DIRECT MESSAGE TO corps.rifat@outlook.com)
// =============================================================================
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const String supportEmail = 'corps.rifat@outlook.com';
  String _selectedTopic = 'General Inquiry';
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  static const List<String> _topics = ['General Inquiry', 'Bug Report', 'Cloud Sync Issue', 'Feature Request', 'Account Help'];

  Future<void> _sendDirectEmail(TransactionProvider provider) async {
    final subject = _subjectCtrl.text.trim().isEmpty
        ? '[FinBlend $_selectedTopic] Support Request'
        : '[FinBlend $_selectedTopic] ${_subjectCtrl.text.trim()}';

    final body = '${_messageCtrl.text.trim()}\n\n'
        '--- User Account Info ---\n'
        'Name: ${provider.userName}\n'
        'Email: ${provider.cloudEmail}\n'
        'Phone: ${provider.userPhone}';

    setState(() => _isSending = true);

    // 1. Also dispatch to cloud support relay so message is logged even if device has no mail app
    try {
      await http
          .post(
        Uri.parse('https://ntfy.sh/finblend_support_corps_rifat'),
        headers: {'Title': subject},
        body: body,
      )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}

    // 2. Open native Email Client / Outlook / Gmail addressed directly to corps.rifat@outlook.com
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
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Message prepared for corps.rifat@outlook.com!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DIRECT SUPPORT EMAIL BANNER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: Colors.tealAccent, size: 28),
                          SizedBox(width: 10),
                          Text('Direct Developer Support', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Official Support Email:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SelectableText(
                            supportEmail,
                            style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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
                const SizedBox(height: 24),

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
                    hintText: 'Brief summary of your question or issue',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.subject, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _messageCtrl,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Message to $supportEmail',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Write your message here...',
                    hintStyle: const TextStyle(color: Colors.grey),
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
                  label: Text(
                    _isSending ? 'Sending...' : 'Send Direct Message to corps.rifat@outlook.com',
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
}

// =============================================================================
// 4. COMPLETE TERMS AND POLICIES SCREEN
// =============================================================================
class TermsPoliciesScreen extends StatelessWidget {
  const TermsPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Terms and Policies', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPolicyCard(
            '1. Terms of Service',
            'FinBlend provides dual-mode Personal Finance, Group Budget Splitting, and Business POS management across Android and Web platforms. By creating an account, you agree to maintain accurate records and keep your account credentials secure.',
          ),
          _buildPolicyCard(
            '2. Cloud Sync & Data Privacy Policy',
            'Your financial records, profile details, wallets, and group split ledgers are isolated under your personal email account. Data is cached locally on your device for instant offline performance and encoded before synchronizing to the cloud.',
          ),
          _buildPolicyCard(
            '3. Group Split & Settlement Accuracy',
            'FinBlend automatically calculates per-member budget targets, individual expense shares, and peer-to-peer settlement recommendations. Budget guardrails prevent accidental overspending beyond your designated group budget.',
          ),
          _buildPolicyCard(
            '4. Permissions & Document Exports',
            'Camera, Gallery, and Storage permissions are used solely when you upload a profile photo or export your financial statements as PDF, PNG, or JPG files.',
          ),
          _buildPolicyCard(
            '5. Contact & Data Rights',
            'You can edit or delete any transaction, wallet, group plan, or business record at any time. For account inquiries or support, contact corps.rifat@outlook.com directly via the Contact Support screen.',
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