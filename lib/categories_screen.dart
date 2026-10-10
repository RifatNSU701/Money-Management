import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.tealAccent, labelColor: Colors.tealAccent, unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'Expense Labels'), Tab(text: 'Income Labels')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCategoryList(context, txProvider.expenseCategories, isExpense: true),
                _buildCategoryList(context, txProvider.incomeCategories, isExpense: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, List<String> categories, {required bool isExpense}) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final color = isExpense ? Colors.redAccent : Colors.greenAccent;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: color),
                ),
                title: Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white30, size: 20),
                      onPressed: () => _showAddCategoryDialog(context, isExpense, existingName: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => context.read<TransactionProvider>().deleteCategory(cat, isExpense),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 20, right: 20,
          child: FloatingActionButton(
            backgroundColor: Colors.tealAccent, foregroundColor: Colors.black,
            onPressed: () => _showAddCategoryDialog(context, isExpense),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context, bool isExpense, {String? existingName}) {
    final nameController = TextEditingController(text: existingName);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existingName == null ? 'Add ${isExpense ? "Expense" : "Income"} Label' : 'Edit Label', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Category Name', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  if (existingName != null) {
                    context.read<TransactionProvider>().updateCategory(existingName, nameController.text.trim(), isExpense);
                  } else {
                    context.read<TransactionProvider>().addCategory(nameController.text.trim(), isExpense);
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Label', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}