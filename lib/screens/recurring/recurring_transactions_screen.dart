import 'package:flutter/material.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Transactions', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _buildRecurringItem('Internet Bill', 'Monthly • Oct 28', '৳ 1,200', Colors.redAccent),
          _buildRecurringItem('Gym Membership', 'Monthly • Nov 1', '৳ 2,000', Colors.redAccent),
          const SizedBox(height: 24),
          const Text('Active Subscriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _buildRecurringItem('Netflix', 'Monthly • Auto-pay', '৳ 800', Colors.redAccent),
          _buildRecurringItem('Salary', 'Monthly • 1st of Month', '+ ৳ 50,000', Colors.greenAccent),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: Colors.tealAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add Scheduled', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRecurringItem(String title, String subtitle, String amount, Color amountColor) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.2),
          child: Icon(Icons.event_repeat, color: amountColor),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
