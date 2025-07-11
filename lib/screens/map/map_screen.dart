// lib/screens/map/map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/providers/theme_provider.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/otp_socket_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/services/station_service.dart';
import 'package:zupito/utils/constants.dart';
import 'widgets/station_bottom_sheet.dart' hide ApiService; // Ensure this import path is correct and the file exists
import 'package:zupito/screens/login_screen.dart';

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

  User? _userProfile;
  Timer? _stationRefreshTimer;

  bool _isRideActive = false;
  bool _isLoading = true;
  String? _activeBikeCode;
  String? _activeRideId;
  LatLng? _activeBikeLocation;
  DateTime? _rideEndTime;
  Duration _remainingRideTime = Duration.zero;
  Timer? _rideCountdownTimer;
  Timer? _dummyBikeMovementTimer;
  final Random _random = Random();

  Station? _selectedStation;

  double _dummyBikeCurrentSpeed = 0.0;
  double _dummyBikeHeading = 0.0;
  Station? _dummyBikeTargetStation;

  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127),
    LatLng(27.6815, 85.3293),
    LatLng(27.6677, 85.3324),
    LatLng(27.6545, 85.3178),
    LatLng(27.6619, 85.2952),
    LatLng(27.6804, 85.2918),
    LatLng(27.6901, 85.2991),
  ];

  final double _stationReturnRadiusMeters = 50.0;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0, end: 80).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _initialize(); // Call initialize after animation controller setup
  }

  void _initialize() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    bool userLoadedSuccessfully = false;
    try {
      await _loadUserProfile();
      if (_userProfile != null) {
        userLoadedSuccessfully = true;
      }
    } catch (e) {
      print("User profile loading error in _initialize: $e");
    }

    if (userLoadedSuccessfully) {
      try {
        await _initLocation();
        await _loadStations();
        await _checkActiveRide();

        if (mounted) {
          _stationRefreshTimer = Timer.periodic(
            const Duration(seconds: 5),
            (_) => _loadStations(),
          );
        }
      } catch (e) {
        print("Map features initialization error in _initialize: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Map features failed to load: ${e.toString()}"),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Only navigate if we are still on MapScreen and userProfile is null
          // This prevents infinite loops if login screen tries to navigate back here
          if (ModalRoute.of(context)?.settings.name != '/login') {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkActiveRide() async {
    try {
      final activeRideData = await _apiService.getActiveRide();
      if (activeRideData != null) {
        if (!mounted) return;
        setState(() {
          _isRideActive = true;
          _activeBikeCode = activeRideData['bikeCode'];
          _activeRideId = activeRideData['rideId'];
          _rideEndTime = DateTime.parse(activeRideData['rideEndTime']);
          _activeBikeLocation = LatLng(
            activeRideData['currentLocation']['latitude'],
            activeRideData['currentLocation']['longitude'],
          );
        });
        _startRideCountdown();
        _startDummyBikeMovement();
        if (_activeBikeLocation != null && mounted) {
          _mapController.move(_activeBikeLocation!, 17.0);
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isRideActive = false;
        });
      }
    } catch (e) {
      print("Error checking active ride: $e");
      if (mounted) {
        setState(() {
          _isRideActive = false;
        });
      }
    }
  }

  Future<void> _moveToNearestStation() async {
    if (_currentLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "❌ Your current location is not available. Please enable GPS and try again.",
          ),
        ),
      );
      return;
    }
    if (_userProfile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to find nearest station.")),
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
          'k': 2,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> nearestList = json['nearestStations'];

        if (nearestList.isNotEmpty) {
          final nearestId = nearestList.first['id'];

          final fullStation = _stations.firstWhere(
            (s) => s.id == nearestId,
            orElse: () {
              final fallback = nearestList.first;
              return Station(
                id: fallback['id'],
                name: fallback['name'],
                latitude: fallback['latitude'],
                longitude: fallback['longitude'],
                capacity: fallback['capacity'] ?? 10,
                bikes: [],
              );
            },
          );
          if (!mounted) return;
          _mapController.move(
            LatLng(fullStation.latitude, fullStation.longitude),
            17.0,
          );

          _onStationTap(fullStation);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ No nearby station found. Try again later."),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to find nearest station: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error finding nearest station: ${e.toString()}"),
        ),
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final data = await _secureStorage.readUserProfile();
    if (data != null) {
      final json = jsonDecode(data);
      final user = User.fromJson(json);
      if (!mounted) return;
      setState(() => _userProfile = user);
      // Ensure socket service is connected only if user profile is successfully loaded and widget is mounted
      if (mounted) {
        OtpSocketService().connect(user.id.toString(), context: context);
      }
    } else {
      print("User profile not found in secure storage.");
      // _initialize will handle the navigation if _userProfile is null
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception("Location permission denied.");
      }
    }

    final loc = await _location.getLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final userLoc = LatLng(loc.latitude!, loc.longitude!);
      if (!mounted) return;
      setState(() {
        _currentLocation = userLoc;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLocation != null) {
          _mapController.move(_currentLocation!, 15);
        }
      });
    } else {
      throw Exception("Could not get initial location.");
    }

    _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final updatedLoc = LatLng(loc.latitude!, loc.longitude!);
        if (!mounted) return;
        setState(() {
          _currentLocation = updatedLoc;
        });
      }
    });
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      debugPrint("🔥 Stations fetched: ${stations.length}");
      if (!mounted) return;
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading stations: ${e.toString()}")),
        );
      }
    }
  }

  void _onStationTap(Station station) async {
    if (_userProfile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User profile not available. Please log in again."),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      return;
    }
    if (_isRideActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You have an active ride. Please end it first."),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedStation = station;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // The call to buildStationBottomSheet is correct for a top-level function.
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        _userProfile!,
        onRideStartConfirmed: (code, rideId, endTime, bikeStartLocation) async {
          if (!mounted) return;
          setState(() {
            _isRideActive = true;
            _activeBikeCode = code;
            _activeRideId = rideId;
            _rideEndTime = endTime;
            _activeBikeLocation = bikeStartLocation;
          });

          if (!mounted) return;
          _mapController.move(bikeStartLocation, 17.0);

          _startRideCountdown();
          _startDummyBikeMovement();
        },
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectedStation = null;
    });
    _loadStations();
  }

  void _startRideCountdown() {
    _rideCountdownTimer?.cancel();
    if (_rideEndTime == null) return;
    if (!mounted) return;
    _remainingRideTime = _rideEndTime!.difference(DateTime.now());
    _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_rideEndTime == null) {
          timer.cancel();
          return;
        }
        _remainingRideTime = _rideEndTime!.difference(DateTime.now());
        if (_remainingRideTime.isNegative) {
          timer.cancel();
          _endRide(manualEnd: false);
        }
      });
    });
  }

  void _startDummyBikeMovement() async {
    _dummyBikeMovementTimer?.cancel();

    if (_activeBikeLocation == null) {
      print("Cannot start dummy bike movement: _activeBikeLocation is null.");
      return;
    }
    final LatLng initialLocation = _activeBikeLocation!;

    if (_stations.isEmpty) {
      try {
        await _loadStations();
      } catch (e) {
        print("Error fetching stations for dummy movement target: $e");
      }
    }

    final List<Station> otherStations = _stations
        .where((s) => s.id != _selectedStation?.id)
        .toList();

    if (otherStations.isNotEmpty) {
      _dummyBikeTargetStation =
          otherStations[_random.nextInt(otherStations.length)];
      print("Dummy bike target: ${_dummyBikeTargetStation?.name}");
    } else {
      _dummyBikeTargetStation = _selectedStation;
      print(
        "No other stations available, dummy bike target: ${_dummyBikeTargetStation?.name}",
      );
    }

    _dummyBikeCurrentSpeed = 0.00005 + _random.nextDouble() * 0.00005;
    _dummyBikeHeading = _random.nextDouble() * 2 * pi;

    final double maxSpeedChange = 0.000005;
    final double maxHeadingChange = 0.1;
    final double targetApproachFactor = 0.05;

    _dummyBikeMovementTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isRideActive || _activeBikeLocation == null) {
        timer.cancel();
        return;
      }

      final LatLng current = _activeBikeLocation!;

      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.latitude,
          _dummyBikeTargetStation!.longitude,
        );
        final Distance distance = const Distance();

        if (distance(current, targetLatLng) < 20) {
          if (!mounted) return;
          setState(() {
            _activeBikeLocation = targetLatLng;
            _dummyBikeCurrentSpeed = 0.0;
            _mapController.move(targetLatLng, _mapController.zoom);
          });
          print(
            "Dummy bike arrived at target station: ${_dummyBikeTargetStation!.name}",
          );
          return;
        }
      }

      _dummyBikeCurrentSpeed += (_random.nextDouble() * 2 - 1) * maxSpeedChange;
      _dummyBikeCurrentSpeed = _dummyBikeCurrentSpeed.clamp(0.00002, 0.00015);

      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.latitude,
          _dummyBikeTargetStation!.longitude,
        );
        final Distance distance = const Distance();

        double bearingToTarget = distance.bearing(current, targetLatLng);
        bearingToTarget = bearingToTarget * (pi / 180.0);

        double angleDiff = bearingToTarget - _dummyBikeHeading;
        if (angleDiff > pi) angleDiff -= 2 * pi;
        if (angleDiff < -pi) angleDiff += 2 * pi;

        _dummyBikeHeading += angleDiff * targetApproachFactor;
        _dummyBikeHeading +=
            (_random.nextDouble() * 2 - 1) * maxHeadingChange * 0.5;
        _dummyBikeHeading = _dummyBikeHeading % (2 * pi);
      } else {
        _dummyBikeHeading += (_random.nextDouble() * 2 - 1) * maxHeadingChange;
        _dummyBikeHeading = _dummyBikeHeading % (2 * pi);
      }

      final double latMove = cos(_dummyBikeHeading) * _dummyBikeCurrentSpeed;
      final double currentLatitudeRadians = current.latitude * (pi / 180.0);
      final double lngCorrectionFactor = cos(currentLatitudeRadians).abs();
      final double lngMove = sin(_dummyBikeHeading) * _dummyBikeCurrentSpeed;

      final LatLng newLocation = LatLng(
        current.latitude + latMove,
        current.longitude + (lngMove / lngCorrectionFactor),
      );

      if (!mounted) return;
      setState(() {
        _activeBikeLocation = newLocation;
      });

      if (mounted) {
        _mapController.move(newLocation, _mapController.zoom);
      }
    });
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 = polygon[(i + 1) % polygon.length];

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
    return intersectCount % 2 == 1;
  }

  Station? _isNearStation(LatLng point) {
    final Distance distance = const Distance();
    for (var station in _stations) {
      final stationLatLng = LatLng(station.latitude, station.longitude);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "❌ Missing ride or bike location data. Cannot end ride.",
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeLocation = null;
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });
      }
      return;
    }

    LatLng finalEndLocation = _activeBikeLocation!;
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
      returnMessage = '✅ Ride ended successfully within Lalitpur boundary!';
      canEndRide = true;
    } else {
      returnMessage =
          '❌ Ride cannot be ended outside Lalitpur boundary and not at a station.';
      penaltyInfo =
          'A penalty of Rs.100 will be applied if the ride were to end here.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Cannot end ride here. Please return to a station or stay within Lalitpur. $penaltyInfo",
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      _startRideCountdown();
      _startDummyBikeMovement();
      return;
    }

    try {
      final response = await _apiService.endRide(
        rideId: _activeRideId!,
        userLocation: finalEndLocation,
      );

      if (response.containsKey('distance')) {
        final String distance = response['distance'] ?? 'N/A';
        final double penaltyAmount =
            (response['penaltyAmount'] as num?)?.toDouble() ?? 0.0;
        final String penaltyReason = response['penaltyReason'] ?? 'No penalty';
        final double finalFare =
            (response['finalFare'] as num?)?.toDouble() ?? 0.0;

        if (!mounted) return;
        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeLocation = null;
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });

        if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Failed to end ride: $message')),
        );
        if (_isRideActive) {
          _startRideCountdown();
          _startDummyBikeMovement();
        }
      }
    } catch (e) {
      debugPrint('❌ Exception ending ride: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error ending ride: ${e.toString()}')),
      );
      if (_isRideActive) {
        _startRideCountdown();
        _startDummyBikeMovement();
      }
    } finally {
      await _loadStations();
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userProfile == null) {
      // This block will be hit if _loadUserProfile fails and doesn't redirect immediately.
      // The _initialize method now handles the pushReplacementNamed to /login if user is null.
      return const Scaffold(
        body: Center(child: Text("Please log in to use the map.")),
      );
    }

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
                  options: MapOptions(center: _currentLocation!, zoom: 15),
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
                          points: _lalitpurBoundary + [_lalitpurBoundary.first],
                          strokeWidth: 3,
                          color: Colors.deepOrange,
                          borderColor: Colors.deepOrange,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ..._stations.map(
                          (station) => Marker(
                            point: LatLng(station.latitude, station.longitude),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () => _onStationTap(station),
                              child: Icon(
                                Icons.location_on,
                                size: 40,
                                color:
                                    station
                                        .bikes
                                        .isNotEmpty // Check if the bikes list is not empty
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
