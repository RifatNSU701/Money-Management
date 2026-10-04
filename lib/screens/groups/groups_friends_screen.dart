import 'package:flutter/material.dart';
import 'group_details_screen.dart';

class GroupsFriendsScreen extends StatelessWidget {
  const GroupsFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.tealAccent,
            tabs: [
              Tab(text: 'Groups'),
              Tab(text: 'Friends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGroupsTab(context),
                _buildFriendsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.group_add),
          label: const Text('Create New Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent.withValues(alpha: 0.1),
            foregroundColor: Colors.tealAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('My Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _buildGroupCard(context, 'Apartment 4B', 'You owe: ৳ 450', Colors.redAccent, Icons.home, Colors.teal),
        _buildGroupCard(context, 'Cox\'s Bazar Trip', 'You are owed: ৳ 2,100', Colors.greenAccent, Icons.flight, Colors.deepPurple),
      ],
    );
  }

  Widget _buildFriendsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent.withValues(alpha: 0.1),
            foregroundColor: Colors.tealAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Friends List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _buildFriendCard('Rafiq', 'Owes you ৳ 500', Colors.greenAccent),
        _buildFriendCard('Tanvir', 'You owe ৳ 1,200', Colors.redAccent),
        _buildFriendCard('Samira', 'Settled up', Colors.grey),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, String name, String status, Color statusColor, IconData icon, Color bgColor) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: bgColor, child: Icon(icon, color: Colors.white)),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(status, style: TextStyle(color: statusColor)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => GroupDetailsScreen(
            groupName: name,
            groupColor: bgColor,
            groupIcon: icon,
          )));
        },
      ),
    );
  }

  Widget _buildFriendCard(String name, String status, Color statusColor) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.grey.shade800, child: Text(name[0], style: const TextStyle(color: Colors.white))),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(status, style: TextStyle(color: statusColor)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Could navigate to a FriendDetailsScreen similar to GroupDetails
        },
      ),
    );
  }
}
