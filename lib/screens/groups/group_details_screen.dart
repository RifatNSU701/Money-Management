import 'package:flutter/material.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupName;
  final Color groupColor;
  final IconData groupIcon;

  const GroupDetailsScreen({
    super.key,
    required this.groupName,
    required this.groupColor,
    required this.groupIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: groupColor.withValues(alpha: 0.2),
              child: Icon(groupIcon, size: 40, color: groupColor),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('You are owed', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('৳ 2,100', style: TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {}, // Trigger Add Expense sheet
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.done_all),
                  label: const Text('Settle Up'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Group Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          _buildExpenseItem('Hotel Booking', 'Tanvir paid ৳ 10,000', 'You lent ৳ 2,000', Colors.greenAccent),
          _buildExpenseItem('Dinner', 'You paid ৳ 1,500', 'You lent ৳ 500', Colors.greenAccent),
          _buildExpenseItem('Taxi', 'Rafiq paid ৳ 800', 'You borrowed ৳ 400', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(String title, String subtitle, String status, Color statusColor) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.receipt, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
