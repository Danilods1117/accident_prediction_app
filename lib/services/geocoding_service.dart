import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeocodingService {
  // Google Maps API Key - Replace with your actual API key
  static const String _googleMapsApiKey = 'AIzaSyAAcBU-SiCt024WRyGx0Z0uOnyj1E753EA';

  // Set to true to use Google Maps API, false to use built-in geocoding
  static const bool _useGoogleMapsAPI = true; // Change to true when you add your API key
  // Convert coordinates to address (Reverse Geocoding)
  Future<Map<String, String?>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // Use Google Maps API if enabled and API key is set
    if (_useGoogleMapsAPI && _googleMapsApiKey != 'AIzaSyAAcBU-SiCt024WRyGx0Z0uOnyj1E753EA') {
      return await _getAddressFromGoogleMaps(latitude, longitude);
    }

    // Otherwise use built-in geocoding
    return await _getAddressFromBuiltInGeocoding(latitude, longitude);
  }

  // Google Maps Geocoding API (more accurate)
  Future<Map<String, String?>> _getAddressFromGoogleMaps(
    double latitude,
    double longitude,
  ) async {
    try {
      print('=== GOOGLE MAPS GEOCODING ===');
      print('Lat: $latitude, Lng: $longitude');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$_googleMapsApiKey&language=en',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final components = result['address_components'] as List;

          print('Google Maps returned ${components.length} address components');

          String? barangay;
          String? municipality;
          String? province;

          // Parse address components
          for (var component in components) {
            final types = component['types'] as List;
            final name = component['long_name'] as String;

            print('Component: $name - Types: $types');

            // Barangay is usually in sublocality_level_1 or neighborhood
            if (types.contains('sublocality_level_1') || types.contains('sublocality') || types.contains('neighborhood')) {
              barangay ??= name;
            }
            // Municipality is in locality
            else if (types.contains('locality')) {
              municipality ??= name;
            }
            // Province is in administrative_area_level_2
            else if (types.contains('administrative_area_level_2')) {
              province ??= name;
            }
          }

          final formattedAddress = result['formatted_address'] as String;

          print('\n=== GOOGLE MAPS RESULT ===');
          print('Barangay: $barangay');
          print('Municipality: $municipality');
          print('Province: $province');
          print('Full: $formattedAddress');

          // Get station name
          final station = getMunicipalityStation(municipality);

          return {
            'barangay': _cleanBarangayName(barangay),
            'municipality': municipality,
            'province': province,
            'fullAddress': formattedAddress,
            'station': station,
          };
        } else {
          print('Google Maps API error: ${data['status']}');
          return _createFallbackResult(latitude, longitude, 'Google Maps: ${data['status']}');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return _createFallbackResult(latitude, longitude, 'HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Google Maps API error: $e');
      print('Stack trace: $stackTrace');
      return _createFallbackResult(latitude, longitude, e.toString());
    }
  }

  // Built-in geocoding (fallback)
  Future<Map<String, String?>> _getAddressFromBuiltInGeocoding(
    double latitude,
    double longitude,
  ) async {
    try {
      print('=== BUILT-IN GEOCODING ===');
      print('Lat: $latitude, Lng: $longitude');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      print('Geocoding returned ${placemarks.length} results');

      if (placemarks.isEmpty) {
        print('No placemarks found');
        return _createFallbackResult(latitude, longitude, 'No placemarks returned');
      }

      // Log ALL data from first placemark to see what's available
      final place = placemarks.first;
      print('\n=== PLACEMARK DATA ===');
      print('name: "${place.name}"');
      print('street: "${place.street}"');
      print('subThoroughfare: "${place.subThoroughfare}"');
      print('thoroughfare: "${place.thoroughfare}"');
      print('subLocality: "${place.subLocality}"');
      print('locality: "${place.locality}"');
      print('subAdministrativeArea: "${place.subAdministrativeArea}"');
      print('administrativeArea: "${place.administrativeArea}"');
      print('postalCode: "${place.postalCode}"');
      print('country: "${place.country}"');
      print('isoCountryCode: "${place.isoCountryCode}"');

      // Try to extract barangay and municipality using multiple strategies
      String? barangay;
      String? municipality;
      String? province = place.administrativeArea;

      // Strategy 1: subLocality usually contains barangay in Philippines
      final subLoc = place.subLocality;
      if (subLoc != null && subLoc.trim().isNotEmpty) {
        barangay = subLoc;
        municipality = place.locality;
        print('\nStrategy 1 (subLocality): barangay=$barangay, municipality=$municipality');
      }
      // Strategy 2: Sometimes name contains barangay
      else {
        final placeName = place.name;
        if (placeName != null && placeName.toLowerCase().contains('barangay')) {
          barangay = placeName;
          municipality = place.locality ?? place.subAdministrativeArea;
          print('\nStrategy 2 (name contains barangay): barangay=$barangay, municipality=$municipality');
        }
        // Strategy 3: Use thoroughfare as barangay
        else {
          final thor = place.thoroughfare;
          if (thor != null && thor.trim().isNotEmpty) {
            barangay = thor;
            municipality = place.locality ?? place.subAdministrativeArea;
            print('\nStrategy 3 (thoroughfare): barangay=$barangay, municipality=$municipality');
          }
          // Strategy 4: Use name field
          else if (placeName != null && placeName.trim().isNotEmpty) {
            barangay = placeName;
            municipality = place.locality ?? place.subAdministrativeArea;
            print('\nStrategy 4 (name): barangay=$barangay, municipality=$municipality');
          }
          // Strategy 5: Fallback to locality
          else {
            barangay = place.locality;
            municipality = place.subAdministrativeArea;
            print('\nStrategy 5 (fallback): barangay=$barangay, municipality=$municipality');
          }
        }
      }

      // Build full address
      String fullAddress = [
        place.street,
        barangay,
        municipality,
        province,
        place.country,
      ].where((e) => e != null && e.isNotEmpty).join(', ');

      print('\n=== FINAL RESULT ===');
      print('Barangay: $barangay');
      print('Municipality: $municipality');
      print('Province: $province');
      print('Full: $fullAddress');

      final result = {
        'barangay': _cleanBarangayName(barangay),
        'municipality': municipality,
        'province': province,
        'fullAddress': fullAddress,
        'street': place.street,
        'postalCode': place.postalCode,
      };

      // If still no barangay, use fallback
      final barangayResult = result['barangay'];
      if (barangayResult == null || barangayResult.isEmpty) {
        print('\nWARNING: Could not extract barangay name');
        return _createFallbackResult(latitude, longitude, 'Barangay name not found in geocoding data');
      }

      return result;
    } catch (e, stackTrace) {
      print('Geocoding error: $e');
      print('Stack trace: $stackTrace');
      return _createFallbackResult(latitude, longitude, e.toString());
    }
  }

  // Create fallback result when geocoding fails
  Map<String, String?> _createFallbackResult(double lat, double lng, String error) {
    if (!isInPangasinan(lat, lng)) {
      return {
        'barangay': null,
        'municipality': null,
        'province': null,
        'fullAddress': 'Outside Pangasinan',
        'error': 'Location not in Pangasinan province',
      };
    }

    return {
      'barangay': null,
      'municipality': null,
      'province': 'Pangasinan',
      'fullAddress': 'Pangasinan (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})',
      'error': error,
    };
  }

  // Convert address/barangay to coordinates (Forward Geocoding)
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return null;
      }

      final location = locations.first;

      return Position(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    } catch (e) {
      print('Forward geocoding error: $e');
      return null;
    }
  }

  // Search for a specific barangay in a municipality
  Future<Position?> searchBarangay(String barangay, String municipality) async {
    try {
      // Try full Philippine address format
      String searchQuery = '$barangay, $municipality, Pangasinan, Philippines';
      return await getCoordinatesFromAddress(searchQuery);
    } catch (e) {
      print('Barangay search error: $e');
      return null;
    }
  }

  // Get distance between two coordinates
  double getDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Clean barangay name (remove "Barangay" prefix and road suffixes)
  String? _cleanBarangayName(String? name) {
    if (name == null) return null;

    // Remove common prefixes and suffixes
    String cleaned = name
        .replaceAll(RegExp(r'^Barangay\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Brgy\.?\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Barangay\s+Road$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Road$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Street$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Ave\.?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Avenue$', caseSensitive: false), '')
        .trim();

    return cleaned.toLowerCase();
  }

  // Validate if coordinates are within Pangasinan bounds
  bool isInPangasinan(double latitude, double longitude) {
    // Approximate bounds of Pangasinan
    const double minLat = 15.5;
    const double maxLat = 16.5;
    const double minLng = 119.8;
    const double maxLng = 120.6;

    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }

  // Get municipality/station based on coordinates
  // This maps municipalities to their police stations
  // IMPORTANT: Must match EXACTLY what's in the backend database
  String? getMunicipalityStation(String? municipality) {
    if (municipality == null) return null;

    final Map<String, String> stationMap = {
      // Cities (with "City" suffix to match database)
      'dagupan': 'Dagupan City',
      'dagupan city': 'Dagupan City',
      'alaminos': 'Alaminos City',
      'alaminos city': 'Alaminos City',
      'urdaneta': 'Urdaneta City',
      'urdaneta city': 'Urdaneta City',
      'san carlos': 'San Carlos City',
      'san carlos city': 'San Carlos City',

      // Municipalities (capitalized to match database)
      'lingayen': 'Lingayen',
      'bayambang': 'Bayambang',
      'malasiqui': 'Malasiqui',
      'manaoag': 'Manaoag',
      'binalonan': 'Binalonan',
      'pozorrubio': 'Pozorrubio',
      'rosales': 'Rosales',
      'umingan': 'Umingan',
      'tayug': 'Tayug',
      'sison': 'Sison',
      'mangaldan': 'Mangaldan',
      'bugallon': 'Bugallon',
      'mapandan': 'Mapandan',
      // Add more as needed
    };

    String municipalityLower = municipality.toLowerCase().trim();
    return stationMap[municipalityLower] ?? municipality; // Return original if not found
  }
}
