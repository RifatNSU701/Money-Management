import 'package:flutter/material.dart';
import 'main.dart';
import 'dashboard.dart';
import 'business_navigation.dart';
import 'records_screen.dart';
import 'budgets_screen.dart';
import 'groups_screen.dart';
import 'categories_screen.dart';

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

  // FIX: This dynamic function replaces the old _pages array,
  // allowing the Dashboard to use setState to navigate to Records.
  Widget _buildPage(int index) {
    switch (index) {
      case 0: return DashboardScreen(onSeeAll: () => setState(() => _currentIndex = 1));
      case 1: return const RecordsScreen();
      case 2: return const BudgetsScreen();
      case 3: return const GroupsScreen();
      case 4: return const CategoriesScreen();
      default: return DashboardScreen(onSeeAll: () => setState(() => _currentIndex = 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('FinBlend', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(userName: _userName, userEmail: _userEmail)),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      // FIX: Call the new function here
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
// PREMIUM PROFILE & SETTINGS SCREEN
// =============================================================================
class ProfileScreen extends StatelessWidget {
  final String userName;
  final String userEmail;

  const ProfileScreen({super.key, required this.userName, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: ListView(
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
                boxShadow: [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
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
          Row(
            children: [
              const CircleAvatar(radius: 36, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 40, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(userEmail, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Edit', style: TextStyle(color: Colors.tealAccent, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 36),
          _buildSectionHeader('Finances'),
          _buildSettingsGroup([
            _buildSettingsTile(Icons.account_balance_wallet_outlined, 'Wallets & Accounts', trailingText: '3'),
            _buildSettingsTile(Icons.category_outlined, 'Categories & Labels'),
            _buildSettingsTile(Icons.update, 'Scheduled Transactions'),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Preferences'),
          _buildSettingsGroup([
            _buildSettingsTile(Icons.palette_outlined, 'Appearance', trailingText: 'Dark'),
            _buildSettingsTile(Icons.notifications_none, 'Notifications'),
            _buildSettingsTile(Icons.security, 'Security'),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Tools & Data'),
          _buildSettingsGroup([
            _buildSettingsTile(Icons.qr_code_scanner, 'Scan Code'),
            _buildSettingsTile(Icons.calculate_outlined, 'CalcBox'),
            _buildSettingsTile(Icons.import_export, 'Export Data'),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Help & Support'),
          _buildSettingsGroup([
            _buildSettingsTile(Icons.help_outline, 'Help Center'),
            _buildSettingsTile(Icons.chat_bubble_outline, 'Contact Support'),
            _buildSettingsTile(Icons.description_outlined, 'Terms and Policies'),
          ]),
          const SizedBox(height: 40),
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

  Widget _buildSettingsTile(IconData icon, String title, {String? trailingText}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Colors.white70, size: 26),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          if (trailingText != null)
            const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
        ],
      ),
      onTap: () {},
    );
  }
}