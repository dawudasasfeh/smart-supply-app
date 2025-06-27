import 'package:flutter/material.dart';
import 'package:flutter_application_2/screens/EditProfile_page.dart';
import 'package:flutter_application_2/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class DeliveryProfilePage extends StatefulWidget {
  const DeliveryProfilePage({super.key});

  @override
  State<DeliveryProfilePage> createState() => _DeliveryProfilePageState();
}

class _DeliveryProfilePageState extends State<DeliveryProfilePage> with SingleTickerProviderStateMixin {
  Map<String, String>? profileData;
  bool showFullToken = false;
  late AnimationController _avatarPulseController;

  @override
  void initState() {
    super.initState();
    _avatarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadProfileData();
  }

  @override
  void dispose() {
    _avatarPulseController.dispose();
    super.dispose();
  }

Future<void> _loadProfileData() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  try {
    final profile = await ApiService.fetchUserProfile(token);
    final data = {
      'username': prefs.getString('username') ?? 'Delivery',
      'fullName': profile['full_name'] ?? 'Delivery Person',
      'role': prefs.getString('role') ?? '',
      'token': token,
      'phone': profile['phone'] ?? 'N/A',
      'vehicleType': profile['vehicle_type'] ?? 'N/A',
      'licensePlate': profile['license_plate'] ?? 'N/A',
      'memberSince': profile['created_at']?.split('T').first ?? 'N/A',
    };
    setState(() => profileData = data.cast<String, String>());
  } catch (e) {
    debugPrint('Delivery profile error: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile')));
  }
}

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final accentColor = isDark ? Colors.indigoAccent[200] : Colors.indigo[700];
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Delivery Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: profileData == null
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildAnimatedAvatar(profileData!['username']!, accentColor!, textPrimary),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    profileData!['fullName']!,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    profileData!['role']!,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profileData!['phone']!,
                  cardColor: cardColor!,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildInfoCard(
                  icon: Icons.motorcycle_outlined,
                  label: 'Vehicle Type',
                  value: profileData!['vehicleType']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildInfoCard(
                  icon: Icons.confirmation_number_outlined,
                  label: 'License Plate',
                  value: profileData!['licensePlate']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildInfoCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: profileData!['memberSince']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildTokenCard(
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  token: profileData!['token']!,
                  showFullToken: showFullToken,
                  toggleShowToken: () => setState(() => showFullToken = !showFullToken),
                  onCopy: () => _copyToClipboard(profileData!['token']!, 'Token'),
                ),

                const SizedBox(height: 60),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: Text(
            "Edit Profile",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: accentColor,
            shadowColor: accentColor != null ? accentColor.withOpacity(0.4) : null,
            elevation: 8,
          ),
          onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfilePage(role: profileData!['role']!),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildAnimatedAvatar(String username, Color accentColor, Color textPrimary) {
    return Center(
      child: AnimatedBuilder(
        animation: _avatarPulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4 * _avatarPulseController.value),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 62,
              backgroundColor: accentColor.withOpacity(0.12),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'D',
                style: GoogleFonts.poppins(
                  fontSize: 58,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: textSecondary),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textSecondary,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTokenCard({
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required String token,
    required bool showFullToken,
    required VoidCallback toggleShowToken,
    required VoidCallback onCopy,
  }) {
    final displayedToken =
        showFullToken ? token : (token.length > 30 ? '${token.substring(0, 30)}...' : token);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key_outlined, size: 32, color: textSecondary),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              displayedToken,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: textPrimary,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(showFullToken ? Icons.visibility_off : Icons.visibility, color: textSecondary),
            onPressed: toggleShowToken,
            tooltip: showFullToken ? 'Hide token' : 'Show full token',
          ),
          IconButton(
            icon: Icon(Icons.copy, color: textSecondary),
            onPressed: onCopy,
            tooltip: 'Copy token',
          ),
        ],
      ),
    );
  }
}
