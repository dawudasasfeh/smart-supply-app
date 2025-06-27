import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AddChatPage extends StatefulWidget {
  final String role;
  const AddChatPage({super.key, required this.role});

  @override
  State<AddChatPage> createState() => _AddChatPageState();
}

class _AddChatPageState extends State<AddChatPage> {
  List<Map<String, dynamic>> users = [];
  String message = "";
  int? selectedId;
  int myId = 0;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getInt('user_id') ?? 0;
    final result = await ApiService.getAvailableChatPartners(myId, widget.role);
    setState(() => users = result);
  }

  Future<void> startChat() async {
    if (selectedId == null || message.isEmpty) return;
    final receiverRole = widget.role == 'supermarket' ? 'distributor' : 'supermarket';
    await ApiService.startChat(
      senderId: myId,
      receiverId: selectedId!,
      senderRole: widget.role,
      receiverRole: receiverRole,
      message: message,
    );
    if (mounted) Navigator.pop(context);
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Start New Chat"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: selectedId,
              hint: const Text("Select user"),
              isExpanded: true,
              items: users.map<DropdownMenuItem<int>>((user) {
                return DropdownMenuItem<int>(
                  value: user['id'],
                  child: Text(user['name']),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedId = val),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: "Message"),
              onChanged: (val) => message = val,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: startChat,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text("Send"),
            )
          ],
        ),
      ),
    );
  }
}
