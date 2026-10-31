import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    final Map<String, double> spentByCategory = {};
    for (var tx in provider.transactions.where((t) => t.isExpense)) {
      spentByCategory[tx.title] = (spentByCategory[tx.title] ?? 0) + tx.amount;
    }

    final double totalBudgetLimit = provider.budgets.values.fold(0.0, (s, v) => s + v);
    double totalBudgetSpent = 0.0;
    provider.budgets.forEach((cat, _) {
      totalBudgetSpent += (spentByCategory[cat] ?? 0.0);
    });
    final double remainingBudget = (totalBudgetLimit - totalBudgetSpent) > 0 ? (totalBudgetLimit - totalBudgetSpent) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            provider.tr('Monthly Budget Control & Charts', 'মাসিক বাজেট নিয়ন্ত্রণ ও চার্ট'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            provider.tr(
              'Set spending limits for each category and track real-time utilization.',
              'প্রতিটি খাতের জন্য মাসিক খরচের সীমা নির্ধারণ করুন এবং লাইভ গ্রাফ দেখুন।',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. BUDGET UTILIZATION DONUT CHART
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
                  provider.tr('Overall Budget Utilization Chart', 'মোট বাজেট ব্যবহারের চার্ট'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    totalBudgetSpent > 0 ? totalBudgetSpent : 0,
                    remainingBudget > 0 ? remainingBudget : (totalBudgetLimit == 0 ? 1 : 0),
                  ],
                  colors: const [Color(0xFFF59E0B), Color(0xFF10B981)],
                  labels: [
                    '${provider.tr("Spent", "ব্যয়িত")} (৳${totalBudgetSpent.toStringAsFixed(0)})',
                    '${provider.tr("Remaining", "অবশিষ্ট")} (৳${remainingBudget.toStringAsFixed(0)})',
                  ],
                  centerTitle: provider.tr('Total Limit', 'মোট বাজেট'),
                  centerValue: '৳${totalBudgetLimit.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. CATEGORY BUDGET CARDS
          if (provider.budgets.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No category budgets set yet. Tap "+ Set Category Budget" below to create spending guardrails.',
                  'এখনো কোনো বাজেট সেট করা হয়নি। নিচে "+ বাজেট নির্ধারণ করুন" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...provider.budgets.entries.map((entry) {
              final String cat = entry.key;
              final double limit = entry.value;
              final double spent = spentByCategory[cat] ?? 0.0;
              final double ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
              final bool isOver = spent > limit;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isOver ? const Color(0xFFEF4444) : const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              '৳${spent.toStringAsFixed(0)} / ৳${limit.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isOver ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
                              onPressed: () => provider.deleteBudget(cat),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF0F172A),
                        color: isOver
                            ? const Color(0xFFEF4444)
                            : (ratio > 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOver
                          ? provider.tr(
                        'Exceeded by ৳${(spent - limit).toStringAsFixed(0)}!',
                        'বাজেট সীমা ৳${(spent - limit).toStringAsFixed(0)} অতিক্রম করেছে!',
                      )
                          : provider.tr(
                        '${((1 - ratio) * 100).toStringAsFixed(0)}\% remaining (৳${(limit - spent).toStringAsFixed(0)} left)',
                        '${((1 - ratio) * 100).toStringAsFixed(0)}\% বাকি আছে (৳${(limit - spent).toStringAsFixed(0)} অবশিষ্ট)',
                      ),
                      style: TextStyle(
                        color: isOver ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                        fontSize: 11,
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
        onPressed: () => _showAddBudgetSheet(context),
        icon: const Icon(Icons.pie_chart_outline),
        label: Text(
          provider.tr('Set Category Budget', 'বাজেট নির্ধারণ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showAddBudgetSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    String selectedCat = provider.expenseCategories.isNotEmpty ? provider.expenseCategories.first : 'Food & Dining';
    final limitCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                provider.tr('Set Monthly Category Budget', 'মাসিক খাতওয়ারী বাজেট নির্ধারণ'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.expenseCategories.map((c) {
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
              const SizedBox(height: 14),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.tr('Monthly Limit (BDT ৳)', 'মাসিক বাজেট সীমা (৳)'),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                  final limit = double.tryParse(limitCtrl.text.trim()) ?? 0.0;
                  if (limit <= 0) return;
                  provider.addBudget(selectedCat, limit);
                  Navigator.pop(ctx);
                },
                child: Text(provider.tr('Save Budget Limit', 'বাজেট সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}