import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class BusinessDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;
  const BusinessDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<TransactionProvider>();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. LIVE STATS GRID
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Sales',
                '৳ ${biz.totalSales.toStringAsFixed(0)}',
                'Net Profit: ৳ ${biz.netProfit.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateTab(2),
                child: _buildStatCard(
                  'Total Products',
                  '${biz.products.length}',
                  'Low Stock: ${biz.lowStockCount}',
                  Icons.inventory_2_outlined,
                  Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateTab(3),
                child: _buildStatCard(
                  'Customer Due',
                  '৳ ${biz.totalCustomerDue.toStringAsFixed(0)}',
                  'Tap to view ledger',
                  Icons.access_time,
                  Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateTab(3),
                child: _buildStatCard(
                  'Total Customers',
                  '${biz.totalCustomersCount} person',
                  'Active parties',
                  Icons.people_outline,
                  Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 2. FUNCTIONAL QUICK ACTIONS
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionTile(context, Icons.local_shipping_outlined, 'Make a Sale', 'New Sale', Colors.tealAccent, () => showBizTxSheet(context, 'Sale'))),
            const SizedBox(width: 12),
            Expanded(child: _buildActionTile(context, Icons.shopping_cart_outlined, 'Make Purchase', 'New Purchase', Colors.orangeAccent, () => showBizTxSheet(context, 'Purchase'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionTile(context, Icons.add_box_outlined, 'Add Product', 'New Product', Colors.blueAccent, () => showProductSheet(context))),
            const SizedBox(width: 12),
            Expanded(child: _buildActionTile(context, Icons.account_balance_wallet_outlined, 'Add Expense', 'Write Expense', Colors.redAccent, () => showBizTxSheet(context, 'Expense'))),
          ],
        ),
        const SizedBox(height: 28),

        // 3. RECENT BUSINESS TRANSACTIONS (TAP TO EDIT / DELETE)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Cashbook Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(
              onPressed: () => onNavigateTab(1),
              child: const Text('View Reports', style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (biz.businessTxs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('No business transactions yet. Tap a Quick Action above!', style: TextStyle(color: Colors.grey))),
          ),
        ...biz.businessTxs.take(6).map((tx) {
          final color = tx.type == 'Sale' ? Colors.tealAccent : (tx.type == 'Purchase' ? Colors.orangeAccent : Colors.redAccent);
          final prefix = tx.type == 'Sale' ? '+ ' : '- ';
          return GestureDetector(
            onTap: () => showBizTxSheet(context, tx.type, existing: tx),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(tx.type == 'Sale' ? Icons.trending_up : Icons.receipt_long, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${tx.type} • ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('$prefix৳ ${tx.amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatCard(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              const Icon(Icons.bolt, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(mainValue, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subValue, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF16221C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // GLOBAL SHEET FOR SALE / PURCHASE / EXPENSE (ADD, EDIT, DELETE)
  static void showBizTxSheet(BuildContext context, String type, {BusinessTxModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New $type' : 'Edit $type', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: 'Amount (৳)', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Description / Item Name', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        context.read<TransactionProvider>().deleteBusinessTx(existing.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      final desc = titleCtrl.text.trim().isEmpty ? '$type Entry' : titleCtrl.text.trim();
                      if (amt > 0) {
                        context.read<TransactionProvider>().saveBusinessTx(id: existing?.id, title: desc, type: type, amount: amt);
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(existing == null ? 'Save $type' : 'Update', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // GLOBAL SHEET FOR ADDING / EDITING PRODUCTS
  static void showProductSheet(BuildContext context, {ProductModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toString() : '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16221C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add Product' : 'Edit Product', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Product Name', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Price (৳)', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Stock Qty', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF0F1A15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        context.read<TransactionProvider>().deleteProduct(existing.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                      final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                      if (name.isNotEmpty) {
                        context.read<TransactionProvider>().saveProduct(id: existing?.id, name: name, price: price, stock: stock);
                        Navigator.pop(ctx);
                      }
                    },
                    child: Text(existing == null ? 'Save Product' : 'Update', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}