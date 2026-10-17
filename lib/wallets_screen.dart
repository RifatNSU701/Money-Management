import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'providers/transaction_provider.dart';

// =============================================================================
// 1. WALLETS & ACCOUNTS SCREEN (HIERARCHICAL MOBILE BANKING & BANKS)
// =============================================================================
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  static const List<String> mobileProviders = ['bKash', 'Nagad', 'Rocket', 'Upay', 'Tap', 'Other MFS'];
  static const List<String> bankProviders = [
    'City Bank',
    'BRAC Bank',
    'DBBL (Dutch-Bangla)',
    'Islami Bank',
    'Eastern Bank (EBL)',
    'Sonali Bank',
    'United Commercial (UCB)',
    'Prime Bank',
    'Standard Chartered',
    'Other Bank',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final wallets = provider.wallets;

    final cashWallets = wallets.where((w) => w.type == 'Cash').toList();
    final mobileWallets = wallets.where((w) => w.type == 'Mobile Banking').toList();
    final bankWallets = wallets.where((w) => w.type == 'Bank Account').toList();

    double maxBal = wallets.isEmpty ? 1000 : wallets.map((w) => w.balance).reduce((a, b) => a > b ? a : b);
    if (maxBal <= 0) maxBal = 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Wallets & Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent),
            onPressed: () => _showWalletSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. TOTAL ASSET CARD + DYNAMIC BAR CHART
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Net Worth (All Accounts)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 6),
                Text('৳ ${provider.totalWalletsBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (wallets.isNotEmpty)
                  SizedBox(
                    height: 140,
                    child: BarChart(
                      BarChartData(
                        maxY: maxBal * 1.2,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= wallets.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    wallets[idx].providerName.split(' ').first,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(wallets.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: wallets[i].balance < 0 ? 0 : wallets[i].balance,
                                color: _getProviderColor(wallets[i].providerName, wallets[i].type),
                                width: 22,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. MOBILE BANKING SECTION
          _buildCategorySection(
            context: context,
            title: 'Mobile Banking (MFS)',
            subtitle: 'bKash, Nagad, Rocket, Upay & Others',
            defaultType: 'Mobile Banking',
            items: mobileWallets,
          ),
          const SizedBox(height: 24),

          // 3. BANK ACCOUNTS SECTION
          _buildCategorySection(
            context: context,
            title: 'Bank Accounts',
            subtitle: 'Savings, Current & Cards',
            defaultType: 'Bank Account',
            items: bankWallets,
          ),
          const SizedBox(height: 24),

          // 4. CASH WALLETS SECTION
          _buildCategorySection(
            context: context,
            title: 'Cash Wallets',
            subtitle: 'Physical Cash in Hand',
            defaultType: 'Cash',
            items: cashWallets,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String defaultType,
    required List<WalletModel> items,
  }) {
    final sectionTotal = items.fold<double>(0, (sum, w) => sum + w.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$subtitle • Total: ৳ ${sectionTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showWalletSheet(context, initialType: defaultType),
              icon: const Icon(Icons.add, color: Colors.tealAccent, size: 18),
              label: const Text('Add', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Text('No $title added yet. Tap + Add.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ...items.map((w) {
          final color = _getProviderColor(w.providerName, w.type);
          final icon = w.type == 'Bank Account'
              ? Icons.account_balance
              : (w.type == 'Mobile Banking' ? Icons.phone_android_rounded : Icons.account_balance_wallet_rounded);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: ListTile(
              onTap: () => _showWalletSheet(context, existing: w),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(w.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(w.providerName, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  w.accountNumber.isNotEmpty ? '${w.type} • ${w.accountNumber}' : '${w.type} • Tap to edit',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              trailing: Text('৳ ${w.balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          );
        }),
      ],
    );
  }

  static Color _getProviderColor(String provider, String type) {
    final p = provider.toLowerCase();
    if (p.contains('bkash')) return Colors.pinkAccent;
    if (p.contains('nagad')) return Colors.deepOrangeAccent;
    if (p.contains('rocket')) return Colors.purpleAccent;
    if (p.contains('upay')) return Colors.amberAccent;
    if (type == 'Bank Account') return Colors.blueAccent;
    if (type == 'Mobile Banking') return Colors.tealAccent;
    return Colors.greenAccent;
  }

  void _showWalletSheet(BuildContext context, {WalletModel? existing, String? initialType}) {
    String selectedType = existing?.type ?? initialType ?? 'Mobile Banking';
    String selectedProvider = existing?.providerName ??
        (selectedType == 'Mobile Banking'
            ? mobileProviders.first
            : (selectedType == 'Bank Account' ? bankProviders.first : 'Cash'));

    final customBankCtrl = TextEditingController(
      text: (existing != null &&
          !mobileProviders.contains(existing.providerName) &&
          !bankProviders.contains(existing.providerName) &&
          existing.type != 'Cash')
          ? existing.providerName
          : '',
    );
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final accNumCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final balCtrl = TextEditingController(text: existing != null ? existing.balance.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<String> currentProviders = selectedType == 'Mobile Banking'
              ? mobileProviders
              : (selectedType == 'Bank Account' ? bankProviders : ['Cash']);

          if (!currentProviders.contains(selectedProvider)) {
            selectedProvider = currentProviders.first;
          }

          final bool isCustomProvider = selectedProvider == 'Other MFS' || selectedProvider == 'Other Bank';

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Add Account / Wallet' : 'Edit Account',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['Mobile Banking', 'Bank Account', 'Cash'].map((t) {
                        final isSelected = selectedType == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(t, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: Colors.tealAccent,
                            backgroundColor: const Color(0xFF1E1E1E),
                            showCheckmark: false,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedType = t;
                                selectedProvider = t == 'Mobile Banking'
                                    ? mobileProviders.first
                                    : (t == 'Bank Account' ? bankProviders.first : 'Cash');
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedType != 'Cash') ...[
                    Text(
                      selectedType == 'Mobile Banking' ? 'Select MFS Provider' : 'Select Bank',
                      style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currentProviders.map((prov) {
                        final isProvSelected = selectedProvider == prov;
                        final chipColor = _getProviderColor(prov, selectedType);
                        return ChoiceChip(
                          label: Text(prov, style: TextStyle(color: isProvSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          selected: isProvSelected,
                          selectedColor: chipColor,
                          backgroundColor: const Color(0xFF1E1E1E),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => selectedProvider = prov),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (isCustomProvider) ...[
                    TextField(
                      controller: customBankCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter Service or Bank Name',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: selectedType == 'Mobile Banking'
                          ? 'Account Label (e.g., Personal $selectedProvider)'
                          : (selectedType == 'Bank Account' ? 'Account Label (e.g., Salary A/C)' : 'Wallet Name (e.g., Petty Cash)'),
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.label_outline, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType != 'Cash') ...[
                    TextField(
                      controller: accNumCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: selectedType == 'Mobile Banking' ? 'Mobile Number (Optional)' : 'A/C or Card Last 4 Digits (Optional)',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(Icons.numbers, color: Colors.tealAccent),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: balCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Current Balance (৳)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (existing != null)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              context.read<TransactionProvider>().deleteWallet(existing.id);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (existing != null) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            final finalProvider = isCustomProvider && customBankCtrl.text.trim().isNotEmpty
                                ? customBankCtrl.text.trim()
                                : selectedProvider;
                            final finalName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : '$finalProvider Account';
                            final balance = double.tryParse(balCtrl.text.trim()) ?? 0;

                            context.read<TransactionProvider>().saveWallet(
                              id: existing?.id,
                              name: finalName,
                              type: selectedType,
                              providerName: finalProvider,
                              accountNumber: accNumCtrl.text.trim(),
                              balance: balance,
                            );
                            Navigator.pop(ctx);
                          },
                          child: Text(existing == null ? 'Save Account' : 'Update Account', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// 2. SCHEDULED TRANSACTIONS SCREEN
// =============================================================================
class ScheduledTransactionsScreen extends StatelessWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Scheduled Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: provider.scheduledTxs.isEmpty
          ? const Center(child: Text('No recurring bills scheduled. Tap + to add one!', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: provider.scheduledTxs.length,
        itemBuilder: (ctx, i) {
          final s = provider.scheduledTxs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
            child: ListTile(
              onTap: () => _showScheduleSheet(context, existing: s),
              leading: CircleAvatar(
                backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                child: const Icon(Icons.event_repeat, color: Colors.tealAccent),
              ),
              title: Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Due: ${s.dueDate} • ৳ ${s.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () {
                  provider.saveTransaction(title: s.title, category: 'Scheduled', amount: s.amount, isExpense: s.isExpense);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged ${s.title} to your records!')));
                },
                child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => _showScheduleSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context, {ScheduledTxModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final dateCtrl = TextEditingController(text: existing?.dueDate ?? '5th of every month');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New Scheduled Bill' : 'Edit Scheduled Bill', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Bill Name (e.g., House Rent, WiFi)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Amount (৳)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: dateCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Schedule (e.g., 10th of month)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            Row(
              children: [
                if (existing != null)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () {
                        context.read<TransactionProvider>().deleteScheduledTx(existing.id);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                if (existing != null) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (titleCtrl.text.trim().isNotEmpty && amt > 0) {
                        context.read<TransactionProvider>().saveScheduledTx(
                          id: existing?.id,
                          title: titleCtrl.text.trim(),
                          amount: amt,
                          dueDate: dateCtrl.text.trim(),
                          isExpense: true,
                        );
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
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

// =============================================================================
// 3. CALCBOX (BUILT-IN FINANCIAL CALCULATOR)
// =============================================================================
class CalcBoxScreen extends StatefulWidget {
  const CalcBoxScreen({super.key});

  @override
  State<CalcBoxScreen> createState() => _CalcBoxScreenState();
}

class _CalcBoxScreenState extends State<CalcBoxScreen> {
  String _display = '0';
  double _firstNum = 0;
  String _operator = '';
  bool _shouldReset = false;

  void _onPress(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _firstNum = 0;
        _operator = '';
      } else if (['+', '-', '×', '÷'].contains(val)) {
        _firstNum = double.tryParse(_display) ?? 0;
        _operator = val;
        _shouldReset = true;
      } else if (val == '=') {
        final second = double.tryParse(_display) ?? 0;
        double res = 0;
        if (_operator == '+') res = _firstNum + second;
        if (_operator == '-') res = _firstNum - second;
        if (_operator == '×') res = _firstNum * second;
        if (_operator == '÷') res = second != 0 ? _firstNum / second : 0;
        _display = res.toStringAsFixed(res.truncateToDouble() == res ? 0 : 2);
        _operator = '';
        _shouldReset = true;
      } else {
        if (_display == '0' || _shouldReset) {
          _display = val;
          _shouldReset = false;
        } else {
          _display += val;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '7', '8', '9', '÷',
      '4', '5', '6', '×',
      '1', '2', '3', '-',
      'C', '0', '=', '+',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: const Text('CalcBox')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(32),
              child: Text(_display, style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.bold)),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: buttons.length,
            itemBuilder: (ctx, i) {
              final b = buttons[i];
              final isOp = ['÷', '×', '-', '+', '='].contains(b);
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOp ? Colors.tealAccent : const Color(0xFF1E1E1E),
                  foregroundColor: isOp ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _onPress(b),
                child: Text(b, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
    );
  }
}