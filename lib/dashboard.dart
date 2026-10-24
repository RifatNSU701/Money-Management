import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'business_navigation.dart';
import 'export_screen.dart';
import 'providers/transaction_provider.dart';
import 'wallets_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hideBalances = false;
  String _txFilter = 'All'; // 'All', 'Income', 'Expense'
  String _searchQuery = '';

  String _fmt(double amount) {
    if (_hideBalances) return '৳ ••••••';
    return '৳ ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double income = provider.totalIncome;
    final double expense = provider.totalExpense;
    final double netCashflow = provider.totalBalance;
    final double walletsTotal = provider.totalWalletsBalance;
    final double totalNetWorth = netCashflow + walletsTotal;

    // Financial Health & Savings Rate Calculation
    final double savingsRate = income > 0 ? ((income - expense) / income * 100).clamp(-100.0, 100.0) : 0.0;
    final double expenseRatio = income > 0 ? (expense / income).clamp(0.0, 1.0) : (expense > 0 ? 1.0 : 0.0);
    final int healthScore = income == 0 && expense == 0
        ? 75
        : (50 + (savingsRate * 0.5)).round().clamp(10, 100);

    String healthLabel;
    Color healthColor;
    if (healthScore >= 80) {
      healthLabel = 'Excellent';
      healthColor = Colors.greenAccent;
    } else if (healthScore >= 60) {
      healthLabel = 'Healthy';
      healthColor = Colors.tealAccent;
    } else if (healthScore >= 40) {
      healthLabel = 'Moderate';
      healthColor = Colors.amberAccent;
    } else {
      healthLabel = 'High Burn';
      healthColor = Colors.redAccent;
    }

    // Category Breakdown Map
    final Map<String, double> categorySpend = {};
    for (var tx in provider.transactions.where((t) => t.isExpense)) {
      categorySpend[tx.title] = (categorySpend[tx.title] ?? 0) + tx.amount;
    }
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Filtered Recent Transactions
    final filteredTxs = provider.transactions.where((tx) {
      if (_txFilter == 'Income' && tx.isExpense) return false;
      if (_txFilter == 'Expense' && !tx.isExpense) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return tx.title.toLowerCase().contains(q) ||
            tx.subtitle.toLowerCase().contains(q) ||
            tx.date.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          // ===================================================================
          // 1. GREETING & LIVE CLOUD STATUS BAR
          // ===================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${provider.userName}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Financial Command Center • ${provider.cloudStatus}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _hideBalances ? 'Show Balances' : 'Privacy Mask',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  _hideBalances ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.tealAccent,
                  size: 20,
                ),
                onPressed: () => setState(() => _hideBalances = !_hideBalances),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ===================================================================
          // 2. EXECUTIVE NET WORTH & HEALTH HERO CARD (OVERFLOW-PROOF)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF13404D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'TOTAL COMBINED NET WORTH',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: healthColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: healthColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Score: $healthScore/100 • $healthLabel',
                        style: TextStyle(color: healthColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fmt(totalNetWorth),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cashflow Balance: ${_fmt(netCashflow)}  •  Wallets & Banks: ${_fmt(walletsTotal)}',
                  style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),

                // INCOME VS EXPENSE RATIO BAR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Savings Rate: ${savingsRate.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Expense Ratio: ${(expenseRatio * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: expenseRatio,
                    minHeight: 7,
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      expenseRatio > 0.85 ? Colors.redAccent : Colors.orangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 3-COLUMN METRICS ROW
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHeroMetric(
                          'Total Income',
                          '+${_fmt(income)}',
                          Icons.south_west_rounded,
                          Colors.greenAccent,
                        ),
                      ),
                      Container(width: 1, height: 34, color: Colors.white12),
                      Expanded(
                        child: _buildHeroMetric(
                          'Total Expense',
                          '-${_fmt(expense)}',
                          Icons.north_east_rounded,
                          Colors.redAccent,
                        ),
                      ),
                      Container(width: 1, height: 34, color: Colors.white12),
                      Expanded(
                        child: _buildHeroMetric(
                          'Biz Net Profit',
                          _fmt(provider.netProfit),
                          Icons.storefront_outlined,
                          Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // 3. NEO-BANK 6-BUTTON QUICK ACTION DOCK
          // ===================================================================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Income',
                    color: Colors.greenAccent,
                    onTap: () => _showSmartTransactionSheet(context, initialIsExpense: false),
                  ),
                ),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Expense',
                    color: Colors.redAccent,
                    onTap: () => _showSmartTransactionSheet(context, initialIsExpense: true),
                  ),
                ),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transfer',
                    color: Colors.tealAccent,
                    onTap: () => _showWalletTransferSheet(context),
                  ),
                ),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallets',
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                  ),
                ),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Statement',
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(userName: provider.userName, userEmail: provider.cloudEmail),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildQuickActionBtn(
                    icon: Icons.storefront_outlined,
                    label: 'Biz POS',
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
                          (route) => false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // 4. LIVE WALLETS & BANKING CAROUSEL
          // ===================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Wallets & Banking Accounts',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                icon: const Icon(Icons.open_in_new, size: 15, color: Colors.tealAccent),
                label: const Text('Manage All', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...provider.wallets.map((w) {
                  IconData wIcon = Icons.payments_outlined;
                  Color wColor = Colors.tealAccent;
                  if (w.type == 'Mobile Banking') {
                    wIcon = Icons.phone_android_rounded;
                    wColor = Colors.pinkAccent;
                  } else if (w.type == 'Bank Account') {
                    wIcon = Icons.account_balance_rounded;
                    wColor = Colors.blueAccent;
                  }

                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                    child: Container(
                      width: 195,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: wColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(wIcon, color: wColor, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  w.providerName,
                                  style: TextStyle(color: wColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            w.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _fmt(w.balance),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_card_rounded, color: Colors.tealAccent, size: 26),
                        SizedBox(height: 6),
                        Text('+ Add Account', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('bKash, Nagad, Bank', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // 5. TOP SPENDING ANALYTICS & BUDGET PULSE
          // ===================================================================
          if (sortedCategories.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Expense Analytics', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Icon(Icons.insights_rounded, color: Colors.tealAccent, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sortedCategories.take(4).map((entry) {
                    final double pct = expense > 0 ? (entry.value / expense).clamp(0.0, 1.0) : 0.0;
                    final double? budgetLimit = provider.budgets[entry.key];
                    final bool overBudget = budgetLimit != null && budgetLimit > 0 && entry.value > budgetLimit;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                budgetLimit != null
                                    ? '${_fmt(entry.value)} / ${_fmt(budgetLimit)} (${(pct * 100).toStringAsFixed(0)}%)'
                                    : '${_fmt(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  color: overBudget ? Colors.redAccent : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                overBudget ? Colors.redAccent : Colors.tealAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ===================================================================
          // 6. RECENT TRANSACTIONS WITH LIVE SEARCH & FILTER CHIPS
          // ===================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: const Text('See All Ledger', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search transactions by category, note, or date...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.tealAccent, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['All', 'Income', 'Expense'].map((f) {
              final isSel = _txFilter == f;
              return ChoiceChip(
                label: Text(
                  f,
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: isSel,
                selectedColor: Colors.tealAccent,
                backgroundColor: const Color(0xFF1A1A1A),
                showCheckmark: false,
                onSelected: (_) => setState(() => _txFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (filteredTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.tealAccent, size: 42),
                  SizedBox(height: 10),
                  Text('No Matching Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 4),
                  Text(
                    'Tap "+ Add Transaction" below or use the Quick Action buttons above to record your income and expenses.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...filteredTxs.take(12).map((tx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  onTap: () => _showSmartTransactionSheet(context, existing: tx),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (tx.isExpense ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      tx.isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
                      color: tx.isExpense ? Colors.redAccent : Colors.greenAccent,
                      size: 20,
                    ),
                  ),
                  title: Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('${tx.subtitle}\n${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tx.isExpense ? "-" : "+"}${_fmt(tx.amount)}',
                        style: TextStyle(
                          color: tx.isExpense ? Colors.redAccent : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                        onPressed: () => provider.deleteTransaction(tx.id),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => _showSmartTransactionSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODAL 1: SMART TRANSACTION SHEET (WITH OPTIONAL WALLET SYNC & BUDGET GUARD)
  // ===========================================================================
  void _showSmartTransactionSheet(BuildContext context, {TransactionModel? existing, bool? initialIsExpense}) {
    final provider = context.read<TransactionProvider>();
    bool isExpense = existing?.isExpense ?? (initialIsExpense ?? true);
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: existing?.subtitle ?? '');

    List<String> currentCategories = isExpense ? provider.expenseCategories : provider.incomeCategories;
    String selectedCategory = existing != null && currentCategories.contains(existing.title)
        ? existing.title
        : (currentCategories.isNotEmpty ? currentCategories.first : (isExpense ? 'Food & Dining' : 'Salary'));

    String selectedWalletId = 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = isExpense ? provider.expenseCategories : provider.incomeCategories;
          if (!categories.contains(selectedCategory) && categories.isNotEmpty) {
            selectedCategory = categories.first;
          }

          final double enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final double? catBudget = isExpense ? provider.budgets[selectedCategory] : null;
          double catSpentSoFar = 0;
          if (isExpense && catBudget != null) {
            for (var t in provider.transactions.where((tx) => tx.isExpense && tx.title == selectedCategory && tx.id != existing?.id)) {
              catSpentSoFar += t.amount;
            }
          }
          final bool willExceedBudget = catBudget != null && catBudget > 0 && (catSpentSoFar + enteredAmount) > catBudget;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Record Financial Transaction' : 'Edit Transaction',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // EXPENSE / INCOME SWITCHER
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Expense (-)', style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: isExpense,
                          selectedColor: Colors.redAccent,
                          labelStyle: TextStyle(color: isExpense ? Colors.white : Colors.grey),
                          backgroundColor: const Color(0xFF1E1E1E),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Income (+)', style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: !isExpense,
                          selectedColor: Colors.greenAccent,
                          labelStyle: TextStyle(color: !isExpense ? Colors.black : Colors.grey),
                          backgroundColor: const Color(0xFF1E1E1E),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CATEGORY SELECTOR
                  const Text('Select Category:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        selectedColor: Colors.tealAccent,
                        backgroundColor: const Color(0xFF1E1E1E),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // AMOUNT FIELD
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount (৳)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.payments_outlined, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),

                  if (willExceedBudget) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent),
                      ),
                      child: Text(
                        '⚠️ Budget Alert: "$selectedCategory" monthly limit is ৳${catBudget.toStringAsFixed(0)} (Already spent: ৳${catSpentSoFar.toStringAsFixed(0)}).',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // NOTE / DESCRIPTION FIELD
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Note / Description (Optional)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.notes_rounded, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),

                  // WALLET SYNC SELECTOR
                  if (existing == null && provider.wallets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      isExpense ? 'Deduct From Wallet (Optional):' : 'Deposit Into Wallet (Optional):',
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Cashflow Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          selected: selectedWalletId == 'none',
                          selectedColor: Colors.tealAccent,
                          labelStyle: TextStyle(color: selectedWalletId == 'none' ? Colors.black : Colors.white70),
                          backgroundColor: const Color(0xFF1E1E1E),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => selectedWalletId = 'none'),
                        ),
                        ...provider.wallets.map((w) {
                          final isSel = selectedWalletId == w.id;
                          return ChoiceChip(
                            label: Text('${w.name} (৳${w.balance.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: Colors.tealAccent,
                            labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white),
                            backgroundColor: const Color(0xFF1E1E1E),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() => selectedWalletId = w.id),
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpense ? Colors.redAccent : Colors.greenAccent,
                      foregroundColor: isExpense ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final double amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) return;

                      String subtitle = noteCtrl.text.trim().isEmpty
                          ? (isExpense ? 'Personal Expense' : 'Personal Income')
                          : noteCtrl.text.trim();

                      if (existing == null && selectedWalletId != 'none') {
                        final wIdx = provider.wallets.indexWhere((w) => w.id == selectedWalletId);
                        if (wIdx != -1) {
                          final w = provider.wallets[wIdx];
                          final double newBal = isExpense ? math.max(0, w.balance - amt) : (w.balance + amt);
                          provider.saveWallet(
                            id: w.id,
                            name: w.name,
                            type: w.type,
                            providerName: w.providerName,
                            accountNumber: w.accountNumber,
                            balance: newBal,
                          );
                          subtitle = '$subtitle • via ${w.name}';
                        }
                      }

                      provider.saveTransaction(
                        id: existing?.id,
                        title: selectedCategory,
                        category: subtitle,
                        amount: amt,
                        isExpense: isExpense,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      existing == null ? (isExpense ? 'Save Expense' : 'Save Income') : 'Update Transaction',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL 2: INSTANT WALLET-TO-WALLET TRANSFER SHEET
  // ===========================================================================
  void _showWalletTransferSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    if (provider.wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Add at least 2 Wallets (e.g., Bank & bKash) in Wallets & Accounts to transfer funds between them!'),
        ),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen()));
      return;
    }

    String fromId = provider.wallets.first.id;
    String toId = provider.wallets[1].id;
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final fromWallet = provider.wallets.firstWhere((w) => w.id == fromId, orElse: () => provider.wallets.first);
          final toWallet = provider.wallets.firstWhere((w) => w.id == toId, orElse: () => provider.wallets.last);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Instant Wallet-to-Wallet Transfer',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text('Transfer From:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: provider.wallets.map((w) {
                    final isSel = w.id == fromId;
                    return ChoiceChip(
                      label: Text('${w.name} (৳${w.balance.toStringAsFixed(0)})', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: Colors.orangeAccent,
                      backgroundColor: const Color(0xFF1E1E1E),
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() => fromId = w.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Transfer To:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: provider.wallets.map((w) {
                    final isSel = w.id == toId;
                    return ChoiceChip(
                      label: Text('${w.name} (৳${w.balance.toStringAsFixed(0)})', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: Colors.tealAccent,
                      backgroundColor: const Color(0xFF1E1E1E),
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() => toId = w.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Transfer Amount (Max: ৳${fromWallet.balance.toStringAsFixed(0)})',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.swap_horiz_rounded, color: Colors.tealAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (amt <= 0 || fromId == toId) return;
                    if (amt > fromWallet.balance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Insufficient balance in source wallet!')),
                      );
                      return;
                    }

                    provider.saveWallet(
                      id: fromWallet.id,
                      name: fromWallet.name,
                      type: fromWallet.type,
                      providerName: fromWallet.providerName,
                      accountNumber: fromWallet.accountNumber,
                      balance: fromWallet.balance - amt,
                    );
                    provider.saveWallet(
                      id: toWallet.id,
                      name: toWallet.name,
                      type: toWallet.type,
                      providerName: toWallet.providerName,
                      accountNumber: toWallet.accountNumber,
                      balance: toWallet.balance + amt,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.teal,
                        content: Text('Transferred ৳${amt.toStringAsFixed(0)} from ${fromWallet.name} to ${toWallet.name}!'),
                      ),
                    );
                  },
                  child: const Text('Confirm Instant Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}