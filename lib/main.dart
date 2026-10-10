import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/transaction_provider.dart';

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

  static Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPassword, password);
    await prefs.setBool(_keyIsLoggedIn, true);
    return null;
  }

  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyUserEmail);
    final storedPassword = prefs.getString(_keyUserPassword);

    if (storedEmail == null || storedEmail.isEmpty) {
      return 'No account found. Please sign up first.';
    }
    if (storedEmail != email) {
      return 'Email does not match our records.';
    }
    if (storedPassword != password) {
      return 'Incorrect password. Please try again.';
    }

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
    return MaterialApp(
      title: 'FinBlend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
          surface: Color(0xFF1E1E1E),
        ),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: startLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
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

    final errorMessage = await AuthService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter your email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.teal.shade900,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                        : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?", style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                        child: const Text('Sign Up', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
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
    final errorMessage = await AuthService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage == null) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Start tracking your daily expenses today', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.tealAccent),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter a password';
                    if (val.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_reset, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => (val != _passwordController.text) ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.teal.shade900,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                      : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
// MAIN NAVIGATION & DRAWER
// =============================================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _userName = 'Loading...';
  String _userEmail = 'Loading...';

  final List<Widget> _pages = [
    const DashboardPage(),
    const TransactionsPage(),
    const BudgetsPage(),
    const GroupsPage(),
  ];

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

  void _logoutUser() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('FinBlend', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const CircleAvatar(radius: 14, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 18, color: Colors.white)),
            onPressed: () => _showProfileDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF161616),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF121212)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 48, color: Colors.tealAccent),
                  const SizedBox(height: 12),
                  Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_userEmail, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            _buildDrawerItem(context, Icons.account_balance, 'Wallets & Accounts', const WalletsPage()),
            _buildDrawerItem(context, Icons.people_alt_outlined, 'Friends', const FriendsPage()),
            _buildDrawerItem(context, Icons.category_outlined, 'Categories & Labels', const CategoriesPage()),
            _buildDrawerItem(context, Icons.update, 'Scheduled Transactions', const ScheduledPage()),
            const Divider(color: Colors.white12, thickness: 1, height: 24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              onTap: _logoutUser,
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: Colors.teal.withValues(alpha: 0.3),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Colors.tealAccent), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Colors.tealAccent), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart, color: Colors.tealAccent), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group, color: Colors.tealAccent), label: 'Groups'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.tealAccent.withValues(alpha: 0.8)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Profile'),
        content: Text('Name: $_userName\nEmail: $_userEmail\nStatus: Active Session'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.tealAccent)))],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD (DYNAMIC PROVIDER INTEGRATION)
// =============================================================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.teal.shade900, const Color(0xFF1E1E1E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text('৳ ${txProvider.totalBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Income', '+ ৳ ${txProvider.totalIncome.toStringAsFixed(0)}', Colors.greenAccent),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStatColumn('Expenses', '- ৳ ${txProvider.totalExpense.toStringAsFixed(0)}', Colors.redAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionBtn(context, Icons.remove_circle_outline, 'Expense', Colors.redAccent),
            _buildActionBtn(context, Icons.add_circle_outline, 'Income', Colors.greenAccent),
            _buildActionBtn(context, Icons.swap_horiz, 'Transfer', Colors.blueAccent),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(color: Colors.tealAccent))),
          ],
        ),
        ...txProvider.transactions.take(5).map((tx) => _buildTxItem(context, tx.icon, tx.title, '${tx.subtitle} • ${tx.date}', '${tx.isExpense ? '- ' : '+ '}৳ ${tx.amount.toStringAsFixed(0)}', tx.color)),
      ],
    );
  }

  Widget _buildStatColumn(String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionBtn(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showTransactionSheet(context, label),
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  void _showTransactionSheet(BuildContext context, String type) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add $type', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            TextField(controller: amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount (৳)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: noteController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Category / Note', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                final enteredNote = noteController.text.trim().isEmpty ? '$type Entry' : noteController.text.trim();
                if (enteredAmount > 0) {
                  context.read<TransactionProvider>().addTransaction(title: enteredNote, category: type, amount: enteredAmount, isExpense: type == 'Expense');
                  Navigator.pop(sheetContext);
                }
              },
              child: const Text('Save Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TRANSACTIONS PAGE
// =============================================================================
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
              child: IconButton(icon: const Icon(Icons.filter_list, color: Colors.tealAccent), onPressed: () => _showFilterSheet(context)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('All Records', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...txProvider.transactions.map((tx) => _buildTxItem(context, tx.icon, tx.title, '${tx.subtitle} • ${tx.date}', '${tx.isExpense ? '- ' : '+ '}৳ ${tx.amount.toStringAsFixed(0)}', tx.color)),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: const Text('All'), backgroundColor: Colors.tealAccent.withValues(alpha: 0.2)),
                const Chip(label: Text('Income')),
                const Chip(label: Text('Expenses')),
                const Chip(label: Text('Transfers')),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                child: const Text('Apply Filters'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

Widget _buildTxItem(BuildContext context, IconData icon, String title, String subtitle, String amount, Color color) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), radius: 24, child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      trailing: Text(amount, style: TextStyle(color: amount.startsWith('+') ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Transaction Details'),
            content: Text('Amount: $amount\nCategory: $subtitle\nDesc: $title'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.tealAccent)))],
          ),
        );
      },
    ),
  );
}

