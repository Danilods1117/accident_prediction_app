import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/alert_card.dart';
import '../widgets/safety_tips_card.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'debug_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedMunicipality;
  String? _selectedBarangay;
  List<String> _municipalities = [];
  List<String> _barangays = [];
  List<String> _safetyTips = [];
  List<Map<String, dynamic>> _alternativeRoutes = [];
  bool _isLoadingMunicipalities = false;
  bool _isLoadingBarangays = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSafetyTips();
      _loadMunicipalities();
    });
  }

  Future<void> _loadSafetyTips() async {
    final apiService = context.read<ApiService>();
    final tips = await apiService.getSafetyTips();
    setState(() {
      _safetyTips = tips;
    });
  }

  Future<void> _loadMunicipalities() async {
    setState(() {
      _isLoadingMunicipalities = true;
    });

    final apiService = context.read<ApiService>();
    final municipalities = await apiService.getMunicipalities();

    setState(() {
      _municipalities = municipalities;
      _isLoadingMunicipalities = false;
    });
  }

  Future<void> _loadBarangays(String municipality) async {
    setState(() {
      _isLoadingBarangays = true;
      _selectedBarangay = null;
      _barangays = [];
    });

    final apiService = context.read<ApiService>();
    final barangays = await apiService.getBarangaysByMunicipality(municipality);

    setState(() {
      _barangays = barangays;
      _isLoadingBarangays = false;
    });
  }

  Future<void> _checkCurrentLocation() async {
    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();

    // Clear previous error
    locationService.clearError();

    // Get current location
    final position = await locationService.getCurrentLocation();

    if (position == null) {
      // Error already shown by location service
      if (mounted && locationService.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationService.error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _checkCurrentLocation,
            ),
          ),
        );
      }
      return;
    }

    // Check if we could determine the barangay
    if (locationService.currentLocationData?.barangay != null) {
      // Check with API
      final prediction = await locationService.checkBarangay(
        apiService,
        locationService.currentLocationData!.barangay!,
        locationService.currentLocationData!.station ?? 'unknown',
      );

      if (prediction != null) {
        _loadAlternativeRoutes(prediction.barangay);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found location: ${locationService.currentLocationData!.barangay!.toUpperCase()}'
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not determine your barangay. Please select manually using the dropdowns below.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkManualLocation() async {
    if (_selectedMunicipality == null || _selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both municipality and barangay'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();

    final prediction = await locationService.checkBarangay(
      apiService,
      _selectedBarangay!,
      _selectedMunicipality!,
    );

    if (prediction != null) {
      _loadAlternativeRoutes(prediction.barangay);
    }
  }

  Future<void> _loadAlternativeRoutes(String barangay) async {
    final apiService = context.read<ApiService>();
    final routes = await apiService.getAlternativeRoutes(barangay);
    setState(() {
      _alternativeRoutes = routes;
    });
  }

  void _toggleTracking() {
    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();
    final notificationService = context.read<NotificationService>();

    if (locationService.isTracking) {
      locationService.stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location tracking stopped'),
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      locationService.startTracking(apiService, notificationService);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location tracking started - You will be alerted when entering accident-prone areas'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Accident Alert',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Pangasinan',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            tooltip: 'View Map',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<LocationService>(
        builder: (context, locationService, child) {
          return RefreshIndicator(
            onRefresh: _checkCurrentLocation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Card(
                    color: locationService.isTracking
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            locationService.isTracking
                                ? Icons.gps_fixed
                                : Icons.gps_off,
                            size: 48,
                            color: locationService.isTracking
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            locationService.isTracking
                                ? 'TRACKING ACTIVE'
                                : 'TRACKING INACTIVE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: locationService.isTracking
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (locationService.currentLocationData?.barangay != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Current: ${locationService.currentLocationData!.barangay!.toUpperCase()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Tracking Control Button
                  ElevatedButton.icon(
                    onPressed: locationService.isLoading ? null : _toggleTracking,
                    icon: Icon(locationService.isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      locationService.isTracking ? 'Stop Tracking' : 'Start Tracking',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: locationService.isTracking
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Check Current Location
                  OutlinedButton.icon(
                    onPressed: locationService.isLoading ? null : _checkCurrentLocation,
                    icon: locationService.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Check Current Location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Manual Check Section
                  const Text(
                    'Check Specific Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Municipality Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedMunicipality,
                    decoration: const InputDecoration(
                      labelText: 'Select Municipality',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    hint: const Text('Choose a municipality'),
                    items: _municipalities.map((String municipality) {
                      return DropdownMenuItem<String>(
                        value: municipality,
                        child: Text(municipality),
                      );
                    }).toList(),
                    onChanged: _isLoadingMunicipalities ? null : (String? newValue) {
                      setState(() {
                        _selectedMunicipality = newValue;
                        _selectedBarangay = null;
                      });
                      if (newValue != null) {
                        _loadBarangays(newValue);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Barangay Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedBarangay,
                    decoration: InputDecoration(
                      labelText: 'Select Barangay',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: _isLoadingBarangays
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    ),
                    hint: Text(_selectedMunicipality == null
                      ? 'Select municipality first'
                      : 'Choose a barangay'),
                    items: _barangays.map((String barangay) {
                      return DropdownMenuItem<String>(
                        value: barangay,
                        child: Text(barangay),
                      );
                    }).toList(),
                    onChanged: (_selectedMunicipality == null || _isLoadingBarangays)
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedBarangay = newValue;
                          });
                        },
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: (locationService.isLoading || _selectedBarangay == null)
                      ? null
                      : _checkManualLocation,
                    icon: const Icon(Icons.search),
                    label: const Text('Check Location'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  // Error Message
                  if (locationService.error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationService.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Prediction Result
                  if (locationService.currentPrediction != null) ...[
                    const SizedBox(height: 24),
                    AlertCard(prediction: locationService.currentPrediction!),
                  ],

                  // Alternative Routes
                  if (_alternativeRoutes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Alternative Routes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._alternativeRoutes.map((route) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: route['recommended'] == true
                              ? Colors.green
                              : Colors.orange,
                          child: Icon(
                            route['recommended'] == true
                                ? Icons.check
                                : Icons.warning,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(route['route_name'] ?? ''),
                        subtitle: Text(
                          '${route['distance']} • ${route['estimated_time']}\nRisk: ${route['risk_level']}',
                        ),
                        isThreeLine: true,
                        trailing: route['recommended'] == true
                            ? const Chip(
                                label: Text('Recommended'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                    )),
                  ],

                  // Safety Tips
                  if (_safetyTips.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SafetyTipsCard(tips: _safetyTips),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
      // Debug test button (only visible in debug mode)
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Test'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}