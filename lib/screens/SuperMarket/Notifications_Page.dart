import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class SupermarketNotificationsPage extends StatefulWidget {
  const SupermarketNotificationsPage({Key? key}) : super(key: key);

  @override
  State<SupermarketNotificationsPage> createState() => _SupermarketNotificationsPageState();
}

class _SupermarketNotificationsPageState extends State<SupermarketNotificationsPage> {
  List<NotificationItem> _getLocalizedNotifications() {
    final locale = AppLocalizations.of(context);
    final isArabic = locale?.isRTL == true;
    
    return [
      NotificationItem(
        id: '1',
        title: isArabic ? 'تنبيه مخزون منخفض' : 'Low Stock Alert',
        message: isArabic 
            ? 'منتجات الحليب على وشك النفاد. يُنصح بإعادة التخزين قريباً.'
            : 'Milk products are running low. Consider restocking soon.',
        type: NotificationType.lowStock,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isRead: false,
      ),
      NotificationItem(
        id: '2',
        title: isArabic ? 'اقتراح إعادة تخزين بالذكاء الاصطناعي' : 'AI Restock Suggestion',
        message: isArabic
            ? 'الذكاء الاصطناعي يقترح إعادة تخزين الخبز - أولوية عالية بناءً على توقعات الطلب.'
            : 'AI suggests restocking Bread - High priority based on demand prediction.',
        type: NotificationType.aiSuggestion,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationItem(
        id: '3',
        title: isArabic ? 'تم استلام طلب جديد' : 'New Order Received',
        message: isArabic
            ? 'تم استلام الطلب رقم #12345 من الموزع ABC.'
            : 'Order #12345 received from Distributor ABC.',
        type: NotificationType.order,
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      NotificationItem(
        id: '4',
        title: isArabic ? 'تحديث النظام' : 'System Update',
        message: isArabic
            ? 'تم تحديث نظام التوريد الذكي بميزات جديدة.'
            : 'Smart Supply system has been updated with new features.',
        type: NotificationType.system,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationItem(
        id: '5',
        title: isArabic ? 'تنبيه الجرد' : 'Inventory Alert',
        message: isArabic
            ? 'تقرير الجرد الأسبوعي جاهز للمراجعة.'
            : 'Weekly inventory report is ready for review.',
        type: NotificationType.inventory,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }
  
  late List<NotificationItem> _notifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    
    // Initialize notifications with localized content
    _notifications = _getLocalizedNotifications();
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(unreadCount),
          _notifications.isEmpty
              ? SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: _buildEmptyState(),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildNotificationCard(_notifications[index]);
                      },
                      childCount: _notifications.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(int unreadCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: bgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [const Color(0xFF000000), const Color(0xFF0A0A0A)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Back Button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back,
                            color: subtextColor,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Profile Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 18,
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
                              locale?.isRTL == true ? 'الإشعارات' : 'Notifications',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              unreadCount > 0 
                                ? (locale?.isRTL == true ? '$unreadCount غير مقروءة' : '$unreadCount unread')
                                : (locale?.isRTL == true ? 'لا توجد إشعارات' : 'All caught up'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Action Buttons
                      if (unreadCount > 0)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.done_all,
                              color: subtextColor,
                              size: 18,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _markAllAsRead();
                            },
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            color: subtextColor,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            // Add more options
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.1),
                    const Color(0xFF1D4ED8).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              locale?.isRTL == true ? 'لا توجد إشعارات!' : 'All Caught Up!',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locale?.isRTL == true 
                ? 'ليس لديك إشعارات جديدة.\nسنعلمك عند حدوث شيء مهم.'
                : 'You have no new notifications.\nWe\'ll notify you when something important happens.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: subtextColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: notification.isRead
                    ? null
                    : (isDark 
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0A0A0A),
                              const Color(0xFF3B82F6).withOpacity(0.05),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              const Color(0xFF3B82F6).withOpacity(0.02),
                            ],
                          )),
                color: notification.isRead ? cardColor : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notification.isRead 
                      ? (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0))
                      : const Color(0xFF3B82F6).withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: notification.isRead 
                        ? Colors.black.withOpacity(isDark ? 0.3 : 0.03)
                        : const Color(0xFF3B82F6).withOpacity(0.08),
                    blurRadius: notification.isRead ? 8 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _markAsRead(notification.id),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _getNotificationGradient(notification.type),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getNotificationColor(notification.type).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (!notification.isRead)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        locale?.isRTL == true ? 'جديد' : 'NEW',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.message,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: subtextColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(notification.type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getNotificationTypeText(notification.type),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getNotificationColor(notification.type),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTimestamp(notification.timestamp, locale),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return const Color(0xFFF59E0B);
      case NotificationType.aiSuggestion:
        return const Color(0xFF8B5CF6);
      case NotificationType.order:
        return const Color(0xFF10B981);
      case NotificationType.system:
        return const Color(0xFF3B82F6);
      case NotificationType.inventory:
        return const Color(0xFF06B6D4);
    }
  }

  List<Color> _getNotificationGradient(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case NotificationType.aiSuggestion:
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
      case NotificationType.order:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case NotificationType.system:
        return [const Color(0xFF3B82F6), const Color(0xFF2563EB)];
      case NotificationType.inventory:
        return [const Color(0xFF06B6D4), const Color(0xFF0891B2)];
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lowStock:
        return Icons.inventory_2_rounded;
      case NotificationType.aiSuggestion:
        return Icons.psychology_rounded;
      case NotificationType.order:
        return Icons.shopping_cart_rounded;
      case NotificationType.system:
        return Icons.system_update_rounded;
      case NotificationType.inventory:
        return Icons.assessment_rounded;
    }
  }

  String _getNotificationTypeText(NotificationType type) {
    final locale = AppLocalizations.of(context);
    if (locale?.isRTL == true) {
      switch (type) {
        case NotificationType.lowStock:
          return 'مخزون منخفض';
        case NotificationType.aiSuggestion:
          return 'اقتراح AI';
        case NotificationType.order:
          return 'طلب';
        case NotificationType.system:
          return 'نظام';
        case NotificationType.inventory:
          return 'جرد';
      }
    }
    switch (type) {
      case NotificationType.lowStock:
        return 'LOW STOCK';
      case NotificationType.aiSuggestion:
        return 'AI INSIGHT';
      case NotificationType.order:
        return 'ORDER';
      case NotificationType.system:
        return 'SYSTEM';
      case NotificationType.inventory:
        return 'INVENTORY';
    }
  }

  String _formatTimestamp(DateTime timestamp, AppLocalizations? locale) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (locale?.isRTL == true) {
      if (difference.inMinutes < 60) {
        return 'منذ ${difference.inMinutes} د';
      } else if (difference.inHours < 24) {
        return 'منذ ${difference.inHours} س';
      } else if (difference.inDays < 7) {
        return 'منذ ${difference.inDays} ي';
      } else {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      }
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum NotificationType {
  lowStock,
  aiSuggestion,
  order,
  system,
  inventory,
}
