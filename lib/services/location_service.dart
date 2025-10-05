import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  String? _currentAddress;

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return permission;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return permission;
    }

    return permission;
  }

  /// Get current location with automatic permission handling
  Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          success: false,
          error: 'Location services are disabled. Please enable location services.',
        );
      }

      // Check and request permission
      LocationPermission permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(
          success: false,
          error: 'Location permission denied. Please allow location access.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          success: false,
          error: 'Location permission permanently denied. Please enable it in app settings.',
        );
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;

      // Get address from coordinates
      String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      _currentAddress = address;

      return LocationResult(
        success: true,
        position: position,
        address: address,
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return LocationResult(
        success: false,
        error: 'Failed to get location: ${e.toString()}',
      );
    }
  }

  /// Get address from coordinates
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Build address string
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        return addressParts.join(', ');
      }
      
      return 'Unknown location';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Unknown location';
    }
  }

  /// Get coordinates from address
  Future<LocationResult> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        Location location = locations.first;
        Position position = Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        return LocationResult(
          success: true,
          position: position,
          address: address,
        );
      }

      return LocationResult(
        success: false,
        error: 'Address not found',
      );
    } catch (e) {
      debugPrint('Error getting coordinates from address: $e');
      return LocationResult(
        success: false,
        error: 'Failed to find address: ${e.toString()}',
      );
    }
  }

  /// Clear current location data
  void clearLocation() {
    _currentPosition = null;
    _currentAddress = null;
  }
}

class LocationResult {
  final bool success;
  final Position? position;
  final String? address;
  final String? error;

  LocationResult({
    required this.success,
    this.position,
    this.address,
    this.error,
  });
}
