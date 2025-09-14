import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class DistributorNotificationsPage extends StatefulWidget {
  const DistributorNotificationsPage({super.key});

  @override
  State<DistributorNotificationsPage> createState() => _DistributorNotificationsPageState();
}

class _DistributorNotificationsPageState extends State<DistributorNotificationsPage> {
  List<dynamic> notifications = [];
  bool isLoading = true;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    
    if (token!.isNotEmpty) {
      try {
        final data = await ApiService.getNotifications(token!);
        setState(() {
          notifications = data;
          isLoading = false;
        });
      } catch (e) {
        print('Error loading notifications: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await ApiService.markNotificationRead(token!, notificationId);
      _loadNotifications(); // Refresh the list
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification['is_read'] ?? false;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRead ? AppColors.textSecondary : AppColors.primary,
                          child: Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['message'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              notification['created_at'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: !isRead
                            ? IconButton(
                                icon: const Icon(Icons.mark_email_read),
                                onPressed: () => _markAsRead(notification['id']),
                              )
                            : null,
                        onTap: !isRead ? () => _markAsRead(notification['id']) : null,
                      ),
                    );
                  },
                ),
    );
  }
}
