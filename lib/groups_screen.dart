import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    // Calculate total amounts based on the database
    double totalOwedToYou = 0;
    double totalYouOwe = 0;
    for (var group in txProvider.groups) {
      if (group.youOwe) {
        totalYouOwe += group.amount;
      } else {
        totalOwedToYou += group.amount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // 1. SPLIT SUMMARY CARD
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF3498DB)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Expanded(child: _buildSummaryText('You Owe', '৳ ${totalYouOwe.toStringAsFixed(0)}', Colors.redAccent)),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(child: _buildSummaryText('You are Owed', '৳ ${totalOwedToYou.toStringAsFixed(0)}', Colors.greenAccent)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. GROUPS LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Groups & Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(
                  onPressed: () => _showAddGroupSheet(context),
                  child: const Text('Add New', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600))
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (txProvider.groups.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No groups yet. Tap Add New.", style: TextStyle(color: Colors.grey)))),

          ...txProvider.groups.map((g) => _buildGroupCard(
              context,
              g.name,
              g.youOwe ? 'You owe: ৳ ${g.amount.toStringAsFixed(0)}' : 'You are owed: ৳ ${g.amount.toStringAsFixed(0)}',
              g.youOwe ? Colors.redAccent : Colors.greenAccent,
              Icons.people,
              Colors.teal,
              g.id
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        onPressed: () => _showAddGroupSheet(context),
        icon: const Icon(Icons.group_add),
        label: const Text('New Split', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryText(String label, String amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(amount, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, String name, String status, Color statusColor, IconData icon, Color avatarColor, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: avatarColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: avatarColor)),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13))),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => context.read<TransactionProvider>().deleteGroup(id),
        ),
        onTap: () => _showAddGroupSheet(context, existingId: id, existingName: name, existingAmount: status.split('৳ ')[1]),
      ),
    );
  }

  void _showAddGroupSheet(BuildContext context, {String? existingId, String? existingName, String? existingAmount}) {
    final nameController = TextEditingController(text: existingName);
    final amountController = TextEditingController(text: existingAmount);
    bool youOwe = true; // Default to 'You Owe'

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existingId == null ? 'Add Group/Friend' : 'Edit Group', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Name (e.g. Office Lunch)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Amount (৳)', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              const SizedBox(height: 16),

              // Toggle for who owes who
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('I Owe Them', style: TextStyle(color: Colors.white)),
                    selected: youOwe, selectedColor: Colors.redAccent.withValues(alpha: 0.3), backgroundColor: const Color(0xFF1E1E1E),
                    onSelected: (val) => setSheetState(() => youOwe = true),
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('They Owe Me', style: TextStyle(color: Colors.white)),
                    selected: !youOwe, selectedColor: Colors.greenAccent.withValues(alpha: 0.3), backgroundColor: const Color(0xFF1E1E1E),
                    onSelected: (val) => setSheetState(() => youOwe = false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    context.read<TransactionProvider>().saveGroup(
                        id: existingId,
                        name: nameController.text.trim(),
                        amount: double.tryParse(amountController.text.trim()) ?? 0,
                        youOwe: youOwe
                    );
                    Navigator.pop(sheetContext);
                  }
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}