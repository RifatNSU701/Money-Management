import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  Future<void> _confirmDeleteWallet(
      BuildContext context,
      TransactionProvider provider,
      WalletModel wallet,
      ) async {
    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Account?', 'অ্যাকাউন্ট ডিলিট করবেন?'),
      message: provider.tr(
        'Remove "${wallet.name}" (${provider.formatMoney(wallet.balance)}) from your wallets?',
        '"${wallet.name}" (${provider.formatMoney(wallet.balance)}) মুছে ফেলবেন?',
      ),
    );
    if (!ok || !context.mounted) return;
    provider.deleteWallet(wallet.id);
    AppFeedback.showInfo(
      context,
      provider.tr('Wallet removed.', 'অ্যাকাউন্ট মুছে ফেলা হয়েছে।'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double total = provider.totalWalletsBalance;

    final double cashSum = provider.wallets
        .where((w) => w.type == 'Cash')
        .fold(0.0, (s, w) => s + w.balance);
    final double mobileSum = provider.wallets
        .where((w) => w.type == 'Mobile Banking')
        .fold(0.0, (s, w) => s + w.balance);
    final double bankSum = provider.wallets
        .where((w) => w.type == 'Bank Account')
        .fold(0.0, (s, w) => s + w.balance);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          provider.tr('Wallets & Bank Accounts', 'ওয়ালেট ও ব্যাংক অ্যাকাউন্ট'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (provider.wallets.length >= 2)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                ),
                onPressed: () => _showTransferSheet(context),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  provider.tr('Transfer', 'ট্রান্সফার'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
            children: [
              // 1. WALLETS ASSET DISTRIBUTION CHART (ZERO-SAFE, NON-CLIPPING LEGEND)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            provider.tr(
                              'Asset Distribution (Cash / MFS / Bank)',
                              'ওয়ালেট ও ব্যাংক জমার অনুপাত',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (provider.wallets.length >= 2)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _showTransferSheet(context),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                            label: Text(
                              provider.tr('Transfer', 'ট্রান্সফার'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RealisticDonutChart(
                      values: [
                        cashSum > 0 ? cashSum : 0.0,
                        mobileSum > 0 ? mobileSum : 0.0,
                        bankSum > 0 ? bankSum : 0.0,
                      ],
                      colors: const [
                        Color(0xFF10B981),
                        Color(0xFFEC4899),
                        Color(0xFF0EA5E9),
                      ],
                      labels: [
                        '${provider.tr("Cash", "ক্যাশ")} (${provider.formatMoney(cashSum)})',
                        '${provider.tr("MFS", "মোবাইল")} (${provider.formatMoney(mobileSum)})',
                        '${provider.tr("Bank", "ব্যাংক")} (${provider.formatMoney(bankSum)})',
                      ],
                      centerTitle: provider.tr('Total Funds', 'মোট জমা'),
                      centerValue: provider.formatMoney(total),
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
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...provider.wallets.map((w) {
                  final double pct =
                  total > 0 ? (w.balance / total).clamp(0.0, 1.0) : 0.0;
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
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${w.type} • ${w.providerName}${w.accountNumber.isNotEmpty ? " • ${w.accountNumber}" : ""}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.formatMoney(w.balance),
                              style: TextStyle(
                                color: w.balance >= 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              tooltip: provider.tr('Edit', 'এডিট'),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF38BDF8),
                                size: 18,
                              ),
                              onPressed: () =>
                                  _showWalletSheet(context, existing: w),
                            ),
                            IconButton(
                              tooltip: provider.tr('Delete', 'মুছুন'),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              onPressed: () =>
                                  _confirmDeleteWallet(context, provider, w),
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
        label: Text(
          provider.tr('Add Account', 'অ্যাকাউন্ট যোগ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showTransferSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    if (provider.wallets.length < 2) return;

    final formKey = GlobalKey<FormState>();
    String fromId = provider.wallets.first.id;
    String toId = provider.wallets[1].id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                    provider.tr(
                      'Wallet-to-Wallet Transfer',
                      'ওয়ালেট থেকে ওয়ালেটে ট্রান্সফার',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.tr(
                      'Transfers move funds between accounts without inflating your total income or expenses.',
                      'ট্রান্সফার করলে আপনার মোট আয় বা ব্যয় বাড়বে না, শুধু অ্যাকাউন্ট ব্যালেন্স আপডেট হবে।',
                    ),
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: fromId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: provider.tr('From Account *', 'যে অ্যাকাউন্ট থেকে *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: provider.wallets
                        .map(
                          (w) => DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          '${w.name} (${provider.formatMoney(w.balance)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => fromId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: toId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    validator: (v) {
                      if (v == null || v == fromId) {
                        return provider.tr(
                          'Choose a different destination account',
                          'আলাদা গন্তব্য অ্যাকাউন্ট নির্বাচন করুন',
                        );
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: provider.tr('To Account *', 'যে অ্যাকাউন্টে *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      errorStyle: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: provider.wallets
                        .map(
                          (w) => DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          '${w.name} (${provider.formatMoney(w.balance)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => toId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppValidators.amountFormatters,
                    validator: (v) => AppValidators.positiveAmount(
                      v,
                      label: provider.tr('Transfer amount', 'ট্রান্সফার পরিমাণ'),
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr(
                        'Amount (${provider.currencyCode} ${provider.currencySymbol}) *',
                        'টাকার পরিমাণ (${provider.currencySymbol}) *',
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      errorStyle: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Note (Optional)', 'নোট (ঐচ্ছিক)'),
                      hintText: provider.tr('e.g., Cash out from bKash', 'যেমন: বিকাশ থেকে ক্যাশ আউট'),
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final amt = AppCurrency.parseAmount(amountCtrl.text);
                      if (amt == null || amt <= 0) return;
                      provider.transferBetweenWallets(
                        fromWalletId: fromId,
                        toWalletId: toId,
                        amount: amt,
                        note: noteCtrl.text.trim(),
                      );
                      Navigator.pop(ctx);
                      AppFeedback.showInfo(
                        context,
                        provider.tr(
                          'Transfer recorded successfully.',
                          'ট্রান্সফার সফলভাবে সম্পন্ন হয়েছে।',
                        ),
                      );
                    },
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      provider.tr('Complete Transfer', 'ট্রান্সফার সম্পন্ন করুন'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletSheet(BuildContext context, {WalletModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    String selectedType = existing?.type ?? 'Mobile Banking';
    String selectedProvider = existing?.providerName ?? 'bKash';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final accCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final double? exBal = existing?.balance;
    final balCtrl = TextEditingController(
      text: exBal != null
          ? ((exBal - exBal.truncateToDouble()).abs() > 0.001
          ? exBal.toStringAsFixed(2)
          : exBal.toStringAsFixed(0))
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<String> providers = selectedType == 'Mobile Banking'
              ? ['bKash', 'Nagad', 'Rocket', 'Upay']
              : (selectedType == 'Bank Account'
              ? [
            'City Bank',
            'BRAC Bank',
            'DBBL',
            'Islami Bank',
            'EBL',
            'Sonali Bank',
          ]
              : ['Physical Cash']);
          if (!providers.contains(selectedProvider)) {
            selectedProvider = providers.first;
          }

          return Padding(
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
                      existing == null
                          ? provider.tr(
                        'Add Wallet / Bank Account',
                        'নতুন ওয়ালেট বা ব্যাংক অ্যাকাউন্ট',
                      )
                          : provider.tr('Edit Account', 'অ্যাকাউন্ট এডিট করুন'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: ['Cash', 'Mobile Banking', 'Bank Account']
                          .map((t) {
                        final isSel = selectedType == t;
                        return ChoiceChip(
                          label: Text(
                            t,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF0EA5E9),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheetState(() => selectedType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: providers.map((p) {
                        final isSel = selectedProvider == p;
                        return ChoiceChip(
                          label: Text(
                            p,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                              fontSize: 11,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheetState(() => selectedProvider = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Account Title (e.g., Personal bKash)',
                          'অ্যাকাউন্টের নাম',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: AppValidators.accountNumberOnly,
                      validator: (v) =>
                          AppValidators.accountNumber(v, required: false),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Account / Mobile Number (Digits only, Optional)',
                          'অ্যাকাউন্ট / মোবাইল নম্বর (শুধু সংখ্যা, ঐচ্ছিক)',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: balCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.nonNegativeAmount(
                        v,
                        label: provider.tr('Balance', 'ব্যালেন্স'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Current Balance (${provider.currencySymbol})',
                          'বর্তমান ব্যালেন্স (${provider.currencySymbol})',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        final name = nameCtrl.text.trim().isEmpty
                            ? selectedProvider
                            : nameCtrl.text.trim();
                        final bal = AppCurrency.parseAmount(balCtrl.text) ?? 0.0;
                        provider.saveWallet(
                          id: existing?.id,
                          name: name,
                          type: selectedType,
                          providerName: selectedProvider,
                          accountNumber: accCtrl.text.trim(),
                          balance: bal,
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          existing == null
                              ? provider.tr(
                            'Wallet added.',
                            'অ্যাকাউন্ট যোগ হয়েছে।',
                          )
                              : provider.tr(
                            'Wallet updated.',
                            'অ্যাকাউন্ট আপডেট হয়েছে।',
                          ),
                        );
                      },
                      child: Text(
                        provider.tr('Save Account', 'অ্যাকাউন্ট সেভ করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// SCHEDULED BILLS & REMINDERS (LOCKED DATE PICKER, EDIT, MARK AS PAID, EMPTY STATE)
// =============================================================================
class ScheduledTransactionsScreen extends StatelessWidget {
  const ScheduledTransactionsScreen({super.key});

  Future<void> _confirmDeleteBill(
      BuildContext context,
      TransactionProvider provider,
      ScheduledTxModel bill,
      ) async {
    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Reminder?', 'রিমাইন্ডার ডিলিট করবেন?'),
      message: provider.tr(
        'Remove scheduled bill "${bill.title}" (${provider.formatMoney(bill.amount)})?',
        '"${bill.title}" (${provider.formatMoney(bill.amount)}) মুছে ফেলবেন?',
      ),
    );
    if (!ok || !context.mounted) return;
    provider.deleteScheduledTx(bill.id);
    AppFeedback.showInfo(
      context,
      provider.tr('Scheduled bill deleted.', 'বিল রিমাইন্ডার মুছে ফেলা হয়েছে।'),
    );
  }

  Future<void> _confirmMarkPaid(
      BuildContext context,
      TransactionProvider provider,
      ScheduledTxModel bill,
      ) async {
    final WalletModel? defaultWallet =
    provider.wallets.isNotEmpty ? provider.wallets.first : null;
    provider.markScheduledTxPaid(
      bill.id,
      walletId: defaultWallet?.id ?? '',
      walletName: defaultWallet?.name ?? '',
    );
    AppFeedback.showInfo(
      context,
      provider.tr(
        '"${bill.title}" marked as paid and recorded in your ledger.',
        '"${bill.title}" পরিশোধিত হিসেবে লেনদেনে যুক্ত হয়েছে।',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double expBills = provider.scheduledTxs
        .where((s) => s.isExpense && !s.isPaid)
        .fold(0.0, (sum, s) => sum + s.amount);
    final double incScheduled = provider.scheduledTxs
        .where((s) => !s.isExpense && !s.isPaid)
        .fold(0.0, (sum, s) => sum + s.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          provider.tr(
            'Scheduled Bills & Reminders',
            'নির্ধারিত বিল ও রিমাইন্ডার',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: RealisticDonutChart(
              values: [expBills, incScheduled],
              colors: const [Color(0xFFEF4444), Color(0xFF10B981)],
              labels: [
                '${provider.tr("Upcoming Bills", "আসন্ন বিল")} (${provider.formatMoney(expBills)})',
                '${provider.tr("Expected Income", "প্রত্যাশিত আয়")} (${provider.formatMoney(incScheduled)})',
              ],
              centerTitle: provider.tr('Scheduled', 'মোট রিমাইন্ডার'),
              centerValue: '${provider.scheduledTxs.length}',
            ),
          ),
          const SizedBox(height: 16),

          if (provider.scheduledTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: Color(0xFF38BDF8),
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.tr(
                      'No scheduled bills or reminders yet.',
                      'এখনো কোনো নির্ধারিত বিল বা রিমাইন্ডার নেই।',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.tr(
                      'Tap "+ Add Scheduled Bill" below to track rent, Wi-Fi, tuition, or monthly salary with calendar due dates.',
                      'বাসা ভাড়া, ওয়াই-ফাই, টিউশন বা বেতন রিমাইন্ডার যোগ করতে নিচে "+ নতুন বিল রিমাইন্ডার" বাটনে ট্যাপ করুন।',
                    ),
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...provider.scheduledTxs.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s.isPaid
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                  if (s.isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        provider.tr('PAID', 'পরিশোধিত'),
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.isPaid
                                    ? '${provider.tr("Paid on", "পরিশোধের তারিখ")}: ${s.paidDate}'
                                    : '${provider.tr("Due Date", "পরিশোধের তারিখ")}: ${s.dueDate}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.formatMoney(s.amount),
                          style: TextStyle(
                            color: s.isExpense
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (!s.isPaid)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _confirmMarkPaid(context, provider, s),
                            icon: const Icon(Icons.check_circle_outline, size: 15),
                            label: Text(
                              provider.tr('Mark Paid', 'পরিশোধিত'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              _showScheduledSheet(context, existing: s),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text(
                            provider.tr('Edit', 'এডিট'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        if (s.hasAttachment)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => AttachmentHelper.viewAttachment(
                              context,
                              s.attachmentBase64,
                              s.attachmentName,
                            ),
                            icon: const Icon(Icons.zoom_in_rounded, size: 14),
                            label: Text(
                              provider.tr('Bill Copy', 'বিল কপি'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFF334155)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              _confirmDeleteBill(context, provider, s),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: Text(
                            provider.tr('Delete', 'মুছুন'),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showScheduledSheet(context),
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text(
          provider.tr('Add Scheduled Bill', 'নতুন বিল রিমাইন্ডার'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showScheduledSheet(BuildContext context, {ScheduledTxModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final double? exAmt = existing?.amount;
    final amtCtrl = TextEditingController(
      text: exAmt != null
          ? ((exAmt - exAmt.truncateToDouble()).abs() > 0.001
          ? exAmt.toStringAsFixed(2)
          : exAmt.toStringAsFixed(0))
          : '',
    );
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    final dateCtrl = TextEditingController(
      text: existing != null && existing.dueDate.trim().isNotEmpty
          ? existing.dueDate
          : provider.formatDateOnly(selectedDueDate),
    );
    bool isExp = existing?.isExpense ?? true;
    String attBase64 = existing?.attachmentBase64 ?? '';
    String attName = existing?.attachmentName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickDueDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDueDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1095)),
            );
            if (picked != null) {
              setSheetState(() {
                selectedDueDate = picked;
                dateCtrl.text = provider.formatDateOnly(picked);
              });
            }
          }

          return Padding(
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
                      existing == null
                          ? provider.tr(
                        'Schedule Bill / Reminder',
                        'নির্ধারিত বিল যোগ করুন',
                      )
                          : provider.tr(
                        'Edit Scheduled Bill',
                        'নির্ধারিত বিল এডিট করুন',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(provider.tr('Expense Bill', 'ব্যয়ের বিল')),
                            ),
                            selected: isExp,
                            selectedColor: const Color(0xFFEF4444),
                            labelStyle: TextStyle(
                              color: isExp
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() => isExp = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                provider.tr('Expected Income', 'প্রত্যাশিত আয়'),
                              ),
                            ),
                            selected: !isExp,
                            selectedColor: const Color(0xFF10B981),
                            labelStyle: TextStyle(
                              color: !isExp
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) =>
                                setSheetState(() => isExp = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtrl,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Bill title', 'বিলের নাম'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Bill Title (e.g., House Rent / Wi-Fi) *',
                          'বিলের নাম *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amtCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.positiveAmount(
                        v,
                        label: provider.tr('Amount', 'পরিমাণ'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Amount (${provider.currencySymbol}) *',
                          'পরিমাণ (${provider.currencySymbol}) *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // LOCKED DATE PICKER (BLOCKS FREE TEXT LIKE "banana")
                    TextFormField(
                      controller: dateCtrl,
                      readOnly: true,
                      onTap: pickDueDate,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Due date', 'পরিশোধের তারিখ'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Due Date (Select from calendar) *',
                          'পরিশোধের তারিখ (ক্যালেন্ডার থেকে) *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFF38BDF8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            color: Color(0xFF38BDF8),
                          ),
                          onPressed: pickDueDate,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        errorStyle: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 11.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (attBase64.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: buildTrueColorWrapper(
                                isDarkMode: provider.isDarkMode,
                                child: Image.memory(
                                  base64Decode(attBase64),
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.upload_file,
                              color: Color(0xFF38BDF8),
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attName.isEmpty
                                  ? provider.tr(
                                'Attach Bill Invoice / Memo',
                                'বিলের কপি যুক্ত করুন',
                              )
                                  : attName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: attName.isEmpty
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF10B981),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked =
                              await AttachmentHelper.pickReceiptOrMemo(
                                context,
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  attBase64 = picked['base64'] ?? '';
                                  attName = picked['name'] ?? '';
                                });
                              }
                            },
                            child: Text(
                              attName.isEmpty
                                  ? provider.tr('Attach', 'যুক্ত করুন')
                                  : provider.tr('Change', 'বদলান'),
                              style: const TextStyle(color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        final amt = AppCurrency.parseAmount(amtCtrl.text);
                        if (amt == null || amt <= 0) return;
                        provider.saveScheduledTx(
                          id: existing?.id,
                          title: titleCtrl.text.trim(),
                          amount: amt,
                          dueDate: dateCtrl.text.trim(),
                          isExpense: isExp,
                          attachmentBase64: attBase64,
                          attachmentName: attName,
                          isPaid: existing?.isPaid ?? false,
                          paidDate: existing?.paidDate ?? '',
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          existing == null
                              ? provider.tr(
                            'Scheduled bill saved.',
                            'বিল রিমাইন্ডার সেভ হয়েছে।',
                          )
                              : provider.tr(
                            'Scheduled bill updated.',
                            'বিল রিমাইন্ডার আপডেট হয়েছে।',
                          ),
                        );
                      },
                      child: Text(
                        existing == null
                            ? provider.tr('Save Reminder', 'সেভ করুন')
                            : provider.tr('Update Reminder', 'আপডেট করুন'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// CALCBOX FINANCIAL CALCULATOR (SIMPLE VS COMPOUND TOGGLE + ZERO-SAFE CHART)
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
  bool _isCompound = false;

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final double rawPrincipal =
    (AppCurrency.parseAmount(_principalCtrl.text) ?? 0.0)
        .clamp(0.0, AppCurrency.maxAmount);
    final double rate =
    (double.tryParse(_rateCtrl.text.trim()) ?? 0.0).clamp(0.0, 1000.0);
    final double years =
    (double.tryParse(_yearsCtrl.text.trim()) ?? 0.0).clamp(0.0, 100.0);

    final double totalMaturity = _isCompound
        ? rawPrincipal * math.pow(1 + (rate / 100.0), years).toDouble()
        : rawPrincipal + (rawPrincipal * (rate / 100.0) * years);
    final double safeMaturity =
    totalMaturity.isFinite ? totalMaturity : rawPrincipal;
    final double profitInterest =
    math.max(0.0, safeMaturity - rawPrincipal);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          p.tr(
            'CalcBox Financial Calculator',
            'ক্যালকবক্স ফিন্যান্সিয়াল ক্যালকুলেটর',
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // SIMPLE VS COMPOUND MODE TOGGLE
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          p.tr('Simple Interest', 'সরল মুনাফা'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      selected: !_isCompound,
                      selectedColor: const Color(0xFF0EA5E9),
                      labelStyle: TextStyle(
                        color: !_isCompound
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      backgroundColor: const Color(0xFF1E293B),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _isCompound = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          p.tr('Compound (Annual)', 'চক্রবৃদ্ধি মুনাফা'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      selected: _isCompound,
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(
                        color: _isCompound
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      backgroundColor: const Color(0xFF1E293B),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _isCompound = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                      _isCompound
                          ? p.tr(
                        'Annual Compounding: A = P × (1 + r/100)^t',
                        'বার্ষিক চক্রবৃদ্ধি: A = P × (1 + r/100)^t',
                      )
                          : p.tr(
                        'Simple Interest: A = P + (P × r × t / 100)',
                        'সরল মুনাফা: A = P + (P × r × t / 100)',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RealisticDonutChart(
                      values: [rawPrincipal, profitInterest],
                      colors: const [Color(0xFF0EA5E9), Color(0xFF10B981)],
                      labels: [
                        '${p.tr("Principal", "আসল")} (${p.formatMoney(rawPrincipal)})',
                        '${p.tr("Return / Interest", "মুনাফা")} (${p.formatMoney(profitInterest)})',
                      ],
                      centerTitle: p.tr('Maturity', 'মোট প্রাপ্য'),
                      centerValue: p.formatMoney(safeMaturity),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _principalCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppValidators.amountFormatters,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: p.tr(
                    'Principal Amount (${p.currencySymbol})',
                    'আসল টাকা (${p.currencySymbol})',
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rateCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppValidators.amountFormatters,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: p.tr('Annual Rate (%)', 'বার্ষিক হার (%)'),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _yearsCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppValidators.amountFormatters,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: p.tr('Duration (Years)', 'মেয়াদ (বছর)'),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}