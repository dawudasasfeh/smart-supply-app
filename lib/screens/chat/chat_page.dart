import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/chat_widgets.dart';
import '../../theme/app_colors.dart';

class ChatPage extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  final String partnerRole;
  final String myRole;

  const ChatPage({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.partnerRole,
    required this.myRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> messages = [];
  int myId = 0;
  bool isLoading = true;
  bool isPartnerOnline = false;
  bool isPartnerTyping = false;
  Timer? _typingTimer;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectSocket();
    }
  }

  Future<void> _initializeChat() async {
    await _loadUserData();
    await _connectSocket();
    await _fetchMessages();
    _listenToSocketEvents();
    _markAllMessagesAsRead();
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
    // Listen for incoming messages
    SocketService.instance.messageStream.listen((messageData) {
      if (messageData['sender_id'] == widget.partnerId || 
          messageData['receiver_id'] == widget.partnerId) {
        
        // Check for duplicates before adding
        final existingIndex = messages.indexWhere((m) => m['id'] == messageData['id']);
        if (existingIndex == -1) {
          setState(() {
            messages.add(messageData);
          });
          _scrollToBottom();
        }
        
        // Mark message as read if it's from partner
        if (messageData['sender_id'] == widget.partnerId) {
          SocketService.instance.markMessageAsRead(messageData['id']);
        }
      }
    });

    // Listen for message status updates
    SocketService.instance.messageStatusStream.listen((statusData) {
      if (statusData['type'] == 'sent') {
        final messageData = statusData['data'];
        setState(() {
          // Replace temp message with real message
          final tempIndex = messages.indexWhere((m) => 
            m['isTemp'] == true && 
            m['sender_id'] == messageData['sender_id'] &&
            m['message'] == messageData['message']);
          
          if (tempIndex != -1) {
            messages[tempIndex] = {
              ...messageData,
              'isTemp': false,
            };
          }
        });
      } else if (statusData['type'] == 'error') {
        // Handle message send error - remove temp message or mark as failed
        setState(() {
          messages.removeWhere((m) => m['isTemp'] == true);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (statusData['type'] == 'read') {
        final messageData = statusData['data'];
        setState(() {
          final index = messages.indexWhere((m) => m['id'] == messageData['messageId']);
          if (index != -1) {
            messages[index]['read'] = true;
          }
        });
      }
    });

    // Listen for typing indicators
    SocketService.instance.typingStream.listen((typingData) {
      if (mounted && typingData['userId'] == widget.partnerId) {
        setState(() {
          isPartnerTyping = typingData['isTyping'];
        });
      }
    });

    // Listen for online status
    SocketService.instance.onlineStatusStream.listen((statusData) {
      if (mounted && statusData['data']['userId'] == widget.partnerId) {
        setState(() {
          isPartnerOnline = statusData['type'] == 'online';
        });
      }
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final result = await ApiService.fetchMessages(myId, widget.partnerId);
      setState(() {
        messages = List<Map<String, dynamic>>.from(result);
        isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage(String message) {
    if (message.trim().isEmpty) return;

    // Generate unique temp ID
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_$myId';
    
    // Add message optimistically to UI with temp ID
    final tempMessage = {
      'id': tempId,
      'sender_id': myId,
      'receiver_id': widget.partnerId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'delivered': false,
      'read': false,
      'isTemp': true,
    };

    setState(() {
      messages.add(tempMessage);
    });
    _scrollToBottom();

    // Send via Socket.IO
    SocketService.instance.sendMessage(
      senderId: myId,
      receiverId: widget.partnerId,
      message: message,
      senderRole: widget.myRole,
      receiverRole: widget.partnerRole,
    );
  }

  void _onTyping(bool isTyping) {
    SocketService.instance.sendTypingIndicator(widget.partnerId, isTyping);
    
    // Stop typing after 3 seconds of inactivity
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        SocketService.instance.sendTypingIndicator(widget.partnerId, false);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markAllMessagesAsRead() async {
    try {
      // Mark all unread messages from this partner as read
      await ApiService.markAllMessagesAsRead(myId, widget.partnerId);
      
      // Also mark them via Socket.IO for real-time updates
      for (final message in messages) {
        if (message['sender_id'] == widget.partnerId && message['read'] == false) {
          SocketService.instance.markMessageAsRead(message['id']);
        }
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    widget.partnerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: OnlineStatusIndicator(
                    isOnline: isPartnerOnline,
                    size: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isPartnerTyping 
                        ? 'typing...' 
                        : isPartnerOnline 
                            ? 'online' 
                            : 'offline',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Add more options like clear chat, block user, etc.
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length + (isPartnerTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isPartnerTyping) {
                            return TypingIndicator(userName: widget.partnerName);
                          }
                          
                          final message = messages[index];
                          final isMe = message['sender_id'] == myId;
                          final showTime = index == 0 || 
                              _shouldShowTime(messages[index - 1], message);
                          
                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            showTime: showTime,
                            onTap: () {
                              // TODO: Add message options like copy, delete, etc.
                            },
                          );
                        },
                      ),
          ),
          ChatInput(
            onSendMessage: _sendMessage,
            onTyping: _onTyping,
          ),
        ],
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
            "Start the conversation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Send a message to ${widget.partnerName}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowTime(Map<String, dynamic> previousMessage, Map<String, dynamic> currentMessage) {
    final prevTime = DateTime.tryParse(previousMessage['timestamp']?.toString() ?? '');
    final currTime = DateTime.tryParse(currentMessage['timestamp']?.toString() ?? '');
    
    if (prevTime == null || currTime == null) return false;
    
    // Show time if messages are more than 5 minutes apart
    return currTime.difference(prevTime).inMinutes > 5;
  }
}
