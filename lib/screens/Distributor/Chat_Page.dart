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
  final TextEditingController messageController = TextEditingController();
  List<dynamic> messages = [];
  int distributorId = 0;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    final prefs = await SharedPreferences.getInstance();
    distributorId = prefs.getInt('userId') ?? 0;
    final data = await ApiService.fetchMessages(distributorId, widget.supermarketId);
    setState(() => messages = data);
  }

  Future<void> sendMessage() async {
    final msg = messageController.text.trim();
    if (msg.isEmpty) return;

    await ApiService.sendMessage(
      senderId: distributorId,
      receiverId: widget.supermarketId,
      senderRole: 'distributor',
      receiverRole: 'supermarket',
      message: msg,
    );

    messageController.clear();
    _loadChat();
  }

  Widget _messageBubble(Map<String, dynamic> msg) {
    final isMine = msg['sender_id'] == distributorId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? Colors.deepPurple[100] : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 12),
          ),
        ),
        child: Text(msg['message']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with Retailer'), backgroundColor: Colors.deepPurple),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _messageBubble(messages[index]),
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
