import 'package:flutter/material.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: const Icon(Icons.filter_list, color: Colors.tealAccent),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          const TabBar(
            isScrollable: true,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.tealAccent,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Expenses'),
              Tab(text: 'Income'),
              Tab(text: 'Transfers'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                _buildTransactionList(context),
                _buildTransactionList(context, filter: 'Expense'),
                _buildTransactionList(context, filter: 'Income'),
                _buildTransactionList(context, filter: 'Transfer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, {String? filter}) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('October 2026', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (filter == null || filter == 'Expense')
          _buildTxItem(context, 'Foodpanda - Bhuna Khichuri', 'Food & Drink • Cash', '- ৳ 320', Colors.orange, Icons.restaurant),
        if (filter == null || filter == 'Expense')
          _buildTxItem(context, 'Uber Ride', 'Transport • Card', '- ৳ 450', Colors.blue, Icons.directions_car),
        if (filter == null || filter == 'Income')
          _buildTxItem(context, 'Client Payment', 'Income • Bank', '+ ৳ 15,000', Colors.green, Icons.attach_money),
        if (filter == null || filter == 'Transfer')
          _buildTxItem(context, 'ATM Withdrawal', 'Transfer • Cash -> Bank', '৳ 5,000', Colors.blueAccent, Icons.swap_horiz),
      ],
    );
  }

  Widget _buildTxItem(BuildContext context, String title, String subtitle, String amount, Color color, IconData icon) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text(amount, style: TextStyle(color: amount.startsWith('+') ? Colors.greenAccent : (amount.startsWith('-') ? Colors.white : Colors.blueAccent), fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionDetailsScreen(
            title: title,
            amount: amount,
            amountColor: amount.startsWith('+') ? Colors.greenAccent : (amount.startsWith('-') ? Colors.white : Colors.blueAccent),
            icon: icon,
          )));
        },
      ),
    );
  }
}
