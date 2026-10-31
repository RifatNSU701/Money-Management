import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'providers/transaction_provider.dart';

class PeerSettlementItem {
  final String fromName;
  final String toName;
  final double amount;

  PeerSettlementItem({
    required this.fromName,
    required this.toName,
    required this.amount,
  });
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _searchQuery = '';
  String _planFilter = 'All'; // 'All', 'Under Budget', 'Collection Pending'

  // ===========================================================================
  // GREEDY PEER-TO-PEER SETTLEMENT ENGINE
  // ===========================================================================
  List<PeerSettlementItem> _calculateSettlements(GroupModel group) {
    if (group.members.isEmpty) return [];
    final double share = group.spentPerMember;
    final List<String> debtorNames = [];
    final List<double> debtorAmounts = [];
    final List<String> creditorNames = [];
    final List<double> creditorAmounts = [];

    for (var m in group.members) {
      final double net = m.paidAmount - share;
      if (net < -0.5) {
        debtorNames.add(m.name);
        debtorAmounts.add(net.abs());
      } else if (net > 0.5) {
        creditorNames.add(m.name);
        creditorAmounts.add(net);
      }
    }

    final List<PeerSettlementItem> transfers = [];
    int i = 0;
    int j = 0;

    while (i < debtorNames.length && j < creditorNames.length) {
      final double give = debtorAmounts[i];
      final double receive = creditorAmounts[j];
      final double settled = math.min(give, receive);

      if (settled > 0.5) {
        transfers.add(
          PeerSettlementItem(
            fromName: debtorNames[i],
            toName: creditorNames[j],
            amount: settled,
          ),
        );
      }

      debtorAmounts[i] -= settled;
      creditorAmounts[j] -= settled;

      if (debtorAmounts[i] <= 0.5) i++;
      if (creditorAmounts[j] <= 0.5) j++;
    }

    return transfers;
  }

