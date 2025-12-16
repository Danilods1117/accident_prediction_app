import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import '../config/api_config.dart';

class ApiService {
  // Using ApiConfig for dynamic URL switching between local and production
  // To switch environments, update isLocal in lib/config/api_config.dart
  static String get baseUrl => '${ApiConfig.baseUrl}/api';
  
  final http.Client _client = http.Client();

  // Check if a location is accident-prone using ML model
  Future<PredictionResult?> checkLocation(String barangay, String station) async {
    try {
      // IMPORTANT: Don't lowercase station - backend expects exact capitalization
      final requestBody = {
        'barangay': barangay.toLowerCase().trim(),
        'station': station.trim(), // Keep original capitalization!
        'timestamp': DateTime.now().toIso8601String(), // Send current timestamp for ML model
        // Optional: Add vehicle_type and weather when available
        // 'vehicle_type': 'car',
        // 'weather': 'clear',
      };

      print('=== API REQUEST (ML Model) ===');
      print('URL: $baseUrl/check_location');
      print('Request body: $requestBody');

      final response = await _client.post(
        Uri.parse('$baseUrl/check_location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = PredictionResult.fromJson(data);
        print('Parsed result: isAccidentProne=${result.isAccidentProne}, riskLevel=${result.riskLevel}');
        return result;
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in checkLocation: $e');
      return null;
    }
  }

  // Get safety tips
  Future<List<String>> getSafetyTips({String riskLevel = 'HIGH'}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/safety_tips?risk_level=$riskLevel'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['tips'] ?? []);
      } else {
        return _getDefaultSafetyTips();
      }
    } catch (e) {
      print('Exception in getSafetyTips: $e');
      return _getDefaultSafetyTips();
    }
  }

  // Get alternative routes
  Future<List<Map<String, dynamic>>> getAlternativeRoutes(
    String currentBarangay,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/alternative_routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_barangay': currentBarangay,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['routes'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print('Exception in getAlternativeRoutes: $e');
      return [];
    }
  }

  // Get overall statistics
  Future<Map<String, dynamic>?> getStatistics() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/statistics'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Exception in getStatistics: $e');
      return null;
    }
  }

  // Get list of barangays
  Future<List<Map<String, dynamic>>> getBarangayList({
    bool accidentProneOnly = false,
  }) async {
    try {
      print('=== FETCHING BARANGAY LIST ===');
      print('URL: $baseUrl/barangay_list?accident_prone_only=$accidentProneOnly');

      final response = await _client.get(
        Uri.parse('$baseUrl/barangay_list?accident_prone_only=$accidentProneOnly'),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final barangays = List<Map<String, dynamic>>.from(data['barangays'] ?? []);

        print('Received ${barangays.length} barangays from API');

        // Show sample of what we received
        if (barangays.isNotEmpty) {
          print('Sample barangay data: ${barangays.first}');
        }

        // Normalize the data - backend uses 'name' field for barangay
        final normalizedBarangays = barangays.map((b) {
          // Create a copy with both 'barangay' and 'name' fields
          return {
            'barangay': b['name'] ?? b['barangay'] ?? 'Unknown',
            'name': b['name'] ?? b['barangay'] ?? 'Unknown',
            'station': b['station'],
            'accident_count': b['total_accidents'] ?? b['accident_count'] ?? 0,
            'fatal_accidents': b['fatal_accidents'] ?? 0,
            'is_accident_prone': b['is_accident_prone'] ?? false,
          };
        }).toList();

        // Filter out entries with "Unknown" names
        final validBarangays = normalizedBarangays.where((b) {
          final barangay = b['barangay'] as String?;
          return barangay != null &&
                 barangay.toLowerCase() != 'unknown' &&
                 barangay.trim().isNotEmpty;
        }).toList();

        print('Valid barangays after normalization: ${validBarangays.length}');
        if (validBarangays.isNotEmpty) {
          print('Sample normalized: ${validBarangays.first}');
        }

        return validBarangays;
      } else {
        print('Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception in getBarangayList: $e');
      return [];
    }
  }

  // Get list of municipalities
  Future<List<String>> getMunicipalities() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/municipalities'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['municipalities'] ?? []);
      } else {
        print('Error getting municipalities: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception in getMunicipalities: $e');
      return [];
    }
  }

  // Get barangays for a specific municipality
  Future<List<String>> getBarangaysByMunicipality(String municipality) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/barangays?municipality=${Uri.encodeComponent(municipality)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['barangays'] ?? []);
      } else {
        print('Error getting barangays: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception in getBarangaysByMunicipality: $e');
      return [];
    }
  }

  // Find nearest barangay from GPS coordinates
  Future<Map<String, String?>?> findNearestBarangay(double latitude, double longitude) async {
    try {
      print('=== FINDING NEAREST BARANGAY ===');
      print('Coordinates: $latitude, $longitude');

      final response = await _client.post(
        Uri.parse('$baseUrl/find_nearest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Nearest barangay: ${data['barangay']}, ${data['municipality']}');

        return {
          'barangay': data['barangay'] as String?,
          'municipality': data['municipality'] as String?,
          'station': data['station'] as String?,
          'distance': data['distance']?.toString(),
        };
      } else {
        print('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception in findNearestBarangay: $e');
      return null;
    }
  }

  // Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      } else {
        return false;
      }
    } catch (e) {
      print('Exception in healthCheck: $e');
      return false;
    }
  }

  // Default safety tips (offline fallback)
  List<String> _getDefaultSafetyTips() {
    return [
      '🚗 Reduce your speed and stay alert',
      '👀 Watch for pedestrians and motorcycles',
      '🌙 Use headlights even during daytime',
      '📱 Avoid using mobile phones while driving',
      '⚡ Maintain safe distance from other vehicles',
      '🛑 Obey all traffic signs and signals',
      '☔ Drive extra carefully during rain',
      '🚸 Be extra cautious near schools and markets',
    ];
  }

  void dispose() {
    _client.close();
  }
}