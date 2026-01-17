import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

/// Modèle pour représenter une localisation
class LocationData {
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? countryName;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.countryName,
    this.address,
  });

  /// Alias pour cityName pour compatibilité
  String? get city => cityName;

  @override
  String toString() {
    if (cityName != null && countryName != null) {
      return '$cityName, $countryName';
    }
    if (address != null) {
      return address!;
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

/// Service pour gérer la géolocalisation
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Vérifie si les permissions de localisation sont accordées
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('⚠️ Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Récupère la position actuelle via GPS
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Récupérer l'adresse depuis les coordonnées
      String? cityName;
      String? countryName;
      String? address;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          cityName = place.locality ?? place.subAdministrativeArea;
          countryName = place.country;
          address = place.street != null && place.street!.isNotEmpty
              ? '${place.street}, ${cityName ?? ""}'
              : cityName;
        }
      } catch (e) {
        debugPrint('⚠️ Error getting address: $e');
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
        countryName: countryName,
        address: address,
      );
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// Recherche une localisation par nom de ville
  Future<List<LocationData>> searchLocation(String query) async {
    try {
      final locations = await locationFromAddress(query);
      final results = <LocationData>[];

      for (final location in locations) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            results.add(LocationData(
              latitude: location.latitude,
              longitude: location.longitude,
              cityName: place.locality ?? place.subAdministrativeArea,
              countryName: place.country,
              address: place.street != null && place.street!.isNotEmpty
                  ? '${place.street}, ${place.locality ?? ""}'
                  : place.locality,
            ));
          } else {
            results.add(LocationData(
              latitude: location.latitude,
              longitude: location.longitude,
            ));
          }
        } catch (e) {
          debugPrint('⚠️ Error getting placemark: $e');
          results.add(LocationData(
            latitude: location.latitude,
            longitude: location.longitude,
          ));
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error searching location: $e');
      return [];
    }
  }
}