  // ===========================================================================
  // OFFICIAL PDF GROUP AUDIT & SETTLEMENT REPORT GENERATOR
  // ===========================================================================
  Future<void> _exportGroupPdfReport(GroupModel group, TransactionProvider provider) async {
    try {
      final settlements = _calculateSettlements(group);
      final doc = pw.Document();

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
                    pw.Text('FINBLEND GROUP & TRIP SPLIT STATEMENT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Plan Name: ${group.name}  |  Created: ${group.createdAt}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Text('Members: ${group.memberCount}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
                  'BDT ${group.totalBudget.toStringAsFixed(0)}',
                  'BDT ${group.totalCollected.toStringAsFixed(0)}',
                  'BDT ${group.totalOwedToBudget.toStringAsFixed(0)}',
                  'BDT ${group.totalSpent.toStringAsFixed(0)}',
                  'BDT ${group.budgetRemaining.toStringAsFixed(0)}',
                  'BDT ${group.poolBalanceLeft.toStringAsFixed(0)}',
                ],
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('1. Member Contributions & Net Standing (Target: BDT ${group.targetPerMember.toStringAsFixed(0)} | Spent Share: BDT ${group.spentPerMember.toStringAsFixed(0)})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Member Name', 'Paid Amount', 'Owed to Budget', 'Expense Share', 'Net Balance'],
              data: group.members.map((m) {
                final double owedBudget = math.max(0.0, group.targetPerMember - m.paidAmount);
                final double net = m.paidAmount - group.spentPerMember;
                return [
                  m.name,
                  'BDT ${m.paidAmount.toStringAsFixed(0)}',
                  'BDT ${owedBudget.toStringAsFixed(0)}',
                  'BDT ${group.spentPerMember.toStringAsFixed(0)}',
                  net >= 0 ? '+BDT ${net.toStringAsFixed(0)} (Receives)' : '-BDT ${net.abs().toStringAsFixed(0)} (Owes)',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Text('2. Peer-to-Peer Settlement Plan', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (settlements.isEmpty)
              pw.Text('All members are settled up.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Payer (From)', 'Receiver (To)', 'Settlement Amount'],
                data: settlements.map((s) => [s.fromName, s.toName, 'BDT ${s.amount.toStringAsFixed(0)}']).toList(),
              ),
            pw.SizedBox(height: 18),
            pw.Text('3. Shared Expense & Receipt Audit Log (${group.expenses.length} entries)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (group.expenses.isEmpty)
              pw.Text('No expenses recorded yet.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Expense Title', 'Paid By', 'Date', 'Receipt', 'Amount'],
                data: group.expenses.map((e) => [
                  e.title,
                  e.paidByMemberName,
                  e.date,
                  e.hasAttachment ? 'Attached (${e.attachmentName})' : 'No',
                  'BDT ${e.amount.toStringAsFixed(0)}',
                ]).toList(),
              ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'FinBlend_Group_${group.name}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Export Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final double totalBudgets = provider.groups.fold(0.0, (s, g) => s + g.totalBudget);
    final double totalCollected = provider.groups.fold(0.0, (s, g) => s + g.totalCollected);
    final double totalSpent = provider.groups.fold(0.0, (s, g) => s + g.totalSpent);
    final double totalOwed = provider.groups.fold(0.0, (s, g) => s + g.totalOwedToBudget);

    final filteredGroups = provider.groups.where((g) {
      if (_planFilter == 'Under Budget' && g.budgetRemaining <= 0) return false;
      if (_planFilter == 'Collection Pending' && g.totalOwedToBudget <= 0) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = g.name.toLowerCase().contains(q);
        final matchMember = g.members.any((m) => m.name.toLowerCase().contains(q));
        return matchName || matchMember;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          // ===================================================================
          // 1. HEADER & SAVED MEMBERS DIRECTORY BUTTON
          // ===================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr('Group & Trip Budget Splitting', 'গ্রুপ ও ট্যুর বাজেট স্প্লিটিং'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider.tr(
                        'Manage shared budgets, member contributions, receipts, and auto-settlements.',
                        'যৌথ বাজেট, সদস্যদের চাঁদা, খরচের রসিদ এবং স্বয়ংক্রিয় দেনা-পাওনা পরিচালনা করুন।',
                      ),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showSavedMembersDirectorySheet(context),
                icon: const Icon(Icons.contacts_outlined, size: 16),
                label: Text(
                  '${provider.tr("Saved Members", "সদস্য তালিকা")} (${provider.savedMembers.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ===================================================================
          // 2. GLOBAL GROUP ANALYTICS CHART (DONUT + PLAN COMPARISON BARS)
          // ===================================================================
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
                        provider.tr('Group Pool Collection vs Spending Chart', 'গ্রুপ তহবিল জমা বনাম ব্যয়ের চার্ট'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${provider.groups.length} ${provider.tr("Active Plans", "টি প্ল্যান")}',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RealisticDonutChart(
                  values: [
                    totalCollected > 0 ? totalCollected : (totalBudgets == 0 ? 1 : 0),
                    totalSpent > 0 ? totalSpent : 0,
                    totalOwed > 0 ? totalOwed : 0,
                  ],
                  colors: const [Color(0xFF10B981), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
                  labels: [
                    '${provider.tr("Total Collected", "মোট জমা")} (৳${totalCollected.toStringAsFixed(0)})',
                    '${provider.tr("Total Spent", "মোট খরচ")} (৳${totalSpent.toStringAsFixed(0)})',
                    '${provider.tr("Pending Collection", "বাকি চাঁদা")} (৳${totalOwed.toStringAsFixed(0)})',
                  ],
                  centerTitle: provider.tr('Total Budget', 'মোট বাজেট'),
                  centerValue: '৳${totalBudgets.toStringAsFixed(0)}',
                ),
                if (provider.groups.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Divider(color: Color(0xFF334155), height: 1),
                  ),
                  Text(
                    provider.tr('Plan-by-Plan Budget Utilization Graph', 'প্ল্যান অনুযায়ী বাজেট ব্যবহারের গ্রাফ'),
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...provider.groups.take(4).map((g) {
                    final double spentPct = g.totalBudget > 0 ? (g.totalSpent / g.totalBudget).clamp(0.0, 1.0) : 0.0;
                    final double colPct = g.totalBudget > 0 ? (g.totalCollected / g.totalBudget).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                '${provider.tr("Spent", "খরচ")}: ৳${g.totalSpent.toStringAsFixed(0)} / ৳${g.totalBudget.toStringAsFixed(0)} (${(spentPct * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                              color: spentPct > 0.9 ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
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

          // ===================================================================
          // 3. SEARCH & FILTER BAR
          // ===================================================================
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: provider.tr('Search group plans or member names...', 'গ্রুপের নাম বা সদস্যের নাম দিয়ে খুঁজুন...'),
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
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
              _buildFilterChip('Under Budget', provider.tr('Active Budget', 'বাজেট চলমান')),
              _buildFilterChip('Collection Pending', provider.tr('Collection Due', 'চাঁদা বাকি')),
            ],
          ),
          const SizedBox(height: 16),

          // ===================================================================
          // 4. 6-METRIC EXECUTIVE GROUP CARDS
          // ===================================================================
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
                  const Icon(Icons.groups_2_outlined, color: Color(0xFF38BDF8), size: 44),
                  const SizedBox(height: 10),
                  Text(
                    provider.tr('No Group or Trip Plans Found', 'কোনো গ্রুপ বা ট্যুর প্ল্যান পাওয়া যায়নি'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.tr(
                      'Tap "+ Create Trip / Split Plan" below to set a target budget, add members from your directory, and split shared costs.',
                      'নিচে "+ নতুন গ্রুপ প্ল্যান" বাটনে ট্যাপ করে বাজেট নির্ধারণ করুন এবং সদস্যদের যোগ করুন।',
                    ),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...filteredGroups.map((g) => _buildExecutiveGroupCard(context, g, provider)),
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
      label: Text(label, style: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSel,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: const Color(0xFF1E293B),
      showCheckmark: false,
      onSelected: (_) => setState(() => _planFilter = key),
    );
  }

  Widget _buildExecutiveGroupCard(BuildContext context, GroupModel g, TransactionProvider provider) {
    final double spentRatio = g.totalBudget > 0 ? (g.totalSpent / g.totalBudget).clamp(0.0, 1.0) : 0.0;
    final double collectRatio = g.totalBudget > 0 ? (g.totalCollected / g.totalBudget).clamp(0.0, 1.0) : 0.0;
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
          // TOP TITLE & ACTIONS
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.luggage_outlined, color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${g.memberCount} ${provider.tr("Members", "জন সদস্য")} • ${provider.tr("Target", "মাথাপিছু বাজেট")}: ৳${g.targetPerMember.toStringAsFixed(0)}/person • $receiptCount ${provider.tr("Receipts", "টি রসিদ")}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: provider.tr('Export PDF Statement', 'পিডিএফ রিপোর্ট'),
                icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF38BDF8), size: 19),
                onPressed: () => _exportGroupPdfReport(g, provider),
              ),
              IconButton(
                tooltip: provider.tr('Edit Plan', 'এডিট করুন'),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 19),
                onPressed: () => _showCreateOrEditGroupSheet(context, existing: g),
              ),
              IconButton(
                tooltip: provider.tr('Delete Plan', 'ডিলিট করুন'),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 19),
                onPressed: () => provider.deleteGroup(g.id),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 6-METRIC GRID (2 ROWS X 3 COLUMNS)
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
                        '৳${g.totalBudget.toStringAsFixed(0)}',
                        const Color(0xFF38BDF8),
                      ),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF334155)),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('2. Total Given', '২. মোট জমা'),
                        '৳${g.totalCollected.toStringAsFixed(0)}',
                        const Color(0xFF10B981),
                      ),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF334155)),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('3. Still Owed', '৩. বাকি চাঁদা'),
                        '৳${g.totalOwedToBudget.toStringAsFixed(0)}',
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
                        '৳${g.totalSpent.toStringAsFixed(0)}',
                        const Color(0xFFEF4444),
                      ),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF334155)),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('5. Budget Left', '৫. অবশিষ্ট বাজেট'),
                        '৳${g.budgetRemaining.toStringAsFixed(0)}',
                        g.budgetRemaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    Container(width: 1, height: 30, color: const Color(0xFF334155)),
                    Expanded(
                      child: _buildSixMetricBox(
                        provider.tr('6. Cash Pool Left', '৬. ক্যাশ তহবিল'),
                        '৳${g.poolBalanceLeft.toStringAsFixed(0)}',
                        g.poolBalanceLeft >= 0 ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // DUAL PROGRESS BARS (COLLECTION & SPENDING)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.tr("Collection Progress", "চাঁদা আদায়ের হার")}: ${(collectRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                '${provider.tr("Budget Spent", "বাজেট ব্যয়ের হার")}: ${(spentRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
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
              color: spentRatio > 0.9 ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 12),

          // MEMBER CHIPS PREVIEW
          if (g.members.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: g.members.map((m) {
                final double owed = math.max(0.0, g.targetPerMember - m.paidAmount);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showMemberDialog(context, g, existing: m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: owed <= 0.5 ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${m.name}: ${provider.tr("Paid", "জমা")} ৳${m.paidAmount.toStringAsFixed(0)} ${owed > 0.5 ? "(${provider.tr("Due", "বাকি")} ৳${owed.toStringAsFixed(0)})" : "✓"}',
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showGroupExpenseSheet(context, g),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                label: Text(provider.tr('Log Expense & Receipt', 'খরচ ও রসিদ যোগ'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showMemberDialog(context, g),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                label: Text(provider.tr('Add / Update Member', 'সদস্য ও চাঁদা'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openFullGroupWorkspaceModal(context, g.id),
                icon: const Icon(Icons.analytics_outlined, size: 15),
                label: Text(provider.tr('Full Ledger, Charts & Settle Up', 'পূর্ণাঙ্গ হিসাব, চার্ট ও নিষ্পত্তি'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL 1: SAVED MEMBERS DIRECTORY MANAGER (ADD / RENAME / DELETE)
  // ===========================================================================
  void _showSavedMembersDirectorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<TransactionProvider>(
        builder: (context, provider, _) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.tr('Saved Members Directory', 'সংরক্ষিত সদস্য তালিকা'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Text(
                provider.tr(
                  'Save frequent friends or colleagues here for 1-tap selection when creating any group split.',
                  'বারবার ব্যবহৃত বন্ধু বা সহকর্মীদের নাম এখানে সেভ রাখুন যাতে ১ ট্যাপেই গ্রুপে যুক্ত করতে পারেন।',
                ),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: provider.tr('Enter member name...', 'সদস্যের নাম লিখুন...'),
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        provider.addSavedMember(nameCtrl.text.trim());
                        nameCtrl.clear();
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(provider.tr('Add', 'যোগ করুন')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (provider.savedMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    provider.tr('Directory is empty. Add names above!', 'তালিকা খালি রয়েছে। উপরে নাম লিখে যোগ করুন!'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                          backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          child: Text(mName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(mName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
                              onPressed: () => _showRenameSavedMemberDialog(context, mName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                              onPressed: () => provider.deleteSavedMember(mName),
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
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(provider.tr('Rename Saved Member', 'সদস্যের নাম পরিবর্তন'), style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(provider.tr('Cancel', 'বাতিল'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.updateSavedMember(oldName, ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text(provider.tr('Save', 'সেভ')),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL 2: CREATE OR EDIT GROUP PLAN (WITH SAVED MEMBER QUICK-SELECT)
  // ===========================================================================
  void _showCreateOrEditGroupSheet(BuildContext context, {GroupModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final budgetCtrl = TextEditingController(text: existing != null ? existing.totalBudget.toStringAsFixed(0) : '');
    final customMemberCtrl = TextEditingController();
    final List<String> selectedNames = existing != null ? existing.members.map((m) => m.name).toList() : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double enteredBudget = double.tryParse(budgetCtrl.text.trim()) ?? 0.0;
          final double perPerson = selectedNames.isNotEmpty ? (enteredBudget / selectedNames.length) : 0.0;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? provider.tr('Create Group / Trip Budget Plan', 'নতুন গ্রুপ বা ট্যুর বাজেট প্ল্যান')
                        : provider.tr('Edit Group Budget Plan', 'গ্রুপ প্ল্যান সম্পাদনা করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Plan / Event Title (e.g., Sajek Valley Tour) *', 'প্ল্যান বা ইভেন্টের নাম *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.tour_outlined, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: provider.tr('Total Target Budget (BDT ৳) *', 'মোট নির্ধারিত বাজেট (৳) *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (selectedNames.isNotEmpty && enteredBudget > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.tr("Auto-Calculated Per Member Target", "মাথাপিছু নির্ধারিত চাঁদা")}: ৳${perPerson.toStringAsFixed(0)} (${selectedNames.length} ${provider.tr("members", "জন সদস্য")})',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // QUICK SELECT FROM SAVED DIRECTORY
                  if (provider.savedMembers.isNotEmpty) ...[
                    Text(
                      provider.tr('Tap to Select from Saved Members:', 'সংরক্ষিত তালিকা থেকে সদস্য নির্বাচন করুন:'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.savedMembers.map((m) {
                        final isSel = selectedNames.contains(m);
                        return FilterChip(
                          label: Text(m, style: TextStyle(color: isSel ? Colors.white : const Color(0xFFCBD5E1), fontSize: 12)),
                          selected: isSel,
                          selectedColor: const Color(0xFF0EA5E9),
                          backgroundColor: const Color(0xFF0F172A),
                          checkmarkColor: Colors.white,
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selectedNames.add(m);
                              } else {
                                selectedNames.remove(m);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ADD NEW MEMBER ON THE FLY
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customMemberCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: provider.tr('Add another member name...', 'নতুন সদস্যের নাম যোগ করুন...'),
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white),
                        onPressed: () {
                          final clean = customMemberCtrl.text.trim();
                          if (clean.isNotEmpty && !selectedNames.contains(clean)) {
                            provider.addSavedMember(clean);
                            setSheetState(() => selectedNames.add(clean));
                            customMemberCtrl.clear();
                          }
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final title = nameCtrl.text.trim();
                      final bdg = double.tryParse(budgetCtrl.text.trim()) ?? 0.0;
                      if (title.isEmpty || bdg <= 0) return;

                      final List<GroupMemberModel> memberModels = selectedNames.map((mName) {
                        final existingMember = existing?.members.where((em) => em.name == mName).toList();
                        if (existingMember != null && existingMember.isNotEmpty) {
                          return existingMember.first;
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
                    },
                    child: Text(
                      existing == null
                          ? provider.tr('Create Plan & Sync Cloud', 'প্ল্যান তৈরি করুন')
                          : provider.tr('Save Changes', 'পরিবর্তন সেভ করুন'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL 3: ADD OR EDIT GROUP MEMBER CONTRIBUTION
  // ===========================================================================
  void _showMemberDialog(BuildContext context, GroupModel group, {GroupMemberModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final paidCtrl = TextEditingController(text: existing != null ? existing.paidAmount.toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null
                      ? provider.tr('Add Member & Contribution', 'সদস্য ও চাঁদা যোগ করুন')
                      : provider.tr('Update Member Contribution', 'সদস্যের চাঁদা আপডেট করুন'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${provider.tr("Required Target Per Member", "মাথাপিছু নির্ধারিত চাঁদা")}: ৳${group.targetPerMember.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                if (existing == null && provider.savedMembers.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.savedMembers.map((m) {
                      return ActionChip(
                        label: Text(m, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        backgroundColor: const Color(0xFF0F172A),
                        onPressed: () => setSheetState(() => nameCtrl.text = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: provider.tr('Member Name *', 'সদস্যের নাম *'),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: paidCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: provider.tr('Total Paid / Given Amount (৳)', 'জমা দেওয়া টাকা (৳)'),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15)),
                      onPressed: () => setSheetState(() => paidCtrl.text = group.targetPerMember.toStringAsFixed(0)),
                      child: Text(
                        provider.tr('Full Target', 'পূর্ণ চাঁদা'),
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (existing != null) ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        onPressed: () {
                          provider.deleteGroupMember(groupId: group.id, memberId: existing.id);
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                          if (name.isEmpty) return;
                          provider.saveGroupMember(
                            groupId: group.id,
                            memberId: existing?.id,
                            name: name,
                            paidAmount: paid,
                          );
                          Navigator.pop(ctx);
                        },
                        child: Text(provider.tr('Save Member', 'সদস্য সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // ===========================================================================
  // MODAL 4: RECORD GROUP EXPENSE WITH STRICT BUDGET GUARDRAIL & RECEIPT UPLOAD
  // ===========================================================================
  void _showGroupExpenseSheet(BuildContext context, GroupModel group, {GroupExpenseModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amtCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    String paidById = existing?.paidByMemberId ?? 'pool';
    String paidByName = existing?.paidByMemberName ?? 'Group Pool';
    bool creditMemberPaid = false;
    String attBase64 = existing?.attachmentBase64 ?? '';
    String attName = existing?.attachmentName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double maxAllowed = group.budgetRemaining + (existing?.amount ?? 0.0);
          final double enteredAmt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
          final bool exceedsCeiling = enteredAmt > maxAllowed;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? provider.tr('Log Shared Expense & Receipt', 'গ্রুপের খরচ ও রসিদ যোগ করুন')
                        : provider.tr('Edit Group Expense', 'গ্রুপের খরচ এডিট করুন'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: exceedsCeiling ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: exceedsCeiling ? const Color(0xFFEF4444) : const Color(0xFF334155)),
                    ),
                    child: Text(
                      exceedsCeiling
                          ? provider.tr(
                        '⚠️ Budget Ceiling Guardrail: Cannot exceed remaining budget of ৳${maxAllowed.toStringAsFixed(0)}!',
                        '⚠️ বাজেট সীমা সতর্কতা: অবশিষ্ট বাজেট ৳${maxAllowed.toStringAsFixed(0)} এর বেশি খরচ করা যাবে না!',
                      )
                          : '${provider.tr("Available Plan Budget Remaining", "অবশিষ্ট অনুমোদিত বাজেট")}: ৳${maxAllowed.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: exceedsCeiling ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: provider.tr('Expense Description (e.g., Hotel / Bus Tickets) *', 'খরচের বিবরণ *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: provider.tr('Expense Amount (BDT ৳) *', 'খরচের পরিমাণ (৳) *'),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.tr('Paid By:', 'কে পরিশোধ করেছে:'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(provider.tr('Group Cash Pool', 'গ্রুপ তহবিল'), style: const TextStyle(fontSize: 11)),
                        selected: paidById == 'pool',
                        selectedColor: const Color(0xFF0EA5E9),
                        labelStyle: TextStyle(color: paidById == 'pool' ? Colors.white : const Color(0xFF94A3B8)),
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
                          label: Text(m.name, style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          selectedColor: const Color(0xFF0EA5E9),
                          labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8)),
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
                        provider.tr('Credit this amount to $paidByName\'s Paid Contribution', 'এই টাকা $paidByName-এর জমা চাঁদায় যোগ করুন'),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      value: creditMemberPaid,
                      onChanged: (v) => setSheetState(() => creditMemberPaid = v),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // UPLOAD RECEIPT / MEMO
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attName.isEmpty
                                ? provider.tr('Attach Bill / Receipt (PDF, JPG, PNG)', 'খরচের রসিদ বা মেমো যুক্ত করুন')
                                : attName,
                            style: TextStyle(color: attName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF10B981), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (attBase64.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, color: Color(0xFF38BDF8), size: 18),
                            onPressed: () => AttachmentHelper.viewAttachment(context, attBase64, attName),
                          ),
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
                          icon: const Icon(Icons.upload_file, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(provider.tr('Upload', 'আপলোড'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: exceedsCeiling ? const Color(0xFF475569) : const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: exceedsCeiling
                        ? null
                        : () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty || enteredAmt <= 0) return;
                      provider.saveGroupExpense(
                        groupId: group.id,
                        expenseId: existing?.id,
                        title: title,
                        amount: enteredAmt,
                        paidByMemberId: paidById,
                        paidByMemberName: paidByName,
                        creditMemberPaidAmount: creditMemberPaid,
                        attachmentBase64: attBase64,
                        attachmentName: attName,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(provider.tr('Save Shared Expense', 'খরচ সেভ করুন'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // MODAL 5: 4-TAB INTERACTIVE GROUP WORKSPACE (CHARTS, MEMBERS, EXPENSES, SETTLE UP)
  // ===========================================================================
  void _openFullGroupWorkspaceModal(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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
            final settlements = _calculateSettlements(group);

            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                '${provider.tr("Budget", "বাজেট")}: ৳${group.totalBudget.toStringAsFixed(0)} • ${provider.tr("Spent", "খরচ")}: ৳${group.totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Export PDF Statement',
                          icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF38BDF8)),
                          onPressed: () => _exportGroupPdfReport(group, provider),
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
                    isScrollable: true,
                    tabs: [
                      Tab(text: provider.tr('1. Charts & Analytics', '১. চার্ট ও বিশ্লেষণ')),
                      Tab(text: '${provider.tr("2. Members", "২. সদস্য")} (${group.memberCount})'),
                      Tab(text: '${provider.tr("3. Expenses & Receipts", "৩. খরচ ও রসিদ")} (${group.expenses.length})'),
                      Tab(text: provider.tr('4. Settle Up', '৪. চূড়ান্ত নিষ্পত্তি')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: CHARTS & MEMBER CONTRIBUTION BARS
                        ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: RealisticDonutChart(
                                values: [
                                  group.totalSpent > 0 ? group.totalSpent : 0,
                                  group.budgetRemaining > 0 ? group.budgetRemaining : 1,
                                ],
                                colors: const [Color(0xFFEF4444), Color(0xFF10B981)],
                                labels: [
                                  '${provider.tr("Total Spent", "মোট খরচ")} (৳${group.totalSpent.toStringAsFixed(0)})',
                                  '${provider.tr("Remaining Budget", "বাকি বাজেট")} (৳${group.budgetRemaining.toStringAsFixed(0)})',
                                ],
                                centerTitle: provider.tr('Cash Pool', 'ক্যাশ তহবিল'),
                                centerValue: '৳${group.poolBalanceLeft.toStringAsFixed(0)}',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.tr('Member Contribution vs Target Chart', 'সদস্যদের জমা বনাম নির্ধারিত চাঁদার গ্রাফ'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            ...group.members.map((m) {
                              final double target = group.targetPerMember > 0 ? group.targetPerMember : 1.0;
                              final double pct = (m.paidAmount / target).clamp(0.0, 1.0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(
                                          '৳${m.paidAmount.toStringAsFixed(0)} / ৳${group.targetPerMember.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 7,
                                        backgroundColor: const Color(0xFF1E293B),
                                        color: pct >= 1.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),

                        // TAB 2: MEMBERS CRUD
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            ...group.members.map((m) {
                              final double owed = math.max(0.0, group.targetPerMember - m.paidAmount);
                              final double net = m.paidAmount - group.spentPerMember;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: ListTile(
                                  onTap: () => _showMemberDialog(context, group, existing: m),
                                  title: Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${provider.tr("Given", "জমা")}: ৳${m.paidAmount.toStringAsFixed(0)} • ${provider.tr("Budget Due", "বাজেটে বাকি")}: ৳${owed.toStringAsFixed(0)}\n${provider.tr("Expense Share", "খরচের ভাগ")}: ৳${group.spentPerMember.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    net >= 0 ? '+৳${net.toStringAsFixed(0)}' : '-৳${net.abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
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
                                child: Text(provider.tr('No expenses logged yet.', 'এখনো কোনো খরচ যোগ করা হয়নি।'), style: const TextStyle(color: Color(0xFF94A3B8))),
                              )
                            else
                              ...group.expenses.map((e) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: ListTile(
                                  onTap: () => _showGroupExpenseSheet(context, group, existing: e),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(e.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      if (e.hasAttachment)
                                        InkWell(
                                          onTap: () => AttachmentHelper.viewAttachment(context, e.attachmentBase64, e.attachmentName),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(provider.tr('Receipt', 'রসিদ'), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text('${provider.tr("Paid by", "পরিশোধকারী")}: ${e.paidByMemberName} • ${e.date}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('৳${e.amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
                                        onPressed: () => provider.deleteGroupExpense(groupId: group.id, expenseId: e.id),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                          ],
                        ),

                        // TAB 4: AUTOMATED PEER-TO-PEER SETTLEMENT ENGINE
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (settlements.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                                child: Text(
                                  provider.tr('All members are evenly settled!', 'সকল সদস্যের হিসাব সমানভাবে নিষ্পত্তি হয়েছে!'),
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              ...settlements.map((s) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${s.fromName}  ➔  ${s.toName}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '৳${s.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                              )),
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