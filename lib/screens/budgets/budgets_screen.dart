import 'package:flutter/material.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Monthly Budgets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.tealAccent),
              label: const Text('Create', style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBudgetCard('Overall Monthly Budget', 25500, 40000, Colors.tealAccent),
        const Divider(color: Colors.white24, height: 32),
        const Text('Category Budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        _buildBudgetCard('Food & Drink', 2500, 5000, Colors.orange),
        _buildBudgetCard('Shopping', 3500, 4000, Colors.pink),
        _buildBudgetCard('Transport', 800, 2000, Colors.blue),
        _buildBudgetCard('Entertainment', 1900, 2000, Colors.purpleAccent), // Near limit alert example
      ],
    );
  }

  Widget _buildBudgetCard(String category, double spent, double total, Color color) {
    double progress = spent / total;
    bool isNearLimit = progress >= 0.9;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(isNearLimit ? Colors.redAccent : color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toInt()}% Used', style: TextStyle(color: isNearLimit ? Colors.redAccent : Colors.grey, fontSize: 12)),
                Text('৳ ${(total - spent).toInt()} left', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            if (isNearLimit)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                    SizedBox(width: 4),
                    Text('Near budget limit!', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
