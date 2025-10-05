import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import 'map_picker_widget.dart';

class LocationInputWidget extends StatefulWidget {
  final String label;
  final String hint;
  final String? initialAddress;
  final LatLng? initialPosition;
  final Function(String address, LatLng? position) onLocationChanged;
  final String? Function(String?)? validator;

  const LocationInputWidget({
    super.key,
    required this.label,
    required this.hint,
    this.initialAddress,
    this.initialPosition,
    required this.onLocationChanged,
    this.validator,
  });

  @override
  State<LocationInputWidget> createState() => _LocationInputWidgetState();
}

class _LocationInputWidgetState extends State<LocationInputWidget> {
  final TextEditingController _addressController = TextEditingController();
  final LocationService _locationService = LocationService();
  
  LatLng? _currentPosition;
  bool _isGettingLocation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
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
          _currentPosition = LatLng(
            result.position!.latitude,
            result.position!.longitude,
          );
          _addressController.text = result.address ?? '';
        });
        
        widget.onLocationChanged(
          result.address ?? '',
          _currentPosition,
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
        builder: (context) => MapPickerWidget(
          initialPosition: _currentPosition,
          initialAddress: _addressController.text.isNotEmpty ? _addressController.text : null,
          onLocationSelected: (position, address) {
            Navigator.of(context).pop(MapPickerResult(
              position: position,
              address: address,
            ));
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentPosition = result.position;
        _addressController.text = result.address;
        _errorMessage = null;
      });
      
      widget.onLocationChanged(result.address, result.position);
    }
  }

  void _onAddressChanged(String value) {
    setState(() {
      _errorMessage = null;
    });
    
    // If user manually types an address, clear the position
    // (they can use map picker to set both address and position)
    if (value != _addressController.text) {
      _currentPosition = null;
    }
    
    widget.onLocationChanged(value, _currentPosition);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          onChanged: _onAddressChanged,
          validator: widget.validator,
          style: TextStyle(
            fontSize: 15,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 15,
              color: subtextColor.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              Icons.location_on,
              color: subtextColor,
              size: 20,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGettingLocation)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _getCurrentLocation,
                    icon: Icon(Icons.my_location, size: 20),
                    tooltip: 'Use Current Location',
                    color: subtextColor,
                  ),
                IconButton(
                  onPressed: _openMapPicker,
                  icon: Icon(Icons.map, size: 20),
                  tooltip: 'Select on Map',
                  color: subtextColor,
                ),
              ],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
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
        if (_currentPosition != null) ...[
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
                    'Location verified: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
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
  final LatLng position;
  final String address;

  MapPickerResult({
    required this.position,
    required this.address,
  });
}
