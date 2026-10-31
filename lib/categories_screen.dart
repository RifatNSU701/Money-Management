import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _showExpense = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final List<String> activeList = _showExpense ? provider.expenseCategories : provider.incomeCategories;

    // Calculate volume per category for the chart
    final Map<String, double> catTotals = {};
    double grandTotal = 0.0;
    for (var c in activeList) {
      final double sum = provider.transactions
          .where((t) => t.isExpense == _showExpense && t.title == c)
          .fold(0.0, (s, t) => s + t.amount);
      catTotals[c] = sum;
      grandTotal += sum;
    }

    final List<Color> palette = const [
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            provider.tr('Categories & Labels Analytics', 'ক্যাটাগরি ও খাতওয়ারী বিশ্লেষণ'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            provider.tr(
              'Customize your income and expense categories and view distribution charts.',
              'আপনার আয় ও ব্যয়ের খাতসমূহ কাস্টমাইজ করুন এবং খাতওয়ারী গ্রাফ দেখুন।',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. CATEGORY DISTRIBUTION CHART
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
                  _showExpense
                      ? provider.tr('Expense Category Share Chart', 'ব্যয়ের খাতওয়ারী অনুপাত চার্ট')
                      : provider.tr('Income Category Share Chart', 'আয়ের খাতওয়ারী অনুপাত চার্ট'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: activeList.isEmpty
                      ? [1]
                      : activeList.map((c) => (catTotals[c] ?? 0) > 0 ? catTotals[c]! : 1.0).toList(),
                  colors: palette,
                  labels: activeList.isEmpty ? ['None'] : activeList,
                  centerTitle: provider.tr('Categories', 'মোট খাত'),
                  centerValue: '${activeList.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. EXPENSE / INCOME TAB SWITCHER
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      provider.tr('Expense Categories (${provider.expenseCategories.length})', 'ব্যয়ের খাত (${provider.expenseCategories.length})'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: _showExpense,
                  selectedColor: const Color(0xFFEF4444),
                  labelStyle: TextStyle(color: _showExpense ? Colors.white : const Color(0xFF94A3B8)),
                  backgroundColor: const Color(0xFF1E293B),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showExpense = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      provider.tr('Income Categories (${provider.incomeCategories.length})', 'আয়ের খাত (${provider.incomeCategories.length})'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: !_showExpense,
                  selectedColor: const Color(0xFF10B981),
                  labelStyle: TextStyle(color: !_showExpense ? Colors.white : const Color(0xFF94A3B8)),
                  backgroundColor: const Color(0xFF1E293B),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showExpense = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. CATEGORY LIST WITH BAR INDICATORS
          ...activeList.asMap().entries.map((entry) {
            final int idx = entry.key;
            final String cat = entry.value;
            final double amt = catTotals[cat] ?? 0.0;
            final double pct = grandTotal > 0 ? (amt / grandTotal).clamp(0.0, 1.0) : 0.0;
            final Color color = palette[idx % palette.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(Icons.label_outline, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '${provider.tr("Recorded Volume", "মোট লেনদেন")}: ৳${amt.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
                        onPressed: () => _showCategoryDialog(context, oldName: cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                        onPressed: () => provider.deleteCategory(cat, _showExpense),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: const Color(0xFF0F172A),
                      color: color,
                    ),
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
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          provider.tr('Add Category', 'নতুন খাত যোগ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {String? oldName}) {
    final provider = context.read<TransactionProvider>();
    final ctrl = TextEditingController(text: oldName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          oldName == null
              ? provider.tr('Add New Category', 'নতুন ক্যাটাগরি যোগ করুন')
              : provider.tr('Rename Category', 'ক্যাটাগরির নাম পরিবর্তন'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: provider.tr('Category Name', 'ক্যাটাগরির নাম'),
            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.tr('Cancel', 'বাতিল')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              if (oldName == null) {
                provider.addCategory(text, _showExpense);
              } else {
                provider.updateCategory(oldName, text, _showExpense);
              }
              Navigator.pop(ctx);
            },
            child: Text(provider.tr('Save', 'সেভ করুন')),
          ),
        ],
      ),
    );
  }
}