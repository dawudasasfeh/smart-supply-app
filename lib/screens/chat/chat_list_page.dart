import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/chat_widgets.dart';
import '../../theme/app_colors.dart';
import 'chat_page.dart';
import 'add_chat_page.dart';

class ChatListPage extends StatefulWidget {
  final String role;
  const ChatListPage({super.key, required this.role});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with WidgetsBindingObserver {
  List<dynamic> chatUsers = [];
  Map<int, bool> onlineUsers = {};
  bool loading = true;
  int myId = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectSocket();
    } else if (state == AppLifecycleState.paused) {
      SocketService.instance.disconnect();
    }
  }

  Future<void> _initializeChat() async {
    await _loadUserData();
    await _connectSocket();
    await _fetchChatPartners();
    _listenToSocketEvents();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    myId = prefs.getInt('user_id') ?? 0;
  }

  Future<void> _connectSocket() async {
    if (!SocketService.instance.isConnected) {
      await SocketService.instance.connect();
    }
  }

  void _listenToSocketEvents() {
    // Listen for online status changes
    SocketService.instance.onlineStatusStream.listen((event) {
      if (mounted) {
        setState(() {
          final userId = event['data']['userId'];
          if (event['type'] == 'online') {
            onlineUsers[userId] = true;
          } else if (event['type'] == 'offline') {
            onlineUsers[userId] = false;
          }
        });
      }
    });

    // Listen for new messages to update chat list
    SocketService.instance.messageStream.listen((message) {
      if (mounted) {
        // Only refresh if the message involves this user and avoid duplicate refreshes
        if ((message['sender_id'] == myId || message['receiver_id'] == myId) && 
            !message.containsKey('isTemp')) {
          // Debounce the refresh to prevent multiple rapid calls
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _fetchChatPartners();
          });
        }
      }
    });
  }

  Future<void> _fetchChatPartners() async {
    try {
      final data = await ApiService.getChatPartners(myId, widget.role);
      if (mounted) {
        setState(() {
          chatUsers = data;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          partnerId: partner['id'],
          partnerName: partner['name'] ?? 'Unknown User',
          partnerRole: _getPartnerRole(),
          myRole: widget.role,
        ),
      ),
    ).then((_) {
      // Refresh chat list when returning from chat
      _fetchChatPartners();
    });
  }

  String _getPartnerRole() {
    switch (widget.role) {
      case 'supermarket':
        return 'distributor';
      case 'distributor':
        return 'supermarket';
      case 'delivery':
        return 'distributor';
      default:
        return 'user';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchChatPartners,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : chatUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchChatPartners,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatUsers.length,
                    itemBuilder: (context, index) {
                      final partner = chatUsers[index];
                      final partnerId = partner['id'];
                      final isOnline = onlineUsers[partnerId] ?? false;
                      
                      return ChatListTile(
                        chat: partner,
                        onTap: () => _openChat(partner),
                        isOnline: isOnline,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddChatPage(role: widget.role),
            ),
          );
          if (result == true) {
            _fetchChatPartners();
          }
        },
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text(
          "New Chat",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "No conversations yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start a new conversation to connect with partners",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddChatPage(role: widget.role),
                ),
              );
              if (result == true) {
                _fetchChatPartners();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("Start New Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
