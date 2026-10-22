import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final groups = txProvider.groups;
    final savedMembers = txProvider.savedMembers;

    double allGroupsBudget = 0;
    double allGroupsCollected = 0;
    double allGroupsSpent = 0;

    for (var g in groups) {
      allGroupsBudget += g.totalBudget;
      allGroupsCollected += g.totalCollected;
      allGroupsSpent += g.totalSpent;
    }
    final double allGroupsBudgetRemaining = allGroupsBudget - allGroupsSpent;
    final double allGroupsPoolLeft = allGroupsCollected - allGroupsSpent;
    final double allGroupsStillOwed = (allGroupsBudget - allGroupsCollected) > 0 ? (allGroupsBudget - allGroupsCollected) : 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // 1. MASTER SUMMARY CARD (BUDGET, GIVEN, OWED, SPENT, REMAINING)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Master Group & Trip Overview', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                      child: Text('${groups.length} Active Plans', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatCol('Total Budget', '৳ ${allGroupsBudget.toStringAsFixed(0)}', Colors.white)),
                    Container(width: 1, height: 34, color: Colors.white24),
                    Expanded(child: _buildStatCol('Total Given', '৳ ${allGroupsCollected.toStringAsFixed(0)}', Colors.tealAccent)),
                    Container(width: 1, height: 34, color: Colors.white24),
                    Expanded(child: _buildStatCol('Members Owe', '৳ ${allGroupsStillOwed.toStringAsFixed(0)}', Colors.amberAccent)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                Row(
                  children: [
                    Expanded(child: _buildStatCol('Total Spent', '৳ ${allGroupsSpent.toStringAsFixed(0)}', Colors.orangeAccent)),
                    Container(width: 1, height: 34, color: Colors.white24),
                    Expanded(
                      child: _buildStatCol(
                        'Budget Left',
                        '৳ ${allGroupsBudgetRemaining.toStringAsFixed(0)}',
                        allGroupsBudgetRemaining >= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    Container(width: 1, height: 34, color: Colors.white24),
                    Expanded(
                      child: _buildStatCol(
                        'Cash Pool Left',
                        '৳ ${allGroupsPoolLeft.toStringAsFixed(0)}',
                        allGroupsPoolLeft >= 0 ? Colors.tealAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. DEDICATED SAVED MEMBERS DIRECTORY (ADD / MANAGE MEMBERS MANUALLY)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_alt_rounded, color: Colors.tealAccent, size: 20),
                        SizedBox(width: 8),
                        Text('Saved Members Directory', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showManageDirectoryMemberDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 15),
                      label: const Text('Add Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add friends here manually, then select them in any Budget Plan below.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 12),
                if (savedMembers.isEmpty)
                  const Text('No saved members yet. Tap "+ Add Member".', style: TextStyle(color: Colors.white54, fontSize: 12))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: savedMembers.map((memberName) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showManageDirectoryMemberDialog(context, existingName: memberName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262626),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
                                child: Text(memberName[0].toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(memberName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, color: Colors.white38, size: 12),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. TRIPS & SHARED BUDGET PLANS HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trips & Shared Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton.icon(
                onPressed: () => _showCreateEditGroupSheet(context),
                icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent, size: 18),
                label: const Text('New Plan', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (groups.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.groups_rounded, size: 52, color: Colors.tealAccent),
                  SizedBox(height: 12),
                  Text('No Group or Trip Plans Yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'Tap "Create Trip / Split" below to set a budget, select or add members, and track who gave how much and how the budget is spent.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          ...groups.map((g) => _buildGroupPlanCard(context, g)),
          const SizedBox(height: 90),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => _showCreateEditGroupSheet(context),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create Trip / Split', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCol(String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGroupPlanCard(BuildContext context, GroupModel group) {
    final double progress = group.totalBudget > 0 ? (group.totalSpent / group.totalBudget).clamp(0.0, 1.0) : 0.0;
    final double targetPerPerson = group.targetPerMember;
    final double spentPerPerson = group.spentPerMember;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.tealAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.flight_takeoff_rounded, color: Colors.tealAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 3),
                    Text(
                      '${group.memberCount} Members • Each Should Give: ৳ ${targetPerPerson.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit Plan & Select Members',
                icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                onPressed: () => _showCreateEditGroupSheet(context, existing: group),
              ),
              IconButton(
                tooltip: 'Delete Plan',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => context.read<TransactionProvider>().deleteGroup(group.id),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(group.totalSpent > group.totalBudget ? Colors.redAccent : Colors.tealAccent),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMetric('Plan Budget', '৳ ${group.totalBudget.toStringAsFixed(0)}', Colors.white),
                    _buildMiniMetric('Total Given', '৳ ${group.totalCollected.toStringAsFixed(0)}', Colors.tealAccent),
                    _buildMiniMetric('Still Owed', '৳ ${group.totalOwedToBudget.toStringAsFixed(0)}', Colors.amberAccent),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMetric('Total Spent', '৳ ${group.totalSpent.toStringAsFixed(0)}', Colors.orangeAccent),
                    _buildMiniMetric(
                      'Budget Remaining',
                      '৳ ${group.budgetRemaining.toStringAsFixed(0)}',
                      group.budgetRemaining >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                    _buildMiniMetric(
                      'Cash Left in Pool',
                      '৳ ${group.poolBalanceLeft.toStringAsFixed(0)}',
                      group.poolBalanceLeft >= 0 ? Colors.tealAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Members (Tap person to edit Given ৳):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Spent/Person: ৳ ${spentPerPerson.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (group.members.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'No members in this plan yet. Tap "+ Member" below!',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: group.members.map((m) {
                final double owedToTarget = (targetPerPerson - m.paidAmount) > 0 ? (targetPerPerson - m.paidAmount) : 0;
                final double netLeftFromPaid = m.paidAmount - spentPerPerson;

                return GestureDetector(
                  onTap: () => GroupDetailScreen.showSingleMemberSheet(context, group.id, existing: m, suggestedTarget: targetPerPerson),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                owedToTarget > 0 ? 'Owes to Budget: ৳ ${owedToTarget.toStringAsFixed(0)}' : 'Target Met ✓',
                                style: TextStyle(color: owedToTarget > 0 ? Colors.amberAccent : Colors.greenAccent, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Given: ৳ ${m.paidAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(
                              netLeftFromPaid >= 0
                                  ? 'Left/Gets back: +৳ ${netLeftFromPaid.toStringAsFixed(0)}'
                                  : 'Due vs Spent: -৳ ${netLeftFromPaid.abs().toStringAsFixed(0)}',
                              style: TextStyle(color: netLeftFromPaid >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, color: Colors.white38, size: 15),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          if (group.expenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('How Budget Was Spent:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...group.expenses.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('• ${e.title} (by ${e.paidByMemberName})', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  Text('- ৳ ${e.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showAddOrSelectMembersForPlanSheet(context, group),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('+ Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => GroupDetailScreen.showExpenseSheet(context, group),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('+ Spend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('Full Ledger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  void _showManageDirectoryMemberDialog(BuildContext context, {String? existingName}) {
    final ctrl = TextEditingController(text: existingName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existingName == null ? 'Add Member to Directory' : 'Edit Saved Member', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Member Name (e.g., Asif, Nabil)',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF141414),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          if (existingName != null)
            TextButton(
              onPressed: () {
                context.read<TransactionProvider>().deleteSavedMember(existingName);
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                if (existingName == null) {
                  context.read<TransactionProvider>().addSavedMember(name);
                } else {
                  context.read<TransactionProvider>().updateSavedMember(existingName, name);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddOrSelectMembersForPlanSheet(BuildContext context, GroupModel group) {
    final provider = context.read<TransactionProvider>();
    final manualNameCtrl = TextEditingController();
    final manualPaidCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final latestGroup = context.watch<TransactionProvider>().groups.firstWhere((g) => g.id == group.id, orElse: () => group);
          final savedDirectory = context.watch<TransactionProvider>().savedMembers;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add / Select Members for "${latestGroup.name}"', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text('Tap to Select / Remove from Saved Members:', style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: savedDirectory.map((savedName) {
                      final existingMemberIndex = latestGroup.members.indexWhere((m) => m.name.toLowerCase() == savedName.toLowerCase());
                      final isSelected = existingMemberIndex != -1;

                      return FilterChip(
                        label: Text(savedName, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: Colors.tealAccent,
                        backgroundColor: const Color(0xFF222222),
                        checkmarkColor: Colors.black,
                        onSelected: (selected) {
                          if (selected && !isSelected) {
                            provider.saveGroupMember(groupId: latestGroup.id, name: savedName, paidAmount: 0);
                          } else if (!selected && isSelected) {
                            provider.deleteGroupMember(groupId: latestGroup.id, memberId: latestGroup.members[existingMemberIndex].id);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text('Or Add New Member Manually + Amount Given:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: manualNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Member Name',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: manualPaidCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Given (৳)',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final name = manualNameCtrl.text.trim();
                          final given = double.tryParse(manualPaidCtrl.text.trim()) ?? 0.0;
                          if (name.isNotEmpty) {
                            provider.saveGroupMember(groupId: latestGroup.id, name: name, paidAmount: given);
                            manualNameCtrl.clear();
                            manualPaidCtrl.clear();
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateEditGroupSheet(BuildContext context, {GroupModel? existing}) {
    final provider = context.read<TransactionProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final budgetCtrl = TextEditingController(text: existing != null ? existing.totalBudget.toStringAsFixed(0) : '');
    final manualMemberNameCtrl = TextEditingController();
    final manualMemberPaidCtrl = TextEditingController();

    List<GroupMemberModel> tempMembers = existing != null ? List<GroupMemberModel>.from(existing.members) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final savedDirectory = context.watch<TransactionProvider>().savedMembers;
          final double currentBudget = double.tryParse(budgetCtrl.text.trim()) ?? 0;
          final double targetPerPerson = tempMembers.isNotEmpty ? (currentBudget / tempMembers.length) : 0;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Create Trip / Split Plan' : 'Edit "${existing.name}" Plan & Members',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Plan Name (e.g., Tour, Company Hosting)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.card_travel, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Total Plan Budget (e.g., 25000)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1. Select from Saved Members:', style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(
                        '${tempMembers.length} Selected • ৳ ${targetPerPerson.toStringAsFixed(0)}/person',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: savedDirectory.map((savedName) {
                      final isSelected = tempMembers.any((m) => m.name.toLowerCase() == savedName.toLowerCase());
                      return FilterChip(
                        label: Text(savedName, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: Colors.tealAccent,
                        backgroundColor: const Color(0xFF222222),
                        checkmarkColor: Colors.black,
                        onSelected: (val) {
                          setSheetState(() {
                            if (val && !isSelected) {
                              tempMembers.add(GroupMemberModel(id: '${DateTime.now().millisecondsSinceEpoch}_${tempMembers.length}', name: savedName, paidAmount: 0));
                            } else if (!val && isSelected) {
                              tempMembers.removeWhere((m) => m.name.toLowerCase() == savedName.toLowerCase());
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('2. Or Add Member Manually + Money Given:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: manualMemberNameCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Name',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: manualMemberPaidCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Given ৳',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final mName = manualMemberNameCtrl.text.trim();
                          final mPaid = double.tryParse(manualMemberPaidCtrl.text.trim()) ?? 0.0;
                          if (mName.isNotEmpty) {
                            setSheetState(() {
                              final existingIdx = tempMembers.indexWhere((m) => m.name.toLowerCase() == mName.toLowerCase());
                              if (existingIdx != -1) {
                                tempMembers[existingIdx] = GroupMemberModel(id: tempMembers[existingIdx].id, name: mName, paidAmount: mPaid);
                              } else {
                                tempMembers.add(GroupMemberModel(id: '${DateTime.now().millisecondsSinceEpoch}_${tempMembers.length}', name: mName, paidAmount: mPaid));
                              }
                              manualMemberNameCtrl.clear();
                              manualMemberPaidCtrl.clear();
                            });
                          }
                        },
                        child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (tempMembers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tempMembers.length,
                        itemBuilder: (context, idx) {
                          final m = tempMembers[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('Given: ৳ ${m.paidAmount.toStringAsFixed(0)} • Target: ৳ ${targetPerPerson.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => setSheetState(() => tempMembers.removeAt(idx)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0.0;
                      if (name.isEmpty) return;

                      if (manualMemberNameCtrl.text.trim().isNotEmpty) {
                        tempMembers.add(
                          GroupMemberModel(
                            id: '${DateTime.now().millisecondsSinceEpoch}_auto',
                            name: manualMemberNameCtrl.text.trim(),
                            paidAmount: double.tryParse(manualMemberPaidCtrl.text.trim()) ?? 0.0,
                          ),
                        );
                      }

                      provider.saveGroupPlan(
                        id: existing?.id,
                        name: name,
                        totalBudget: budget,
                        updatedMembers: tempMembers,
                      );
                      Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Save Plan & Members' : 'Update Plan & Members', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
// DETAILED GROUP / TRIP LEDGER SCREEN (FULL BREAKDOWN)
// =============================================================================
class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final groupIndex = provider.groups.indexWhere((g) => g.id == groupId);

    if (groupIndex == -1) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(backgroundColor: const Color(0xFF121212)),
        body: const Center(child: Text('Group not found', style: TextStyle(color: Colors.white))),
      );
    }

    final group = provider.groups[groupIndex];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('${group.memberCount} Members • Created ${group.createdAt}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Members (Given & Owed)'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'How Budget is Spent'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopStat('Total Budget', '৳ ${group.totalBudget.toStringAsFixed(0)}', Colors.white),
                      _buildTopStat('Target / Person', '৳ ${group.targetPerMember.toStringAsFixed(0)}', Colors.tealAccent),
                      _buildTopStat('Total Given', '৳ ${group.totalCollected.toStringAsFixed(0)}', Colors.greenAccent),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(color: Colors.white12, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopStat('Total Spent', '৳ ${group.totalSpent.toStringAsFixed(0)}', Colors.orangeAccent),
                      _buildTopStat(
                        'Budget Remaining',
                        '৳ ${group.budgetRemaining.toStringAsFixed(0)}',
                        group.budgetRemaining >= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                      _buildTopStat(
                        'Cash Pool Left',
                        '৳ ${group.poolBalanceLeft.toStringAsFixed(0)}',
                        group.poolBalanceLeft >= 0 ? Colors.tealAccent : Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMembersTab(context, group),
                  _buildExpensesTab(context, group),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMembersTab(BuildContext context, GroupModel group) {
    final targetPerPerson = group.targetPerMember;
    final spentPerPerson = group.spentPerMember;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: group.members.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No members yet. Tap "+ Add Member" below!', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: group.members.length,
        itemBuilder: (ctx, i) {
          final m = group.members[i];
          final double individualLeftFromPaid = m.paidAmount - spentPerPerson;
          final double dueToTarget = targetPerPerson - m.paidAmount;

          String settlementText;
          Color settlementColor;
          if (individualLeftFromPaid > 0.5) {
            settlementText = 'Gets back / Has left from Given: +৳ ${individualLeftFromPaid.toStringAsFixed(0)}';
            settlementColor = Colors.greenAccent;
          } else if (individualLeftFromPaid < -0.5) {
            settlementText = 'Owes for Expenses (Spent > Given): -৳ ${individualLeftFromPaid.abs().toStringAsFixed(0)}';
            settlementColor = Colors.redAccent;
          } else {
            settlementText = 'Settled up with current spending';
            settlementColor = Colors.grey;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                      child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            dueToTarget > 0
                                ? 'Owes to Budget Target: ৳ ${dueToTarget.toStringAsFixed(0)} (of ৳ ${targetPerPerson.toStringAsFixed(0)})'
                                : (dueToTarget < 0
                                ? 'Gave ৳ ${dueToTarget.abs().toStringAsFixed(0)} extra above target'
                                : 'Met full target share (৳ ${targetPerPerson.toStringAsFixed(0)})'),
                            style: TextStyle(
                              color: dueToTarget > 0 ? Colors.amberAccent : Colors.tealAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                      onPressed: () => showSingleMemberSheet(context, group.id, existing: m, suggestedTarget: targetPerPerson),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => context.read<TransactionProvider>().deleteGroupMember(groupId: group.id, memberId: m.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMemberCell('Given', '৳ ${m.paidAmount.toStringAsFixed(0)}', Colors.tealAccent),
                      _buildMemberCell('Owes Target', '৳ ${(dueToTarget > 0 ? dueToTarget : 0).toStringAsFixed(0)}', Colors.amberAccent),
                      _buildMemberCell('Spent Share', '৳ ${spentPerPerson.toStringAsFixed(0)}', Colors.orangeAccent),
                      _buildMemberCell(
                        'Money Left',
                        '${individualLeftFromPaid >= 0 ? '+' : ''}৳ ${individualLeftFromPaid.toStringAsFixed(0)}',
                        individualLeftFromPaid >= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(settlementText, style: TextStyle(color: settlementColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                        foregroundColor: Colors.tealAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => showSingleMemberSheet(context, group.id, existing: m, suggestedTarget: targetPerPerson),
                      icon: const Icon(Icons.payments_outlined, size: 15),
                      label: const Text('Update Given', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => showSingleMemberSheet(context, group.id, suggestedTarget: targetPerPerson),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMemberCell(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildExpensesTab(BuildContext context, GroupModel group) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: group.expenses.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No group expenses recorded yet. Tap "+ Spend Budget" below!', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: group.expenses.length,
        itemBuilder: (ctx, i) {
          final exp = group.expenses[i];
          final perPersonCost = group.memberCount > 0 ? (exp.amount / group.memberCount) : exp.amount;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: ListTile(
              onTap: () => showExpenseSheet(context, group, existing: exp),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long, color: Colors.orangeAccent),
              ),
              title: Text(exp.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Paid by: ${exp.paidByMemberName} • ৳ ${perPersonCost.toStringAsFixed(0)}/person\n${exp.date}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('- ৳ ${exp.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => context.read<TransactionProvider>().deleteGroupExpense(groupId: group.id, expenseId: exp.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.black,
        onPressed: () => showExpenseSheet(context, group),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Spend Budget', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  static void showSingleMemberSheet(BuildContext context, String groupId, {GroupMemberModel? existing, required double suggestedTarget}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final paidCtrl = TextEditingController(text: existing != null ? existing.paidAmount.toStringAsFixed(0) : '');

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
            Text(
              existing == null ? 'Add Member & Money Given' : 'Update ${existing.name}\'s Contribution',
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Member Name (e.g., Rifat)',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.tealAccent),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paidCtrl,
              keyboardType: TextInputType.number,
              autofocus: existing != null,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Total Amount Given (৳)',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.payments_outlined, color: Colors.tealAccent),
                suffixIcon: suggestedTarget > 0
                    ? TextButton(
                  onPressed: () => paidCtrl.text = suggestedTarget.toStringAsFixed(0),
                  child: Text('Full ৳${suggestedTarget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  context.read<TransactionProvider>().saveGroupMember(
                    groupId: groupId,
                    memberId: existing?.id,
                    name: name,
                    paidAmount: paid,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(existing == null ? 'Save Member' : 'Save Given Amount', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showExpenseSheet(BuildContext context, GroupModel group, {GroupExpenseModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    String selectedPayerId = existing?.paidByMemberId ?? 'pool';
    String selectedPayerName = existing?.paidByMemberName ?? 'Group Pool';
    bool creditMember = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'Spend from "${group.name}" Budget' : 'Edit Expense',
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What was bought? (e.g., Hotel, Food, Bus)',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.receipt_outlined, color: Colors.orangeAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Amount Spent (৳)',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.orangeAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Who Paid for This Expense?', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Collected Group Pool'),
                      selected: selectedPayerId == 'pool',
                      selectedColor: Colors.tealAccent,
                      labelStyle: TextStyle(color: selectedPayerId == 'pool' ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      backgroundColor: const Color(0xFF1E1E1E),
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() {
                        selectedPayerId = 'pool';
                        selectedPayerName = 'Group Pool';
                      }),
                    ),
                    ...group.members.map((m) {
                      final isSel = selectedPayerId == m.id;
                      return ChoiceChip(
                        label: Text(m.name),
                        selected: isSel,
                        selectedColor: Colors.orangeAccent,
                        labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        backgroundColor: const Color(0xFF1E1E1E),
                        showCheckmark: false,
                        onSelected: (_) => setSheetState(() {
                          selectedPayerId = m.id;
                          selectedPayerName = m.name;
                        }),
                      );
                    }),
                  ],
                ),
                if (existing == null && selectedPayerId != 'pool') ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Colors.tealAccent,
                    title: Text('Add this ৳ to $selectedPayerName\'s Given total?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    subtitle: const Text('Keep ON if they paid out of their own pocket', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    value: creditMember,
                    onChanged: (v) => setSheetState(() => creditMember = v),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (title.isNotEmpty && amt > 0) {
                      context.read<TransactionProvider>().saveGroupExpense(
                        groupId: group.id,
                        expenseId: existing?.id,
                        title: title,
                        amount: amt,
                        paidByMemberId: selectedPayerId,
                        paidByMemberName: selectedPayerName,
                        creditMemberPaidAmount: creditMember,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(existing == null ? 'Save Expense' : 'Update Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}