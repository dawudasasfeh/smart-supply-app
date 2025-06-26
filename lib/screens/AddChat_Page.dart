import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddChatPage extends StatefulWidget {
  final String role; // "supermarket" or "distributor"
  const AddChatPage({super.key, required this.role});

  @override
  State<AddChatPage> createState() => _AddChatPageState();
}

class _AddChatPageState extends State<AddChatPage> {
  int? selectedUserId;
  String message = '';
  List<Map<String, dynamic>> availableUsers = [];
  int myId = 0;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getInt('userId') ?? 0;

    final users = await ApiService.getAvailableChatPartners(myId, widget.role);
    setState(() => availableUsers = users);
  }

  Future<void> startChat() async {
    if (selectedUserId == null || message.trim().isEmpty) return;

    await ApiService.startChat(
      senderId: myId,
      receiverId: selectedUserId!,
      senderRole: widget.role,
      receiverRole: widget.role == 'supermarket' ? 'distributor' : 'supermarket',
      message: message.trim(),
    );

    Navigator.pop(context); // Go back to chat list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start New Chat"), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: selectedUserId,
              items: availableUsers
                  .map((u) => DropdownMenuItem<int>(
                        value: u['id'] as int,
                        child: Text(u['name']),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => selectedUserId = val),
              decoration: const InputDecoration(labelText: "Select User"),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              onChanged: (val) => message = val,
              decoration: const InputDecoration(
                labelText: "Your Message",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: startChat,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text("Send & Start Chat"),
            ),
          ],
        ),
      ),
    );
  }
}
