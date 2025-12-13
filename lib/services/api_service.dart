import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import '../config/api_config.dart';

class ApiService {
  // Using ApiConfig for dynamic URL switching between local and production
  // To switch environments, update isLocal in lib/config/api_config.dart
  static String get baseUrl => '${ApiConfig.baseUrl}/api';
  
  final http.Client _client = http.Client();

  // Check if a location is accident-prone
  Future<PredictionResult?> checkLocation(String barangay, String station) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/check_location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'barangay': barangay.toLowerCase().trim(),
          'station': station.toLowerCase().trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PredictionResult.fromJson(data);
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
      final response = await _client.get(
        Uri.parse('$baseUrl/barangay_list?accident_prone_only=$accidentProneOnly'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['barangays'] ?? []);
      } else {
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