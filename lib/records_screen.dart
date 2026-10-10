import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _searchQuery = '';
  String _filterType = 'All'; // Options: All, Income, Expense

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    // Dynamic Filtering Logic
    final filteredTransactions = txProvider.transactions.where((tx) {
      final matchesSearch = tx.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _filterType == 'All' ||
          (_filterType == 'Income' && !tx.isExpense) ||
          (_filterType == 'Expense' && tx.isExpense);
      return matchesSearch && matchesFilter;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: ['All', 'Income', 'Expense'].map((filter) {
                final isSelected = _filterType == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: Colors.tealAccent,
                    backgroundColor: const Color(0xFF1E1E1E),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (selected) {
                      if (selected) setState(() => _filterType = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 3. SWIPEABLE TRANSACTION LIST
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('No records found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                  ),
                  onDismissed: (direction) {
                    txProvider.deleteTransaction(tx.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Transaction deleted', style: TextStyle(color: Colors.white)),
                        backgroundColor: const Color(0xFF1E1E1E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: _buildPremiumTxItem(
                    context,
                    tx.icon,
                    tx.title,
                    '${tx.subtitle} • ${tx.date}',
                    '${tx.isExpense ? '- ' : '+ '}৳ ${tx.amount.toStringAsFixed(0)}',
                    tx.color,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTxItem(BuildContext context, IconData icon, String title, String subtitle, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: amount.startsWith('+') ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}