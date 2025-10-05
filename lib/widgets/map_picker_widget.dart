import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class MapPickerWidget extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;
  final Function(LatLng position, String address) onLocationSelected;

  const MapPickerWidget({
    super.key,
    this.initialPosition,
    this.initialAddress,
    required this.onLocationSelected,
  });

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isGettingAddress = false;
  final LocationService _locationService = LocationService();

  // Default location (if no initial position provided)
  static const LatLng _defaultLocation = LatLng(31.9539, 35.9106); // Amman, Jordan

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition;
      _selectedAddress = widget.initialAddress;
      setState(() => _isLoading = false);
      return;
    }

    // Try to get current location
    final locationResult = await _locationService.getCurrentLocation();
    
    if (locationResult.success && locationResult.position != null) {
      _selectedPosition = LatLng(
        locationResult.position!.latitude,
        locationResult.position!.longitude,
      );
      _selectedAddress = locationResult.address;
    } else {
      // Use default location
      _selectedPosition = _defaultLocation;
      _selectedAddress = await _locationService.getAddressFromCoordinates(
        _defaultLocation.latitude,
        _defaultLocation.longitude,
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _reverseGeocodeSelected() async {
    if (_selectedPosition == null) return;
    setState(() {
      _isGettingAddress = true;
    });
    try {
      final address = await _locationService.getAddressFromCoordinates(
        _selectedPosition!.latitude,
        _selectedPosition!.longitude,
      );
      setState(() {
        _selectedAddress = address;
        _isGettingAddress = false;
      });
    } catch (_) {
      setState(() {
        _selectedAddress = 'Unknown location';
        _isGettingAddress = false;
      });
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    
    if (_selectedPosition != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLng(_selectedPosition!),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoading = true);
    
    final locationResult = await _locationService.getCurrentLocation();
    
    if (locationResult.success && locationResult.position != null) {
      final newPosition = LatLng(
        locationResult.position!.latitude,
        locationResult.position!.longitude,
      );
      
      setState(() {
        _selectedPosition = newPosition;
        _selectedAddress = locationResult.address;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    } else {
      final locale = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationResult.error ?? locale?.translate('failed_get_location') ?? 'Failed to get current location'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _confirmLocation() {
    if (_selectedPosition != null && _selectedAddress != null) {
      widget.onLocationSelected(_selectedPosition!, _selectedAddress!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: textColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Expanded(
                    child: Text(
                      locale?.translate('select_location') ?? 'Select Location',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Current location button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: _goToCurrentLocation,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            GoogleMap(
              onMapCreated: (controller) async {
                await _onMapCreated(controller);
                // Apply dark mode style if needed
                if (isDark) {
                  controller.setMapStyle('''
                    [
                      {"elementType":"geometry","stylers":[{"color":"#212121"}]},
                      {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
                      {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
                      {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
                      {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
                      {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
                      {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
                      {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
                      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
                      {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
                    ]
                  ''');
                }
              },
              initialCameraPosition: CameraPosition(
                target: _selectedPosition ?? _defaultLocation,
                zoom: 11.0,
              ),
              onCameraMove: (pos) {
                _selectedPosition = pos.target;
              },
              onCameraIdle: _reverseGeocodeSelected,
              markers: const {},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              mapToolbarEnabled: true,
              minMaxZoomPreference: MinMaxZoomPreference.unbounded,
            ),
          
          // Center marker
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 40),
                if (_isGettingAddress)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          locale?.translate('getting_address') ?? 'Getting address...',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom panel with address and confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subtextColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedAddress ?? (locale?.translate('tap_map_select') ?? 'Tap on map to select location'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _selectedPosition != null ? _confirmLocation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: subtextColor.withOpacity(0.3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        locale?.translate('confirm_location') ?? 'Confirm Location',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
