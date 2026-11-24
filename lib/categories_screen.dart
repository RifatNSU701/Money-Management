import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'providers/transaction_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _showExpense = true;

  Future<void> _confirmDeleteCategory(
      BuildContext context,
      TransactionProvider provider,
      String cat,
      ) async {
    final int linkedTxCount = provider.transactions
        .where(
          (t) =>
      !t.isTransfer &&
          t.isExpense == _showExpense &&
          (t.title == cat || t.subtitle == cat),
    )
        .length;
    final bool hasBudget = _showExpense && provider.budgets.containsKey(cat);

    final String detail = (linkedTxCount > 0 || hasBudget)
        ? provider.tr(
      'This will reassign $linkedTxCount linked ${linkedTxCount == 1 ? "transaction" : "transactions"} to "Uncategorized"${hasBudget ? " and remove its monthly budget" : ""}.',
      'এতে যুক্ত $linkedTxCount টি লেনদেন "Uncategorized"-এ স্থানান্তরিত হবে${hasBudget ? " এবং এর মাসিক বাজেট মুছে যাবে" : ""}।',
    )
        : provider.tr(
      'Remove "$cat" from your categories?',
      '"$cat" ক্যাটাগরিটি মুছে ফেলবেন?',
    );

    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Category "$cat"?', '"$cat" ডিলিট করবেন?'),
      message: detail,
    );
    if (!ok || !context.mounted) return;

    provider.deleteCategory(cat, _showExpense, reassignOrphans: true);
    AppFeedback.showInfo(
      context,
      provider.tr(
        'Category "$cat" deleted.',
        '"$cat" ক্যাটাগরি মুছে ফেলা হয়েছে।',
      ),
    );
  }

  Future<void> _confirmDeleteLabel(
      BuildContext context,
      TransactionProvider provider,
      String label,
      ) async {
    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Label "#$label"?', '"#$label" ট্যাগ ডিলিট করবেন?'),
      message: provider.tr(
        'Remove "#$label" from your quick-select transaction labels?',
        'লেনদেনের ট্যাগ তালিকা থেকে "#$label" মুছে ফেলবেন?',
      ),
    );
    if (!ok || !context.mounted) return;
    provider.deleteCustomLabel(label);
    AppFeedback.showInfo(
      context,
      provider.tr('Label "#$label" removed.', '"#$label" ট্যাগ মুছে ফেলা হয়েছে।'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final List<String> activeList =
    _showExpense ? provider.expenseCategories : provider.incomeCategories;

    final Map<String, double> catTotals = {};
    double grandTotal = 0.0;
    for (final c in activeList) {
      final double sum = provider.transactions
          .where((t) => !t.isTransfer && t.isExpense == _showExpense && t.title == c)
          .fold(0.0, (s, t) => s + t.amount);
      catTotals[c] = sum;
      grandTotal += sum;
    }

    const List<Color> palette = [
      Color(0xFF0EA5E9),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
        children: [
          Text(
            provider.tr(
              'Categories & Labels Analytics',
              'ক্যাটাগরি ও ট্যাগ বিশ্লেষণ',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.tr(
              'Customize income/expense categories, manage tags, and track category share.',
              'আয় ও ব্যয়ের খাত এবং ট্যাগ কাস্টমাইজ করুন এবং খাতওয়ারী গ্রাফ দেখুন।',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 1. CATEGORY DISTRIBUTION CHART (ZERO-SAFE, NEVER FAKE EQUAL SLICES)
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
                  _showExpense
                      ? provider.tr(
                    'Expense Category Share',
                    'ব্যয়ের খাতওয়ারী অনুপাত',
                  )
                      : provider.tr(
                    'Income Category Share',
                    'আয়ের খাতওয়ারী অনুপাত',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                RealisticDonutChart(
                  values: activeList.isEmpty
                      ? const [0.0]
                      : activeList.map((c) => catTotals[c] ?? 0.0).toList(),
                  colors: palette,
                  labels: activeList.isEmpty
                      ? [provider.tr('No Categories', 'কোনো খাত নেই')]
                      : activeList,
                  centerTitle: provider.tr('Total Volume', 'মোট লেনদেন'),
                  centerValue: provider.formatMoney(grandTotal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. EXPENSE / INCOME TAB SWITCHER (CLIP-PROOF)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.tr(
                          'Expense (${provider.expenseCategories.length})',
                          'ব্যয়ের খাত (${provider.expenseCategories.length})',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  selected: _showExpense,
                  selectedColor: const Color(0xFFEF4444),
                  labelStyle: TextStyle(
                    color: _showExpense ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showExpense = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.tr(
                          'Income (${provider.incomeCategories.length})',
                          'আয়ের খাত (${provider.incomeCategories.length})',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  selected: !_showExpense,
                  selectedColor: const Color(0xFF10B981),
                  labelStyle: TextStyle(
                    color:
                    !_showExpense ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showExpense = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. CATEGORY LIST WITH VOLUME BARS
          if (activeList.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                provider.tr(
                  'No categories yet. Tap "+ Add Category" below to create one.',
                  'কোনো ক্যাটাগরি নেই। নিচে "+ নতুন খাত" বাটনে ট্যাপ করুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...activeList.asMap().entries.map((entry) {
              final int idx = entry.key;
              final String cat = entry.value;
              final double amt = catTotals[cat] ?? 0.0;
              final double pct =
              grandTotal > 0 ? (amt / grandTotal).clamp(0.0, 1.0) : 0.0;
              final Color color = palette[idx % palette.length];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.category_outlined,
                            color: color,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${provider.tr("Recorded Volume", "মোট লেনদেন")}: ${provider.formatMoney(amt)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: provider.tr('Rename', 'নাম পরিবর্তন'),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                          onPressed: () =>
                              _showCategoryDialog(context, oldName: cat),
                        ),
                        IconButton(
                          tooltip: provider.tr('Delete', 'মুছুন'),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          onPressed: () =>
                              _confirmDeleteCategory(context, provider, cat),
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
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 18),

          // 4. TRANSACTION LABELS / TAGS MANAGER (CONNECTED TO TRANSACTION MODAL)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
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
                          'Transaction Labels / Tags (${provider.customLabels.length})',
                          'লেনদেনের ট্যাগ / লেবেল (${provider.customLabels.length})',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddLabelDialog(context),
                      icon: const Icon(
                        Icons.new_label_outlined,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      label: Text(
                        provider.tr('New Tag', 'নতুন ট্যাগ'),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  provider.tr(
                    'Assign these tags when recording income or expenses to group and search related entries.',
                    'লেনদেন যোগ করার সময় এই ট্যাগগুলো যুক্ত করে সহজেই খুঁজে বের করুন।',
                  ),
                  style:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                if (provider.customLabels.isEmpty)
                  Text(
                    provider.tr('No custom tags yet.', 'কোনো ট্যাগ নেই।'),
                    style:
                    const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.customLabels.map((lbl) {
                      final int usageCount = provider.transactions
                          .where((t) => t.labels.contains(lbl))
                          .length;
                      return InputChip(
                        backgroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        label: Text(
                          '#$lbl ($usageCount)',
                          style: const TextStyle(
                            color: Color(0xFFC4B5FD),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                        onDeleted: () =>
                            _confirmDeleteLabel(context, provider, lbl),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          provider.tr('Add Category', 'নতুন খাত যোগ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {String? oldName}) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: oldName ?? '');
    final existingList =
    _showExpense ? provider.expenseCategories : provider.incomeCategories;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          oldName == null
              ? provider.tr('Add New Category', 'নতুন ক্যাটাগরি যোগ করুন')
              : provider.tr('Rename Category', 'ক্যাটাগরির নাম পরিবর্তন'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            validator: (val) {
              final req = AppValidators.requiredText(
                val,
                provider.tr('Category name', 'ক্যাটাগরির নাম'),
              );
              if (req != null) return req;
              final lower = val!.trim().toLowerCase();
              final origLower = oldName?.trim().toLowerCase();
              final dup = existingList.any(
                    (c) => c.trim().toLowerCase() == lower && lower != origLower,
              );
              if (dup) {
                return provider.tr(
                  'This category already exists',
                  'এই ক্যাটাগরিটি ইতিমধ্যেই রয়েছে',
                );
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: provider.tr('Category Name *', 'ক্যাটাগরির নাম *'),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              provider.tr('Cancel', 'বাতিল'),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final text = ctrl.text.trim();
              if (oldName == null) {
                provider.addCategory(text, _showExpense);
              } else {
                provider.updateCategory(oldName, text, _showExpense);
              }
              Navigator.pop(ctx);
              AppFeedback.showInfo(
                context,
                oldName == null
                    ? provider.tr('Category added.', 'ক্যাটাগরি যোগ হয়েছে।')
                    : provider.tr('Category renamed.', 'ক্যাটাগরি আপডেট হয়েছে।'),
              );
            },
            child: Text(provider.tr('Save', 'সেভ করুন')),
          ),
        ],
      ),
    );
  }

  void _showAddLabelDialog(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          provider.tr('Add Transaction Tag', 'নতুন ট্যাগ যোগ করুন'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            validator: (val) {
              final req = AppValidators.requiredText(
                val,
                provider.tr('Tag name', 'ট্যাগের নাম'),
              );
              if (req != null) return req;
              final lower = val!.trim().toLowerCase();
              if (provider.customLabels
                  .any((l) => l.trim().toLowerCase() == lower)) {
                return provider.tr(
                  'This tag already exists',
                  'এই ট্যাগটি ইতিমধ্যেই রয়েছে',
                );
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: provider.tr('Tag Name (e.g., Tax, Trip) *', 'ট্যাগের নাম *'),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixText: '# ',
              prefixStyle: const TextStyle(color: Color(0xFF38BDF8)),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              provider.tr('Cancel', 'বাতিল'),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              provider.addCustomLabel(ctrl.text.trim());
              Navigator.pop(ctx);
              AppFeedback.showInfo(
                context,
                provider.tr('Tag added.', 'ট্যাগ যোগ হয়েছে।'),
              );
            },
            child: Text(provider.tr('Save', 'সেভ করুন')),
          ),
        ],
      ),
    );
  }
}