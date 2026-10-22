import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _userName = 'Loading...';
  String _userEmail = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  void _loadUserSession() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _userName = user['name']!;
      _userEmail = user['email']!;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final alerts = txProvider.activeAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('FinBlend', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          // 1. LIVE NOTIFICATION BELL WITH BADGE
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

          // 2. INSTANT DARK / LIGHT MODE TOGGLE
          IconButton(
            tooltip: 'Switch Dark / Light Mode',
            icon: Icon(
              txProvider.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.tealAccent,
            ),
            onPressed: () => txProvider.toggleDarkMode(!txProvider.isDarkMode),
          ),

          // 3. PROFILE AVATAR
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userName: _userName, userEmail: _userEmail)),
                );
                _loadUserSession();
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
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
// FULLY FUNCTIONAL PROFILE & SETTINGS SCREEN
// =============================================================================
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({super.key, required this.userName, required this.userEmail});

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
  late String _name;
  late String _email;

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _email = widget.userEmail;
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
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

          // 1. PROFILE HEADER
          Row(
            children: [
              const CircleAvatar(radius: 36, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 40, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showEditProfileSheet(context),
                child: const Text('Edit', style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 36),

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

          // 3. PREFERENCES GROUP (DARK/LIGHT, NOTIFICATIONS & PERMISSIONS)
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

          // 4. TOOLS & DATA GROUP (WITH PDF, PNG & JPG EXPORT)
          _buildSectionHeader('Tools & Data'),
          _buildSettingsGroup([
            _buildSettingsTile(
              Icons.qr_code_scanner,
              'Scan Code',
              onTap: () => _showInfoDialog(context, 'QR Code Hub', 'Share your FinBlend ID ($_email) with friends to split group expenses.'),
            ),
            _buildSettingsTile(
              Icons.calculate_outlined,
              'CalcBox',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalcBoxScreen())),
            ),
            _buildSettingsTile(
              Icons.import_export,
              'Export Data (PDF, PNG, JPG)',
              trailingText: 'Export',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExportScreen(userName: _name, userEmail: _email)),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // 5. HELP & SUPPORT GROUP
          _buildSectionHeader('Help & Support'),
          _buildSettingsGroup([
            _buildSettingsTile(
              Icons.help_outline,
              'Help Center',
              onTap: () => _showInfoDialog(context, 'Help Center', 'Tap any record, budget, product, or party across the app to edit or delete it.'),
            ),
            _buildSettingsTile(
              Icons.chat_bubble_outline,
              'Contact Support',
              onTap: () => _showInfoDialog(context, 'Support', 'Need assistance? Reach out at support@finblend.app'),
            ),
            _buildSettingsTile(
              Icons.description_outlined,
              'Terms and Policies',
              onTap: () => _showInfoDialog(context, 'Terms & Privacy', 'All financial records are stored locally and synced securely.'),
            ),
          ]),
          const SizedBox(height: 40),

          // 6. LOGOUT BUTTON
          GestureDetector(
            onTap: () async {
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

  void _showEditProfileSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Full Name', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Email Address', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', nameCtrl.text.trim());
                await prefs.setString('user_email', emailCtrl.text.trim());
                setState(() {
                  _name = nameCtrl.text.trim();
                  _email = emailCtrl.text.trim();
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: Colors.tealAccent))),
        ],
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
          if (trailingText != null) Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          if (trailingText != null) const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}