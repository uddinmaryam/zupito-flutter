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
import 'widgets/station_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  LatLng? _currentLocation;
  List<LatLng> _rideRoute = [];
  int _routeIndex = 0;
  final MapController _mapController = MapController();
  final Location _location = Location();
  final List<Station> _stations = [];
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  UserProfile? _userProfile;
  Marker? _currentLocationMarker;
  Timer? _stationRefreshTimer;

  bool _isRideActive = false;
  String? _activeBikeCode;
  String? _activeRideId;
  LatLng? _activeBikeStartLocation;
  DateTime? _rideEndTime;
  Duration _remainingRideTime = Duration.zero;
  Timer? _rideCountdownTimer;
  Timer? _dummyBikeMovementTimer;
  final Random _random = Random();

  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127),
    LatLng(27.6815, 85.3293),
    LatLng(27.6677, 85.3324),
    LatLng(27.6545, 85.3178),
    LatLng(27.6619, 85.2952),
    LatLng(27.6804, 85.2918),
    LatLng(27.6901, 85.2991),
  ];

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

  Future<void> _loadUserProfile() async {
    final data = await _secureStorage.readUser();
    if (data != null) {
      final json = jsonDecode(data);
      final user = UserProfile.fromJson(json);
      setState(() => _userProfile = user);
      OtpSocketService().connect(user.id.toString(), context: context);
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    } else {
      throw Exception('Failed to fetch route');
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

      // 🛠 FIX THIS LINE:
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userLoc, 15);
      });
    }

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
        });
      }
    });
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      print("🔥 Stations fetched: ${stations.length}");
      if (stations.isNotEmpty) {
        print(
          "🚲 First station lat/lng: ${stations.first.lat}, ${stations.first.lng}",
        );
      }
      print(
        "📍 First station: ${stations.isNotEmpty ? stations.first.toJson() : 'None'}",
      );

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
        onRideStartConfirmed: (code, rideId, endTime, bikeLocation) async {
          final route = await fetchRoute(_currentLocation!, bikeLocation);
          setState(() {
            _isRideActive = true;
            _activeBikeCode = code;
            _activeRideId = rideId;
            _rideEndTime = endTime;
            _activeBikeStartLocation = bikeLocation;
            _rideRoute = route; // ⬅️ Store route
            _routeIndex = 0; // ⬅️ Reset index
          });
          _startRideCountdown();
          _startDummyBikeMovement();
        },
      ),
    );
    _loadStations();
  }

  void _startRideCountdown() {
    _rideCountdownTimer?.cancel();
    _remainingRideTime = _rideEndTime!.difference(DateTime.now());
    _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingRideTime = _rideEndTime!.difference(DateTime.now());
        if (_remainingRideTime.isNegative) {
          timer.cancel();
          _endRide(manualEnd: false);
        }
      });
    });
  }

  void _startDummyBikeMovement() {
    _dummyBikeMovementTimer?.cancel();

    _dummyBikeMovementTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (_routeIndex < _rideRoute.length) {
        setState(() {
          _activeBikeStartLocation = _rideRoute[_routeIndex];
          _routeIndex++;
        });
      } else {
        timer.cancel(); // Reached end of route
      }
    });
  }

  Future<void> _endRide({bool manualEnd = true}) async {
    _rideCountdownTimer?.cancel();
    _dummyBikeMovementTimer?.cancel();

    if (_activeRideId == null || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Missing ride or location data")),
      );
      return;
    }

    try {
      final response = await _apiService.endRide(
        rideId: _activeRideId!,
        userLocation: _currentLocation!,
      );

      if (response['success'] == true) {
        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeStartLocation = null;
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              manualEnd
                  ? '✅ Ride ended successfully!'
                  : '⏱️ Ride auto-ended. Time up!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final message = response['message'] ?? 'Ride could not be ended.';
        if (message.contains("Please return bike to station")) {
          _showReturnToStationWarning();
          _startRideCountdown();
          _startDummyBikeMovement();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('⚠️ Failed: $message')));
        }
      }
    } catch (e) {
      debugPrint('❌ Exception ending ride: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
      _startRideCountdown();
      _startDummyBikeMovement();
    } finally {
      await _loadStations();
    }
  }

  void _showReturnToStationWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Return to Station"),
        content: const Text("⚠️ Please return bike to a station to end ride."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
                          points: _lalitpurBoundary + [_lalitpurBoundary[0]],
                          strokeWidth: 2,
                          color: Colors.red,
                          isDotted: true,
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
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                        // 🔵 Current Location Marker with ripple
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
                                  builder: (context, child) {
                                    return Container(
                                      width: _rippleAnimation.value,
                                      height: _rippleAnimation.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.withOpacity(
                                          1 - _rippleController.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const Icon(
                                  Icons.person_pin_circle,
                                  size: 36,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),

                        if (_isRideActive && _activeBikeStartLocation != null)
                          Marker(
                            point: _activeBikeStartLocation!,
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
    );
  }
}
