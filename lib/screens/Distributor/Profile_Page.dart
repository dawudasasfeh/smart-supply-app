import 'package:flutter/material.dart';
import 'package:flutter_application_2/screens/EditProfile_page.dart';
import 'package:flutter_application_2/services/api_service.dart';
import 'package:flutter_application_2/widgets/map_address_picker.dart';
import 'package:flutter_application_2/themes/role_theme_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DistributorProfilePage extends StatefulWidget {
  const DistributorProfilePage({super.key});
  @override
  State<DistributorProfilePage> createState() => _DistributorProfilePageState();
}

class _DistributorProfilePageState extends State<DistributorProfilePage>
    with SingleTickerProviderStateMixin {
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
      'username': prefs.getString('username') ?? 'Distributor',
      'companyName': profile['company_name'] ?? 'My Company',
      'email': profile['email'] ?? prefs.getString('email') ?? '',
      'role': prefs.getString('role') ?? '',
      'token': token,
      'phone': profile['phone'] ?? 'N/A',
      'address': profile['address'] ?? 'N/A',
      'memberSince': profile['created_at']?.split('T').first ?? 'N/A',
    };
    setState(() => profileData = data.cast<String, String>());
  } catch (e) {
    debugPrint('Distributor profile error: $e');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile')));
  }
}

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void _editAddress() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController addressController = TextEditingController(
          text: profileData!['address'] != 'N/A' ? profileData!['address']! : '',
        );
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_location_outlined, color: Colors.deepOrange[700]),
              const SizedBox(width: 8),
              Text(
                'Edit Company Address',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Company Address',
                    hintText: 'Enter your complete business address\nInclude street, city, state, postal code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.business_outlined),
                    helperText: 'This will be used for deliveries and business correspondence',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _getCurrentLocation(addressController),
                        icon: const Icon(Icons.my_location_outlined, size: 18),
                        label: Text(
                          'GPS Location',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange[700],
                          side: BorderSide(color: Colors.deepOrange[700]!, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMapEditor(addressController),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          'Map Editor',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddressTips(),
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: Text(
                          'Tips',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newAddress = addressController.text.trim();
                if (newAddress.isNotEmpty) {
                  await _updateAddress(newAddress);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid address'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save Address',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation(TextEditingController addressController) async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        addressController.text = address;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found and address updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to get current location'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openMapEditor(TextEditingController addressController) async {
    // Parse current address to get initial location if possible
    LatLng? initialLocation;
    String currentAddress = addressController.text.trim();
    
    if (currentAddress.isNotEmpty && currentAddress != 'N/A') {
      try {
        List<Location> locations = await locationFromAddress(currentAddress);
        if (locations.isNotEmpty) {
          initialLocation = LatLng(locations.first.latitude, locations.first.longitude);
        }
      } catch (e) {
        print('Error geocoding current address: $e');
      }
    }
    
    // Navigate to full-screen map picker
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapAddressPicker(
          initialAddress: currentAddress.isNotEmpty && currentAddress != 'N/A' ? currentAddress : null,
          initialLocation: initialLocation,
          onLocationSelected: (String address, LatLng location) {
            // Update the address field with the selected address
            addressController.text = address;
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Address updated: ${address.length > 50 ? '${address.substring(0, 50)}...' : address}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
  }


  void _showAddressTips() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text(
                'Address Tips',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For best results, include:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildTipItem('🏢', 'Building/Company name'),
              _buildTipItem('🛣️', 'Street number and name'),
              _buildTipItem('🏙️', 'City or locality'),
              _buildTipItem('📍', 'State/Province'),
              _buildTipItem('📮', 'Postal/ZIP code'),
              _buildTipItem('🌍', 'Country'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'Example:\nABC Distribution Center\n123 Industrial Ave\nBusiness District, Cairo\nCairo Governorate 11511\nEgypt',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  color: Colors.deepOrange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTipItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.roboto(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _editEmail() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController emailController = TextEditingController(
          text: profileData!['email'] != 'N/A' ? profileData!['email']! : '',
        );
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.deepOrange[700]),
              const SizedBox(width: 8),
              Text(
                'Edit Email Address',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your business email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: 'This will be used for business communications',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newEmail = emailController.text.trim();
                if (newEmail.isNotEmpty && newEmail.contains('@')) {
                  await _updateUserField('email', newEmail, 'Email');
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save Email',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editPhone() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController phoneController = TextEditingController(
          text: profileData!['phone'] != 'N/A' ? profileData!['phone']! : '',
        );
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.phone_outlined, color: Colors.deepOrange[700]),
              const SizedBox(width: 8),
              Text(
                'Edit Phone Number',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your business phone number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone),
              helperText: 'Include country code (e.g., +1234567890)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPhone = phoneController.text.trim();
                if (newPhone.isNotEmpty) {
                  await _updateUserField('phone', newPhone, 'Phone number');
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid phone number'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save Phone',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editCompanyName() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController companyController = TextEditingController(
          text: profileData!['companyName'] != 'My Company' ? profileData!['companyName']! : '',
        );
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.business_outlined, color: Colors.deepOrange[700]),
              const SizedBox(width: 8),
              Text(
                'Edit Company Name',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: TextField(
            controller: companyController,
            decoration: InputDecoration(
              labelText: 'Company Name',
              hintText: 'Enter your company or business name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.domain),
              helperText: 'This will be displayed on your business profile',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCompanyName = companyController.text.trim();
                if (newCompanyName.isNotEmpty) {
                  await _updateDistributorField('company_name', newCompanyName, 'Company name');
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid company name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save Company',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserField(String field, String newValue, String fieldName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // Update user field via API (email and phone are in users table)
      await ApiService.updateProfile(token, {field: newValue}, 'distributor');
      
      // Update local state
      setState(() {
        profileData![field] = newValue;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fieldName updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating $field: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update $fieldName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateDistributorField(String field, String newValue, String fieldName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // Update distributor field via API (company_name, etc. are in distributors table)
      await ApiService.updateProfile(token, {field: newValue}, 'distributor');
      
      // Update local state - map company_name to companyName for UI
      setState(() {
        if (field == 'company_name') {
          profileData!['companyName'] = newValue;
        } else {
          profileData![field] = newValue;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fieldName updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating $field: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update $fieldName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAddress(String newAddress) async {
    try {
      print('🔧 DEBUG: Starting address update...');
      print('🔧 DEBUG: New address: $newAddress');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userId = prefs.getInt('user_id');
      final userRole = prefs.getString('role');
      
      print('🔧 DEBUG: Token length: ${token.length}');
      print('🔧 DEBUG: User ID: $userId');
      print('🔧 DEBUG: User role: $userRole');
      
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Updating address...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 10),
        ),
      );
      
      // Update address via API - use address field for distributors
      print('🔧 DEBUG: Calling API with data: {"address": "$newAddress"}');
      final result = await ApiService.updateProfile(token, {'address': newAddress}, 'distributor');
      print('🔧 DEBUG: API call successful, result: $result');
      
      // Update local state
      setState(() {
        profileData!['address'] = newAddress;
      });
      
      // Hide loading and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Address updated successfully!\n${newAddress.length > 50 ? '${newAddress.substring(0, 50)}...' : newAddress}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      
    } catch (e) {
      print('❌ ERROR: Address update failed: $e');
      
      // Hide loading
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show detailed error message
      String errorMessage = 'Failed to update address';
      if (e.toString().contains('No authentication token')) {
        errorMessage = 'Please log in again to update your address';
      } else if (e.toString().contains('Failed to update profile')) {
        errorMessage = 'Server error: Unable to update address';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        errorMessage = 'Network error: Please check your internet connection';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Error: ${e.toString()}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _updateAddress(newAddress),
          ),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roleColors = context.roleColors;
    final bgColor = roleColors.background;
    final cardColor = roleColors.surface;
    final textPrimary = roleColors.onSurface;
    final textSecondary = roleColors.onSurface.withOpacity(0.7);
    final accentColor = roleColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Distributor Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: cardColor!.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            profileData!['companyName']!,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: accentColor,
                              size: 20,
                            ),
                            onPressed: () => _editCompanyName(),
                            tooltip: 'Edit Company Name',
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
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
                const SizedBox(height: 32),

                _buildInfoCard(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profileData!['email']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onEdit: () => _editEmail(),
                ),
                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profileData!['phone']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onEdit: () => _editPhone(),
                ),
                _buildInfoCard(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: profileData!['address']!,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onEdit: () => _editAddress(),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(
              "Edit Profile",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shadowColor: accentColor!.withOpacity(0.3),
              elevation: 6,
              minimumSize: const Size(double.infinity, 56),
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
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          )
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: textSecondary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    color: textPrimary,
                    height: 1.3,
                  ),
                  maxLines: value.length > 50 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.deepOrange[700]!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: Colors.deepOrange[700],
                  size: 20,
                ),
                onPressed: onEdit,
                tooltip: 'Edit $label',
                padding: const EdgeInsets.all(10),
              ),
            ),
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
