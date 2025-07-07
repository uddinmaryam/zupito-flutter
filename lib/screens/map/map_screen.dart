// ✅ Full refactored and enhanced version of MapScreen
// With smoother UI/UX, animated dummy bike movement, error handling
// Compatible with updated station_bottom_sheet.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/otp_socket_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/services/station_service.dart';
import 'package:zupito/utils/constants.dart';
import 'widgets/station_bottom_sheet.dart'; // Ensure this path is correct

// For distance calculations
import 'package:latlong2/latlong.dart' as ltl;

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
  final List<Station> _stations = [];
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  UserProfile? _userProfile;
  Marker?
  _currentLocationMarker; // This marker is used for the user's actual location
  Timer? _stationRefreshTimer;

  bool _isRideActive = false;
  String? _activeBikeCode;
  String? _activeRideId;
  LatLng?
  _activeBikeLocation; // This represents the *bike's* current position during a free-roam ride
  DateTime? _rideEndTime;
  Duration _remainingRideTime = Duration.zero;
  Timer? _rideCountdownTimer;
  Timer? _dummyBikeMovementTimer;
  final Random _random = Random();

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

  final double _stationReturnRadiusMeters =
      50.0; // 50 meters radius to consider "at a station"

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
    _loadStations();
    _stationRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadStations(),
    );
  }

  Future<void> _moveToNearestStation() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ Location not available")));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/stations/nearest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': _currentLocation!.latitude,
          'lon': _currentLocation!.longitude,
          'k': 3, // Request 2 nearest stations
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
                bikes: [],
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
            const SnackBar(content: Text("❌ No nearby station found")),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: ${e.toString()}")));
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
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied)
      permissionGranted = await _location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) return;

    final loc = await _location.getLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final userLoc = LatLng(loc.latitude!, loc.longitude!);
      setState(() {
        _currentLocation = userLoc;
        _currentLocationMarker = Marker(
          point: userLoc,
          width: 60,
          height: 60,
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.blue,
            size: 36,
          ),
        );
      });

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
          _currentLocationMarker = Marker(
            point: updatedLoc,
            width: 60,
            height: 60,
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.blue,
              size: 36,
            ),
          );
          // For the dummy bike movement, we will keep it independent of user's _currentLocation
          // unless the dummy movement is directly tied to user's location.
          // Since you want "he can do anywhere it wants" for the bike, the dummy movement
          // will simulate random movement from the bike's perspective, not necessarily tracking the user exactly.
          // _activeBikeLocation is updated by _startDummyBikeMovement, not here.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User or location missing")));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        _userProfile!,
        // When ride is confirmed, the bikeLocation passed is the *station's* location
        onRideStartConfirmed: (code, rideId, endTime, bikeLocation) async {
          setState(() {
            _isRideActive = true;
            _activeBikeCode = code;
            _activeRideId = rideId;
            _rideEndTime = endTime;
            // The bike starts at the station's location
            _activeBikeLocation = bikeLocation;
          });
          _startRideCountdown();
          _startDummyBikeMovement(); // This will simulate random movement for the bike
        },
      ),
    );
    _loadStations(); // Refresh stations after sheet is dismissed, in case a bike was taken
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

  // This function will simulate random movement within a broader area for the bike
  void _startDummyBikeMovement() {
    _dummyBikeMovementTimer?.cancel();

    _dummyBikeMovementTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) {
      if (!_isRideActive) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_activeBikeLocation != null) {
          // Simulate movement by adding a small random offset
          // These offsets are approximate to keep movement local but not fixed
          double latOffset =
              (_random.nextDouble() - 0.5) *
              0.001; // +/- 0.0005 degrees (approx 55 meters)
          double lngOffset = (_random.nextDouble() - 0.5) * 0.001;

          LatLng newLocation = LatLng(
            _activeBikeLocation!.latitude + latOffset,
            _activeBikeLocation!.longitude + lngOffset,
          );

          // Optional: Restrict movement to a general area or Lalitpur boundary
          // For truly "anywhere in Lalitpur", this might be less strict.
          // For this dummy, we assume small increments keep it reasonably local.
          _activeBikeLocation = newLocation;
        } else if (_currentLocation != null) {
          // Fallback: If activeBikeLocation somehow became null, re-initialize it
          // This might happen if the ride was just started and _activeBikeLocation wasn't set yet.
          _activeBikeLocation =
              _currentLocation; // Using user location as a temporary start for dummy move
        }
      });
    });
  }

  // New Helper: Point-in-polygon check for Lalitpur boundary
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int intersectCount = 0;
    for (int i = 0; i < polygon.length - 1; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 = polygon[i + 1];

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
    // If the point's longitude is on the edge
    if (point.longitude == polygon.last.longitude &&
        point.longitude == polygon.first.longitude) {
      if ((point.latitude >=
              min(polygon.last.latitude, polygon.first.latitude) &&
          point.latitude <=
              max(polygon.last.latitude, polygon.first.latitude))) {
        return true; // Point on a vertical edge.
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
        const SnackBar(content: Text("❌ Missing ride or bike location data")),
      );
      return;
    }

    // Determine the end location for the API call
    LatLng finalEndLocation = _activeBikeLocation!;
    String? endStationId;
    String returnMessage = '';

    // Step 1: Check if near a required station
    final Station? nearbyStation = _isNearStation(finalEndLocation);
    if (nearbyStation != null) {
      endStationId = nearbyStation.id;
      returnMessage = '✅ Ride ended at ${nearbyStation.name} station!';
    }
    // Step 2: If not near a station, check if inside Lalitpur boundary
    else if (_isPointInPolygon(finalEndLocation, _lalitpurBoundary)) {
      returnMessage = '✅ Ride ended successfully within Lalitpur boundary!';
    }
    // Step 3: If neither, show error and prevent end
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Cannot end ride here. Please return to a station or stay within Lalitpur.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // Re-activate timers if ride couldn't be ended
      _startRideCountdown();
      _startDummyBikeMovement();
      return; // Stop here, do not call API
    }

    try {
      final response = await _apiService.endRide(
        rideId: _activeRideId!,
        userLocation: finalEndLocation,
        endStationId: endStationId, // Pass null if not ending at a station
      );

      if (response['success'] == true) {
        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeLocation = null; // Clear the bike's location
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(returnMessage), // Use dynamic message
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final message = response['message'] ?? 'Ride could not be ended.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('⚠️ Failed: $message')));
        // If there's an API-side error but the app state still indicates active,
        // (e.g., backend has more strict rules), re-enable timers.
        if (_isRideActive) {
          // Check _isRideActive in case it was already set to false
          _startRideCountdown();
          _startDummyBikeMovement();
        }
      }
    } catch (e) {
      debugPrint('❌ Exception ending ride: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
      // Re-enable timers if an exception occurred and ride is still conceptually active
      if (_isRideActive) {
        _startRideCountdown();
        _startDummyBikeMovement();
      }
    } finally {
      await _loadStations(); // Always refresh stations to reflect bike availability changes
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
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
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
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _lalitpurBoundary + [_lalitpurBoundary.first],
                          strokeWidth: 3,
                          color: Colors.deepOrange,
                          isDotted: false,
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
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.pedal_bike,
                              size: 36,
                              color: Colors.black,
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
