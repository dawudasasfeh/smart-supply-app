import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../l10n/app_localizations.dart';

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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  List<Map<String, dynamic>> messages = [];
  int myId = 0;
  bool isLoading = true;
  bool isPartnerOnline = false;
  bool isPartnerTyping = false;
  bool isSending = false;
  Timer? _typingTimer;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _initializeChat();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              _buildModernAppBar(isDark, locale),
              Expanded(
                child: isLoading
                    ? _buildLoadingState(isDark, locale)
                    : _buildMessageList(isDark),
              ),
              _buildMessageInput(isDark, locale),
            ],
          ),
          // Styled Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(bool isDark, AppLocalizations? locale) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F1F1F) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back Button
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
              
              // Profile Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                child: Icon(
                  Icons.person,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.partnerName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isPartnerOnline)
                      Text(
                        locale?.isRTL == true ? 'متصل' : 'Online',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Action Button
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // Add more options
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuturisticAvatar() {
    final initials = widget.partnerName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();
    
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00F5FF),
                Color(0xFF0080FF),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00F5FF).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
        if (isPartnerOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                border: Border.all(
                  color: const Color(0xFF0A0A0B),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    String status = 'offline';
    Color statusColor = Colors.grey;
    
    if (isPartnerTyping) {
      status = 'neural processing...';
      statusColor = const Color(0xFF00F5FF);
    } else if (isPartnerOnline) {
      status = 'neural link active';
      statusColor = const Color(0xFF00FF88);
    } else {
      status = 'neural link inactive';
      statusColor = Colors.grey;
    }
    
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: statusColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00F5FF).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFF00F5FF).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'SECURE',
        style: GoogleFonts.orbitron(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF00F5FF),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark, AppLocalizations? locale) {
    return Center(
      child: CircularProgressIndicator(
        color: Colors.grey,
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (isPartnerTyping ? 1 : 0),
      itemBuilder: (context, index) {
        final reversedIndex = messages.length - 1 - index + (isPartnerTyping ? 1 : 0);
        
        if (index == 0 && isPartnerTyping) {
          return _buildTypingIndicator(isDark);
        }
        
        final messageIndex = isPartnerTyping ? reversedIndex - 1 : reversedIndex;
        if (messageIndex < 0 || messageIndex >= messages.length) return const SizedBox();
        
        final message = messages[messageIndex];
        final isMe = message['sender_id'] == myId;
        final showTime = messageIndex == messages.length - 1 || 
                        _shouldShowTime(message, messages[messageIndex + 1]);
        
        return _buildMessageBubble(message, isMe, showTime, messageIndex, isDark);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, bool showTime, int index, bool isDark) {
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] ?? '';
    final isTemp = message['isTemp'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showTime) _buildTimeStamp(timestamp),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                _buildSmallAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.white,
                    border: Border.all(
                      color: isMe 
                          ? Colors.transparent 
                          : Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isMe ? const Color(0xFF00F5FF) : const Color(0xFF1A1A1B)).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messageText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isMe ? Colors.white : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      if (isTemp)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMe ? Colors.black54 : const Color(0xFF00F5FF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'sending...',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isMe ? Colors.black54 : const Color(0xFF00F5FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                _buildSmallAvatar(isMe: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar({bool isMe = false}) {
    final name = isMe ? 'Me' : widget.partnerName;
    final initial = name[0].toUpperCase();
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMe 
              ? [const Color(0xFF00FF88), const Color(0xFF00CC66)]
              : [const Color(0xFF00F5FF), const Color(0xFF0080FF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStamp(String timestamp) {
    final time = _formatMessageTime(timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF00F5FF).withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 600 + (index * 200)),
            tween: Tween(begin: 0.3, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5FF).withOpacity(value),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildMessageInput(bool isDark, AppLocalizations? locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF000000) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1F1F1F) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: locale?.isRTL == true ? 'رسالة' : 'Message',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (text) {
                    _onTyping(text.isNotEmpty);
                  },
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      _sendMessage(text);
                      _messageController.clear();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isSending ? null : () {
                final text = _messageController.text.trim();
                if (text.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  _sendMessage(text);
                  _messageController.clear();
                }
              },
              icon: Icon(
                Icons.send,
                color: isSending ? Colors.grey : const Color(0xFF3B82F6),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 60,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Start Conversation',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Send a message to ${widget.partnerName}\nto start the conversation',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _shouldShowTime(Map<String, dynamic> previousMessage, Map<String, dynamic> currentMessage) {
    final prevTime = DateTime.tryParse(previousMessage['timestamp']?.toString() ?? '');
    final currTime = DateTime.tryParse(currentMessage['timestamp']?.toString() ?? '');
    
    if (prevTime == null || currTime == null) return false;
    
    return currTime.difference(prevTime).inMinutes > 5;
  }

  String _formatMessageTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  void _sendMessage(String message) {
    if (message.trim().isEmpty || isSending) return;

    setState(() {
      isSending = true;
    });

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_$myId';
    
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
      isSending = false;
    });
    _scrollToBottom();

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
    
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        SocketService.instance.sendTypingIndicator(widget.partnerId, false);
      });
    }
  }
}
