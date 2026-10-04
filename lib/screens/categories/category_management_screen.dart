import 'package:flutter/material.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Labels', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.tealAccent,
              tabs: [
                Tab(text: 'Expenses'),
                Tab(text: 'Income'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCategoryList(['Food & Drink', 'Shopping', 'Transport', 'Bills', 'Entertainment']),
                  _buildCategoryList(['Salary', 'Freelance', 'Investments', 'Gifts']),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.tealAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildCategoryList(List<String> categories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.category, color: Colors.white),
            ),
            title: Text(categories[index], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () {}),
          ),
        );
      },
    );
  }
}
