import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'providers/transaction_provider.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const DashboardScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final allTx = txProvider.transactions.reversed.toList();
    List<FlSpot> chartSpots = [];
    double runningBalance = 0;

    if (allTx.isEmpty) {
      chartSpots = const [FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0)];
    } else {
      for (int i = 0; i < allTx.length; i++) {
        runningBalance += allTx[i].isExpense ? -allTx[i].amount : allTx[i].amount;
        chartSpots.add(FlSpot(i.toDouble(), runningBalance));
      }
    }

    double minY = chartSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = chartSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) { minY -= 100; maxY += 100; }

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        // 1. BALANCE CARD
        Container(
          height: 240,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Text('Live', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)))
                ],
              ),
              const SizedBox(height: 8),
              Text('৳ ${txProvider.totalBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              SizedBox(
                height: 70,
                child: LineChart(
                  LineChartData(
                    minY: minY, maxY: maxY + (maxY * 0.1), gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartSpots, isCurved: true, curveSmoothness: 0.3, color: Colors.tealAccent, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.tealAccent.withValues(alpha: 0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 2. QUICK ACTIONS
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionCard(context, Icons.arrow_upward_rounded, 'Expense', Colors.redAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(context, Icons.arrow_downward_rounded, 'Income', Colors.greenAccent)),
          ],
        ),
        const SizedBox(height: 32),

        // 3. RECENT RECORDS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(onPressed: onSeeAll, child: const Text('See All', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 8),

        // TAP TO EDIT/DELETE
        ...txProvider.transactions.take(5).map((tx) => GestureDetector(
          onTap: () => _showTransactionSheet(context, tx.isExpense ? 'Expense' : 'Income', existingTx: tx),
          child: _buildPremiumTxItem(tx.icon, tx.title, '${tx.subtitle} • ${tx.date}', '${tx.isExpense ? '- ' : '+ '}৳ ${tx.amount.toStringAsFixed(0)}', tx.color),
        )),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showTransactionSheet(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 12), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _buildPremiumTxItem(IconData icon, String title, String subtitle, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
          Text(amount, style: TextStyle(color: amount.startsWith('+') ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // COMBINED ADD / EDIT / DELETE SHEET
  void _showTransactionSheet(BuildContext context, String type, {TransactionModel? existingTx}) {
    final amountController = TextEditingController(text: existingTx != null ? existingTx.amount.toString() : '');
    final noteController = TextEditingController(text: existingTx != null ? existingTx.title : '');

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existingTx != null ? 'Edit $type' : 'Add $type', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(controller: amountController, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: '৳ 0.00', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            TextField(controller: noteController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'What was this for?', hintStyle: const TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.edit_note, color: Colors.tealAccent), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
            const SizedBox(height: 32),
            Row(
              children: [
                if (existingTx != null) Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.1), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: () { context.read<TransactionProvider>().deleteTransaction(existingTx.id); Navigator.pop(sheetContext); },
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                if (existingTx != null) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: () {
                      final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                      final enteredNote = noteController.text.trim().isEmpty ? '$type Entry' : noteController.text.trim();
                      if (enteredAmount > 0) {
                        context.read<TransactionProvider>().saveTransaction(id: existingTx?.id, title: enteredNote, category: type, amount: enteredAmount, isExpense: type == 'Expense');
                        Navigator.pop(sheetContext);
                      }
                    },
                    child: Text(existingTx != null ? 'Update' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}