import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'providers/transaction_provider.dart';

class BusinessDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;
  const BusinessDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<TransactionProvider>();
    final int custCount = biz.totalCustomersCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // 1. LIVE STATS GRID
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                biz.tr('Total Sales', 'মোট বিক্রয়'),
                biz.formatMoney(biz.totalSales),
                '${biz.tr("Net Profit", "নিট লাভ")}: ${biz.formatMoney(biz.netProfit)}',
                Icons.trending_up,
                Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateTab(1),
                child: _buildStatCard(
                  biz.tr('Total Products', 'মোট পণ্য'),
                  '${biz.products.length}',
                  '${biz.tr("Low Stock", "কম স্টক")}: ${biz.lowStockCount}',
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
                onTap: () => onNavigateTab(2),
                child: _buildStatCard(
                  biz.tr('Customer Due', 'কাস্টমার বাকি'),
                  biz.formatMoney(biz.totalCustomerDue),
                  biz.tr('Tap to view ledger', 'লেজার দেখতে ট্যাপ করুন'),
                  Icons.access_time,
                  Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigateTab(2),
                child: _buildStatCard(
                  biz.tr('Total Customers', 'মোট কাস্টমার'),
                  biz.isBengali
                      ? '$custCount জন'
                      : '$custCount ${custCount == 1 ? "person" : "people"}',
                  biz.tr('Active parties', 'সক্রিয় পার্টি'),
                  Icons.people_outline,
                  Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. FUNCTIONAL QUICK ACTIONS
        Text(
          biz.tr('Quick Actions', 'দ্রুত কার্যক্রম'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                Icons.local_shipping_outlined,
                biz.tr('Make a Sale', 'নতুন বিক্রয়'),
                biz.tr('New Sale', 'বিক্রয় যোগ'),
                Colors.tealAccent,
                    () => showBizTxSheet(context, 'Sale'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                context,
                Icons.shopping_cart_outlined,
                biz.tr('Make Purchase', 'নতুন ক্রয়'),
                biz.tr('New Purchase', 'ক্রয় যোগ'),
                Colors.orangeAccent,
                    () => showBizTxSheet(context, 'Purchase'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                Icons.add_box_outlined,
                biz.tr('Add Product', 'পণ্য যোগ'),
                biz.tr('New Product', 'নতুন পণ্য'),
                Colors.blueAccent,
                    () => showProductSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                context,
                Icons.account_balance_wallet_outlined,
                biz.tr('Add Expense', 'ব্যয় যোগ'),
                biz.tr('Write Expense', 'খরচ লিখুন'),
                Colors.redAccent,
                    () => showBizTxSheet(context, 'Expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. RECENT BUSINESS TRANSACTIONS (TAP TO EDIT / DELETE)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                biz.tr('Recent Cashbook Entries', 'সাম্প্রতিক ক্যাশবুক এন্ট্রি'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onNavigateTab(3),
              child: Text(
                biz.tr('View Vouchers', 'ভাউচার দেখুন'),
                style: const TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (biz.businessTxs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                biz.tr(
                  'No business transactions yet. Tap a Quick Action above!',
                  'এখনো কোনো ব্যবসায়িক লেনদেন নেই। উপরে দ্রুত কার্যক্রমে ট্যাপ করুন!',
                ),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...biz.businessTxs.take(6).map((tx) {
          Color color = Colors.tealAccent;
          bool isInflow = true;
          if (tx.type == 'Purchase') {
            color = Colors.orangeAccent;
            isInflow = false;
          } else if (tx.type == 'Expense') {
            color = Colors.redAccent;
            isInflow = false;
          } else if (tx.type == 'Due Collection') {
            color = const Color(0xFF38BDF8);
            isInflow = true;
          } else if (tx.type == 'Supplier Payment') {
            color = const Color(0xFFF59E0B);
            isInflow = false;
          }

          return GestureDetector(
            onTap: () => showBizTxSheet(context, tx.type, existing: tx),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16221C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      tx.type == 'Sale'
                          ? Icons.trending_up
                          : Icons.receipt_long,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tx.type} • ${tx.date}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    biz.formatMoney(
                      isInflow ? tx.amount : -tx.amount,
                      showPlusSign: isInflow,
                    ),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(
      String title,
      String mainValue,
      String subValue,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16221C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
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
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              mainValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16221C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // GLOBAL SHEET FOR SALE / PURCHASE / EXPENSE (INLINE VALIDATION + CONFIRM DELETE)
  static void showBizTxSheet(
      BuildContext context,
      String type, {
        BusinessTxModel? existing,
      }) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16221C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'New $type' : 'Edit $type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppValidators.amountFormatters,
                  validator: (v) =>
                      AppValidators.positiveAmount(v, label: 'Amount'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Amount (${provider.currencySymbol})',
                    hintStyle: const TextStyle(color: Colors.grey),
                    errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                    filled: true,
                    fillColor: const Color(0xFF0F1A15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleCtrl,
                  validator: (v) =>
                      AppValidators.requiredText(v, 'Description / Item Name'),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Description / Item Name *',
                    hintStyle: const TextStyle(color: Colors.grey),
                    errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                    filled: true,
                    fillColor: const Color(0xFF0F1A15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (existing != null)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.redAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await AppFeedback.confirmDelete(
                              context,
                              title: 'Delete $type?',
                              message:
                              'Remove "${existing.title}" (${provider.formatMoney(existing.amount)})?',
                            );
                            if (!ok || !ctx.mounted) return;
                            provider.deleteBusinessTx(existing.id);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final amt = AppCurrency.parseAmount(amountCtrl.text);
                          if (amt == null || amt <= 0) return;
                          provider.saveBusinessTx(
                            id: existing?.id,
                            title: titleCtrl.text.trim(),
                            type: type,
                            amount: amt,
                          );
                          Navigator.pop(ctx);
                          AppFeedback.showInfo(context, '$type saved.');
                        },
                        child: Text(
                          existing == null ? 'Save $type' : 'Update',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // GLOBAL SHEET FOR ADDING / EDITING PRODUCTS (WITH COST PRICE & VALIDATION)
  static void showProductSheet(
      BuildContext context, {
        ProductModel? existing,
      }) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final costCtrl = TextEditingController(
      text: existing != null && existing.costPrice > 0
          ? existing.costPrice.toStringAsFixed(2)
          : '',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final stockCtrl = TextEditingController(
      text: existing != null ? existing.stock.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16221C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'Add Product' : 'Edit Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) =>
                      AppValidators.requiredText(v, 'Product Name'),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Product Name *',
                    hintStyle: const TextStyle(color: Colors.grey),
                    errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                    filled: true,
                    fillColor: const Color(0xFF0F1A15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: AppValidators.amountFormatters,
                        validator: (v) => AppValidators.nonNegativeAmount(
                          v,
                          label: 'Cost Price',
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cost (${provider.currencySymbol})',
                          hintStyle: const TextStyle(color: Colors.grey),
                          errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                          filled: true,
                          fillColor: const Color(0xFF0F1A15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: AppValidators.amountFormatters,
                        validator: (v) => AppValidators.positiveAmount(
                          v,
                          label: 'Selling Price',
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Price (${provider.currencySymbol}) *',
                          hintStyle: const TextStyle(color: Colors.grey),
                          errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                          filled: true,
                          fillColor: const Color(0xFF0F1A15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid stock quantity';
                    }
                    return null;
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Stock Qty *',
                    hintStyle: const TextStyle(color: Colors.grey),
                    errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
                    filled: true,
                    fillColor: const Color(0xFF0F1A15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (existing != null)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            Colors.redAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await AppFeedback.confirmDelete(
                              context,
                              title: 'Delete "${existing.name}"?',
                              message:
                              'Remove this product from your inventory?',
                            );
                            if (!ok || !ctx.mounted) return;
                            provider.deleteProduct(existing.id);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final sell = AppCurrency.parseAmount(priceCtrl.text);
                          final cost =
                              AppCurrency.parseAmount(costCtrl.text) ?? 0.0;
                          final stock =
                              int.tryParse(stockCtrl.text.trim()) ?? 0;
                          if (sell == null || sell <= 0) return;

                          provider.saveProduct(
                            id: existing?.id,
                            name: nameCtrl.text.trim(),
                            price: sell,
                            costPrice: cost,
                            stock: stock,
                          );
                          Navigator.pop(ctx);
                          AppFeedback.showInfo(context, 'Product saved.');
                        },
                        child: Text(
                          existing == null ? 'Save Product' : 'Update',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}