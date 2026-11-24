import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'business_navigation.dart';
import 'core/utils/app_currency.dart';
import 'core/widgets/app_feedback.dart';
import 'export_screen.dart';
import 'providers/transaction_provider.dart';
import 'records_screen.dart';
import 'wallets_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _txFilter = 'All';
  String _periodScope = 'All'; // 'All' or 'This Month'
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _inActivePeriod(TransactionModel tx) {
    if (_periodScope != 'This Month') return true;
    final now = DateTime.now();
    final dt = tx.dateTime;
    return dt.year == now.year && dt.month == now.month;
  }

  Future<void> _confirmDeleteTx(
      BuildContext context,
      TransactionProvider provider,
      TransactionModel tx,
      ) async {
    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Transaction?', 'লেনদেন ডিলিট করবেন?'),
      message: provider.tr(
        'Remove "${tx.title}" (${provider.formatMoney(tx.amount)})?',
        '"${tx.title}" (${provider.formatMoney(tx.amount)}) মুছে ফেলবেন?',
      ),
    );
    if (!ok || !context.mounted) return;
    provider.deleteTransaction(tx.id);
    AppFeedback.showInfo(
      context,
      provider.tr('Transaction deleted.', 'লেনদেন মুছে ফেলা হয়েছে।'),
      onUndo: () => provider.restoreTransaction(tx),
    );
  }

  Color _syncBadgeColor(String status) {
    if (status.contains('✓')) return const Color(0xFF10B981);
    if (status.contains('Unsynced')) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    final periodTxs = provider.transactions.where(_inActivePeriod).toList();
    final double income = periodTxs
        .where((t) => !t.isExpense && !t.isTransfer)
        .fold(0.0, (s, t) => s + t.amount);
    final double expense = periodTxs
        .where((t) => t.isExpense && !t.isTransfer)
        .fold(0.0, (s, t) => s + t.amount);
    final double netCashflow = income - expense;
    final double walletsTotal = provider.totalWalletsBalance;
    final double totalNetWorth = provider.totalBalance + walletsTotal;

    final Map<String, double> categorySpend = {};
    for (final tx in periodTxs.where((t) => t.isExpense && !t.isTransfer)) {
      categorySpend[tx.title] = (categorySpend[tx.title] ?? 0.0) + tx.amount;
    }
    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final filteredTxs = periodTxs.where((tx) {
      if (_txFilter == 'Income' && (tx.isExpense || tx.isTransfer)) {
        return false;
      }
      if (_txFilter == 'Expense' && (!tx.isExpense || tx.isTransfer)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final amtRaw = tx.amount.toString();
        final amtFmt =
        AppCurrency.format(tx.amount, respectPrivacy: false).toLowerCase();
        return tx.title.toLowerCase().contains(q) ||
            tx.subtitle.toLowerCase().contains(q) ||
            tx.date.toLowerCase().contains(q) ||
            tx.walletName.toLowerCase().contains(q) ||
            tx.labels.join(' ').toLowerCase().contains(q) ||
            amtRaw.contains(q) ||
            amtFmt.contains(q);
      }
      return true;
    }).toList();

    final badgeColor = _syncBadgeColor(provider.cloudStatus);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
        children: [
          // 1. GREETING & GLOBAL PRIVACY TOGGLE
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr(
                        'Hello, ${provider.userName}',
                        'স্বাগতম, ${provider.userName}',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.tr(
                        'Personal Financial Summary & Live Analytics',
                        'ব্যক্তিগত আর্থিক সারসংক্ষেপ ও লাইভ অ্যানালিটিক্স',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: provider.hideBalances
                    ? provider.tr('Show All Balances', 'ব্যালেন্স দেখান')
                    : provider.tr('Hide All Balances', 'ব্যালেন্স লুকান'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  provider.hideBalances
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: provider.hideBalances
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF38BDF8),
                  size: 20,
                ),
                onPressed: () => provider.toggleHideBalances(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // PERIOD SCOPE TOGGLE (ALL TIME VS THIS MONTH)
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  provider.tr('All Time', 'সব সময়'),
                  style: TextStyle(
                    color: _periodScope == 'All'
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: _periodScope == 'All',
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _periodScope = 'All'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(
                  provider.tr('This Month', 'এই মাস'),
                  style: TextStyle(
                    color: _periodScope == 'This Month'
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: _periodScope == 'This Month',
                selectedColor: const Color(0xFF0EA5E9),
                backgroundColor: const Color(0xFF1E293B),
                showCheckmark: false,
                onSelected: (_) => setState(() => _periodScope = 'This Month'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. EXECUTIVE BALANCE CARD (NO TRUNCATION + TRUTHFUL SYNC BADGE)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr(
                          'TOTAL NET BALANCE (CASH + WALLETS)',
                          'মোট নিট ব্যালেন্স (ক্যাশ + ওয়ালেট)',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        provider.cloudStatus,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    provider.formatMoney(totalNetWorth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${provider.tr("Cashflow", "ক্যাশফ্লো")}: ${provider.formatMoney(netCashflow)}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${provider.tr("Accounts & Banks", "ব্যাংক ও ওয়ালেট")}: ${provider.formatMoney(walletsTotal)}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                          provider.formatMoney(income, showPlusSign: true),
                          const Color(0xFF10B981),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFF334155),
                      ),
                      Expanded(
                        child: _buildMetricCol(
                          provider.tr('Total Expense', 'মোট ব্যয়'),
                          provider.formatMoney(-expense),
                          const Color(0xFFEF4444),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: const Color(0xFF334155),
                      ),
                      Expanded(
                        child: _buildMetricCol(
                          provider.tr('Business Profit', 'ব্যবসায়িক লাভ'),
                          provider.formatMoney(provider.netProfit),
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. QUICK ACTIONS BAR (INCLUDING REPEAT LAST TRANSACTION)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
                    provider.tr('Income', 'আয় যোগ'),
                    const Color(0xFF10B981),
                        () => RecordsScreen.showRecordSheet(
                      context,
                      initialIsExpense: false,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.remove_circle_outline_rounded,
                    provider.tr('Expense', 'ব্যয় যোগ'),
                    const Color(0xFFEF4444),
                        () => RecordsScreen.showRecordSheet(
                      context,
                      initialIsExpense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.replay_rounded,
                    provider.tr('Repeat', 'পুনরাবৃত্তি'),
                    const Color(0xFF38BDF8),
                        () {
                      final ok = provider.repeatLastTransaction();
                      if (ok) {
                        AppFeedback.showInfo(
                          context,
                          provider.tr(
                            'Last transaction repeated.',
                            'সর্বশেষ লেনদেনটি পুনরায় যোগ হয়েছে।',
                          ),
                        );
                      } else {
                        AppFeedback.showError(
                          context,
                          provider.tr(
                            'No previous transaction to repeat yet.',
                            'পুনরাবৃত্তি করার মতো কোনো লেনদেন নেই।',
                          ),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.account_balance_wallet_outlined,
                    provider.tr('Wallets', 'ওয়ালেট'),
                    const Color(0xFF818CF8),
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletsScreen()),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.picture_as_pdf_outlined,
                    provider.tr('Export', 'এক্সপোর্ট'),
                    const Color(0xFFF59E0B),
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(
                          userName: provider.userName,
                          userEmail: provider.cloudEmail,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildActionBtn(
                    Icons.storefront_outlined,
                    provider.tr('Biz POS', 'বিজনেস'),
                    const Color(0xFFEC4899),
                        () async {
                      await provider.saveNavigationState(isBusinessMode: true);
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BusinessNavigationScreen(),
                        ),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. INTERACTIVE CHARTS SECTION (ZERO-SAFE, NEVER 100% ON EMPTY)
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
                  provider.tr(
                    'Cashflow & Category Analytics',
                    'আয়-ব্যয় এবং ক্যাটাগরি চার্ট বিশ্লেষণ',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.tr(
                    'Visual ratio of your income, expenses, and wallet reserves.',
                    'আপনার আয়, ব্যয় এবং ওয়ালেট জমার আনুপাতিক চিত্র।',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    income,
                    expense,
                    walletsTotal > 0 ? walletsTotal : 0.0,
                  ],
                  colors: const [
                    Color(0xFF10B981),
                    Color(0xFFEF4444),
                    Color(0xFF0EA5E9),
                  ],
                  labels: [
                    '${provider.tr("Income", "আয়")} (${provider.formatMoney(income)})',
                    '${provider.tr("Expense", "ব্যয়")} (${provider.formatMoney(expense)})',
                    '${provider.tr("Wallets", "ওয়ালেট")} (${provider.formatMoney(walletsTotal)})',
                  ],
                  centerTitle: provider.tr('Net Flow', 'নিট ফ্লো'),
                  centerValue: provider.formatMoney(netCashflow),
                ),
                if (sortedCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Divider(color: Color(0xFF334155), height: 1),
                  ),
                  Text(
                    provider.tr('Spending by Category', 'খাতওয়ারী ব্যয়ের গ্রাফ'),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sortedCategories.take(4).map((entry) {
                    final double pct =
                    expense > 0 ? (entry.value / expense).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${provider.formatMoney(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
          const SizedBox(height: 20),

          // 5. RECENT TRANSACTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  provider.tr(
                    'Recent Transactions & Receipts',
                    'সাম্প্রতিক লেনদেন ও রসিদসমূহ',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: Text(
                    provider.tr('View All', 'সব দেখুন'),
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search category, note, amount, or date...',
                'ক্যাটাগরি, নোট, টাকা বা তারিখ দিয়ে খুঁজুন...',
              ),
              hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon:
              const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['All', 'Income', 'Expense'].map((f) {
              final isSel = _txFilter == f;
              final label = f == 'All'
                  ? provider.tr('All', 'সব')
                  : (f == 'Income'
                  ? provider.tr('Income', 'আয়')
                  : provider.tr('Expense', 'ব্যয়'));
              return ChoiceChip(
                label: Text(
                  label,
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  'No transactions recorded yet. Tap "+ Record Transaction" below to add an entry with an optional receipt.',
                  'এখনো কোনো লেনদেন যোগ করা হয়নি। নিচে "+ লেনদেন যোগ করুন" বাটনে ট্যাপ করে রসিদসহ হিসাব যুক্ত করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredTxs.take(10).map((tx) {
              final Color accent = tx.isTransfer
                  ? const Color(0xFF38BDF8)
                  : (tx.isExpense
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981));
              final String cleanMemo = (tx.subtitle == 'Recorded Entry' ||
                  tx.subtitle == 'Expense Entry' ||
                  tx.subtitle == 'Income Entry')
                  ? ''
                  : tx.subtitle;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        tx.isTransfer
                            ? Icons.swap_horiz_rounded
                            : (tx.isExpense
                            ? Icons.north_east_rounded
                            : Icons.south_west_rounded),
                        color: accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tx.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (tx.hasAttachment)
                                InkWell(
                                  onTap: () => AttachmentHelper.viewAttachment(
                                    context,
                                    tx.attachmentBase64,
                                    tx.attachmentName,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.zoom_in_rounded,
                                          color: Color(0xFF38BDF8),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          provider.tr('Receipt', 'রসিদ'),
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (cleanMemo.isNotEmpty)
                            Text(
                              cleanMemo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11.5,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${tx.date}${tx.walletName.isNotEmpty ? " • ${tx.walletName}" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          tx.isTransfer
                              ? provider.formatMoney(tx.amount)
                              : provider.formatMoney(
                            tx.isExpense ? -tx.amount : tx.amount,
                            showPlusSign: !tx.isExpense,
                          ),
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!tx.isTransfer)
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => RecordsScreen.showRecordSheet(
                                  context,
                                  existing: tx,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF38BDF8),
                                    size: 17,
                                  ),
                                ),
                              ),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () =>
                                  _confirmDeleteTx(context, provider, tx),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                  size: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => RecordsScreen.showRecordSheet(context),
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
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}