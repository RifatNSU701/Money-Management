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
  String _txFilter = 'All';
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

    final Map<String, double> categorySpend = {};
    for (var tx in provider.transactions.where((t) => t.isExpense)) {
      categorySpend[tx.title] = (categorySpend[tx.title] ?? 0) + tx.amount;
    }
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr('Hello, ${provider.userName}', 'স্বাগতম, ${provider.userName}'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.tr(
                        'Personal Financial Summary & Live Analytics',
                        'ব্যক্তিগত আর্থিক সারসংক্ষেপ ও লাইভ অ্যানালিটিক্স',
                      ),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: provider.tr('Show / Hide Balances', 'ব্যালেন্স লুকান / দেখুন'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  _hideBalances ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF38BDF8),
                  size: 20,
                ),
                onPressed: () => setState(() => _hideBalances = !_hideBalances),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // EXECUTIVE BALANCE CARD
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr('TOTAL NET BALANCE (CASH + WALLETS)', 'মোট নিট ব্যালেন্স (ক্যাশ + ওয়ালেট)'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        provider.cloudStatus,
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _fmt(totalNetWorth),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.tr(
                    'Cashflow Ledger: ${_fmt(netCashflow)}  •  Accounts & Banks: ${_fmt(walletsTotal)}',
                    'ক্যাশফ্লো ব্যালেন্স: ${_fmt(netCashflow)}  •  ব্যাংক ও ওয়ালেট: ${_fmt(walletsTotal)}',
                  ),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricCol(
                          provider.tr('Total Income', 'মোট আয়'),
                          '+${_fmt(income)}',
                          const Color(0xFF10B981),
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFF334155)),
                      Expanded(
                        child: _buildMetricCol(
                          provider.tr('Total Expense', 'মোট ব্যয়'),
                          '-${_fmt(expense)}',
                          const Color(0xFFEF4444),
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFF334155)),
                      Expanded(
                        child: _buildMetricCol(
                          provider.tr('Business Profit', 'ব্যবসায়িক লাভ'),
                          _fmt(provider.netProfit),
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QUICK ACTIONS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    Icons.add_circle_outline_rounded,
                    provider.tr('Add Income', 'আয় যোগ'),
                    const Color(0xFF10B981),
                        () => _showTransactionSheet(context, initialIsExpense: false),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.remove_circle_outline_rounded,
                    provider.tr('Add Expense', 'ব্যয় যোগ'),
                    const Color(0xFFEF4444),
                        () => _showTransactionSheet(context, initialIsExpense: true),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.upload_file_rounded,
                    provider.tr('Add Receipt', 'রসিদ যুক্ত'),
                    const Color(0xFF38BDF8),
                        () => _showTransactionSheet(context, initialIsExpense: true),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.account_balance_wallet_outlined,
                    provider.tr('Wallets', 'ওয়ালেট'),
                    const Color(0xFF818CF8),
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.picture_as_pdf_outlined,
                    provider.tr('Export PDF', 'পিডিএফ'),
                    const Color(0xFFF59E0B),
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExportScreen(userName: provider.userName, userEmail: provider.cloudEmail)),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.storefront_outlined,
                    provider.tr('Biz POS', 'বিজনেস'),
                    const Color(0xFFEC4899),
                        () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessNavigationScreen()),
                          (route) => false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // INTERACTIVE CHARTS SECTION
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
                Text(
                  provider.tr('Cashflow & Category Analytics Chart', 'আয়-ব্যয় এবং ক্যাটাগরি চার্ট বিশ্লেষণ'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.tr(
                    'Visual ratio of your total income, expenses, and wallet reserves.',
                    'আপনার মোট আয়, ব্যয় এবং ওয়ালেট জমার আনুপাতিক চিত্র।',
                  ),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    income > 0 ? income : 1,
                    expense > 0 ? expense : 0,
                    walletsTotal > 0 ? walletsTotal : 0,
                  ],
                  colors: const [Color(0xFF10B981), Color(0xFFEF4444), Color(0xFF0EA5E9)],
                  labels: [
                    provider.tr('Income', 'মোট আয়'),
                    provider.tr('Expense', 'মোট ব্যয়'),
                    provider.tr('Wallets', 'ওয়ালেট জমা'),
                  ],
                  centerTitle: provider.tr('Net Flow', 'নিট ফ্লো'),
                  centerValue: _fmt(netCashflow),
                ),
                if (sortedCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Divider(color: Color(0xFF334155), height: 1),
                  ),
                  Text(
                    provider.tr('Spending by Category', 'খাতওয়ারী ব্যয়ের গ্রাফ'),
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...sortedCategories.take(4).map((entry) {
                    final double pct = expense > 0 ? (entry.value / expense).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text('${_fmt(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: const Color(0xFF0F172A),
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // RECENT TRANSACTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.tr('Recent Transactions & Memos', 'সাম্প্রতিক লেনদেন ও রসিদসমূহ'),
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: Text(provider.tr('View All', 'সব দেখুন'), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr('Search by category, note, or date...', 'ক্যাটাগরি, নোট বা তারিখ দিয়ে খুঁজুন...'),
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All', 'Income', 'Expense'].map((f) {
              final isSel = _txFilter == f;
              final label = f == 'All'
                  ? provider.tr('All', 'সব')
                  : (f == 'Income' ? provider.tr('Income', 'আয়') : provider.tr('Expense', 'ব্যয়'));
              return ChoiceChip(
                label: Text(label, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _txFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (filteredTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No transactions recorded yet. Tap "+ Record Transaction" below to add an entry with an optional PDF/Image receipt.',
                  'এখনো কোনো লেনদেন যোগ করা হয়নি। নিচে "+ লেনদেন যোগ করুন" বাটনে ট্যাপ করে রসিদসহ হিসাব যুক্ত করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredTxs.take(12).map((tx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: ListTile(
                  onTap: () => _showTransactionSheet(context, existing: tx),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tx.isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
                      color: tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      if (tx.hasAttachment)
                        InkWell(
                          onTap: () => AttachmentHelper.viewAttachment(context, tx.attachmentBase64, tx.attachmentName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  provider.tr('Receipt', 'রসিদ'),
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('${tx.subtitle}\n${tx.date}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tx.isExpense ? "-" : "+"}${_fmt(tx.amount)}',
                        style: TextStyle(
                          color: tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
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
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showTransactionSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          provider.tr('Record Transaction', 'লেনদেন যোগ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showTransactionSheet(BuildContext context, {TransactionModel? existing, bool? initialIsExpense}) {
    final provider = context.read<TransactionProvider>();
    bool isExpense = existing?.isExpense ?? (initialIsExpense ?? true);
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: existing?.subtitle ?? '');

    List<String> currentCategories = isExpense ? provider.expenseCategories : provider.incomeCategories;
    String selectedCategory = existing != null && currentCategories.contains(existing.title)
        ? existing.title
        : (currentCategories.isNotEmpty ? currentCategories.first : (isExpense ? 'Food & Dining' : 'Monthly Salary'));

    String selectedWalletId = 'none';
    String attachmentBase64 = existing?.attachmentBase64 ?? '';
    String attachmentName = existing?.attachmentName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = isExpense ? provider.expenseCategories : provider.incomeCategories;
          if (!categories.contains(selectedCategory) && categories.isNotEmpty) {
            selectedCategory = categories.first;
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? provider.tr('Record Financial Transaction', 'নতুন লেনদেন যোগ করুন')
                        : provider.tr('Edit Transaction', 'লেনদেন সম্পাদনা করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(provider.tr('Expense (-)', 'ব্যয় (-)'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          selected: isExpense,
                          selectedColor: const Color(0xFFEF4444),
                          labelStyle: TextStyle(color: isExpense ? Colors.white : const Color(0xFF94A3B8)),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(provider.tr('Income (+)', 'আয় (+)'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          selected: !isExpense,
                          selectedColor: const Color(0xFF10B981),
                          labelStyle: TextStyle(color: !isExpense ? Colors.white : const Color(0xFF94A3B8)),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(provider.tr('Select Category:', 'ক্যাটাগরি নির্বাচন করুন:'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(color: isSel ? Colors.white : const Color(0xFFCBD5E1), fontSize: 12)),
                        selected: isSel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF0F172A),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: provider.tr('Amount (BDT ৳) *', 'টাকার পরিমাণ (৳) *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Memo / Note / Reference', 'মেমো / বিবরণ / নোট'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // UPLOAD RECEIPT / MEMO (PDF, JPG, JPEG, PNG)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachmentName.isEmpty
                                ? provider.tr('Attach Receipt / Memo (PDF, JPG, PNG)', 'রসিদ বা মেমো যুক্ত করুন (PDF, JPG, PNG)')
                                : attachmentName,
                            style: TextStyle(
                              color: attachmentName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (attachmentBase64.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, color: Color(0xFF38BDF8), size: 18),
                            onPressed: () => AttachmentHelper.viewAttachment(context, attachmentBase64, attachmentName),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await AttachmentHelper.pickReceiptOrMemo(context);
                            if (picked != null) {
                              setSheetState(() {
                                attachmentBase64 = picked['base64']?.toString() ?? '';
                                attachmentName = picked['name']?.toString() ?? '';
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(provider.tr('Upload', 'আপলোড'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  if (existing == null && provider.wallets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.tr('Link to Wallet (Optional):', 'ওয়ালেট নির্বাচন করুন (ঐচ্ছিক):'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(provider.tr('None', 'কোনোটি নয়'), style: const TextStyle(fontSize: 11)),
                          selected: selectedWalletId == 'none',
                          selectedColor: const Color(0xFF0EA5E9),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => selectedWalletId = 'none'),
                        ),
                        ...provider.wallets.map((w) {
                          final isSel = selectedWalletId == w.id;
                          return ChoiceChip(
                            label: Text('${w.name} (৳${w.balance.toStringAsFixed(0)})', style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0EA5E9),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() => selectedWalletId = w.id),
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final double amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt == 0 || amt.isNegative) return;

                      String subtitle = noteCtrl.text.trim().isEmpty
                          ? (isExpense ? 'Expense Entry' : 'Income Entry')
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
                          subtitle = '$subtitle • ${w.name}';
                        }
                      }

                      provider.saveTransaction(
                        id: existing?.id,
                        title: selectedCategory,
                        category: subtitle,
                        amount: amt,
                        isExpense: isExpense,
                        attachmentBase64: attachmentBase64,
                        attachmentName: attachmentName,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      provider.tr('Save Transaction', 'লেনদেন সেভ করুন'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
}