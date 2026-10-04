import 'package:flutter/material.dart';
import 'quick_actions_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Total Balance Card
        Card(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('Total Balance', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('৳ 42,500.00', style: TextStyle(color: Colors.tealAccent, fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatColumn('Income', '+ ৳ 50,000', Colors.greenAccent),
                    _buildStatColumn('Expenses', '- ৳ 7,500', Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Spending Summary Placeholder
        const Text('Spending Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('Chart Placeholder', style: TextStyle(color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions Row (Alternatively triggered via FAB)
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildQuickAction(context, Icons.remove_circle_outline, 'Expense', Colors.redAccent),
            _buildQuickAction(context, Icons.add_circle_outline, 'Income', Colors.greenAccent),
            _buildQuickAction(context, Icons.swap_horiz, 'Transfer', Colors.blueAccent),
          ],
        ),
        const SizedBox(height: 32),

        // Recent Transactions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(
              onPressed: () {}, 
              child: const Text('See All', style: TextStyle(color: Colors.tealAccent))
            ),
          ],
        ),
        _buildTransactionItem(Icons.restaurant, 'Foodpanda - Beef Rezala', 'Today, 6:15 AM', '- ৳ 450', Colors.orange),
        _buildTransactionItem(Icons.shopping_bag, 'Grocery Store', 'Yesterday', '- ৳ 1,200', Colors.pink),
        _buildTransactionItem(Icons.account_balance, 'Salary Deposit', 'Oct 1', '+ ৳ 50,000', Colors.green),
      ],
    );
  }

  Widget _buildStatColumn(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => const QuickActionsSheet(),
        );
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(IconData icon, String title, String subtitle, String amount, Color iconColor) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: iconColor.withValues(alpha: 0.2), child: Icon(icon, color: iconColor)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Text(amount, style: TextStyle(color: amount.startsWith('+') ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
