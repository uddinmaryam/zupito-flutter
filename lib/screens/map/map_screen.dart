// lib/screens/map/map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Import for 'pi' and Random
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Make sure this is still needed if you only use 'location'
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // Correct way to import LatLng and Distance
import 'package:location/location.dart'; // For real-time location and permissions
import 'package:provider/provider.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/providers/theme_provider.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/otp_socket_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/services/station_service.dart';
import 'package:zupito/utils/constants.dart';
import 'widgets/station_bottom_sheet.dart'; // Ensure this path is correct

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  final Location _location = Location();
  final List<Station> _stations = []; // This holds all loaded stations
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  UserProfile? _userProfile;
  Marker? _currentLocationMarker;
  Timer? _stationRefreshTimer;

  bool _isRideActive = false;
  bool _isLoading = true;
  String? _activeBikeCode;
  String? _activeRideId;
  LatLng? _activeBikeLocation; // This is the dummy GPS location of the bike
  DateTime? _rideEndTime;
  Duration _remainingRideTime = Duration.zero;
  Timer? _rideCountdownTimer;
  Timer? _dummyBikeMovementTimer;
  final Random _random = Random();

  Station? _selectedStation; // Correctly defined as a state variable

  // Dummy bike movement variables (already in place)
  double _dummyBikeCurrentSpeed = 0.0;
  double _dummyBikeHeading = 0.0;
  Station? _dummyBikeTargetStation;

  // Define Lalitpur Boundary (approximate polygon)
  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127), // North-West (e.g., Godawari-side)
    LatLng(27.6815, 85.3293), // North-East (e.g., Koteshwor-side)
    LatLng(27.6677, 85.3324), // East (e.g., Gwarko-side)
    LatLng(27.6545, 85.3178), // South-East (e.g., Lubhu-side)
    LatLng(27.6619, 85.2952), // South-West (e.g., Bungamati-side)
    LatLng(27.6804, 85.2918), // West (e.g., Balkhu-side)
    LatLng(27.6901, 85.2991), // North-West (closer to ring road)
  ];

  final double _stationReturnRadiusMeters = 50.0; // 50 meters radius

  @override
  void initState() {
    super.initState();
    _initialize();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0, end: 80).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  void _initialize() async {
    await _loadUserProfile();
    await _initLocation();
    await _loadStations(); // Ensure stations are loaded before potential use
    _stationRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadStations(),
    );
  }

  Future<void> _moveToNearestStation() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Location not available. Please enable GPS."),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/stations/nearest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': _currentLocation!.latitude,
          'lon': _currentLocation!.longitude,
          'k': 2, // Request 2 nearest stations
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> nearestList = json['nearestStations'];

        if (nearestList.isNotEmpty) {
          final nearestId = nearestList.first['id'];

          // Find full station info from previously loaded _stations list
          final fullStation = _stations.firstWhere(
            (s) => s.id == nearestId,
            orElse: () {
              // Fallback in case it's not found (e.g., race condition)
              final fallback = nearestList.first;
              return Station(
                id: fallback['id'],
                name: fallback['name'],
                lat: fallback['latitude'],
                lng: fallback['longitude'],
                capacity: fallback['capacity'] ?? 10,
                bikes:
                    [], // Bikes not available in nearest response, assume empty
                description: '',
              );
            },
          );

          // Move map to that station
          _mapController.move(LatLng(fullStation.lat, fullStation.lng), 17.0);

          // Open bottom sheet for that station
          _onStationTap(fullStation);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ No nearby station found. Try again later."),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to find nearest station: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error finding nearest station: ${e.toString()}"),
        ),
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final data = await _secureStorage.readUser();
    if (data != null) {
      final json = jsonDecode(data);
      final user = UserProfile.fromJson(json);
      setState(() => _userProfile = user);
      OtpSocketService().connect(user.id.toString(), context: context);
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❌ Location services are disabled. Please enable them.",
            ),
          ),
        );
        return;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❌ Location permission denied. Cannot show your location.",
            ),
          ),
        );
        return;
      }
    }

    final loc = await _location.getLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final userLoc = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _currentLocation = userLoc;
        // The _currentLocationMarker is now drawn directly in MarkerLayer
        // _currentLocationMarker = Marker(...) is no longer needed here.
      });

      // Move map to user's current location initially
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userLoc, 15);
      });
    }

    // Listen for real-time location updates for the user
    _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final updatedLoc = LatLng(loc.latitude!, loc.longitude!);
        setState(() {
          _currentLocation = updatedLoc;
          // The _currentLocationMarker is now drawn directly in MarkerLayer
        });
      }
    });
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      debugPrint("🔥 Stations fetched: ${stations.length}");
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading stations: $e")));
    }
  }

  void _onStationTap(Station station) async {
    if (_userProfile == null || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "User profile or current location not available. Please try again.",
          ),
        ),
      );
      return;
    }
    // Check if a ride is already active
    if (_isRideActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You have an active ride. Please end it first."),
        ),
      );
      return;
    }

    // Set the selected station immediately when tapped
    setState(() {
      _selectedStation = station;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        _userProfile!,
        onRideStartConfirmed: (code, rideId, endTime, bikeStartLocation) async {
          setState(() {
            _isRideActive = true;
            _activeBikeCode = code;
            _activeRideId = rideId;
            _rideEndTime = endTime;
            _activeBikeLocation =
                bikeStartLocation; // Bike starts at the station
          });

          // Move map to the bike's starting location and zoom in
          _mapController.move(bikeStartLocation, 17.0);

          _startRideCountdown();
          // Call dummy movement. _activeBikeLocation is already set to bikeStartLocation.
          // _selectedStation is also correctly set here from _onStationTap.
          _startDummyBikeMovement();
        },
      ),
    );

    // Clear selected station when sheet is dismissed
    setState(() {
      _selectedStation = null;
    });
    _loadStations(); // Refresh stations after sheet is dismissed
  }

  void _startRideCountdown() {
    _rideCountdownTimer?.cancel();
    _remainingRideTime = _rideEndTime!.difference(DateTime.now());
    _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingRideTime = _rideEndTime!.difference(DateTime.now());
        if (_remainingRideTime.isNegative) {
          timer.cancel();
          _endRide(manualEnd: false); // Auto-end if time runs out
        }
      });
    });
  }

  /// Simulates bike movement, now with target-seeking behavior towards a station.
  void _startDummyBikeMovement() async {
    _dummyBikeMovementTimer?.cancel(); // Cancel any existing timer

    // _activeBikeLocation is guaranteed to be set by _onRideStartConfirmed before this is called.
    final LatLng initialLocation = _activeBikeLocation!;

    // --- Determine Target Station ---
    // Ensure _stations (your main station list) is populated
    if (_stations.isEmpty) {
      try {
        await _loadStations(); // Try to load stations if empty
      } catch (e) {
        print("Error fetching stations for dummy movement target: $e");
        // Fallback: if stations can't be fetched, the dummy bike will just random walk
      }
    }

    // Pick a target station:
    final List<Station> otherStations = _stations
        .where(
          (s) => s.id != _selectedStation?.id,
        ) // Use _selectedStation for the starting station ID
        .toList();

    if (otherStations.isNotEmpty) {
      _dummyBikeTargetStation =
          otherStations[_random.nextInt(otherStations.length)];
      print("Dummy bike target: ${_dummyBikeTargetStation?.name}");
    } else {
      // Fallback to the starting station if no other stations are available
      _dummyBikeTargetStation = _selectedStation;
      print(
        "No other stations available, dummy bike target: ${_dummyBikeTargetStation?.name}",
      );
    }
    // --- END Determine Target Station ---

    // Initialize speed and heading
    _dummyBikeCurrentSpeed =
        0.00005 + _random.nextDouble() * 0.00005; // Speed in degrees/sec
    _dummyBikeHeading = _random.nextDouble() * 2 * pi; // Initial random heading

    final double maxSpeedChange = 0.000005;
    final double maxHeadingChange =
        0.1; // Reduced for smoother turns towards target
    final double targetApproachFactor =
        0.05; // How strongly to steer towards the target

    _dummyBikeMovementTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!_isRideActive || _activeBikeLocation == null) {
        timer.cancel();
        return;
      }

      final LatLng current = _activeBikeLocation!;

      // --- Check for Arrival at Target Station ---
      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.lat,
          _dummyBikeTargetStation!.lng,
        );
        final Distance distance = const Distance(); // From latlong2 package

        // If very close to the target station (e.g., within 20 meters)
        if (distance(current, targetLatLng) < 20) {
          setState(() {
            _activeBikeLocation =
                targetLatLng; // Snap to exact station location
            _dummyBikeCurrentSpeed = 0.0; // Stop movement
            _mapController.move(
              targetLatLng,
              _mapController.zoom,
            ); // Center map
          });
          print(
            "Dummy bike arrived at target station: ${_dummyBikeTargetStation!.name}",
          );
          // For now, we'll let the timer continue but the bike will be stationary.
          // The user still needs to manually end the ride via the button.
          return; // Skip further movement calculation for this step
        }
      }
      // --- END Check for Arrival ---

      // 1. Randomly adjust speed (within realistic range for a bike)
      _dummyBikeCurrentSpeed += (_random.nextDouble() * 2 - 1) * maxSpeedChange;
      _dummyBikeCurrentSpeed = _dummyBikeCurrentSpeed.clamp(0.00002, 0.00015);

      // 2. Adjust heading: Bias towards target station if set
      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.lat,
          _dummyBikeTargetStation!.lng,
        );
        final Distance distance = const Distance();

        // Calculate the bearing from current location to target
        double bearingToTarget = distance.bearing(current, targetLatLng);
        // Convert bearing to radians (bearing is usually 0-360 degrees)
        bearingToTarget = bearingToTarget * (pi / 180.0);

        // Calculate the difference between current heading and target bearing
        double angleDiff = bearingToTarget - _dummyBikeHeading;
        // Normalize angle difference to be within -PI to PI
        if (angleDiff > pi) angleDiff -= 2 * pi;
        if (angleDiff < -pi) angleDiff += 2 * pi;

        // Adjust current heading: mostly towards target, but with some randomness
        _dummyBikeHeading += angleDiff * targetApproachFactor;
        _dummyBikeHeading +=
            (_random.nextDouble() * 2 - 1) *
            maxHeadingChange *
            0.5; // Smaller random wobble
        _dummyBikeHeading =
            _dummyBikeHeading % (2 * pi); // Keep heading within 0 to 2*PI
      } else {
        // If no target (e.g., stations failed to load), just random walk
        _dummyBikeHeading += (_random.nextDouble() * 2 - 1) * maxHeadingChange;
        _dummyBikeHeading = _dummyBikeHeading % (2 * pi);
      }

      // 3. Calculate new position based on current speed and heading
      final double latMove = cos(_dummyBikeHeading) * _dummyBikeCurrentSpeed;
      final double currentLatitudeRadians = current.latitude * (pi / 180.0);
      final double lngCorrectionFactor = cos(currentLatitudeRadians).abs();
      final double lngMove = sin(_dummyBikeHeading) * _dummyBikeCurrentSpeed;

      final LatLng newLocation = LatLng(
        current.latitude + latMove,
        current.longitude + (lngMove / lngCorrectionFactor),
      );

      setState(() {
        _activeBikeLocation = newLocation;
      });

      // Move the map to follow the bike
      _mapController.move(newLocation, _mapController.zoom);
    });
  }

  // New Helper: Point-in-polygon check for Lalitpur boundary
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 =
          polygon[(i + 1) % polygon.length]; // Connect last point to first

      // Check if point.longitude is between p1.longitude and p2.longitude (exclusive)
      if (((p1.longitude <= point.longitude &&
                  point.longitude < p2.longitude) ||
              (p2.longitude <= point.longitude &&
                  point.longitude < p1.longitude)) &&
          (point.latitude <
              (p2.latitude - p1.latitude) *
                      (point.longitude - p1.longitude) /
                      (p2.longitude - p1.longitude) +
                  p1.latitude)) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1; // Odd number of intersections means inside
  }

  // New Helper: Check if a point is near any station
  Station? _isNearStation(LatLng point) {
    final Distance distance = const Distance(); // From latlong2 package
    for (var station in _stations) {
      final stationLatLng = LatLng(station.lat, station.lng);
      final double dist = distance(point, stationLatLng);
      debugPrint("Distance to ${station.name}: $dist meters");
      if (dist <= _stationReturnRadiusMeters) {
        return station;
      }
    }
    return null;
  }

  Future<void> _endRide({bool manualEnd = true}) async {
    _rideCountdownTimer?.cancel();
    _dummyBikeMovementTimer?.cancel();

    if (_activeRideId == null || _activeBikeLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "❌ Missing ride or bike location data. Cannot end ride.",
          ),
        ),
      );
      // Reset ride state if data is missing for some reason
      setState(() {
        _isRideActive = false;
        _activeBikeCode = null;
        _activeRideId = null;
        _activeBikeLocation = null;
        _rideEndTime = null;
        _remainingRideTime = Duration.zero;
      });
      return;
    }

    LatLng finalEndLocation =
        _activeBikeLocation!; // The dummy bike location is the "real" end location
    Station? returnedStation = _isNearStation(finalEndLocation);
    bool isInLalitpur = _isPointInPolygon(finalEndLocation, _lalitpurBoundary);

    String? endStationId;
    String returnMessage = '';
    String penaltyInfo = '';
    bool canEndRide = false;

    if (returnedStation != null) {
      endStationId = returnedStation.id;
      returnMessage = '✅ Ride ended at ${returnedStation.name} station!';
      canEndRide = true;
    } else if (isInLalitpur) {
      // User is within Lalitpur but not at a station. This is allowed as per new rules.
      returnMessage = '✅ Ride ended successfully within Lalitpur boundary!';
      canEndRide = true;
    } else {
      // User is outside Lalitpur boundary and not at a station.
      returnMessage =
          '❌ Ride cannot be ended outside Lalitpur boundary and not at a station.';
      penaltyInfo =
          'A penalty of Rs.100 will be applied if the ride were to end here.'; // Informative
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Cannot end ride here. Please return to a station or stay within Lalitpur. $penaltyInfo",
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      // Re-start timers since ride is not ending
      _startRideCountdown();
      _startDummyBikeMovement(); // Continue movement from current location
      return; // Do not proceed with API call
    }

    // If we reach here, canEndRide is true, meaning we are either at a station or within Lalitpur.
    try {
      final response = await _apiService.endRide(
        rideId: _activeRideId!,
        userLocation: finalEndLocation,
        // The backend should handle calculating distance, duration, and any penalties
        // based on the final location provided.
      );

      if (response.containsKey('distance')) {
        // ✅ Success case
        final String distance = response['distance'] ?? 'N/A';
        final int penaltyAmount = response['penaltyAmount'] ?? 0;
        final String penaltyReason = response['penaltyReason'] ?? 'No penalty';
        final double finalFare = (response['finalFare'] ?? 0).toDouble();

        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeLocation = null;
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });

        // Display Ride Summary
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('✅ Ride Ended Successfully'),
              content: Text(
                '$returnMessage\n\n'
                '📏 Distance: $distance\n'
                '💰 Fare: Rs. ${finalFare.toStringAsFixed(2)}\n'
                '⚠️ Penalty: Rs. ${penaltyAmount.toStringAsFixed(2)}\n'
                '${penaltyReason.isNotEmpty && penaltyAmount > 0 ? 'Reason: $penaltyReason' : ''}',
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      } else {
        final String message =
            response['error'] ??
            response['message'] ??
            'Ride could not be ended. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Failed to end ride: $message')),
        );
        // If the ride somehow failed to end on the backend, restart timers
        if (_isRideActive) {
          _startRideCountdown();
          _startDummyBikeMovement();
        }
      }
    } catch (e) {
      debugPrint('❌ Exception ending ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error ending ride: ${e.toString()}')),
      );
      // If there's a network error or other exception, restart timers
      if (_isRideActive) {
        _startRideCountdown();
        _startDummyBikeMovement();
      }
    } finally {
      await _loadStations(); // Always refresh stations after an attempted ride end
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _stationRefreshTimer?.cancel();
    _rideCountdownTimer?.cancel();
    _dummyBikeMovementTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      appBar: AppBar(
        title: const Text("Explore Zupito Rides"),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme(!themeProvider.isDarkMode);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),

      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(center: _currentLocation, zoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      retinaMode: RetinaMode.isHighDensity(context),
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.zupito',
                    ),
                    PolylineLayer(
                      polylineCulling: false,
                      polylines: [
                        Polyline(
                          points:
                              _lalitpurBoundary +
                              [_lalitpurBoundary.first], // Close the polygon
                          strokeWidth: 3,
                          color: Colors.deepOrange,
                          borderColor: Colors.deepOrange, // For visual clarity
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ..._stations.map(
                          (station) => Marker(
                            point: LatLng(station.lat, station.lng),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () => _onStationTap(station),
                              child: Icon(
                                Icons.location_on,
                                size: 40,
                                color: station.availableBikes > 0
                                    ? Colors.indigo
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _rippleController,
                                  builder: (context, child) => Container(
                                    width: _rippleAnimation.value,
                                    height: _rippleAnimation.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.withOpacity(
                                        1 - _rippleController.value,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.person_pin_circle,
                                  size: 36,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),

                        if (_isRideActive && _activeBikeLocation != null)
                          Marker(
                            point: _activeBikeLocation!,
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _rippleController,
                                  builder: (context, child) => Container(
                                    width: _rippleAnimation.value,
                                    height: _rippleAnimation.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green.withOpacity(
                                        1 - _rippleController.value,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.pedal_bike,
                                  size: 36,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
          if (_isRideActive)
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Card(
                color: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Active Ride: ${_activeBikeCode ?? '---'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Time Left: ${_formatDuration(_remainingRideTime)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _endRide(manualEnd: true),
                        icon: const Icon(Icons.lock, color: Colors.black),
                        label: const Text(
                          "End Ride",
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _moveToNearestStation,
        icon: const Icon(Icons.navigation),
        label: const Text("Nearest Station"),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}
