import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import 'free_map_picker_widget.dart';

class FreeLocationInputWidget extends StatefulWidget {
  final String label;
  final String hint;
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(String address, double? latitude, double? longitude) onLocationChanged;
  final String? Function(String?)? validator;

  const FreeLocationInputWidget({
    super.key,
    required this.label,
    required this.hint,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationChanged,
    this.validator,
  });

  @override
  State<FreeLocationInputWidget> createState() => _FreeLocationInputWidgetState();
}

class _FreeLocationInputWidgetState extends State<FreeLocationInputWidget> {
  final TextEditingController _addressController = TextEditingController();
  final LocationService _locationService = LocationService();
  
  double? _currentLatitude;
  double? _currentLongitude;
  bool _isGettingLocation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentLatitude = widget.initialLatitude;
      _currentLongitude = widget.initialLongitude;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _errorMessage = null;
    });

    try {
      final result = await _locationService.getCurrentLocation();
      
      if (result.success && result.position != null) {
        setState(() {
          _currentLatitude = result.position!.latitude;
          _currentLongitude = result.position!.longitude;
          _addressController.text = result.address ?? '';
        });
        
        widget.onLocationChanged(
          result.address ?? '',
          _currentLatitude,
          _currentLongitude,
        );
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to get location';
        });
        
        _showErrorSnackBar(_errorMessage!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
      
      _showErrorSnackBar(_errorMessage!);
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (context) => FreeMapPickerWidget(
          initialLatitude: _currentLatitude,
          initialLongitude: _currentLongitude,
          initialAddress: _addressController.text.isNotEmpty ? _addressController.text : null,
          onLocationSelected: (latitude, longitude, address) {
            Navigator.of(context).pop(MapPickerResult(
              latitude: latitude,
              longitude: longitude,
              address: address,
            ));
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentLatitude = result.latitude;
        _currentLongitude = result.longitude;
        _addressController.text = result.address;
        _errorMessage = null;
      });
      
      widget.onLocationChanged(result.address, result.latitude, result.longitude);
    }
  }

  void _onAddressChanged(String value) {
    setState(() {
      _errorMessage = null;
    });
    
    // If user manually types an address, clear the coordinates
    // (they can use map picker to set both address and coordinates)
    if (value != _addressController.text) {
      _currentLatitude = null;
      _currentLongitude = null;
    }
    
    widget.onLocationChanged(value, _currentLatitude, _currentLongitude);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          onChanged: _onAddressChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(
              Icons.location_on,
              color: AppColors.primary,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGettingLocation)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Use Current Location',
                    color: AppColors.primary,
                  ),
                IconButton(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map),
                  tooltip: 'Select on Map',
                  color: AppColors.primary,
                ),
              ],
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_currentLatitude != null && _currentLongitude != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location verified: ${_currentLatitude!.toStringAsFixed(4)}, ${_currentLongitude!.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class MapPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}
