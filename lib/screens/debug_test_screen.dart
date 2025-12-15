import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/geocoding_service.dart';

class DebugTestScreen extends StatefulWidget {
  const DebugTestScreen({super.key});

  @override
  State<DebugTestScreen> createState() => _DebugTestScreenState();
}

class _DebugTestScreenState extends State<DebugTestScreen> {
  List<Map<String, dynamic>> _accidentProneBarangays = [];
  bool _loadingBarangays = false;
  String? _apiError;

  // For testing with real municipalities and barangays
  List<String> _municipalities = [];
  String? _selectedMunicipality;
  List<String> _barangaysForTest = [];
  bool _loadingMunicipalities = false;

  @override
  void initState() {
    super.initState();
    _loadAccidentProneBarangays();
    _loadMunicipalitiesForTest();
  }

  Future<void> _loadAccidentProneBarangays() async {
    setState(() {
      _loadingBarangays = true;
      _apiError = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final barangays = await apiService.getBarangayList(accidentProneOnly: true);

      setState(() {
        _accidentProneBarangays = barangays;
        _loadingBarangays = false;
      });

      print('Loaded ${barangays.length} accident-prone barangays from API');
    } catch (e) {
      setState(() {
        _apiError = 'Failed to load accident-prone barangays: $e';
        _loadingBarangays = false;
      });
      print('Error loading barangays: $e');
    }
  }

  Future<void> _loadMunicipalitiesForTest() async {
    setState(() {
      _loadingMunicipalities = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final municipalities = await apiService.getMunicipalities();

      setState(() {
        _municipalities = municipalities;
        _loadingMunicipalities = false;
      });

      print('Loaded ${municipalities.length} municipalities for testing');

      // Auto-select first municipality and load its barangays
      if (municipalities.isNotEmpty && mounted) {
        _selectedMunicipality = municipalities.first;
        _loadBarangaysForTest(municipalities.first);
      }
    } catch (e) {
      setState(() {
        _loadingMunicipalities = false;
      });
      print('Error loading municipalities: $e');
    }
  }

  Future<void> _loadBarangaysForTest(String municipality) async {
    try {
      final apiService = context.read<ApiService>();
      final barangays = await apiService.getBarangaysByMunicipality(municipality);

      setState(() {
        _barangaysForTest = barangays;
      });

      print('Loaded ${barangays.length} barangays for $municipality');
    } catch (e) {
      print('Error loading barangays for test: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Test Mode'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccidentProneBarangays,
            tooltip: 'Refresh barangay list',
          ),
        ],
      ),
      body: Consumer<LocationService>(
        builder: (context, locationService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Debug Mode Status
                Card(
                  color: locationService.debugMode ? Colors.orange[100] : Colors.grey[200],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          locationService.debugMode ? Icons.bug_report : Icons.bug_report_outlined,
                          size: 48,
                          color: locationService.debugMode ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locationService.debugMode ? 'Debug Mode: ON' : 'Debug Mode: OFF',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Test barangay notifications from home without GPS spoofing',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Test:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('1. Tap any barangay button below'),
                        Text('2. App will simulate entering that barangay'),
                        Text('3. If accident-prone, you\'ll get a notification'),
                        Text('4. Check the notification panel'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Current Status
                if (locationService.currentLocationData != null) ...[
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Simulated Location:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Barangay: ${locationService.currentLocationData!.barangay ?? "Unknown"}'),
                          Text('Station: ${locationService.currentLocationData!.station ?? "Unknown"}'),
                          const SizedBox(height: 8),
                          if (locationService.currentPrediction != null) ...[
                            Text(
                              'Status: ${locationService.currentPrediction!.isAccidentProne ? "⚠️ ACCIDENT-PRONE" : "✅ SAFE"}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: locationService.currentPrediction!.isAccidentProne
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            if (locationService.currentPrediction!.message.isNotEmpty)
                              Text('Message: ${locationService.currentPrediction!.message}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Test Barangays from API
                const Text(
                  'Accident-Prone Barangays from API:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (_loadingBarangays)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_apiError != null)
                  Card(
                    color: Colors.red[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            _apiError!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadAccidentProneBarangays,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_accidentProneBarangays.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No accident-prone barangays found in database.\nUsing hardcoded test barangays instead.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._accidentProneBarangays.take(5).map((barangayData) {
                    final barangay = barangayData['barangay'] as String? ?? 'Unknown';
                    final station = barangayData['station'] as String? ?? 'unknown';
                    final accidentCount = barangayData['accident_count'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        onPressed: locationService.isLoading
                            ? null
                            : () => _simulateBarangayDirect(context, barangay, station),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    barangay.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Station: $station • $accidentCount accidents',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Hardcoded Test Barangays (fallback)
                const Text(
                  'Hardcoded Test Barangays:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                // Generate buttons for each barangay
                ...locationService.availableBarangays.map((barangay) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: OutlinedButton.icon(
                      onPressed: locationService.isLoading
                          ? null
                          : () => _simulateBarangay(context, barangay),
                      icon: const Icon(Icons.location_on, size: 18),
                      label: Text(
                        barangay.toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Quick Test Section with real municipality data
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Quick Test (Works from Laptop)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select a municipality and barangay to test notifications:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),

                        // Municipality dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedMunicipality,
                          decoration: const InputDecoration(
                            labelText: 'Municipality',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _municipalities.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMunicipality = value;
                              });
                              _loadBarangaysForTest(value);
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // Barangay buttons
                        if (_barangaysForTest.isNotEmpty) ...[
                          const Text('Tap any barangay to test:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _barangaysForTest.take(6).map((barangay) {
                              return ElevatedButton(
                                onPressed: () => _testBarangayFromAPI(
                                  context,
                                  barangay,
                                  _selectedMunicipality ?? 'unknown'
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(barangay.toUpperCase()),
                              );
                            }).toList(),
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Select a municipality to see barangays'),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Test REAL GPS Location
                ElevatedButton.icon(
                  onPressed: () => _testRealGPS(context),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Test Real GPS Location Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: 12),

                // Diagnostic: Show ALL barangays (including safe ones)
                ElevatedButton.icon(
                  onPressed: _showAllBarangays,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Show All Barangays in Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: 16),

                // Reset button
                OutlinedButton.icon(
                  onPressed: () {
                    locationService.reset();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset complete')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Test'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _simulateBarangay(BuildContext context, String barangay) async {
    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();
    final notificationService = context.read<NotificationService>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulating entering $barangay...'),
        duration: const Duration(seconds: 2),
      ),
    );

    await locationService.simulateEnteringBarangay(
      apiService,
      notificationService,
      barangay,
    );

    if (context.mounted) {
      final prediction = locationService.currentPrediction;
      if (prediction != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prediction.isAccidentProne
                  ? '⚠️ ALERT: ${prediction.message}'
                  : '✅ Safe area',
            ),
            backgroundColor: prediction.isAccidentProne ? Colors.red : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _simulateBarangayDirect(BuildContext context, String barangay, String station) async {
    final apiService = context.read<ApiService>();
    final notificationService = context.read<NotificationService>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Testing $barangay, $station...'),
        duration: const Duration(seconds: 2),
      ),
    );

    print('====================================');
    print('DIRECT TEST: $barangay, $station');
    print('====================================');

    // Directly check with API using the barangay name from database
    final prediction = await apiService.checkLocation(barangay, station);

    if (prediction != null && context.mounted) {
      print('Result: isAccidentProne=${prediction.isAccidentProne}, message=${prediction.message}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prediction.isAccidentProne
                ? '⚠️ ALERT: ${prediction.message}'
                : '✅ ${prediction.message}',
          ),
          backgroundColor: prediction.isAccidentProne ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Show notification if accident-prone
      if (prediction.isAccidentProne) {
        await notificationService.showAccidentAlert(
          barangay: barangay,
          message: prediction.message,
          riskLevel: prediction.riskLevel,
        );
      }
    }
  }

  Future<void> _testBarangayFromAPI(BuildContext context, String barangay, String municipality) async {
    final apiService = context.read<ApiService>();
    final notificationService = context.read<NotificationService>();

    print('====================================');
    print('TESTING: $barangay, $municipality');
    print('====================================');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Testing $barangay...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Use geocoding service to get correct station name
      final geocodingService = GeocodingService();
      final station = geocodingService.getMunicipalityStation(municipality) ?? municipality;

      print('Using station: $station (from municipality: $municipality)');

      // Check with API
      final prediction = await apiService.checkLocation(barangay, station);

      if (prediction != null && context.mounted) {
        print('Result: isAccidentProne=${prediction.isAccidentProne}');
        print('Message: ${prediction.message}');

        // Show result in dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              prediction.isAccidentProne ? '⚠️ ACCIDENT-PRONE!' : '✅ SAFE',
              style: TextStyle(
                color: prediction.isAccidentProne ? Colors.red : Colors.green,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Barangay: $barangay'),
                Text('Municipality: $municipality'),
                const SizedBox(height: 12),
                Text('Risk Level: ${prediction.riskLevel}'),
                Text('Accidents: ${prediction.accidentCount}'),
                if (prediction.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(prediction.message),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Send notification if accident-prone
        if (prediction.isAccidentProne) {
          await notificationService.showAccidentAlert(
            barangay: barangay,
            message: prediction.message,
            riskLevel: prediction.riskLevel,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Check your notifications!'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get prediction from API'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error testing barangay: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testRealGPS(BuildContext context) async {
    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();
    final notificationService = context.read<NotificationService>();

    print('====================================');
    print('TESTING REAL GPS LOCATION');
    print('====================================');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting your real GPS location...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Start location service
      await locationService.startTracking(apiService, notificationService);

      // Wait a bit for location to be acquired
      await Future.delayed(const Duration(seconds: 2));

      if (!context.mounted) return;

      final position = locationService.currentPosition;
      final locationData = locationService.currentLocationData;

      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get GPS location. Check permissions.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        print('ERROR: Could not get GPS position');
        return;
      }

      print('GPS Position: ${position.latitude}, ${position.longitude}');
      print('Location Data: $locationData');

      String message = 'GPS Location:\n'
          'Lat: ${position.latitude.toStringAsFixed(6)}\n'
          'Lng: ${position.longitude.toStringAsFixed(6)}\n';

      if (locationData != null) {
        message += '\nBarangay: ${locationData.barangay ?? "Unknown"}\n'
            'Station: ${locationData.station ?? "Unknown"}';

        // Check if accident-prone
        final prediction = locationService.currentPrediction;
        if (prediction != null) {
          message += '\n\nStatus: ${prediction.isAccidentProne ? "⚠️ ACCIDENT-PRONE!" : "✅ SAFE"}';
          message += '\nMessage: ${prediction.message}';
        }
      } else {
        message += '\nCould not determine barangay (geocoding failed)';
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Real GPS Location'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      print('Error testing GPS: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showAllBarangays() async {
    print('====================================');
    print('FETCHING ALL BARANGAYS (including safe ones)');
    print('====================================');

    try {
      final apiService = context.read<ApiService>();

      // Get ALL barangays (not just accident-prone)
      final allBarangays = await apiService.getBarangayList(accidentProneOnly: false);

      print('Total barangays in database: ${allBarangays.length}');

      if (allBarangays.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No barangays found in database!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show dialog with all barangays
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('All Barangays (${allBarangays.length})'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allBarangays.length,
                itemBuilder: (context, index) {
                  final b = allBarangays[index];
                  final barangay = b['barangay'] as String? ?? 'Unknown';
                  final station = b['station'] as String? ?? 'unknown';
                  final accidentCount = b['accident_count'] as int? ?? 0;
                  final isAccidentProne = b['is_accident_prone'] as bool? ?? false;

                  return ListTile(
                    leading: Icon(
                      isAccidentProne ? Icons.warning : Icons.check_circle,
                      color: isAccidentProne ? Colors.red : Colors.green,
                    ),
                    title: Text(barangay),
                    subtitle: Text('Station: $station'),
                    trailing: Text('$accidentCount accidents'),
                    onTap: () {
                      Navigator.pop(context);
                      _simulateBarangayDirect(context, barangay, station);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      // Also print to console
      print('First 10 barangays:');
      for (int i = 0; i < allBarangays.length && i < 10; i++) {
        print('  ${i + 1}. ${allBarangays[i]}');
      }

    } catch (e) {
      print('Error fetching all barangays: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
