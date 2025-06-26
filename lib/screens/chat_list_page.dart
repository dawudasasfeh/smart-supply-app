import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'addchat_page.dart';

class ChatListPage extends StatefulWidget {
  final String role; // "supermarket" or "distributor"
  const ChatListPage({super.key, required this.role});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<dynamic> chatUsers = [];
  bool loading = true;
  int myId = 0;

  @override
  void initState() {
    super.initState();
    fetchChatPartners();
  }

  Future<void> fetchChatPartners() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getInt('userId') ?? 0;
    try {
      final data = await ApiService.getChatPartners(myId, widget.role);
      setState(() {
        chatUsers = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chats: $e')),
      );
    }
  }

  void openChat(Map<String, dynamic> partner) {
    if (widget.role == 'supermarket') {
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {'distributorId': partner['id']},
      );
    } else if (widget.role == 'distributor') {
      Navigator.pushNamed(
        context,
        '/supplierChat',
        arguments: {'supermarketId': partner['id']},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.grey[100],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : chatUsers.isEmpty
              ? const Center(child: Text("No chat history yet"))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: chatUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final partner = chatUsers[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(partner['name'] ?? 'User'),
                      subtitle: Text(partner['lastmessage'] ?? 'No messages'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => openChat(partner),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add_comment),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddChatPage(role: widget.role),
            ),
          );
          fetchChatPartners(); // refresh after adding new chat
        },
      ),
    );
  }
}
