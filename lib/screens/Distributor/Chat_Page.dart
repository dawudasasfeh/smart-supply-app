// distributor/chat_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class SupplierChatPage extends StatefulWidget {
  final int supermarketId;

  const SupplierChatPage({super.key, required this.supermarketId});

  @override
  State<SupplierChatPage> createState() => _SupplierChatPageState();
}

class _SupplierChatPageState extends State<SupplierChatPage> {
  List<dynamic> messages = [];
  final TextEditingController _controller = TextEditingController();
  int myId = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getInt('user_id') ?? 0;
    await fetchMessages();
  }

  Future<void> fetchMessages() async {
    final result = await ApiService.fetchMessages(myId, widget.supermarketId);
    setState(() => messages = result);
  }

  Future<void> sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    await ApiService.sendMessage(
      senderId: myId,
      receiverId: widget.supermarketId,
      senderRole: 'distributor',
      receiverRole: 'supermarket',
      message: message,
    );

    _controller.clear();
    await fetchMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat with Supermarket"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender_id'] == myId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.deepPurple[200] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(msg['message']),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
