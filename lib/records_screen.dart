import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

typedef TxList = List<TransactionModel>;

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  /// Shared Add/Edit Transaction modal (used by both Records and Home Dashboard).
  static void showRecordSheet(
      BuildContext context, {
        TransactionModel? existing,
        bool? initialIsExpense,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransactionEditorSheet(
        existing: existing,
        initialIsExpense: initialIsExpense,
      ),
    );
  }

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _filterType = 'All'; // All, Income, Expense, Transfer, With Receipt
  String _periodFilter = 'All'; // All, This Month, Last Month, Custom
  String _sortBy = 'Newest'; // Newest, Oldest, HighAmount, LowAmount
  String _searchQuery = '';
  DateTimeRange? _customRange;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _periodFilter = 'Custom';
      });
    }
  }

  bool _matchesPeriod(TransactionModel tx) {
    final dt = tx.dateTime;
    final now = DateTime.now();
    if (_periodFilter == 'This Month') {
      return dt.year == now.year && dt.month == now.month;
    }
    if (_periodFilter == 'Last Month') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return dt.year == lastMonth.year && dt.month == lastMonth.month;
    }
    if (_periodFilter == 'Custom' && _customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );
      return !dt.isBefore(start) && !dt.isAfter(end);
    }
    return true;
  }

  String _dayKey(DateTime dt, TransactionProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) {
      return '${provider.tr("Today", "আজ")} • ${provider.formatDateOnly(dt)}';
    }
    if (target == yesterday) {
      return '${provider.tr("Yesterday", "গতকাল")} • ${provider.formatDateOnly(dt)}';
    }
    return provider.formatDateOnly(dt);
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
        'Remove "${tx.title}" (${provider.formatMoney(tx.amount)}) from your records?',
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    final List<TransactionModel> filtered = provider.transactions.where((tx) {
      if (!_matchesPeriod(tx)) return false;
      if (_filterType == 'Income' && (tx.isExpense || tx.isTransfer)) {
        return false;
      }
      if (_filterType == 'Expense' && (!tx.isExpense || tx.isTransfer)) {
        return false;
      }
      if (_filterType == 'Transfer' && !tx.isTransfer) return false;
      if (_filterType == 'With Receipt' && !tx.hasAttachment) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final amtRaw = tx.amount.toString();
        final amtFixed = tx.amount.toStringAsFixed(2);
        final amtFormatted =
        AppCurrency.format(tx.amount, respectPrivacy: false).toLowerCase();
        final labelText = tx.labels.join(' ').toLowerCase();
        return tx.title.toLowerCase().contains(q) ||
            tx.subtitle.toLowerCase().contains(q) ||
            tx.date.toLowerCase().contains(q) ||
            tx.walletName.toLowerCase().contains(q) ||
            labelText.contains(q) ||
            amtRaw.contains(q) ||
            amtFixed.contains(q) ||
            amtFormatted.contains(q);
      }
      return true;
    }).toList();

    // Apply Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Oldest':
          return a.timestampMs.compareTo(b.timestampMs);
        case 'HighAmount':
          return b.amount.compareTo(a.amount);
        case 'LowAmount':
          return a.amount.compareTo(b.amount);
        case 'Newest':
        default:
          return b.timestampMs.compareTo(a.timestampMs);
      }
    });

    final double filteredInc = filtered
        .where((t) => !t.isExpense && !t.isTransfer)
        .fold(0.0, (s, t) => s + t.amount);
    final double filteredExp = filtered
        .where((t) => t.isExpense && !t.isTransfer)
        .fold(0.0, (s, t) => s + t.amount);
    final int receiptCount = filtered.where((t) => t.hasAttachment).length;

    // Group transactions by day while preserving sorted order
    final List<String> dayOrder = [];
    final Map<String, TxList> groupedByDay = {};
    for (final tx in filtered) {
      final key = _dayKey(tx.dateTime, provider);
      if (!groupedByDay.containsKey(key)) {
        dayOrder.add(key);
        groupedByDay[key] = [];
      }
      groupedByDay[key]!.add(tx);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
        children: [
          Text(
            provider.tr(
              'Transaction Ledger & Audit Trail',
              'লেনদেনের পূর্ণাঙ্গ তালিকা ও অডিট',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.tr(
              'Search by name or amount, filter by month/date range, and inspect receipts.',
              'নাম বা টাকার পরিমাণ দিয়ে খুঁজুন, মাস/তারিখ ফিল্টার করুন এবং রসিদ দেখুন।',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. ANALYTICS DONUT CHART CARD (ZERO-SAFE, NO 100% ON EMPTY)
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
                    Expanded(
                      child: Text(
                        provider.tr(
                          'Income vs Expense Ratio',
                          'আয় বনাম ব্যয়ের তুলনা',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.tr(
                          '$receiptCount ${receiptCount == 1 ? "Receipt" : "Receipts"}',
                          '$receiptCount টি রসিদ',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                RealisticDonutChart(
                  values: [filteredInc, filteredExp],
                  colors: const [Color(0xFF10B981), Color(0xFFEF4444)],
                  labels: [
                    '${provider.tr("Income", "আয়")} (${provider.formatMoney(filteredInc)})',
                    '${provider.tr("Expense", "ব্যয়")} (${provider.formatMoney(filteredExp)})',
                  ],
                  centerTitle: provider.tr('Entries', 'মোট লেনদেন'),
                  centerValue: '${filtered.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. SEARCH BAR (MATCHES CATEGORY, MEMO, WALLET, LABEL, DATE & AMOUNT)
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search category, memo, amount, label, or wallet...',
                'ক্যাটাগরি, মেমো, টাকা, ট্যাগ বা ওয়ালেট খুঁজুন...',
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

          // 3. MONTH / DATE RANGE FILTER + SORT BAR
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip('All', provider.tr('All Time', 'সব সময়')),
                      const SizedBox(width: 6),
                      _buildPeriodChip(
                        'This Month',
                        provider.tr('This Month', 'এই মাস'),
                      ),
                      const SizedBox(width: 6),
                      _buildPeriodChip(
                        'Last Month',
                        provider.tr('Last Month', 'গত মাস'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: Color(0xFF38BDF8),
                        ),
                        backgroundColor: _periodFilter == 'Custom'
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.25)
                            : const Color(0xFF1E293B),
                        side: BorderSide(
                          color: _periodFilter == 'Custom'
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF334155),
                        ),
                        label: Text(
                          _periodFilter == 'Custom' && _customRange != null
                              ? '${provider.formatDateOnly(_customRange!.start)} - ${provider.formatDateOnly(_customRange!.end)}'
                              : provider.tr('Date Range', 'তারিখ সীমা'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _pickCustomDateRange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: provider.tr('Sort Records', 'সাজান'),
                color: const Color(0xFF1E293B),
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'Newest',
                    child: Text(
                      provider.tr('Newest First', 'নতুন আগে'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Oldest',
                    child: Text(
                      provider.tr('Oldest First', 'পুরোনো আগে'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'HighAmount',
                    child: Text(
                      provider.tr('Highest Amount', 'বেশি টাকা আগে'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'LowAmount',
                    child: Text(
                      provider.tr('Lowest Amount', 'কম টাকা আগে'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(
                    Icons.sort_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. TYPE FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', provider.tr('All', 'সব')),
                const SizedBox(width: 6),
                _buildFilterChip('Income', provider.tr('Income', 'আয়')),
                const SizedBox(width: 6),
                _buildFilterChip('Expense', provider.tr('Expense', 'ব্যয়')),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Transfer',
                  provider.tr('Transfers', 'ট্রান্সফার'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'With Receipt',
                  provider.tr('With Receipt', 'রসিদসহ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. DAY-GROUPED TRANSACTION LIST WITH DAILY SUBTOTALS
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No matching records found. Tap "+ Add Record" below to log a transaction.',
                  'কোনো লেনদেন পাওয়া যায়নি। নিচে "+ নতুন লেনদেন" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...dayOrder.map((dayLabel) {
              final dayTxs = groupedByDay[dayLabel]!;
              final double dayNet = dayTxs.fold(0.0, (sum, tx) {
                if (tx.isTransfer) return sum;
                return sum + (tx.isExpense ? -tx.amount : tx.amount);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8, left: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.tr("Day Net", "দৈনিক নিট")}: ${provider.formatMoney(dayNet, showPlusSign: true)}',
                          style: TextStyle(
                            color: dayNet >= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayTxs.map((tx) => _buildTxCard(context, provider, tx)),
                ],
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
          provider.tr('Add Record', 'নতুন লেনদেন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTxCard(
      BuildContext context,
      TransactionProvider provider,
      TransactionModel tx,
      ) {
    final Color accent = tx.isTransfer
        ? const Color(0xFF38BDF8)
        : (tx.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981));

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  tx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (cleanMemo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    cleanMemo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tx.date,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                    ),
                    if (tx.walletName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          tx.walletName,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ...tx.labels.map(
                          (lbl) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$lbl',
                          style: const TextStyle(
                            color: Color(0xFFC4B5FD),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (tx.hasAttachment)
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
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
                            color:
                            const Color(0xFF0EA5E9).withValues(alpha: 0.2),
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
                                tx.attachmentName.isNotEmpty
                                    ? tx.attachmentName
                                    : provider.tr('View Receipt', 'রসিদ দেখুন'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!tx.isTransfer)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          RecordsScreen.showRecordSheet(context, existing: tx),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmDeleteTx(context, provider, tx),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 18,
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
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _filterType == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSel ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSel,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      onSelected: (_) => setState(() => _filterType = key),
    );
  }

  Widget _buildPeriodChip(String key, String label) {
    final isSel = _periodFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSel ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSel,
      selectedColor: const Color(0xFF1D4ED8),
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      onSelected: (_) => setState(() => _periodFilter = key),
    );
  }
}

// =============================================================================
// UNIFIED ADD / EDIT TRANSACTION MODAL (WALLET, DATE, LABELS, RECEIPT, RECURRING)
// =============================================================================
class _TransactionEditorSheet extends StatefulWidget {
  final TransactionModel? existing;
  final bool? initialIsExpense;

  const _TransactionEditorSheet({this.existing, this.initialIsExpense});

  @override
  State<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<_TransactionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late bool _isExpense;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _selectedCat;
  late DateTime _selectedDate;
  String _selectedWalletId = '';
  List<String> _selectedLabels = [];
  String _attBase64 = '';
  String _attName = '';
  bool _alsoScheduleBill = false;
  DateTime _nextBillDueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    final ex = widget.existing;
    _isExpense = ex?.isExpense ?? widget.initialIsExpense ?? true;

    final double? existingAmt = ex?.amount;
    String amtText = '';
    if (existingAmt != null) {
      final hasDec =
          (existingAmt - existingAmt.truncateToDouble()).abs() > 0.001;
      amtText = hasDec
          ? existingAmt.toStringAsFixed(2)
          : existingAmt.toStringAsFixed(0);
    }
    _amountCtrl = TextEditingController(text: amtText);

    // Keep memo blank on Edit if none was actually typed
    final rawSub = ex?.subtitle ?? '';
    final cleanSub = (rawSub == 'Recorded Entry' ||
        rawSub == 'Expense Entry' ||
        rawSub == 'Income Entry')
        ? ''
        : rawSub;
    _noteCtrl = TextEditingController(text: cleanSub);

    final cats =
    _isExpense ? provider.expenseCategories : provider.incomeCategories;
    final lastUsed = _isExpense
        ? provider.lastUsedExpenseCategory
        : provider.lastUsedIncomeCategory;

    if (ex != null && cats.contains(ex.title)) {
      _selectedCat = ex.title;
    } else if (cats.contains(lastUsed)) {
      _selectedCat = lastUsed;
    } else {
      _selectedCat = cats.isNotEmpty ? cats.first : 'General';
    }

    _selectedDate = ex?.dateTime ?? DateTime.now();

    if (ex != null && ex.walletId.isNotEmpty) {
      _selectedWalletId = ex.walletId;
    } else if (provider.lastUsedWalletId.isNotEmpty &&
        provider.wallets.any((w) => w.id == provider.lastUsedWalletId)) {
      _selectedWalletId = provider.lastUsedWalletId;
    } else if (provider.wallets.isNotEmpty) {
      _selectedWalletId = provider.wallets.first.id;
    }

    _selectedLabels = List<String>.from(ex?.labels ?? const []);
    _attBase64 = ex?.attachmentBase64 ?? '';
    _attName = ex?.attachmentName ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _pickNextDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() => _nextBillDueDate = picked);
    }
  }

  Future<void> _quickAddCategory(TransactionProvider provider) async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          provider.tr('New Category', 'নতুন ক্যাটাগরি'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: provider.tr('e.g., Medical / Education', 'যেমন: চিকিৎসা / শিক্ষা'),
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.tr('Cancel', 'বাতিল')),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: Text(provider.tr('Add', 'যোগ করুন')),
          ),
        ],
      ),
    );
    if (added != null && added.isNotEmpty && mounted) {
      provider.addCategory(added, _isExpense);
      setState(() => _selectedCat = added);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currentCats =
    _isExpense ? provider.expenseCategories : provider.incomeCategories;
    if (!currentCats.contains(_selectedCat) && currentCats.isNotEmpty) {
      _selectedCat = currentCats.first;
    }

    final WalletModel? activeWallet = provider.wallets.any(
          (w) => w.id == _selectedWalletId,
    )
        ? provider.wallets.firstWhere((w) => w.id == _selectedWalletId)
        : null;

    final double? typedAmt = AppCurrency.parseAmount(_amountCtrl.text);
    double? projectedWalletBalance;
    if (activeWallet != null && typedAmt != null && typedAmt > 0) {
      projectedWalletBalance = activeWallet.balance +
          (_isExpense ? -typedAmt : typedAmt);
    }

    final now = DateTime.now();
    final bool isToday = DateUtils.isSameDay(_selectedDate, now);
    final bool isYesterday = DateUtils.isSameDay(
      _selectedDate,
      now.subtract(const Duration(days: 1)),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? provider.tr(
                        'Record Transaction',
                        'নতুন লেনদেন যোগ করুন',
                      )
                          : provider.tr(
                        'Edit Transaction',
                        'লেনদেন এডিট করুন',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // EXPENSE / INCOME SWITCHER
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(provider.tr('Expense (-)', 'ব্যয় (-)')),
                      ),
                      selected: _isExpense,
                      selectedColor: const Color(0xFFEF4444),
                      labelStyle: TextStyle(
                        color: _isExpense
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _isExpense = true;
                        if (provider.expenseCategories
                            .contains(provider.lastUsedExpenseCategory)) {
                          _selectedCat = provider.lastUsedExpenseCategory;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(provider.tr('Income (+)', 'আয় (+)')),
                      ),
                      selected: !_isExpense,
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(
                        color: !_isExpense
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _isExpense = false;
                        if (provider.incomeCategories
                            .contains(provider.lastUsedIncomeCategory)) {
                          _selectedCat = provider.lastUsedIncomeCategory;
                        }
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // AMOUNT FIELD (EXACT DECIMALS + UPPER CAP + INLINE VALIDATION)
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppValidators.amountFormatters,
                validator: (v) => AppValidators.positiveAmount(
                  v,
                  label: provider.tr('Amount', 'পরিমাণ'),
                ),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: provider.tr(
                    'Amount (${provider.currencyCode} ${provider.currencySymbol}) *',
                    'টাকার পরিমাণ (${provider.currencySymbol}) *',
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: 'e.g. 250.50',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  errorStyle: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 11.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // CATEGORY CHIPS + CUSTOM CATEGORY BUTTON
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.tr('Category', 'ক্যাটাগরি'),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _quickAddCategory(provider),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 14,
                      color: Color(0xFF38BDF8),
                    ),
                    label: Text(
                      provider.tr('New Category', 'নতুন খাত'),
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: currentCats.map((c) {
                  final isSel = c == _selectedCat;
                  return ChoiceChip(
                    label: Text(
                      c,
                      style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF0EA5E9),
                    backgroundColor: const Color(0xFF0F172A),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedCat = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // DATE PICKER WITH TODAY / YESTERDAY QUICK BUTTONS
              Text(
                provider.tr('Date', 'তারিখ'),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(provider.tr('Today', 'আজ')),
                    selected: isToday,
                    selectedColor: const Color(0xFF0EA5E9),
                    labelStyle: TextStyle(
                      color: isToday ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _selectedDate = DateTime.now()),
                  ),
                  ChoiceChip(
                    label: Text(provider.tr('Yesterday', 'গতকাল')),
                    selected: isYesterday,
                    selectedColor: const Color(0xFF0EA5E9),
                    labelStyle: TextStyle(
                      color:
                      isYesterday ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                    showCheckmark: false,
                    onSelected: (_) => setState(
                          () => _selectedDate =
                          DateTime.now().subtract(const Duration(days: 1)),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.calendar_month_outlined,
                      size: 15,
                      color: Color(0xFF38BDF8),
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: Text(
                      provider.formatDateOnly(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // WALLET SELECTOR + LIVE POST-TRANSACTION WALLET BALANCE PREVIEW
              if (provider.wallets.isNotEmpty) ...[
                Text(
                  provider.tr('Link to Wallet', 'ওয়ালেট নির্বাচন'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: provider.wallets
                          .any((w) => w.id == _selectedWalletId)
                          ? _selectedWalletId
                          : '',
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(
                            provider.tr(
                              'No wallet linked',
                              'কোনো ওয়ালেট যুক্ত নয়',
                            ),
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                        ...provider.wallets.map(
                              (w) => DropdownMenuItem<String>(
                            value: w.id,
                            child: Text(
                              '${w.name} (${provider.formatMoney(w.balance)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedWalletId = val ?? ''),
                    ),
                  ),
                ),
                if (activeWallet != null && projectedWalletBalance != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${provider.tr("Wallet balance after entry", "লেনদেনের পর ওয়ালেট ব্যালেন্স")}: ${provider.formatMoney(projectedWalletBalance)}',
                    style: TextStyle(
                      color: projectedWalletBalance >= 0
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFF87171),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // LABELS / TAGS MULTI-SELECT CHIPS (CONNECTS TO LABELS TAB)
              if (provider.customLabels.isNotEmpty) ...[
                Text(
                  provider.tr('Labels / Tags (Optional)', 'ট্যাগ / লেবেল (ঐচ্ছিক)'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: provider.customLabels.map((lbl) {
                    final selected = _selectedLabels.contains(lbl);
                    return FilterChip(
                      label: Text(
                        '#$lbl',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFCBD5E1),
                          fontSize: 11.5,
                        ),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF7C3AED),
                      backgroundColor: const Color(0xFF0F172A),
                      showCheckmark: false,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _selectedLabels.add(lbl);
                          } else {
                            _selectedLabels.remove(lbl);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // MEMO FIELD (OPTIONAL — NEVER AUTO-FILLED WITH GENERIC TEXT)
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: provider.tr(
                    'Memo / Note (Optional)',
                    'মেমো / বিবরণ (ঐচ্ছিক)',
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: provider.tr(
                    'e.g., Lunch with team',
                    'যেমন: দুপুরের খাবার',
                  ),
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // RECEIPT ATTACHMENT WITH THUMBNAIL PREVIEW & TAP-TO-ZOOM
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _attBase64.isNotEmpty
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_attBase64.isNotEmpty)
                          GestureDetector(
                            onTap: () => AttachmentHelper.viewAttachment(
                              context,
                              _attBase64,
                              _attName,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: buildTrueColorWrapper(
                                isDarkMode: provider.isDarkMode,
                                child: Image.memory(
                                  base64Decode(_attBase64),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.attach_file,
                            color: Color(0xFF38BDF8),
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _attBase64.isEmpty
                                    ? provider.tr(
                                  'Attach Receipt Photo (Compressed)',
                                  'রসিদের ছবি যুক্ত করুন',
                                )
                                    : (_attName.isNotEmpty
                                    ? _attName
                                    : 'Receipt attached'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _attBase64.isEmpty
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_attBase64.isNotEmpty)
                                Text(
                                  provider.tr(
                                    'Tap thumbnail to zoom & read',
                                    'বড় করে দেখতে ছবিতে ট্যাপ করুন',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_attBase64.isNotEmpty)
                          IconButton(
                            tooltip: provider.tr('Remove', 'মুছুন'),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () => setState(() {
                              _attBase64 = '';
                              _attName = '';
                            }),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked =
                            await AttachmentHelper.pickReceiptOrMemo(
                              context,
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _attBase64 = picked['base64'] ?? '';
                                _attName = picked['name'] ?? '';
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.upload_file,
                            size: 16,
                            color: Color(0xFF38BDF8),
                          ),
                          label: Text(
                            _attBase64.isEmpty
                                ? provider.tr('Attach', 'যুক্ত করুন')
                                : provider.tr('Change', 'বদলান'),
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // OPTIONAL RECURRING / SCHEDULED BILL REMINDER TOGGLE
              if (widget.existing == null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFF0EA5E9),
                  title: Text(
                    provider.tr(
                      'Also save as Scheduled Bill Reminder',
                      'নির্ধারিত বিল রিমাইন্ডার হিসেবে সেভ করুন',
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: _alsoScheduleBill
                      ? GestureDetector(
                    onTap: _pickNextDueDate,
                    child: Text(
                      '${provider.tr("Next Due Date", "পরবর্তী তারিখ")}: ${provider.formatDateOnly(_nextBillDueDate)} (${provider.tr("tap to change", "বদলাতে ট্যাপ করুন")})',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11.5,
                      ),
                    ),
                  )
                      : null,
                  value: _alsoScheduleBill,
                  onChanged: (v) => setState(() => _alsoScheduleBill = v),
                ),
              ],

              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final amt = AppCurrency.parseAmount(_amountCtrl.text);
                  if (amt == null || amt <= 0) return;

                  final walletName = activeWallet?.name ?? '';
                  provider.saveTransaction(
                    id: widget.existing?.id,
                    title: _selectedCat,
                    category: _noteCtrl.text.trim(),
                    amount: amt,
                    isExpense: _isExpense,
                    attachmentBase64: _attBase64,
                    attachmentName: _attName,
                    dateTime: _selectedDate,
                    walletId: _selectedWalletId,
                    walletName: walletName,
                    labels: _selectedLabels,
                    updateWalletBalance: _selectedWalletId.isNotEmpty,
                  );

                  if (_alsoScheduleBill && widget.existing == null) {
                    provider.saveScheduledTx(
                      title: _noteCtrl.text.trim().isNotEmpty
                          ? _noteCtrl.text.trim()
                          : _selectedCat,
                      amount: amt,
                      dueDate: provider.formatDateOnly(_nextBillDueDate),
                      isExpense: _isExpense,
                      attachmentBase64: _attBase64,
                      attachmentName: _attName,
                    );
                  }

                  Navigator.pop(context);
                  AppFeedback.showInfo(
                    context,
                    widget.existing == null
                        ? provider.tr('Transaction saved.', 'লেনদেন সেভ হয়েছে।')
                        : provider.tr(
                      'Transaction updated.',
                      'লেনদেন আপডেট হয়েছে।',
                    ),
                  );
                },
                child: Text(
                  widget.existing == null
                      ? provider.tr('Save Record', 'লেনদেন সেভ করুন')
                      : provider.tr('Update Record', 'লেনদেন আপডেট করুন'),
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
    );
  }
}