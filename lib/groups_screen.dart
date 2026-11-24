import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'core/utils/app_currency.dart';
import 'core/utils/app_validators.dart';
import 'core/widgets/app_feedback.dart';
import 'main_navigation.dart';
import 'providers/transaction_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _searchQuery = '';
  String _planFilter = 'All'; // 'All', 'Under Budget', 'Collection Pending'
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _memberCountText(int count, TransactionProvider provider) {
    if (provider.isBengali) return '$count জন সদস্য';
    return '$count ${count == 1 ? "member" : "members"}';
  }

  // ===========================================================================
  // OFFICIAL PDF GROUP AUDIT & SETTLEMENT REPORT GENERATOR
  // ===========================================================================
  Future<void> _exportGroupPdfReport(
      GroupModel group,
      TransactionProvider provider,
      ) async {
    try {
      final settlements = group.computeSettlements();
      final doc = pw.Document();
      final String code = provider.currencyCode;

      String pdfMoney(double v) => '$code ${v.toStringAsFixed(2)}';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FINBLEND GROUP & TRIP SPLIT STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Plan Name: ${group.name}  |  Created: ${group.createdAt}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Text(
                  'Members: ${group.memberCount}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Divider(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Plan Budget',
                'Total Collected',
                'Still Owed',
                'Total Spent',
                'Budget Left',
                'Cash Pool Left',
              ],
              data: [
                [
                  pdfMoney(group.totalBudget),
                  pdfMoney(group.totalCollected),
                  pdfMoney(group.totalMemberDues),
                  pdfMoney(group.totalSpent),
                  pdfMoney(group.budgetRemaining),
                  pdfMoney(group.poolBalanceLeft),
                ],
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              '1. Member Contributions & Standing (Default Target: ${pdfMoney(group.targetPerMember)})',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Member',
                'Target',
                'Paid',
                'Due / Credit',
                'Status',
              ],
              data: group.members.map((m) {
                final target = group.targetForMember(m);
                final due = group.memberDue(m);
                final credit = group.memberCredit(m);
                final standing = credit > 0
                    ? '+${pdfMoney(credit)} Credit'
                    : (due > 0 ? '${pdfMoney(due)} Due' : 'Balanced');
                return [
                  m.name,
                  pdfMoney(target),
                  pdfMoney(m.paidAmount),
                  standing,
                  m.isSettled ? 'Settled' : 'Open',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              '2. Settlement Plan (Includes Pool Shortfalls / Refunds)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (settlements.isEmpty)
              pw.Text(
                'All members are evenly settled.',
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Payer (From)', 'Receiver (To)', 'Amount'],
                data: settlements
                    .map((s) => [s.fromName, s.toName, pdfMoney(s.amount)])
                    .toList(),
              ),
            pw.SizedBox(height: 18),
            pw.Text(
              '3. Shared Expense & Receipt Log (${group.expenses.length} entries)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (group.expenses.isEmpty)
              pw.Text(
                'No expenses recorded yet.',
                style: const pw.TextStyle(fontSize: 10),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Expense', 'Paid By', 'Date', 'Receipt', 'Amount'],
                data: group.expenses
                    .map(
                      (e) => [
                    e.title,
                    e.paidByMemberName,
                    e.date,
                    e.hasAttachment ? e.attachmentName : '-',
                    pdfMoney(e.amount),
                  ],
                )
                    .toList(),
              ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'FinBlend_Group_${group.name.replaceAll(" ", "_")}.pdf',
      );
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'PDF Export Error: $e');
      }
    }
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context,
      TransactionProvider provider,
      GroupModel group,
      ) async {
    final ok = await AppFeedback.confirmDelete(
      context,
      title: provider.tr('Delete Group Plan?', 'গ্রুপ প্ল্যান ডিলিট করবেন?'),
      message: provider.tr(
        'Permanently delete "${group.name}" including all ${group.memberCount} ${_memberCountText(group.memberCount, provider)} and ${group.expenses.length} logged expenses?',
        '"${group.name}" এবং এর সকল সদস্য ও খরচের হিসাব স্থায়ীভাবে মুছে ফেলবেন?',
      ),
    );
    if (!ok || !context.mounted) return;
    provider.deleteGroup(group.id);
    AppFeedback.showInfo(
      context,
      provider.tr('Group plan deleted.', 'গ্রুপ প্ল্যান মুছে ফেলা হয়েছে।'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double totalBudgets =
    provider.groups.fold(0.0, (s, g) => s + g.totalBudget);
    final double totalCollected =
    provider.groups.fold(0.0, (s, g) => s + g.totalCollected);
    final double totalSpent =
    provider.groups.fold(0.0, (s, g) => s + g.totalSpent);
    final double totalOwed =
    provider.groups.fold(0.0, (s, g) => s + g.totalMemberDues);

    final filteredGroups = provider.groups.where((g) {
      if (_planFilter == 'Under Budget' && g.budgetRemaining <= 0) return false;
      if (_planFilter == 'Collection Pending' && g.totalMemberDues <= 0) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = g.name.toLowerCase().contains(q);
        final matchMember =
        g.members.any((m) => m.name.toLowerCase().contains(q));
        return matchName || matchMember;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 118),
        children: [
          // 1. HEADER & SAVED MEMBERS DIRECTORY BUTTON
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr(
                        'Group & Trip Budget Splitting',
                        'গ্রুপ ও ট্যুর বাজেট স্প্লিটিং',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider.tr(
                        'Manage shared budgets, custom targets, credits, receipts & settlements.',
                        'যৌথ বাজেট, সদস্যদের চাঁদা, রসিদ এবং নিষ্পত্তি পরিচালনা করুন।',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showSavedMembersDirectorySheet(context),
                icon: const Icon(Icons.contacts_outlined, size: 15),
                label: Text(
                  '${provider.tr("Directory", "সদস্য")} (${provider.savedMembers.length})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. GLOBAL GROUP ANALYTICS CHART (ZERO-SAFE + COMPLETE 3-SLICE LEGEND)
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
                  children: [
                    Expanded(
                      child: Text(
                        provider.tr(
                          'Group Pool Collection vs Spending',
                          'গ্রুপ তহবিল জমা বনাম ব্যয়ের চার্ট',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${provider.groups.length} ${provider.tr(provider.groups.length == 1 ? "Plan" : "Plans", "টি প্ল্যান")}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [totalCollected, totalSpent, totalOwed],
                  colors: const [
                    Color(0xFF10B981),
                    Color(0xFF0EA5E9),
                    Color(0xFFF59E0B),
                  ],
                  labels: [
                    '${provider.tr("Collected", "মোট জমা")} (${provider.formatMoney(totalCollected)})',
                    '${provider.tr("Total Spent", "মোট খরচ")} (${provider.formatMoney(totalSpent)})',
                    '${provider.tr("Pending Due", "বাকি চাঁদা")} (${provider.formatMoney(totalOwed)})',
                  ],
                  centerTitle: provider.tr('Total Budget', 'মোট বাজেট'),
                  centerValue: provider.formatMoney(totalBudgets),
                ),
                if (provider.groups.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Divider(color: Color(0xFF334155), height: 1),
                  ),
                  Text(
                    provider.tr(
                      'Plan-by-Plan Budget Utilization',
                      'প্ল্যান অনুযায়ী বাজেট ব্যবহার',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...provider.groups.take(4).map((g) {
                    final double spentPct = g.totalBudget > 0
                        ? (g.totalSpent / g.totalBudget).clamp(0.0, 1.0)
                        : 0.0;
                    final double colPct = g.totalBudget > 0
                        ? (g.totalCollected / g.totalBudget).clamp(0.0, 1.0)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  g.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${provider.formatMoney(g.totalSpent)} / ${provider.formatMoney(g.totalBudget)} (${(spentPct * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: spentPct,
                              minHeight: 6,
                              backgroundColor: const Color(0xFF0F172A),
                              color: spentPct > 0.9
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0EA5E9),
                            ),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: colPct,
                              minHeight: 4,
                              backgroundColor: const Color(0xFF0F172A),
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. SEARCH & FILTER BAR
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr(
                'Search group plans or member names...',
                'গ্রুপের নাম বা সদস্যের নাম দিয়ে খুঁজুন...',
              ),
              hintStyle:
              const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon:
              const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', provider.tr('All Plans', 'সকল প্ল্যান')),
              _buildFilterChip(
                'Under Budget',
                provider.tr('Active Budget', 'বাজেট চলমান'),
              ),
              _buildFilterChip(
                'Collection Pending',
                provider.tr('Collection Due', 'চাঁদা বাকি'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. GROUP CARDS OR EMPTY STATE (WITH FULL FAB CLEARANCE)
          if (filteredGroups.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.groups_2_outlined,
                    color: Color(0xFF38BDF8),
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.tr(
                      'No Group or Trip Plans Found',
                      'কোনো গ্রুপ বা ট্যুর প্ল্যান পাওয়া যায়নি',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.tr(
                      'Tap "+ Create Trip / Split Plan" below to set a target budget, add members, and split shared costs.',
                      'নিচে "+ নতুন গ্রুপ প্ল্যান" বাটনে ট্যাপ করে বাজেট নির্ধারণ করুন এবং সদস্যদের যোগ করুন।',
                    ),
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...filteredGroups
                .map((g) => _buildExecutiveGroupCard(context, g, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () => _showCreateOrEditGroupSheet(context),
        icon: const Icon(Icons.group_add_rounded),
        label: Text(
          provider.tr('Create Trip / Split Plan', 'নতুন গ্রুপ প্ল্যান'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _planFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSel ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSel,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      onSelected: (_) => setState(() => _planFilter = key),
    );
  }

  Widget _buildExecutiveGroupCard(
      BuildContext context,
      GroupModel g,
      TransactionProvider provider,
      ) {
    final double spentRatio =
    g.totalBudget > 0 ? (g.totalSpent / g.totalBudget).clamp(0.0, 1.0) : 0.0;
    final double collectRatio = g.totalBudget > 0
        ? (g.totalCollected / g.totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final int receiptCount = g.expenses.where((e) => e.hasAttachment).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.luggage_outlined,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_memberCountText(g.memberCount, provider)} • ${provider.tr("Target", "লক্ষ্য")}: ${provider.formatMoney(g.targetPerMember)} • $receiptCount ${provider.tr(receiptCount == 1 ? "receipt" : "receipts", "টি রসিদ")}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: provider.tr('Export PDF Statement', 'পিডিএফ রিপোর্ট'),
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Color(0xFF38BDF8),
                  size: 19,
                ),
                onPressed: () => _exportGroupPdfReport(g, provider),
              ),
              IconButton(
                tooltip: provider.tr('Edit Plan', 'এডিট করুন'),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF94A3B8),
                  size: 19,
                ),
                onPressed: () =>
                    _showCreateOrEditGroupSheet(context, existing: g),
              ),
              IconButton(
                tooltip: provider.tr('Delete Plan', 'ডিলিট করুন'),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 19,
                ),
                onPressed: () => _confirmDeleteGroup(context, provider, g),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 6-METRIC GRID (ACCURATE DUES EVEN WITH OVERPAYING MEMBERS)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('1. Plan Budget', '১. মোট বাজেট'),
                        provider.formatMoney(g.totalBudget),
                        const Color(0xFF38BDF8),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF334155),
                    ),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('2. Total Given', '২. মোট জমা'),
                        provider.formatMoney(g.totalCollected),
                        const Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF334155),
                    ),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('3. Still Owed', '৩. বাকি চাঁদা'),
                        provider.formatMoney(g.totalMemberDues),
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Color(0xFF334155), height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('4. Total Spent', '৪. মোট খরচ'),
                        provider.formatMoney(g.totalSpent),
                        const Color(0xFFEF4444),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF334155),
                    ),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('5. Budget Left', '৫. অবশিষ্ট বাজেট'),
                        provider.formatMoney(g.budgetRemaining),
                        g.budgetRemaining >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFF334155),
                    ),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('6. Cash Pool Left', '৬. ক্যাশ তহবিল'),
                        provider.formatMoney(g.poolBalanceLeft),
                        g.poolBalanceLeft >= 0
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.tr("Collection", "চাঁদা আদায়")}: ${(collectRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${provider.tr("Budget Spent", "বাজেট ব্যয়")}: ${(spentRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 7,
              backgroundColor: const Color(0xFF0F172A),
              color: spentRatio > 0.9
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 12),

          // MEMBER CHIPS PREVIEW (SHOWS OVERPAYMENT CREDIT + SETTLED BADGE)
          if (g.members.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: g.members.map((m) {
                final double due = g.memberDue(m);
                final double credit = g.memberCredit(m);
                final String badgeText = credit > 0
                    ? '(+${provider.formatMoney(credit)} ${provider.tr("Credit", "অগ্রিম")})'
                    : (due > 0
                    ? '(${provider.tr("Due", "বাকি")} ${provider.formatMoney(due)})'
                    : '✓');
                final Color borderColor = m.isSettled
                    ? const Color(0xFF38BDF8)
                    : (credit > 0
                    ? const Color(0xFF10B981)
                    : (due > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981)));

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showMemberDialog(context, g, existing: m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      '${m.name}: ${provider.formatMoney(m.paidAmount)} $badgeText${m.isSettled ? " • Settled" : ""}',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // ACTION BUTTONS ROW
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showGroupExpenseSheet(context, g),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                label: Text(
                  provider.tr('Log Expense', 'খরচ যোগ'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showMemberDialog(context, g),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                label: Text(
                  provider.tr('Add / Update Member', 'সদস্য ও চাঁদা'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openFullGroupWorkspaceModal(context, g.id),
                icon: const Icon(Icons.analytics_outlined, size: 15),
                label: Text(
                  provider.tr('Full Ledger & Settle Up', 'পূর্ণাঙ্গ হিসাব ও নিষ্পত্তি'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSixMetricBox(String title, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL 1: SAVED MEMBERS DIRECTORY MANAGER
  // ===========================================================================
  void _showSavedMembersDirectorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.tr(
                      'Saved Members Directory',
                      'সংরক্ষিত সদস্য তালিকা',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                provider.tr(
                  'Save frequent friends or colleagues here for 1-tap selection in any group split.',
                  'বারবার ব্যবহৃত বন্ধু বা সহকর্মীদের নাম এখানে সেভ রাখুন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),
              Form(
                key: formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: nameCtrl,
                        validator: (v) => AppValidators.uniqueMemberName(
                          v,
                          provider.savedMembers,
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: provider.tr(
                            'Enter member name...',
                            'সদস্যের নাম লিখুন...',
                          ),
                          hintStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          errorStyle: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        provider.addSavedMember(nameCtrl.text.trim());
                        nameCtrl.clear();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(provider.tr('Add', 'যোগ')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (provider.savedMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    provider.tr(
                      'Directory is empty. Add names above!',
                      'তালিকা খালি রয়েছে। উপরে নাম লিখে যোগ করুন!',
                    ),
                    style:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.savedMembers.length,
                    itemBuilder: (c, i) {
                      final mName = provider.savedMembers[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor:
                          const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          child: Text(
                            mName.isNotEmpty ? mName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          mName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF38BDF8),
                                size: 18,
                              ),
                              onPressed: () =>
                                  _showRenameSavedMemberDialog(context, mName),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              onPressed: () async {
                                final ok = await AppFeedback.confirmDelete(
                                  context,
                                  title: provider.tr(
                                    'Remove "$mName"?',
                                    '"$mName" মুছবেন?',
                                  ),
                                  message: provider.tr(
                                    'Remove "$mName" from your saved directory?',
                                    'সংরক্ষিত তালিকা থেকে "$mName" মুছে ফেলবেন?',
                                  ),
                                );
                                if (ok) provider.deleteSavedMember(mName);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameSavedMemberDialog(BuildContext context, String oldName) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          provider.tr('Rename Saved Member', 'সদস্যের নাম পরিবর্তন'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            validator: (v) => AppValidators.uniqueMemberName(
              v,
              provider.savedMembers,
              editingOriginalName: oldName,
            ),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(provider.tr('Cancel', 'বাতিল')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              provider.updateSavedMember(oldName, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(provider.tr('Save', 'সেভ')),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL 2: CREATE OR EDIT GROUP PLAN (INLINE VALIDATION, NO SILENT FAILURE)
  // ===========================================================================
  void _showCreateOrEditGroupSheet(
      BuildContext context, {
        GroupModel? existing,
      }) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final double? exBudget = existing?.totalBudget;
    final budgetCtrl = TextEditingController(
      text: exBudget != null
          ? ((exBudget - exBudget.truncateToDouble()).abs() > 0.001
          ? exBudget.toStringAsFixed(2)
          : exBudget.toStringAsFixed(0))
          : '',
    );
    final customMemberCtrl = TextEditingController();
    final List<String> selectedNames = existing != null
        ? existing.members.map((m) => m.name).toList()
        : [];
    String? memberInlineError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double enteredBudget =
              AppCurrency.parseAmount(budgetCtrl.text) ?? 0.0;
          final double perPerson =
          selectedNames.isNotEmpty ? (enteredBudget / selectedNames.length) : 0.0;

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
                        'Create Group / Trip Budget Plan',
                        'নতুন গ্রুপ বা ট্যুর বাজেট প্ল্যান',
                      )
                          : provider.tr(
                        'Edit Group Budget Plan',
                        'গ্রুপ প্ল্যান সম্পাদনা করুন',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Plan title', 'প্ল্যানের নাম'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Plan / Event Title (e.g., Sajek Valley Tour) *',
                          'প্ল্যান বা ইভেন্টের নাম *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.tour_outlined,
                          color: Color(0xFF38BDF8),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: budgetCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.positiveAmount(
                        v,
                        label: provider.tr('Total budget', 'মোট বাজেট'),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Total Target Budget (${provider.currencySymbol}) *',
                          'মোট নির্ধারিত বাজেট (${provider.currencySymbol}) *',
                        ),
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(
                          Icons.payments_outlined,
                          color: Color(0xFF10B981),
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
                    if (selectedNames.isNotEmpty && enteredBudget > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${provider.tr("Default Target Per Member", "মাথাপিছু নির্ধারিত চাঁদা")}: ${provider.formatMoney(perPerson)} (${_memberCountText(selectedNames.length, provider)})',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    if (provider.savedMembers.isNotEmpty) ...[
                      Text(
                        provider.tr(
                          'Tap to Select from Saved Members:',
                          'সংরক্ষিত তালিকা থেকে সদস্য নির্বাচন করুন:',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.savedMembers.map((m) {
                          final isSel = selectedNames.any(
                                (n) => n.toLowerCase() == m.toLowerCase(),
                          );
                          return FilterChip(
                            label: Text(
                              m,
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF0EA5E9),
                            backgroundColor: const Color(0xFF0F172A),
                            checkmarkColor: Colors.white,
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  if (!isSel) selectedNames.add(m);
                                } else {
                                  selectedNames.removeWhere(
                                        (n) => n.toLowerCase() == m.toLowerCase(),
                                  );
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customMemberCtrl,
                            onChanged: (_) {
                              if (memberInlineError != null) {
                                setSheetState(() => memberInlineError = null);
                              }
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: provider.tr(
                                'Add another member name...',
                                'নতুন সদস্যের নাম যোগ করুন...',
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                              errorText: memberInlineError,
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF334155),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final err = AppValidators.uniqueMemberName(
                              customMemberCtrl.text,
                              selectedNames,
                            );
                            if (err != null) {
                              setSheetState(() => memberInlineError = err);
                              return;
                            }
                            final clean = customMemberCtrl.text.trim();
                            provider.addSavedMember(clean);
                            setSheetState(() {
                              selectedNames.add(clean);
                              memberInlineError = null;
                            });
                            customMemberCtrl.clear();
                          },
                          child: Text(provider.tr('+ Add', '+ যোগ')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                        final title = nameCtrl.text.trim();
                        final bdg = AppCurrency.parseAmount(budgetCtrl.text);
                        if (bdg == null || bdg <= 0) return;

                        final List<GroupMemberModel> memberModels =
                        selectedNames.map((mName) {
                          final matches = existing?.members
                              .where(
                                (em) =>
                            em.name.toLowerCase() ==
                                mName.toLowerCase(),
                          )
                              .toList();
                          if (matches != null && matches.isNotEmpty) {
                            return matches.first;
                          }
                          return GroupMemberModel(
                            id: '${DateTime.now().millisecondsSinceEpoch}_${mName.hashCode}',
                            name: mName,
                            paidAmount: 0.0,
                          );
                        }).toList();

                        provider.saveGroupPlan(
                          id: existing?.id,
                          name: title,
                          totalBudget: bdg,
                          updatedMembers: memberModels,
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          existing == null
                              ? provider.tr(
                            'Group plan created.',
                            'গ্রুপ প্ল্যান তৈরি হয়েছে।',
                          )
                              : provider.tr(
                            'Group plan updated.',
                            'গ্রুপ প্ল্যান আপডেট হয়েছে।',
                          ),
                        );
                      },
                      child: Text(
                        existing == null
                            ? provider.tr('Create Plan', 'প্ল্যান তৈরি করুন')
                            : provider.tr('Save Changes', 'পরিবর্তন সেভ করুন'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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

  // ===========================================================================
  // MODAL 3: ADD OR UPDATE GROUP MEMBER (ZERO DUPLICATES + ADD/SET + CUSTOM SPLIT)
  // ===========================================================================
  void _showMemberDialog(
      BuildContext context,
      GroupModel group, {
        GroupMemberModel? existing,
      }) {
    final provider = context.read<TransactionProvider>();
    final formKey = GlobalKey<FormState>();

    GroupMemberModel? activeExisting = existing;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final paidCtrl = TextEditingController(
      text: existing != null
          ? ((existing.paidAmount - existing.paidAmount.truncateToDouble())
          .abs() >
          0.001
          ? existing.paidAmount.toStringAsFixed(2)
          : existing.paidAmount.toStringAsFixed(0))
          : '',
    );
    final customTargetCtrl = TextEditingController(
      text: existing?.customTarget != null
          ? existing!.customTarget!.toStringAsFixed(0)
          : '',
    );
    bool addToExistingPaid = false;
    bool isSettled = existing?.isSettled ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double targetAmt = activeExisting != null
              ? group.targetForMember(activeExisting!)
              : group.targetPerMember;

          void selectExistingOrDirectoryName(String name) {
            final matchIdx = group.members.indexWhere(
                  (m) => m.name.trim().toLowerCase() == name.trim().toLowerCase(),
            );
            setSheetState(() {
              nameCtrl.text = name;
              if (matchIdx != -1) {
                activeExisting = group.members[matchIdx];
                isSettled = activeExisting!.isSettled;
                addToExistingPaid = true;
                paidCtrl.clear();
                customTargetCtrl.text = activeExisting!.customTarget != null
                    ? activeExisting!.customTarget!.toStringAsFixed(0)
                    : '';
              } else {
                activeExisting = null;
                addToExistingPaid = false;
                paidCtrl.clear();
                customTargetCtrl.clear();
              }
            });
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
                      activeExisting == null
                          ? provider.tr(
                        'Add Member & Contribution',
                        'সদস্য ও চাঁদা যোগ করুন',
                      )
                          : provider.tr(
                        'Update ${activeExisting!.name}\'s Contribution',
                        '${activeExisting!.name}-এর চাঁদা আপডেট করুন',
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
                      activeExisting != null
                          ? '${provider.tr("Currently Paid", "বর্তমান জমা")}: ${provider.formatMoney(activeExisting!.paidAmount)} • ${provider.tr("Target", "লক্ষ্য")}: ${provider.formatMoney(targetAmt)}'
                          : '${provider.tr("Default Target Per Member", "মাথাপিছু নির্ধারিত চাঁদা")}: ${provider.formatMoney(targetAmt)}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // QUICK-PICK EXISTING GROUP MEMBERS OR SAVED DIRECTORY (NO DUPLICATES!)
                    if (existing == null &&
                        (group.members.isNotEmpty ||
                            provider.savedMembers.isNotEmpty)) ...[
                      Text(
                        provider.tr(
                          'Tap an existing member to update them, or pick from directory:',
                          'বিদ্যমান সদস্য আপডেট করতে অথবা তালিকা থেকে নির্বাচন করতে ট্যাপ করুন:',
                        ),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: {
                          ...group.members.map((m) => m.name),
                          ...provider.savedMembers,
                        }.map((mName) {
                          final inGroup = group.members.any(
                                (m) => m.name.toLowerCase() == mName.toLowerCase(),
                          );
                          final isSelected =
                              nameCtrl.text.trim().toLowerCase() ==
                                  mName.toLowerCase();
                          return ChoiceChip(
                            label: Text(
                              inGroup ? '$mName • In Group' : mName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFE2E8F0),
                                fontSize: 11,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0EA5E9),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) =>
                                selectExistingOrDirectoryName(mName),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: nameCtrl,
                      validator: (v) => AppValidators.uniqueMemberName(
                        v,
                        group.members.map((m) => m.name),
                        editingOriginalName: activeExisting?.name,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr('Member Name *', 'সদস্যের নাম *'),
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

                    // CLEAR ADD VS OVERWRITE MODE WHEN UPDATING AN EXISTING MEMBER
                    if (activeExisting != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  provider.tr('Set Total Paid', 'মোট জমা সেট'),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                              selected: !addToExistingPaid,
                              selectedColor: const Color(0xFF0EA5E9),
                              labelStyle: TextStyle(
                                color: !addToExistingPaid
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: const Color(0xFF0F172A),
                              showCheckmark: false,
                              onSelected: (_) => setSheetState(() {
                                addToExistingPaid = false;
                                paidCtrl.text = activeExisting!.paidAmount
                                    .toStringAsFixed(0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  provider.tr(
                                    '+ Add Installment',
                                    '+ নতুন জমা যোগ',
                                  ),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                              selected: addToExistingPaid,
                              selectedColor: const Color(0xFF10B981),
                              labelStyle: TextStyle(
                                color: addToExistingPaid
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: const Color(0xFF0F172A),
                              showCheckmark: false,
                              onSelected: (_) => setSheetState(() {
                                addToExistingPaid = true;
                                paidCtrl.clear();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: AppValidators.amountFormatters,
                            validator: (v) => AppValidators.nonNegativeAmount(
                              v,
                              label: provider.tr('Amount', 'পরিমাণ'),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: addToExistingPaid
                                  ? provider.tr(
                                'Amount to Add (${provider.currencySymbol})',
                                'অতিরিক্ত জমার পরিমাণ (${provider.currencySymbol})',
                              )
                                  : provider.tr(
                                'Total Paid Amount (${provider.currencySymbol})',
                                'মোট জমা দেওয়া টাকা (${provider.currencySymbol})',
                              ),
                              labelStyle:
                              const TextStyle(color: Color(0xFF94A3B8)),
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
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF10B981).withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                          ),
                          onPressed: () {
                            final double fillVal = addToExistingPaid &&
                                activeExisting != null
                                ? group.memberDue(activeExisting!)
                                : targetAmt;
                            setSheetState(
                                  () => paidCtrl.text = fillVal.toStringAsFixed(0),
                            );
                          },
                          child: Text(
                            addToExistingPaid
                                ? provider.tr('Fill Due', 'বাকি পূরণ')
                                : provider.tr('Full Target', 'পূর্ণ চাঁদা'),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // OPTIONAL UNEQUAL / CUSTOM SPLIT TARGET PER MEMBER
                    TextFormField(
                      controller: customTargetCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.nonNegativeAmount(
                        v,
                        label: provider.tr('Custom target', 'কাস্টম লক্ষ্য'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Custom Split Target (Optional — blank = equal split)',
                          'কাস্টম চাঁদা (ঐচ্ছিক — খালি রাখলে সমান ভাগ)',
                        ),
                        labelStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
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

                    if (activeExisting != null) ...[
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF10B981),
                        title: Text(
                          provider.tr(
                            'Mark Member as Settled',
                            'সদস্যকে নিষ্পত্তি হিসেবে চিহ্নিত করুন',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        value: isSettled,
                        onChanged: (v) => setSheetState(() => isSettled = v),
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (activeExisting != null) ...[
                          IconButton(
                            tooltip: provider.tr('Remove Member', 'সদস্য মুছুন'),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () async {
                              final ok = await AppFeedback.confirmDelete(
                                context,
                                title: provider.tr(
                                  'Remove ${activeExisting!.name}?',
                                  '${activeExisting!.name}-কে মুছবেন?',
                                ),
                                message: provider.tr(
                                  'Remove this member from "${group.name}"?',
                                  '"${group.name}" থেকে এই সদস্যকে মুছে ফেলবেন?',
                                ),
                              );
                              if (!ok || !ctx.mounted) return;
                              provider.deleteGroupMember(
                                groupId: group.id,
                                memberId: activeExisting!.id,
                              );
                              Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false)) {
                                return;
                              }
                              final name = nameCtrl.text.trim();
                              final paid =
                                  AppCurrency.parseAmount(paidCtrl.text) ?? 0.0;
                              final double? customTarget =
                              customTargetCtrl.text.trim().isEmpty
                                  ? null
                                  : AppCurrency.parseAmount(
                                customTargetCtrl.text,
                              );

                              provider.saveGroupMember(
                                groupId: group.id,
                                memberId: activeExisting?.id,
                                name: name,
                                paidAmount: paid,
                                customTarget: customTarget,
                                isSettled: isSettled,
                                addToExistingPaid:
                                activeExisting != null && addToExistingPaid,
                              );
                              Navigator.pop(ctx);
                              AppFeedback.showInfo(
                                context,
                                activeExisting == null
                                    ? provider.tr(
                                  '$name added to group.',
                                  '$name গ্রুপে যুক্ত হয়েছে।',
                                )
                                    : provider.tr(
                                  '$name updated.',
                                  '$name আপডেট হয়েছে।',
                                ),
                              );
                            },
                            child: Text(
                              activeExisting == null
                                  ? provider.tr('Save Member', 'সদস্য সেভ করুন')
                                  : provider.tr(
                                'Update Member',
                                'সদস্য আপডেট করুন',
                              ),
                              style:
                              const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  // ===========================================================================
  // MODAL 4: RECORD GROUP EXPENSE (WITH WARNING BANNER + RECEIPT THUMBNAIL)
  // ===========================================================================
  void _showGroupExpenseSheet(
      BuildContext context,
      GroupModel group, {
        GroupExpenseModel? existing,
      }) {
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
    String paidById = existing?.paidByMemberId ?? 'pool';
    String paidByName = existing?.paidByMemberName ?? 'Group Pool';
    bool creditMemberPaid = false;
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
          final double maxBudgetRem =
              group.budgetRemaining + (existing?.amount ?? 0.0);
          final double enteredAmt =
              AppCurrency.parseAmount(amtCtrl.text) ?? 0.0;
          final bool overBudget = enteredAmt > maxBudgetRem;

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
                        'Log Shared Expense & Receipt',
                        'গ্রুপের খরচ ও রসিদ যোগ করুন',
                      )
                          : provider.tr(
                        'Edit Group Expense',
                        'গ্রুপের খরচ এডিট করুন',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: overBudget
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: overBudget
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Text(
                        overBudget
                            ? provider.tr(
                          'Note: Exceeds planned budget by ${provider.formatMoney(enteredAmt - maxBudgetRem)}. Any pool shortfall will be assigned in Settle Up.',
                          'নোট: নির্ধারিত বাজেটের চেয়ে ${provider.formatMoney(enteredAmt - maxBudgetRem)} বেশি। ঘাটতি টাকা নিষ্পত্তিতে ভাগ হয়ে যাবে।',
                        )
                            : '${provider.tr("Budget Remaining", "অবশিষ্ট বাজেট")}: ${provider.formatMoney(maxBudgetRem)} • ${provider.tr("Cash Pool", "তহবিল")}: ${provider.formatMoney(group.poolBalanceLeft)}',
                        style: TextStyle(
                          color: overBudget
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF10B981),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtrl,
                      validator: (v) => AppValidators.requiredText(
                        v,
                        provider.tr('Expense description', 'খরচের বিবরণ'),
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Expense Description (e.g., Hotel / Bus) *',
                          'খরচের বিবরণ *',
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
                      controller: amtCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) => AppValidators.positiveAmount(
                        v,
                        label: provider.tr('Expense amount', 'খরচের পরিমাণ'),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: provider.tr(
                          'Expense Amount (${provider.currencySymbol}) *',
                          'খরচের পরিমাণ (${provider.currencySymbol}) *',
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
                    Text(
                      provider.tr('Paid By:', 'কে পরিশোধ করেছে:'),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            provider.tr('Group Cash Pool', 'গ্রুপ তহবিল'),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: paidById == 'pool',
                          selectedColor: const Color(0xFF0EA5E9),
                          labelStyle: TextStyle(
                            color: paidById == 'pool'
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() {
                            paidById = 'pool';
                            paidByName = 'Group Pool';
                          }),
                        ),
                        ...group.members.map((m) {
                          final isSel = paidById == m.id;
                          return ChoiceChip(
                            label: Text(
                              m.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF0EA5E9),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                            backgroundColor: const Color(0xFF0F172A),
                            showCheckmark: false,
                            onSelected: (_) => setSheetState(() {
                              paidById = m.id;
                              paidByName = m.name;
                            }),
                          );
                        }),
                      ],
                    ),
                    if (existing == null && paidById != 'pool') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF10B981),
                        title: Text(
                          provider.tr(
                            'Credit this amount to $paidByName\'s Paid Contribution',
                            'এই টাকা $paidByName-এর জমা চাঁদায় যোগ করুন',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        value: creditMemberPaid,
                        onChanged: (v) =>
                            setSheetState(() => creditMemberPaid = v),
                      ),
                    ],
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: attBase64.isNotEmpty
                              ? const Color(0xFF10B981)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (attBase64.isNotEmpty)
                            GestureDetector(
                              onTap: () => AttachmentHelper.viewAttachment(
                                context,
                                attBase64,
                                attName,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: buildTrueColorWrapper(
                                  isDarkMode: provider.isDarkMode,
                                  child: Image.memory(
                                    base64Decode(attBase64),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.attach_file,
                              color: Color(0xFF38BDF8),
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attName.isEmpty
                                  ? provider.tr(
                                'Attach Bill / Receipt Photo',
                                'খরচের রসিদ যুক্ত করুন',
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
                          TextButton.icon(
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
                            icon: const Icon(
                              Icons.upload_file,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                            label: Text(
                              attBase64.isEmpty
                                  ? provider.tr('Upload', 'আপলোড')
                                  : provider.tr('Change', 'বদলান'),
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
                        final title = titleCtrl.text.trim();
                        final amt = AppCurrency.parseAmount(amtCtrl.text);
                        if (amt == null || amt <= 0) return;
                        provider.saveGroupExpense(
                          groupId: group.id,
                          expenseId: existing?.id,
                          title: title,
                          amount: amt,
                          paidByMemberId: paidById,
                          paidByMemberName: paidByName,
                          creditMemberPaidAmount: creditMemberPaid,
                          attachmentBase64: attBase64,
                          attachmentName: attName,
                        );
                        Navigator.pop(ctx);
                        AppFeedback.showInfo(
                          context,
                          provider.tr(
                            'Group expense saved.',
                            'গ্রুপ খরচ সেভ হয়েছে।',
                          ),
                        );
                      },
                      child: Text(
                        provider.tr('Save Shared Expense', 'খরচ সেভ করুন'),
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

  // ===========================================================================
  // MODAL 5: 4-TAB INTERACTIVE GROUP WORKSPACE (ALIGNED CHARTS, NO CLIPPING)
  // ===========================================================================
  void _openFullGroupWorkspaceModal(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (context, scrollCtrl) => Consumer<TransactionProvider>(
          builder: (context, provider, _) {
            final idx = provider.groups.indexWhere((g) => g.id == groupId);
            if (idx == -1) return const SizedBox();
            final group = provider.groups[idx];
            final settlements = group.computeSettlements();

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${provider.tr("Budget", "বাজেট")}: ${provider.formatMoney(group.totalBudget)} • ${provider.tr("Spent", "খরচ")}: ${provider.formatMoney(group.totalSpent)}',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Export PDF Statement',
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Color(0xFF38BDF8),
                          ),
                          onPressed: () =>
                              _exportGroupPdfReport(group, provider),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    labelColor: const Color(0xFF38BDF8),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorColor: const Color(0xFF0EA5E9),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    tabs: [
                      Tab(text: provider.tr('Charts', 'চার্ট')),
                      Tab(
                        text:
                        '${provider.tr("Members", "সদস্য")} (${group.memberCount})',
                      ),
                      Tab(
                        text:
                        '${provider.tr("Expenses", "খরচ")} (${group.expenses.length})',
                      ),
                      Tab(text: provider.tr('Settle Up', 'নিষ্পত্তি')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: ALIGNED CHARTS & OVERPAYMENT-AWARE MEMBER BARS
                        ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Column(
                                children: [
                                  // Center metric ("Plan Budget") now matches the ring denominator!
                                  RealisticDonutChart(
                                    values: [
                                      group.totalSpent,
                                      group.budgetRemaining > 0
                                          ? group.budgetRemaining
                                          : 0.0,
                                    ],
                                    colors: const [
                                      Color(0xFFEF4444),
                                      Color(0xFF10B981),
                                    ],
                                    labels: [
                                      '${provider.tr("Spent", "মোট খরচ")} (${provider.formatMoney(group.totalSpent)})',
                                      '${provider.tr("Remaining", "বাকি বাজেট")} (${provider.formatMoney(group.budgetRemaining > 0 ? group.budgetRemaining : 0)})',
                                    ],
                                    centerTitle:
                                    provider.tr('Plan Budget', 'মোট বাজেট'),
                                    centerValue:
                                    provider.formatMoney(group.totalBudget),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: Color(0xFF334155),
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${provider.tr("Collected Pool", "সংগৃহীত তহবিল")}: ${provider.formatMoney(group.totalCollected)}',
                                        style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        group.poolShortfall > 0
                                            ? '${provider.tr("Pool Shortfall", "ঘাটতি")}: ${provider.formatMoney(group.poolShortfall)}'
                                            : '${provider.tr("Pool Left", "তহবিল বাকি")}: ${provider.formatMoney(group.poolBalanceLeft)}',
                                        style: TextStyle(
                                          color: group.poolShortfall > 0
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF38BDF8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.tr(
                                'Member Contributions vs Target',
                                'সদস্যদের জমা বনাম নির্ধারিত চাঁদা',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...group.members.map((m) {
                              final double target = group.targetForMember(m);
                              final double credit = group.memberCredit(m);
                              final double ratio = target > 0
                                  ? (m.paidAmount / target).clamp(0.0, 1.0)
                                  : 0.0;
                              final String rightLabel = credit > 0
                                  ? '${provider.formatMoney(m.paidAmount)} / ${provider.formatMoney(target)} (+${provider.formatMoney(credit)} ${provider.tr("Credit", "অগ্রিম")})'
                                  : '${provider.formatMoney(m.paidAmount)} / ${provider.formatMoney(target)} (${(ratio * 100).toStringAsFixed(0)}%)';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          rightLabel,
                                          style: TextStyle(
                                            color: credit > 0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 7,
                                        backgroundColor:
                                        const Color(0xFF1E293B),
                                        color: ratio >= 1.0
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),

                        // TAB 2: MEMBERS CRUD (EDIT, MARK SETTLED, DELETE)
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            ...group.members.map((m) {
                              final double target = group.targetForMember(m);
                              final double due = group.memberDue(m);
                              final double credit = group.memberCredit(m);
                              final double net =
                                  m.paidAmount - group.spentPerMember;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: m.isSettled
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          provider.formatMoney(
                                            net,
                                            showPlusSign: true,
                                          ),
                                          style: TextStyle(
                                            color: net >= 0
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${provider.tr("Paid", "জমা")}: ${provider.formatMoney(m.paidAmount)} • ${provider.tr("Target", "লক্ষ্য")}: ${provider.formatMoney(target)} • ${credit > 0 ? "${provider.tr("Credit", "অগ্রিম")}: +${provider.formatMoney(credit)}" : "${provider.tr("Due", "বাকি")}: ${provider.formatMoney(due)}"}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: m.isSettled
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF94A3B8),
                                            side: BorderSide(
                                              color: m.isSettled
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF334155),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () => provider
                                              .toggleGroupMemberSettled(
                                            groupId: group.id,
                                            memberId: m.id,
                                          ),
                                          icon: Icon(
                                            m.isSettled
                                                ? Icons.check_circle
                                                : Icons.check_circle_outline,
                                            size: 14,
                                          ),
                                          label: Text(
                                            m.isSettled
                                                ? provider.tr(
                                              'Settled',
                                              'নিষ্পত্তিকৃত',
                                            )
                                                : provider.tr(
                                              'Mark Settled',
                                              'নিষ্পত্তি চিহ্নিত',
                                            ),
                                            style:
                                            const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                            const Color(0xFF38BDF8),
                                            side: const BorderSide(
                                              color: Color(0xFF334155),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () => _showMemberDialog(
                                            context,
                                            group,
                                            existing: m,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 14,
                                          ),
                                          label: Text(
                                            provider.tr('Edit', 'এডিট'),
                                            style:
                                            const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                            const Color(0xFFEF4444),
                                            side: const BorderSide(
                                              color: Color(0xFF334155),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () async {
                                            final ok =
                                            await AppFeedback.confirmDelete(
                                              context,
                                              title: provider.tr(
                                                'Remove ${m.name}?',
                                                '${m.name}-কে মুছবেন?',
                                              ),
                                              message: provider.tr(
                                                'Remove ${m.name} from "${group.name}"?',
                                                '"${group.name}" থেকে ${m.name}-কে মুছে ফেলবেন?',
                                              ),
                                            );
                                            if (ok) {
                                              provider.deleteGroupMember(
                                                groupId: group.id,
                                                memberId: m.id,
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 14,
                                          ),
                                          label: Text(
                                            provider.tr('Remove', 'মুছুন'),
                                            style:
                                            const TextStyle(fontSize: 11),
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

                        // TAB 3: EXPENSES & ATTACHED RECEIPTS CRUD
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (group.expenses.isEmpty)
                              Center(
                                child: Text(
                                  provider.tr(
                                    'No expenses logged yet.',
                                    'এখনো কোনো খরচ যোগ করা হয়নি।',
                                  ),
                                  style:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              )
                            else
                              ...group.expenses.map(
                                    (e) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _showGroupExpenseSheet(
                                      context,
                                      group,
                                      existing: e,
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (e.hasAttachment)
                                          InkWell(
                                            onTap: () =>
                                                AttachmentHelper.viewAttachment(
                                                  context,
                                                  e.attachmentBase64,
                                                  e.attachmentName,
                                                ),
                                            child: Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9)
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                provider.tr('Receipt', 'রসিদ'),
                                                style: const TextStyle(
                                                  color: Color(0xFF38BDF8),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${provider.tr("Paid by", "পরিশোধকারী")}: ${e.paidByMemberName} • ${e.date}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          provider.formatMoney(e.amount),
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFEF4444),
                                            size: 18,
                                          ),
                                          onPressed: () async {
                                            final ok =
                                            await AppFeedback.confirmDelete(
                                              context,
                                              title: provider.tr(
                                                'Delete Expense?',
                                                'খরচ ডিলিট করবেন?',
                                              ),
                                              message: provider.tr(
                                                'Remove "${e.title}" (${provider.formatMoney(e.amount)})?',
                                                '"${e.title}" (${provider.formatMoney(e.amount)}) মুছে ফেলবেন?',
                                              ),
                                            );
                                            if (ok) {
                                              provider.deleteGroupExpense(
                                                groupId: group.id,
                                                expenseId: e.id,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // TAB 4: COMPLETE SETTLEMENT ENGINE (ASSIGNED SHORTFALLS & REFUNDS)
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (group.poolShortfall > 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  provider.tr(
                                    'Pool Shortfall Detected: ${provider.formatMoney(group.totalSpent)} spent against ${provider.formatMoney(group.totalCollected)} collected (${provider.formatMoney(group.poolShortfall)} shortfall assigned below).',
                                    'তহবিল ঘাটতি: ${provider.formatMoney(group.totalCollected)} জমার বিপরীতে ${provider.formatMoney(group.totalSpent)} খরচ হয়েছে (${provider.formatMoney(group.poolShortfall)} ঘাটতি নিচে বণ্টন করা হয়েছে)।',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (settlements.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  provider.tr(
                                    'All members are evenly settled!',
                                    'সকল সদস্যের হিসাব সমানভাবে নিষ্পত্তি হয়েছে!',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              ...settlements.map(
                                    (s) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: s.isPoolTransfer
                                          ? const Color(0xFF0EA5E9)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${s.fromName}  ➔  ${s.toName}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        provider.formatMoney(s.amount),
                                        style: TextStyle(
                                          color: s.isPoolTransfer
                                              ? const Color(0xFF38BDF8)
                                              : const Color(0xFFF59E0B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}