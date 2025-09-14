import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../services/logout_helper.dart' as logout_helper;

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoRestockEnabled = false;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsSection(
              'Notifications',
              [
                _buildSwitchTile(
                  'Push Notifications',
                  'Receive notifications for low stock and orders',
                  Icons.notifications_outlined,
                  _notificationsEnabled,
                  (value) => setState(() => _notificationsEnabled = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              'Appearance',
              [
                _buildSwitchTile(
                  'Dark Mode',
                  'Switch to dark theme',
                  Icons.dark_mode_outlined,
                  _darkModeEnabled,
                  (value) => setState(() => _darkModeEnabled = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_userRole == 'supermarket' || _userRole == 'distributor')
              _buildSettingsSection(
                'Inventory Management',
                [
                  _buildSwitchTile(
                    'Auto Restock Alerts',
                    _userRole == 'supermarket' 
                        ? 'Automatically suggest restocking when items are low'
                        : 'Get alerts for low stock items in your inventory',
                    Icons.inventory_outlined,
                    _autoRestockEnabled,
                    (value) => setState(() => _autoRestockEnabled = value),
                  ),
                ],
              ),
            if (_userRole == 'supermarket' || _userRole == 'distributor')
              const SizedBox(height: 24),
            _buildSettingsSection(
              'Account',
              [
                _buildActionTile(
                  'Profile Information',
                  'Update your profile details',
                  Icons.person_outline,
                  () => _navigateToProfile(),
                ),
                _buildActionTile(
                  'Change Password',
                  'Update your account password',
                  Icons.lock_outline,
                  () => _showChangePasswordDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              'Support',
              [
                _buildActionTile(
                  'Help & FAQ',
                  'Get help and find answers',
                  Icons.help_outline,
                  () => _showHelpDialog(),
                ),
                _buildActionTile(
                  'Contact Support',
                  'Get in touch with our support team',
                  Icons.support_agent_outlined,
                  () => _showContactDialog(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        subtitle: const Text(
          'Sign out of your account',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        onTap: () => _handleLogout(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.pushNamed(context, '/profile');
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('Password change functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    List<String> faqItems = [];
    
    switch (_userRole) {
      case 'supermarket':
        faqItems = [
          '• How do I restock items?',
          '• How do I view AI suggestions?',
          '• How do I manage my inventory?',
          '• How do I contact distributors?',
        ];
        break;
      case 'distributor':
        faqItems = [
          '• How do I add new products?',
          '• How do I create offers?',
          '• How do I manage orders?',
          '• How do I contact supermarkets?',
        ];
        break;
      case 'delivery':
        faqItems = [
          '• How do I accept deliveries?',
          '• How do I update delivery status?',
          '• How do I scan QR codes?',
          '• How do I contact customers?',
        ];
        break;
      default:
        faqItems = [
          '• How do I use the app?',
          '• How do I manage my account?',
          '• How do I get support?',
        ];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frequently Asked Questions:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...faqItems.map((item) => Text(item)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get in touch with us:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('📧 Email: support@smartsupply.com'),
            Text('📞 Phone: +1 (555) 123-4567'),
            Text('💬 Live Chat: Available 24/7'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              logout_helper.logout(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
