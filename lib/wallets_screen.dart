import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double total = provider.totalWalletsBalance;

    final double cashSum = provider.wallets.where((w) => w.type == 'Cash').fold(0.0, (s, w) => s + w.balance);
    final double mobileSum = provider.wallets.where((w) => w.type == 'Mobile Banking').fold(0.0, (s, w) => s + w.balance);
    final double bankSum = provider.wallets.where((w) => w.type == 'Bank Account').fold(0.0, (s, w) => s + w.balance);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr('Wallets & Bank Accounts', 'ওয়ালেট ও ব্যাংক অ্যাকাউন্ট'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              // 1. WALLETS ASSET DISTRIBUTION CHART
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr('Asset Distribution Chart (Cash / MFS / Bank)', 'ওয়ালেট ও ব্যাংক জমার আনুপাতিক চার্ট'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    RealisticDonutChart(
                      values: [
                        cashSum > 0 ? cashSum : (total == 0 ? 1 : 0),
                        mobileSum > 0 ? mobileSum : 0,
                        bankSum > 0 ? bankSum : 0,
                      ],
                      colors: const [Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF0EA5E9)],
                      labels: [
                        '${provider.tr("Physical Cash", "নগদ ক্যাশ")} (৳${cashSum.toStringAsFixed(0)})',
                        '${provider.tr("Mobile Banking", "মোবাইল ব্যাংকিং")} (৳${mobileSum.toStringAsFixed(0)})',
                        '${provider.tr("Bank Accounts", "ব্যাংক অ্যাকাউন্ট")} (৳${bankSum.toStringAsFixed(0)})',
                      ],
                      centerTitle: provider.tr('Total Funds', 'মোট জমা'),
                      centerValue: '৳${total.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (provider.wallets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    provider.tr(
                      'No wallets or bank accounts added yet. Tap "+ Add Account" below to add Cash, bKash, Nagad, or Bank accounts.',
                      'এখনো কোনো ওয়ালেট বা ব্যাংক যুক্ত করা হয়নি। নিচে "+ অ্যাকাউন্ট যোগ করুন" বাটনে ট্যাপ করুন।',
                    ),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...provider.wallets.map((w) {
                  final double pct = total > 0 ? (w.balance / total).clamp(0.0, 1.0) : 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF0F172A),
                              child: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF38BDF8)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text('${w.type} • ${w.providerName} ${w.accountNumber.isNotEmpty ? "• ${w.accountNumber}" : ""}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('৳${w.balance.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
                              onPressed: () => _showWalletSheet(context, existing: w),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                              onPressed: () => provider.deleteWallet(w.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: const Color(0xFF0F172A),
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showWalletSheet(context),
        icon: const Icon(Icons.add_card_rounded),
        label: Text(provider.tr('Add Account', 'অ্যাকাউন্ট যোগ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showWalletSheet(BuildContext context, {WalletModel? existing}) {
    final provider = context.read<TransactionProvider>();
    String selectedType = existing?.type ?? 'Mobile Banking';
    String selectedProvider = existing?.providerName ?? 'bKash';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final accCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final balCtrl = TextEditingController(text: existing != null ? existing.balance.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<String> providers = selectedType == 'Mobile Banking'
              ? ['bKash', 'Nagad', 'Rocket', 'Upay']
              : (selectedType == 'Bank Account' ? ['City Bank', 'BRAC Bank', 'DBBL', 'Islami Bank', 'EBL', 'Sonali Bank'] : ['Physical Cash']);
          if (!providers.contains(selectedProvider)) selectedProvider = providers.first;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? provider.tr('Add Wallet / Bank Account', 'নতুন ওয়ালেট বা ব্যাংক অ্যাকাউন্ট') : provider.tr('Edit Account', 'অ্যাকাউন্ট এডিট করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: ['Cash', 'Mobile Banking', 'Bank Account'].map((t) {
                      final isSel = selectedType == t;
                      return ChoiceChip(
                        label: Text(t, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 12)),
                        selected: isSel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF0F172A),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => selectedType = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: providers.map((p) {
                      final isSel = selectedProvider == p;
                      return ChoiceChip(
                        label: Text(p, style: TextStyle(color: isSel ? Colors.white : const Color(0xFFCBD5E1), fontSize: 11)),
                        selected: isSel,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: const Color(0xFF0F172A),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() => selectedProvider = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Account Title (e.g., Personal bKash)', 'অ্যাকাউন্টের নাম'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Account / Mobile Number (Optional)', 'অ্যাকাউন্ট / মোবাইল নম্বর (ঐচ্ছিক)'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Current Balance (৳)', 'বর্তমান ব্যালেন্স (৳)'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: () {
                      final name = nameCtrl.text.trim().isEmpty ? selectedProvider : nameCtrl.text.trim();
                      final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                      provider.saveWallet(
                        id: existing?.id,
                        name: name,
                        type: selectedType,
                        providerName: selectedProvider,
                        accountNumber: accCtrl.text.trim(),
                        balance: bal,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(provider.tr('Save Account', 'অ্যাকাউন্ট সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
// SCHEDULED TRANSACTIONS SCREEN (WITH CHART + RECEIPT / MEMO UPLOAD)
// =============================================================================
class ScheduledTransactionsScreen extends StatelessWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double expBills = provider.scheduledTxs.where((s) => s.isExpense).fold(0.0, (sum, s) => sum + s.amount);
    final double incScheduled = provider.scheduledTxs.where((s) => !s.isExpense).fold(0.0, (sum, s) => sum + s.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(provider.tr('Scheduled Bills & Reminders', 'নির্ধারিত বিল ও রিমাইন্ডার')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: RealisticDonutChart(
              values: [
                expBills > 0 ? expBills : 1,
                incScheduled > 0 ? incScheduled : 0,
              ],
              colors: const [Color(0xFFEF4444), Color(0xFF10B981)],
              labels: [
                '${provider.tr("Upcoming Bills", "আসন্ন বিল")} (৳${expBills.toStringAsFixed(0)})',
                '${provider.tr("Expected Income", "প্রত্যাশিত আয়")} (৳${incScheduled.toStringAsFixed(0)})',
              ],
              centerTitle: provider.tr('Scheduled', 'মোট রিমাইন্ডার'),
              centerValue: '${provider.scheduledTxs.length}',
            ),
          ),
          const SizedBox(height: 16),
          ...provider.scheduledTxs.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: ListTile(
              title: Row(
                children: [
                  Expanded(child: Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  if (s.hasAttachment)
                    TextButton.icon(
                      onPressed: () => AttachmentHelper.viewAttachment(context, s.attachmentBase64, s.attachmentName),
                      icon: const Icon(Icons.attach_file, size: 14, color: Color(0xFF38BDF8)),
                      label: Text(provider.tr('Bill Copy', 'বিল কপি'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                    ),
                ],
              ),
              subtitle: Text('Due: ${s.dueDate}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('৳${s.amount.toStringAsFixed(0)}', style: TextStyle(color: s.isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
                    onPressed: () => provider.deleteScheduledTx(s.id),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showAddScheduledSheet(context),
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(provider.tr('Add Scheduled Bill', 'নতুন বিল রিমাইন্ডার')),
      ),
    );
  }

  void _showAddScheduledSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: '5th of Month');
    bool isExp = true;
    String attBase64 = '';
    String attName = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(provider.tr('Schedule Bill / Memo', 'নির্ধারিত বিল যোগ করুন'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Bill Title (e.g., House Rent / Wi-Fi)', 'বিলের নাম'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Amount (৳)', 'পরিমাণ (৳)'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: dateCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: provider.tr('Due Date', 'পরিশোধের তারিখ'), filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final picked = await AttachmentHelper.pickReceiptOrMemo(context);
                  if (picked != null) {
                    setSheetState(() {
                      attBase64 = picked['base64']?.toString() ?? '';
                      attName = picked['name']?.toString() ?? '';
                    });
                  }
                },
                icon: const Icon(Icons.upload_file, color: Color(0xFF38BDF8)),
                label: Text(attName.isEmpty ? provider.tr('Attach Bill Invoice / Memo', 'বিলের কপি যুক্ত করুন') : attName, style: const TextStyle(color: Color(0xFF38BDF8))),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                  if (titleCtrl.text.trim().isEmpty || amt <= 0) return;
                  provider.saveScheduledTx(
                    title: titleCtrl.text.trim(),
                    amount: amt,
                    dueDate: dateCtrl.text.trim(),
                    isExpense: isExp,
                    attachmentBase64: attBase64,
                    attachmentName: attName,
                  );
                  Navigator.pop(ctx);
                },
                child: Text(provider.tr('Save Reminder', 'সেভ করুন')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CALCBOX FINANCIAL CALCULATOR WITH VISUAL CHART
// =============================================================================
class CalcBoxScreen extends StatefulWidget {
  const CalcBoxScreen({super.key});

  @override
  State<CalcBoxScreen> createState() => _CalcBoxScreenState();
}

class _CalcBoxScreenState extends State<CalcBoxScreen> {
  final _principalCtrl = TextEditingController(text: '50000');
  final _rateCtrl = TextEditingController(text: '10');
  final _yearsCtrl = TextEditingController(text: '2');

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final double principal = double.tryParse(_principalCtrl.text) ?? 0.0;
    final double rate = double.tryParse(_rateCtrl.text) ?? 0.0;
    final double years = double.tryParse(_yearsCtrl.text) ?? 1.0;
    final double profitInterest = principal * (rate / 100) * years;
    final double totalMaturity = principal + profitInterest;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), title: Text(p.tr('CalcBox Financial Planner', 'ক্যালকবক্স ফিন্যান্সিয়াল ক্যালকুলেটর'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF334155))),
            child: RealisticDonutChart(
              values: [principal > 0 ? principal : 1, profitInterest > 0 ? profitInterest : 0],
              colors: const [Color(0xFF0EA5E9), Color(0xFF10B981)],
              labels: [
                '${p.tr("Principal", "আসল")} (৳${principal.toStringAsFixed(0)})',
                '${p.tr("Return / Interest", "মুনাফা")} (৳${profitInterest.toStringAsFixed(0)})',
              ],
              centerTitle: p.tr('Maturity', 'মোট প্রাপ্য'),
              centerValue: '৳${totalMaturity.toStringAsFixed(0)}',
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _principalCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: p.tr('Principal Amount (৳)', 'আসল টাকা (৳)'), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: _rateCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: p.tr('Annual Rate (%)', 'বার্ষিক হার (%)'), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: _yearsCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: p.tr('Duration (Years)', 'মেয়াদ (বছর)'), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        ],
      ),
    );
  }
}