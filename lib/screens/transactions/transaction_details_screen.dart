import 'package:flutter/material.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;
  final IconData icon;

  const TransactionDetailsScreen({
    super.key,
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.tealAccent), onPressed: () {}),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: amountColor.withValues(alpha: 0.15),
              child: Icon(icon, color: amountColor, size: 40),
            ),
            const SizedBox(height: 24),
            Text(amount, style: TextStyle(color: amountColor, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _buildDetailRow('Date', 'Oct 24, 2026 • 6:15 AM'),
            const Divider(color: Colors.white24, height: 32),
            _buildDetailRow('Category', 'Food & Drink'),
            const Divider(color: Colors.white24, height: 32),
            _buildDetailRow('Wallet', 'Cash'),
            const Divider(color: Colors.white24, height: 32),
            _buildDetailRow('Notes', 'Lunch with colleagues'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
