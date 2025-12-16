import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';
import '../models/prediction_result.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'geocoding_service.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  LocationData? _currentLocationData;
  PredictionResult? _currentPrediction;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _error;

  // DEBUG MODE - Set to true to test notifications from home
  bool _debugMode = kDebugMode; // Automatically true in debug builds

  // Geocoding service for converting coordinates to addresses
  final GeocodingService _geocodingService = GeocodingService();

  // Test barangays for debug mode (only used when simulating)
  final Map<String, Map<String, dynamic>> _testBarangayCoordinates = {
    'poblacion': {'lat': 16.0434, 'lng': 120.3328, 'station': 'Dagupan City'},
    'lucao': {'lat': 16.0468, 'lng': 120.3406, 'station': 'Dagupan City'},
    'pantal': {'lat': 16.0510, 'lng': 120.3442, 'station': 'Dagupan City'},
    // Add more test barangays as needed
  };

  // Getters
  Position? get currentPosition => _currentPosition;
  LocationData? get currentLocationData => _currentLocationData;
  PredictionResult? get currentPrediction => _currentPrediction;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get debugMode => _debugMode;

  // Get list of available barangays for testing
  List<String> get availableBarangays => _testBarangayCoordinates.keys.toList();

  // Request location permissions
  Future<bool> requestPermissions() async {
    try {
      // Request location permission
      final locationStatus = await Permission.location.request();
      
      if (locationStatus.isGranted) {
        // Request background location for Android 10+
        if (await Permission.locationAlways.isDenied) {
          await Permission.locationAlways.request();
        }
        
        // Request notification permission for Android 13+
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
        
        return true;
      } else if (locationStatus.isPermanentlyDenied) {
        _error = 'Location permission permanently denied. Please enable in settings.';
        notifyListeners();
        await openAppSettings();
        return false;
      } else {
        _error = 'Location permission denied';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error requesting permissions: $e';
      notifyListeners();
      return false;
    }
  }

  // Check if location services are enabled
  Future<bool> checkLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Location services are disabled. Please enable GPS.';
      notifyListeners();
      return false;
    }
    return true;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (!await checkLocationService()) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      if (!await requestPermissions()) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Note: getCurrentLocation doesn't have apiService parameter
      // Will use geocoding only
      await _updateLocationData();
      
      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = 'Error getting location: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Start continuous tracking
  Future<void> startTracking(ApiService apiService, NotificationService notificationService) async {
    if (_isTracking) return;

    if (!await checkLocationService() || !await requestPermissions()) {
      return;
    }

    _isTracking = true;
    _error = null;
    notifyListeners();

    // Configure location settings for continuous tracking
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters
    );

    try {
      Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) async {
          _currentPosition = position;
          await _updateLocationData(apiService: apiService);

          // Check if location is accident-prone
          if (_currentLocationData?.barangay != null) {
            await _checkAndNotify(
              apiService,
              notificationService,
              _currentLocationData!.barangay!,
              _currentLocationData!.station ?? 'unknown',
            );
          }

          notifyListeners();
        },
        onError: (error) {
          _error = 'Tracking error: $error';
          _isTracking = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Error starting tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  // Stop tracking
  void stopTracking() {
    _isTracking = false;
    notifyListeners();
  }

  // Update location data based on current position
  // Uses LocationIQ geocoding for accurate location detection
  Future<void> _updateLocationData({ApiService? apiService}) async {
    if (_currentPosition == null) return;

    String? barangay;
    String? municipality;
    String? station;

    try {
      // Get location using LocationIQ geocoding
      print('Getting location from LocationIQ...');
      final addressData = await _geocodingService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      barangay = addressData['barangay'];
      municipality = addressData['municipality'];

      // Get station name based on municipality
      station = _geocodingService.getMunicipalityStation(municipality);

      print('LocationIQ result: Barangay: $barangay, Municipality: $municipality, Station: $station');

      // Validate if location is in Pangasinan
      bool isInPangasinan = _geocodingService.isInPangasinan(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (!isInPangasinan) {
        print('⚠️  Warning: Location is outside Pangasinan bounds');
      }

      _currentLocationData = LocationData(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        barangay: barangay,
        station: station,
      );

      if (kDebugMode) {
        print('Final location: Barangay: $barangay, Station: $station');
      }
    } catch (e) {
      print('Error updating location data: $e');

      // Fallback to basic location data without barangay info
      _currentLocationData = LocationData(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        barangay: null,
        station: null,
      );
    }
  }

  // Check location and send notification if accident-prone
  Future<void> _checkAndNotify(
    ApiService apiService,
    NotificationService notificationService,
    String barangay,
    String station,
  ) async {
    try {
      // Only check if it's a new barangay
      if (_currentPrediction?.barangay == barangay) {
        return;
      }

      final prediction = await apiService.checkLocation(barangay, station);
      
      if (prediction != null) {
        _currentPrediction = prediction;
        
        // Send notification if accident-prone
        if (prediction.isAccidentProne) {
          await notificationService.showAccidentAlert(
            barangay: prediction.barangay,
            message: prediction.message,
            riskLevel: prediction.riskLevel,
          );
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error checking location: $e');
    }
  }

  // Manual check for a specific barangay
  Future<PredictionResult?> checkBarangay(
    ApiService apiService,
    String barangay,
    String station,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final prediction = await apiService.checkLocation(barangay, station);
      
      if (prediction != null) {
        _currentPrediction = prediction;
      } else {
        _error = 'Could not check location. Please try again.';
      }
      
      _isLoading = false;
      notifyListeners();
      return prediction;
    } catch (e) {
      _error = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset all data
  void reset() {
    _currentPosition = null;
    _currentLocationData = null;
    _currentPrediction = null;
    _isTracking = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // DEBUG: Toggle debug mode
  void toggleDebugMode() {
    _debugMode = !_debugMode;
    notifyListeners();
  }

  // DEBUG: Simulate entering a barangay (for testing from home)
  Future<void> simulateEnteringBarangay(
    ApiService apiService,
    NotificationService notificationService,
    String barangayName,
  ) async {
    if (!_debugMode) {
      print('Debug mode is disabled. Enable it first.');
      return;
    }

    final barangayData = _testBarangayCoordinates[barangayName.toLowerCase()];
    if (barangayData == null) {
      _error = 'Barangay "$barangayName" not found in test data';
      notifyListeners();
      return;
    }

    print('====================================');
    print('DEBUG: Simulating entering $barangayName');
    print('Station: ${barangayData['station']}');
    print('Coordinates: ${barangayData['lat']}, ${barangayData['lng']}');
    print('====================================');

    // Simulate position at barangay
    _currentPosition = Position(
      latitude: barangayData['lat'],
      longitude: barangayData['lng'],
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

    _currentLocationData = LocationData(
      latitude: barangayData['lat'],
      longitude: barangayData['lng'],
      barangay: barangayName.toLowerCase(),
      station: barangayData['station'],
    );

    notifyListeners();

    // Trigger notification check
    print('Calling API to check if accident-prone...');
    await _checkAndNotify(
      apiService,
      notificationService,
      barangayName.toLowerCase(),
      barangayData['station'],
    );

    print('DEBUG: Simulation complete for $barangayName');
    print('====================================');
  }
}