// =============================================================================
// BUDGETS PAGE
// =============================================================================
class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Monthly Budget Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        _buildBudgetCard('Food & Drink', 2500, 5000, Colors.orange),
        _buildBudgetCard('Shopping', 3500, 4000, Colors.pink),
        _buildBudgetCard('Transport', 800, 2000, Colors.blue),
      ],
    );
  }

  Widget _buildBudgetCard(String category, double spent, double total, Color color) {
    double progress = spent / total;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('৳ ${spent.toInt()} / ৳ ${total.toInt()}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(progress > 0.85 ? Colors.redAccent : color),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).toInt()}% Used', style: TextStyle(color: progress > 0.85 ? Colors.redAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GROUPS PAGE
// =============================================================================
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        ElevatedButton.icon(
          onPressed: () => _showCreateGroupSheet(context),
          icon: const Icon(Icons.group_add),
          label: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('My Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _buildGroupItem(context, 'Apartment 4B', 'You owe: ৳ 450', Colors.redAccent, Icons.home, Colors.teal),
        _buildGroupItem(context, "Cox's Bazar Trip", 'You are owed: ৳ 2,100', Colors.greenAccent, Icons.flight, Colors.deepPurple),
      ],
    );
  }

  Widget _buildGroupItem(BuildContext context, String name, String status, Color statusColor, IconData icon, Color avatarColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(backgroundColor: avatarColor, radius: 24, child: Icon(icon, color: Colors.white)),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $name Ledger...'))),
      ),
    );
  }
}

// =============================================================================
// DRAWER SUB-PAGES
// =============================================================================
class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallets & Accounts'), backgroundColor: const Color(0xFF121212)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDetailCard('Cash Wallet', '৳ 5,000', Icons.account_balance_wallet, Colors.green),
          _buildDetailCard('DBBL Bank Account', '৳ 35,000', Icons.account_balance, Colors.blue),
          _buildDetailCard('Mobile Money (Bkash)', '৳ 2,500', Icons.phone_android, Colors.pink),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.tealAccent, child: const Icon(Icons.add, color: Colors.black), onPressed: () => _showAddWalletSheet(context)),
    );
  }
}

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends'), backgroundColor: const Color(0xFF121212)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDetailCard('A (Roommate)', 'Owes you: ৳ 500', Icons.person, Colors.teal),
          _buildDetailCard('B (Friend)', 'You owe: ৳ 120', Icons.person, Colors.orange),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.tealAccent, child: const Icon(Icons.person_add, color: Colors.black), onPressed: () => _showAddFriendSheet(context)),
    );
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories & Labels'),
          backgroundColor: const Color(0xFF121212),
          bottom: const TabBar(
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'Expenses'), Tab(text: 'Income')],
          ),
        ),
        body: const Center(child: Text('Category Management Screen', style: TextStyle(color: Colors.grey))),
        floatingActionButton: FloatingActionButton(backgroundColor: Colors.tealAccent, child: const Icon(Icons.add, color: Colors.black), onPressed: () => _showAddCategorySheet(context)),
      ),
    );
  }
}

class ScheduledPage extends StatelessWidget {
  const ScheduledPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Transactions'), backgroundColor: const Color(0xFF121212)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDetailCard('Internet Bill', 'Every Month (৳ 1,200)', Icons.wifi, Colors.blueAccent),
          _buildDetailCard('Gym Membership', 'Every Month (৳ 2,000)', Icons.fitness_center, Colors.orangeAccent),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.tealAccent, child: const Icon(Icons.add, color: Colors.black), onPressed: () => _showAddScheduledSheet(context)),
    );
  }
}

Widget _buildDetailCard(String title, String subtitle, IconData icon, Color iconColor) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.2), child: Icon(icon, color: iconColor)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.more_vert, color: Colors.grey),
    ),
  );
}

// =============================================================================
// BOTTOM SHEETS
// =============================================================================
void _showCreateGroupSheet(BuildContext context) {
  _buildGenericBottomSheet(context, 'Create New Group', ['Group Name', 'Members (comma separated)'], 'Create Group');
}

void _showAddWalletSheet(BuildContext context) {
  _buildGenericBottomSheet(context, 'Add Wallet / Account', ['Account Name', 'Initial Balance'], 'Save Account');
}

void _showAddFriendSheet(BuildContext context) {
  _buildGenericBottomSheet(context, 'Add Friend', ['Friend\'s Email or Phone'], 'Send Invite');
}

void _showAddCategorySheet(BuildContext context) {
  _buildGenericBottomSheet(context, 'Add Category', ['Category Name', 'Type (Income/Expense)'], 'Save Category');
}

void _showAddScheduledSheet(BuildContext context) {
  _buildGenericBottomSheet(context, 'Add Scheduled Transaction', ['Title', 'Amount', 'Frequency (e.g. Monthly)'], 'Save Schedule');
}

void _buildGenericBottomSheet(BuildContext context, String title, List<String> fields, String btnText) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ...fields.map((field) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(decoration: InputDecoration(labelText: field, border: const OutlineInputBorder())),
            )),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title saved successfully!')));
              },
              child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    ),
  );
}