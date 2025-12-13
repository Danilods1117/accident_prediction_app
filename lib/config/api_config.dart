class ApiConfig {
  // ========================================
  // DEPLOYMENT CONFIGURATION
  // ========================================

  // PRODUCTION: Replace this with your deployed API URL after deployment
  // Example: 'https://accident-prediction-api-xxxx.onrender.com'
  // Example: 'https://your-app.up.railway.app'
  static const String productionUrl = 'https://accident-prediction-api.onrender.com';

  // DEVELOPMENT: Localhost URLs for testing
  static const String localhostAndroid = 'http://10.0.2.2:5000'; // Android emulator
  static const String localhostIOS = 'http://localhost:5000'; // iOS simulator
  static const String localhostWeb = 'http://localhost:5000'; // Web browser

  // ========================================
  // ENVIRONMENT SELECTION
  // ========================================

  // Set this to true when testing locally, false when using deployed API
  static const bool isLocal = false;

  // Automatically select the correct base URL
  static String get baseUrl {
    if (isLocal) {
      // For local development - you can manually choose which one
      return localhostAndroid; // Change this based on your platform
    } else {
      return productionUrl;
    }
  }

  // ========================================
  // API ENDPOINTS
  // ========================================

  // Location Services
  static String get checkLocation => '$baseUrl/api/check_location';

  // Safety Information
  static String get safetyTips => '$baseUrl/api/safety_tips';
  static String get alternativeRoutes => '$baseUrl/api/alternative_routes';

  // Data Retrieval
  static String get statistics => '$baseUrl/api/statistics';
  static String get barangayList => '$baseUrl/api/barangay_list';
  static String get municipalities => '$baseUrl/api/municipalities';
  static String get barangays => '$baseUrl/api/barangays';

  // Health Check
  static String get health => '$baseUrl/api/health';

  // ========================================
  // HELPER METHODS
  // ========================================

  /// Get barangays for a specific municipality
  static String getBarangaysByMunicipality(String municipality) {
    return '$barangays?municipality=${Uri.encodeComponent(municipality)}';
  }

  /// Get safety tips by risk level
  static String getSafetyTipsByRiskLevel(String riskLevel) {
    return '$safetyTips?risk_level=${Uri.encodeComponent(riskLevel)}';
  }

  /// Get filtered barangay list (accident-prone only)
  static String getAccidentProneBarangays() {
    return '$barangayList?accident_prone_only=true';
  }

  // ========================================
  // API INFO
  // ========================================

  static const String apiVersion = '1.0.0';
  static const String apiName = 'Accident Prone Area Prediction API';

  /// Check if using production environment
  static bool get isProduction => !isLocal;

  /// Get current environment name
  static String get environmentName => isLocal ? 'Development' : 'Production';
}
