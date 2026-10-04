import 'package:flutter/material.dart';

class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionBtn(context, Icons.remove_circle_outline, 'Add Expense', Colors.redAccent),
              _buildActionBtn(context, Icons.add_circle_outline, 'Add Income', Colors.greenAccent),
              _buildActionBtn(context, Icons.swap_horiz, 'Transfer', Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionBtn(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // close sheet
        // In a real app, this would push an Add Transaction screen
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
