import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'providers/transaction_provider.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final totalExpense = txProvider.totalExpense;

    // Dynamically group expenses by their title/note to draw the chart
    Map<String, double> expensesByCategory = {};
    for (var tx in txProvider.transactions.where((t) => t.isExpense)) {
      expensesByCategory[tx.title] = (expensesByCategory[tx.title] ?? 0) + tx.amount;
    }

    final List<Color> sliceColors = [Colors.tealAccent, Colors.redAccent, Colors.blueAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.pinkAccent];

    List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    expensesByCategory.forEach((category, amount) {
      final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0;
      pieSections.add(PieChartSectionData(
        color: sliceColors[colorIndex % sliceColors.length], value: amount,
        title: '${percentage.toStringAsFixed(0)}%', radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
      ));
      colorIndex++;
    });

    if (pieSections.isEmpty) pieSections.add(PieChartSectionData(color: Colors.white10, value: 1, title: '', radius: 50));

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text('Spending Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 24),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 70, sections: pieSections)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Out', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('৳ ${totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Monthly Budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent), onPressed: () => _showAddBudgetDialog(context)),
          ],
        ),
        const SizedBox(height: 12),

        // Loop through saved budgets from the database
        if (txProvider.budgets.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No budgets set. Tap + to create one.", style: TextStyle(color: Colors.grey)))),

        ...txProvider.budgets.entries.map((entry) {
          // Calculate how much was actually spent on this specific category
          double spent = expensesByCategory[entry.key] ?? 0.0;
          return _buildBudgetCard(context, entry.key, spent, entry.value, sliceColors[txProvider.budgets.keys.toList().indexOf(entry.key) % sliceColors.length]);
        }),
      ],
    );
  }

  Widget _buildBudgetCard(BuildContext context, String category, double spent, double limit, Color color) {
    double progress = limit > 0 ? (spent / limit) : 0;
    bool isDanger = progress > 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Text('৳ ${spent.toInt()} / ৳ ${limit.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.read<TransactionProvider>().deleteBudget(category),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  )
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress, backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(isDanger ? Colors.redAccent : color), minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(isDanger ? 'Almost out of budget!' : '${(progress * 100).toInt()}% Used', style: TextStyle(color: isDanger ? Colors.redAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add New Budget', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Category Name (e.g., Food)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Monthly Limit (৳)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                final name = nameController.text.trim();
                final limit = double.tryParse(amountController.text.trim()) ?? 0;
                if (name.isNotEmpty && limit > 0) {
                  context.read<TransactionProvider>().addBudget(name, limit);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Budget', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}