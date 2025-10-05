import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';

class IntegratedMapWidget extends StatefulWidget {
  final String? address;
  final double? latitude;
  final double? longitude;
  final String title;
  final bool showNavigationButton;
  final Function(String address, double latitude, double longitude)? onLocationSelected;

  const IntegratedMapWidget({
    super.key,
    this.address,
    this.latitude,
    this.longitude,
    required this.title,
    this.showNavigationButton = true,
    this.onLocationSelected,
  });

  @override
  State<IntegratedMapWidget> createState() => _IntegratedMapWidgetState();
}

class _IntegratedMapWidgetState extends State<IntegratedMapWidget> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String? _currentAddress;
  bool _isLoading = true;
  final LocationService _locationService = LocationService();

  // Default location (Amman, Jordan)
  static const LatLng _defaultLocation = LatLng(31.9539, 35.9106);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.latitude != null && widget.longitude != null) {
      _currentPosition = LatLng(widget.latitude!, widget.longitude!);
      _currentAddress = widget.address;
      setState(() => _isLoading = false);
      return;
    }

    if (widget.address != null && widget.address!.isNotEmpty) {
      // Try to get coordinates from address
      final result = await _locationService.getCoordinatesFromAddress(widget.address!);
      if (result.success && result.position != null) {
        _currentPosition = LatLng(
          result.position!.latitude,
          result.position!.longitude,
        );
        _currentAddress = result.address;
      } else {
        _currentPosition = _defaultLocation;
        _currentAddress = 'Location not found';
      }
    } else {
      // Try to get current location
      final locationResult = await _locationService.getCurrentLocation();
      if (locationResult.success && locationResult.position != null) {
        _currentPosition = LatLng(
          locationResult.position!.latitude,
          locationResult.position!.longitude,
        );
        _currentAddress = locationResult.address;
      } else {
        _currentPosition = _defaultLocation;
        _currentAddress = 'Default location';
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    
    if (_currentPosition != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
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
        _currentPosition = newPosition;
        _currentAddress = locationResult.address;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationResult.error ?? 'Failed to get current location'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _openInExternalMaps() {
    if (_currentPosition == null) return;

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final address = _currentAddress ?? 'Selected location';
    
    // Show options for different map apps
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Open in External Maps',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildMapOption(
              'Google Maps',
              Icons.map,
              Colors.red,
              () => _launchGoogleMaps(lat, lng, address),
            ),
            _buildMapOption(
              'Apple Maps',
              Icons.map_outlined,
              Colors.blue,
              () => _launchAppleMaps(lat, lng, address),
            ),
            _buildMapOption(
              'Waze',
              Icons.navigation,
              Colors.blue,
              () => _launchWaze(lat, lng, address),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapOption(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _launchGoogleMaps(double lat, double lng, String address) {
    // Implementation for launching Google Maps
    // This would use url_launcher to open external Google Maps
  }

  void _launchAppleMaps(double lat, double lng, String address) {
    // Implementation for launching Apple Maps
  }

  void _launchWaze(double lat, double lng, String address) {
    // Implementation for launching Waze
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.showNavigationButton)
            IconButton(
              onPressed: _goToCurrentLocation,
              icon: const Icon(Icons.my_location),
              tooltip: 'Current Location',
            ),
          IconButton(
            onPressed: _openInExternalMaps,
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in External Maps',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? _defaultLocation,
                zoom: 11.0,
              ),
              markers: _currentPosition != null
                  ? {
                      Marker(
                        markerId: const MarkerId('location_marker'),
                        position: _currentPosition!,
                        infoWindow: InfoWindow(
                          title: widget.title,
                          snippet: _currentAddress ?? 'Selected location',
                        ),
                      ),
                    }
                  : {},
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
          
          // Address info overlay
          if (_currentAddress != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentAddress!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
