import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _filterType = 'All'; // 'All', 'Income', 'Expense', 'With Receipt'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double totalInc = provider.totalIncome;
    final double totalExp = provider.totalExpense;
    final int receiptCount = provider.transactions.where((t) => t.hasAttachment).length;

    final filteredList = provider.transactions.where((tx) {
      if (_filterType == 'Income' && tx.isExpense) return false;
      if (_filterType == 'Expense' && !tx.isExpense) return false;
      if (_filterType == 'With Receipt' && !tx.hasAttachment) return false;
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
          Text(
            provider.tr('Transaction Ledger & Audit Trail', 'লেনদেনের পূর্ণাঙ্গ তালিকা ও অডিট'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            provider.tr(
              'Search, filter, and inspect all income, expenses, and attached receipts.',
              'সকল আয়, ব্যয় এবং সংযুক্ত রসিদ বা মেমো এখান থেকে খুঁজুন ও যাচাই করুন।',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. ANALYTICS CHART CARD (OVERFLOW-PROOF HEADER)
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr('Income vs Expense Ratio Chart', 'আয় বনাম ব্যয়ের তুলনামূলক চার্ট'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.tr('$receiptCount Receipts', '$receiptCount টি রসিদ'),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    totalInc > 0 ? totalInc : 1,
                    totalExp > 0 ? totalExp : 0,
                  ],
                  colors: const [Color(0xFF10B981), Color(0xFFEF4444)],
                  labels: [
                    '${provider.tr("Total Income", "মোট আয়")} (৳${totalInc.toStringAsFixed(0)})',
                    '${provider.tr("Total Expense", "মোট ব্যয়")} (৳${totalExp.toStringAsFixed(0)})',
                  ],
                  centerTitle: provider.tr('Total Entries', 'মোট লেনদেন'),
                  centerValue: '${provider.transactions.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. SEARCH & FILTER BAR
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr('Search records by category, memo, or date...', 'ক্যাটাগরি, মেমো বা তারিখ দিয়ে খুঁজুন...'),
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', provider.tr('All Records', 'সব লেনদেন')),
              _buildFilterChip('Income', provider.tr('Income Only', 'শুধু আয়')),
              _buildFilterChip('Expense', provider.tr('Expense Only', 'শুধু ব্যয়')),
              _buildFilterChip('With Receipt', provider.tr('With Receipt / Memo', 'রসিদসহ লেনদেন')),
            ],
          ),
          const SizedBox(height: 14),

          // 3. TRANSACTION LIST
          if (filteredList.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No matching records found. Tap "+ Add Record & Receipt" below to log a transaction.',
                  'কোনো লেনদেন পাওয়া যায়নি। নিচে "+ নতুন লেনদেন ও রসিদ" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredList.map((tx) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ListTile(
                onTap: () => _showRecordDialog(context, existing: tx),
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
                      child: Text(
                        tx.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      '${tx.isExpense ? "-" : "+"}৳${tx.amount.toStringAsFixed(0)}',
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
            )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showRecordDialog(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(
          provider.tr('Add Record & Receipt', 'নতুন লেনদেন ও রসিদ'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _filterType == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSel,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      onSelected: (_) => setState(() => _filterType = key),
    );
  }

  void _showRecordDialog(BuildContext context, {TransactionModel? existing}) {
    final provider = context.read<TransactionProvider>();
    bool isExpense = existing?.isExpense ?? true;
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final noteCtrl = TextEditingController(text: existing?.subtitle ?? '');
    List<String> cats = isExpense ? provider.expenseCategories : provider.incomeCategories;
    String selectedCat = existing != null && cats.contains(existing.title)
        ? existing.title
        : (cats.isNotEmpty ? cats.first : 'General');
    String attBase64 = existing?.attachmentBase64 ?? '';
    String attName = existing?.attachmentName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentCats = isExpense ? provider.expenseCategories : provider.incomeCategories;
          if (!currentCats.contains(selectedCat) && currentCats.isNotEmpty) {
            selectedCat = currentCats.first;
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
                        ? provider.tr('Add Transaction & Memo', 'লেনদেন ও মেমো যোগ করুন')
                        : provider.tr('Update Transaction', 'লেনদেন আপডেট করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(provider.tr('Expense (-)', 'ব্যয় (-)'))),
                          selected: isExpense,
                          selectedColor: const Color(0xFFEF4444),
                          labelStyle: TextStyle(color: isExpense ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(provider.tr('Income (+)', 'আয় (+)'))),
                          selected: !isExpense,
                          selectedColor: const Color(0xFF10B981),
                          labelStyle: TextStyle(color: !isExpense ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => isExpense = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentCats.map((c) {
                      final isSel = c == selectedCat;
                      return ChoiceChip(
                        label: Text(c, style: TextStyle(color: isSel ? Colors.white : const Color(0xFFCBD5E1), fontSize: 12)),
                        selected: isSel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF0F172A),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => selectedCat = c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Amount (৳)', 'টাকার পরিমাণ (৳)'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
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
                      labelText: provider.tr('Memo / Description', 'মেমো / বিবরণ'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attName.isEmpty
                                ? provider.tr('Upload Receipt / Memo (Image/PDF)', 'রসিদ বা মেমো আপলোড করুন')
                                : attName,
                            style: TextStyle(color: attName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF10B981), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await AttachmentHelper.pickReceiptOrMemo(context);
                            if (picked != null) {
                              setSheetState(() {
                                attBase64 = picked['base64']?.toString() ?? '';
                                attName = picked['name']?.toString() ?? '';
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(provider.tr('Attach', 'যুক্ত করুন'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) return;
                      provider.saveTransaction(
                        id: existing?.id,
                        title: selectedCat,
                        category: noteCtrl.text.trim().isEmpty ? 'Recorded Entry' : noteCtrl.text.trim(),
                        amount: amt,
                        isExpense: isExpense,
                        attachmentBase64: attBase64,
                        attachmentName: attName,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(provider.tr('Save Record', 'লেনদেন সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
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