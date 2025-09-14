import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';

class EnhancedSettingsPage extends StatefulWidget {
  const EnhancedSettingsPage({super.key});

  @override
  State<EnhancedSettingsPage> createState() => _EnhancedSettingsPageState();
}

class _EnhancedSettingsPageState extends State<EnhancedSettingsPage> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = false;
  bool _biometricEnabled = false;
  String _language = 'English';
  String _currency = 'USD';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Appearance'),
          _buildThemeSelector(themeProvider),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Notifications'),
          _buildNotificationSettings(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Privacy & Security'),
          _buildPrivacySettings(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Preferences'),
          _buildPreferenceSettings(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Account'),
          _buildAccountSettings(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Support'),
          _buildSupportSettings(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider) {
    return Card(
      child: Column(
        children: [
          _buildThemeOption(
            'Light Mode',
            'Clean and bright interface',
            Icons.light_mode,
            ThemeMode.light,
            themeProvider,
          ),
          const Divider(height: 1),
          _buildThemeOption(
            'Dark Mode',
            'Easy on the eyes',
            Icons.dark_mode,
            ThemeMode.dark,
            themeProvider,
          ),
          const Divider(height: 1),
          _buildThemeOption(
            'System Default',
            'Follow device settings',
            Icons.settings_system_daydream,
            ThemeMode.system,
            themeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    String subtitle,
    IconData icon,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => themeProvider.setThemeMode(mode),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive order updates and alerts'),
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Notification Schedule'),
            subtitle: const Text('9:00 AM - 6:00 PM'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotificationScheduleDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Sound & Vibration'),
            subtitle: const Text('Customize notification sounds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSoundSettingsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Location Services'),
            subtitle: const Text('Enable for delivery tracking'),
            value: _locationEnabled,
            onChanged: (value) => setState(() => _locationEnabled = value),
            secondary: const Icon(Icons.location_on),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Use fingerprint or face unlock'),
            value: _biometricEnabled,
            onChanged: (value) => setState(() => _biometricEnabled = value),
            secondary: const Icon(Icons.fingerprint),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy Policy'),
            subtitle: const Text('View our privacy practices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacyPolicy(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageSelector(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text(_currency),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencySelector(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics Dashboard'),
            subtitle: const Text('View business insights'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            subtitle: const Text('Update your information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/editProfile'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            subtitle: const Text('Update your password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text('Sign Out', style: TextStyle(color: AppColors.error)),
            onTap: () => _showSignOutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help Center'),
            subtitle: const Text('Get help and support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHelpCenter(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Send Feedback'),
            subtitle: const Text('Help us improve the app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFeedbackDialog(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('App version and information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  void _showNotificationScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Schedule'),
        content: const Text('Configure when you want to receive notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSoundSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sound & Vibration'),
        content: const Text('Customize notification sounds and vibration patterns.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final languages = ['English', 'Arabic', 'French', 'Spanish'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) => ListTile(
            title: Text(lang),
            trailing: _language == lang ? const Icon(Icons.check) : null,
            onTap: () {
              setState(() => _language = lang);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCurrencySelector() {
    final currencies = ['USD', 'EUR', 'GBP', 'SAR'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((curr) => ListTile(
            title: Text(curr),
            trailing: _currency == curr ? const Icon(Icons.check) : null,
            onTap: () {
              setState(() => _currency = curr);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performSignOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This app collects and uses data to provide better service...',
          ),
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

  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: const Text('Visit our help center for tutorials and FAQs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Smart Supply Chain',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.business),
      children: [
        const Text('A comprehensive supply chain management solution.'),
      ],
    );
  }

  Future<void> _performSignOut() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Clear user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to login screen and clear navigation stack
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
