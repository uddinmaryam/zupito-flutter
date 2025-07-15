// lib/screens/map/map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'
    as geo; // Using alias to avoid conflict with Location package
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/providers/theme_provider.dart';
import 'package:zupito/screens/payment_service.dart';
import 'package:zupito/screens/paypal_webview.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/otp_socket_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
// import 'package:zupito/services/station_service.dart'; // This import seems unused, can be removed
import 'package:zupito/utils/constants.dart';
import 'widgets/station_bottom_sheet.dart';
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
    _initialize();
  }

  void _initialize() async {
    if (!mounted) {
      debugPrint("DEBUG: _initialize called but widget not mounted.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final token = await _secureStorage.readUserAuthToken();
    if (token != null) {
      _apiService.setAuthToken(token);
      debugPrint("DEBUG: MapScreen initialized ApiService with token.");
    } else {
      debugPrint(
        "DEBUG: MapScreen: No user auth token found, redirecting to login.",
      );
      if (mounted) {
        // Use WidgetsBinding.instance.addPostFrameCallback to ensure navigation
        // happens after the build cycle completes, preventing setState during build errors.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Re-check mounted after post frame callback
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    bool userLoadedSuccessfully = false;
    try {
      await _loadUserProfile();
      if (_userProfile != null) {
        userLoadedSuccessfully = true;
      }
    } catch (e) {
      debugPrint("ERROR: User profile loading error in _initialize: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load user profile: ${e.toString()}"),
          ),
        );
      }
    }

    if (!mounted) return; // Check mounted after async operation

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
          debugPrint("DEBUG: Station refresh timer started.");
        }
      } on Exception catch (e) {
        debugPrint(
          "ERROR: Map features initialization error in _initialize: $e",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Map features failed to load: ${e.toString()}"),
            ),
          );
        }
      } catch (e) {
        debugPrint(
          "ERROR: Unexpected error during map features initialization: $e",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("An unexpected error occurred: ${e.toString()}"),
            ),
          );
        }
      }
    } else {
      debugPrint("DEBUG: User profile not loaded, ensuring redirect to login.");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check current route to prevent redundant pushes if already on login
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
      debugPrint("DEBUG: _isLoading set to false.");
    }
  }

  Future<void> _checkActiveRide() async {
    try {
      final activeRideData = await _apiService.getActiveRide();
      if (!mounted) return; // Check mounted after API call
      if (activeRideData != null) {
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
          // Use .camera.zoom for MapController in flutter_map v8
          _mapController.move(_activeBikeLocation!, _mapController.camera.zoom);
          debugPrint("DEBUG: Map centered on active bike location.");
        }
        debugPrint("DEBUG: Active ride found: $_activeBikeCode");
      } else {
        setState(() {
          _isRideActive = false;
        });
        debugPrint("DEBUG: No active ride found.");
      }
    } catch (e) {
      debugPrint("ERROR: Error checking active ride: $e");
      if (mounted) {
        setState(() {
          _isRideActive = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to check active ride status: ${e.toString()}",
            ),
          ),
        );
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
      debugPrint(
        "WARN: _moveToNearestStation called but _currentLocation is null.",
      );
      return;
    }
    if (_userProfile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to find nearest station.")),
      );
      debugPrint(
        "WARN: _moveToNearestStation called but _userProfile is null.",
      );
      return;
    }

    try {
      // Ensure headers are set from _apiService for authenticated requests
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/stations/nearest'),
        headers: _apiService.getHeaders(),
        body: jsonEncode({
          'lat': _currentLocation!.latitude,
          'lon': _currentLocation!.longitude,
          'k': 2, // Assuming 'k' is for number of nearest stations
        }),
      );

      if (!mounted) return; // Check mounted after async operation

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> nearestList = json['nearestStations'];

        if (nearestList.isNotEmpty) {
          final nearestId = nearestList.first['id'];

          // Find the full station object from our _stations list
          final Station? fullStation = _stations.firstWhereOrNull(
            (s) => s.id == nearestId,
          );

          if (fullStation != null) {
            // Use .camera.zoom for MapController in flutter_map v8
            _mapController.move(
              LatLng(fullStation.latitude, fullStation.longitude),
              _mapController.camera.zoom, // Updated
            );
            debugPrint(
              "DEBUG: Map moved to nearest station: ${fullStation.name}",
            );
            _onStationTap(fullStation);
          } else {
            // Fallback if the full station wasn't in our loaded _stations list
            // This case should ideally not happen if _loadStations is reliable.
            final fallbackStationData = nearestList.first;
            final fallbackStation = Station(
              id: fallbackStationData['id'],
              name: fallbackStationData['name'] ?? 'Unknown Station',
              latitude: fallbackStationData['latitude'],
              longitude: fallbackStationData['longitude'],
              capacity: fallbackStationData['capacity'] ?? 10,
              bikes: [], // Bikes might not be included in the 'nearest' endpoint response
            );
            // Use .camera.zoom for MapController in flutter_map v8
            _mapController.move(
              LatLng(fallbackStation.latitude, fallbackStation.longitude),
              _mapController.camera.zoom, // Updated
            );
            debugPrint(
              "DEBUG: Map moved to fallback nearest station: ${fallbackStation.name}",
            );
            // Consider if you want to show bottom sheet for fallback, as bike data might be missing
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Found nearest station: ${fallbackStation.name}"),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ No nearby station found. Try again later."),
            ),
          );
          debugPrint("INFO: Nearest stations list was empty.");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Failed to find nearest station: ${response.statusCode} - ${response.body}",
            ),
          ),
        );
        debugPrint(
          "ERROR: Failed to find nearest station, status: ${response.statusCode}, body: ${response.body}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error finding nearest station: ${e.toString()}"),
        ),
      );
      debugPrint("ERROR: Exception in _moveToNearestStation: ${e.toString()}");
    }
  }

  Future<void> _loadUserProfile() async {
    final data = await _secureStorage.readUserProfile();
    if (!mounted) return; // Check mounted after async operation
    if (data != null) {
      try {
        final json = jsonDecode(data);
        final user = User.fromJson(json);
        setState(() => _userProfile = user);
        debugPrint("DEBUG: User profile loaded: ${user.email}");
        if (mounted) {
          // Ensure context is available and socket service is connected
          OtpSocketService().connect(user.id.toString(), context: context);
          debugPrint("DEBUG: OTP Socket Service connected.");
        }
      } catch (e) {
        debugPrint("ERROR: Failed to parse user profile from storage: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error loading user data. Please log in again."),
            ),
          );
        }
        await _secureStorage.deleteUserAuthToken(); // Clear invalid token
        await _secureStorage.deleteUserProfile();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } else {
      debugPrint("INFO: User profile not found in secure storage.");
    }
  }

  Future<void> _initLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Location services are disabled. Requesting to enable..."),
          ),
        );
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Location services denied. Please enable them manually."),
            ),
          );
          throw Exception("Location services are disabled.");
        }
      }

      // Check location permissions
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Location permission denied. Requesting permission..."),
          ),
        );
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Permission permanently denied. Grant it from settings."),
            ),
          );
          throw Exception("Location permission denied.");
        }
      }

      // Get initial location
      final loc = await _location.getLocation();
      if (loc.latitude == null || loc.longitude == null) {
        throw Exception("Location data is null.");
      }

      final userLoc = LatLng(loc.latitude!, loc.longitude!);
      if (!mounted) return;
      setState(() {
        _currentLocation = userLoc;
      });

      // Fit camera AFTER map has rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentLocation != null) {
          // Corrected for flutter_map v8: use _mapController.fitCamera
          // The 'move' method is for LatLng and zoom, not CameraFit.bounds
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints([_currentLocation!]),
              padding: const EdgeInsets.all(20), // Use const for EdgeInsets
            ),
            // source: MapEventSource.programmatic, // Removed in flutter_map v8
          );
        }
      });

      // Listen for live location updates
      _location.onLocationChanged.listen((loc) {
        if (!mounted || loc.latitude == null || loc.longitude == null) return;
        setState(() {
          _currentLocation = LatLng(loc.latitude!, loc.longitude!);
        });
      });
    } catch (e) {
      debugPrint("ERROR during location init: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location error: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _loadStations() async {
    try {
      final stations = await _apiService.getStations();
      debugPrint("DEBUG: Stations fetched: ${stations.length}");
      if (!mounted) return; // Check mounted after async operation
      setState(() {
        _stations.clear();
        _stations.addAll(stations);
      });
    } catch (e) {
      debugPrint("ERROR: Error loading stations: ${e.toString()}");
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
      debugPrint(
        "WARN: Station tapped but _userProfile is null. Redirecting to login.",
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
      debugPrint("INFO: Station tapped but a ride is already active.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedStation = station;
    });
    debugPrint("DEBUG: Station tapped: ${station.name}");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        _userProfile!,
        _apiService,
        onRideStartConfirmed: (code, rideId, endTime, bikeStartLocation) async {
          if (!mounted) return; // Check mounted before setState
          setState(() {
            _isRideActive = true;
            _activeBikeCode = code;
            _activeRideId = rideId;
            _rideEndTime = endTime;
            _activeBikeLocation = bikeStartLocation;
          });
          debugPrint(
            "DEBUG: Ride started confirmed. Bike: $code, Ride ID: $rideId",
          );

          if (mounted) {
            // Re-check mounted after setState
            // Use .camera.zoom for MapController in flutter_map v8
            _mapController.move(
                bikeStartLocation, _mapController.camera.zoom); // Updated
            debugPrint("DEBUG: Map moved to bike start location.");
          }

          _startRideCountdown();
          _startDummyBikeMovement();
        },
      ),
    );

    if (!mounted) return; // Check mounted after bottom sheet is dismissed
    setState(() {
      _selectedStation = null;
    });
    _loadStations(); // Refresh stations after potential ride start/end via bottom sheet
  }

  void _startRideCountdown() {
    _rideCountdownTimer?.cancel();
    if (_rideEndTime == null) {
      debugPrint("WARN: _startRideCountdown called but _rideEndTime is null.");
      return;
    }
    if (!mounted) return;
    _remainingRideTime = _rideEndTime!.difference(DateTime.now());
    _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        debugPrint("DEBUG: Ride countdown timer cancelled: widget unmounted.");
        return;
      }
      setState(() {
        if (_rideEndTime == null) {
          // Double check inside setState
          timer.cancel();
          debugPrint(
            "DEBUG: Ride countdown timer cancelled: _rideEndTime became null.",
          );
          return;
        }
        _remainingRideTime = _rideEndTime!.difference(DateTime.now());
        if (_remainingRideTime.isNegative) {
          timer.cancel();
          debugPrint(
            "DEBUG: Ride countdown timer finished. Ending ride (time's up).",
          );
          _endRide(manualEnd: false); // Automatically end ride if time runs out
        }
      });
    });
  }

  void _startDummyBikeMovement() async {
    _dummyBikeMovementTimer?.cancel();
    debugPrint("DEBUG: Dummy bike movement started.");

    if (_activeBikeLocation == null) {
      debugPrint(
        "ERROR: Cannot start dummy bike movement: _activeBikeLocation is null.",
      );
      return;
    }
    // final LatLng initialLocation = _activeBikeLocation!; // Not strictly needed as _activeBikeLocation is updated

    if (_stations.isEmpty) {
      debugPrint(
        "INFO: Stations list empty, attempting to load for dummy movement target.",
      );
      try {
        await _loadStations();
      } catch (e) {
        debugPrint(
          "ERROR: Error fetching stations for dummy movement target: $e",
        );
      }
    }

    if (!mounted) return; // Check mounted after async station load

    final List<Station> otherStations = _stations
        .where(
          (s) => s.id != _selectedStation?.id,
        ) // Exclude the station where ride started
        .toList();

    if (otherStations.isNotEmpty) {
      _dummyBikeTargetStation =
          otherStations[_random.nextInt(otherStations.length)];
      debugPrint("DEBUG: Dummy bike target: ${_dummyBikeTargetStation?.name}");
    } else {
      // Fallback: If only one station exists or no other stations, target the starting one
      _dummyBikeTargetStation = _selectedStation;
      debugPrint(
        "WARN: No other stations available, dummy bike target: ${_dummyBikeTargetStation?.name ?? 'None'}",
      );
    }

    _dummyBikeCurrentSpeed = 0.00005 +
        _random.nextDouble() * 0.00005; // Base speed + random variation
    _dummyBikeHeading = _random.nextDouble() * 2 * pi; // Random initial heading

    final double maxSpeedChange = 0.000005;
    final double maxHeadingChange = 0.1;
    final double targetApproachFactor =
        0.05; // How strongly the bike steers towards the target

    _dummyBikeMovementTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        debugPrint(
          "DEBUG: Dummy bike movement timer cancelled: widget unmounted.",
        );
        return;
      }
      if (!_isRideActive || _activeBikeLocation == null) {
        timer.cancel();
        debugPrint(
          "DEBUG: Dummy bike movement timer cancelled: ride not active or location null.",
        );
        return;
      }

      final LatLng current = _activeBikeLocation!;

      // Check if near target station
      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.latitude,
          _dummyBikeTargetStation!.longitude,
        );
        final Distance distance = const Distance();

        if (distance(current, targetLatLng) < 20) {
          // Within 20 meters, consider "arrived"
          if (!mounted) return;
          setState(() {
            _activeBikeLocation = targetLatLng; // Snap to target
            _dummyBikeCurrentSpeed = 0.0; // Stop
            // Use .camera.zoom for MapController in flutter_map v8
            _mapController.move(
              targetLatLng,
              _mapController.camera.zoom, // Updated
            ); // Center map on arrival
          });
          debugPrint(
            "DEBUG: Dummy bike arrived at target station: ${_dummyBikeTargetStation!.name}",
          );
          timer.cancel(); // Stop movement once arrived
          return;
        }
      }

      // Adjust speed
      _dummyBikeCurrentSpeed += (_random.nextDouble() * 2 - 1) *
          maxSpeedChange; // Slight random speed changes
      _dummyBikeCurrentSpeed = _dummyBikeCurrentSpeed.clamp(
        0.00002,
        0.00015,
      ); // Keep speed within reasonable bounds

      // Adjust heading
      if (_dummyBikeTargetStation != null) {
        final LatLng targetLatLng = LatLng(
          _dummyBikeTargetStation!.latitude,
          _dummyBikeTargetStation!.longitude,
        );
        final Distance distance = const Distance();

        // Calculate bearing to target and convert to radians
        double bearingToTarget = distance.bearing(current, targetLatLng);
        bearingToTarget = bearingToTarget * (pi / 180.0);

        // Calculate angle difference, ensuring it's the shortest path around the circle
        double angleDiff = bearingToTarget - _dummyBikeHeading;
        if (angleDiff > pi) angleDiff -= 2 * pi;
        if (angleDiff < -pi) angleDiff += 2 * pi;

        // Apply a factor to steer towards the target
        _dummyBikeHeading += angleDiff * targetApproachFactor;
        // Add some random wobble to the heading
        _dummyBikeHeading +=
            (_random.nextDouble() * 2 - 1) * maxHeadingChange * 0.5;
        _dummyBikeHeading =
            _dummyBikeHeading % (2 * pi); // Keep heading within 0 to 2*pi
      } else {
        // If no target, just wander randomly
        _dummyBikeHeading += (_random.nextDouble() * 2 - 1) * maxHeadingChange;
        _dummyBikeHeading = _dummyBikeHeading % (2 * pi);
      }

      // Calculate new position
      final double latMove = cos(_dummyBikeHeading) * _dummyBikeCurrentSpeed;
      final double currentLatitudeRadians = current.latitude * (pi / 180.0);
      final double lngCorrectionFactor = cos(
        currentLatitudeRadians,
      ).abs().clamp(0.0001, 1.0); // Avoid division by zero near poles
      final double lngMove = sin(_dummyBikeHeading) * _dummyBikeCurrentSpeed;

      final LatLng newLocation = LatLng(
        current.latitude + latMove,
        current.longitude + (lngMove / lngCorrectionFactor),
      );

      // Keep location within Lalitpur boundary (optional, for realism)
      // This is a simple boundary check, more complex boundary handling might be needed.
      if (!_isPointInPolygon(newLocation, _lalitpurBoundary)) {
        // If outside boundary, try to steer back or clamp
        // For simplicity, let's just reverse heading slightly if hit boundary
        _dummyBikeHeading += pi +
            (_random.nextDouble() * 0.5 -
                0.25); // Turn around with some randomness
        _dummyBikeHeading = _dummyBikeHeading % (2 * pi);
        debugPrint("DEBUG: Dummy bike hit boundary, re-calculating heading.");
      }

      if (!mounted) return;
      setState(() {
        _activeBikeLocation = newLocation;
      });

      if (mounted) {
        // Only move map if the user is not actively panning/zooming,
        // or if we want to force follow the bike.
        // For now, it always follows. Could add a toggle.
        // Use .camera.zoom for MapController in flutter_map v8
        _mapController.move(newLocation, _mapController.camera.zoom); // Updated
      }
    });
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    // Ray-casting algorithm for point in polygon
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 = polygon[(i + 1) % polygon.length];

      // Check if ray from point (horizontally right) intersects segment (p1, p2)
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
    return intersectCount % 2 == 1; // Odd intersections means inside
  }

  Station? _isNearStation(LatLng point) {
    final Distance distance = const Distance();
    for (var station in _stations) {
      final stationLatLng = LatLng(station.latitude, station.longitude);
      final double dist = distance(point, stationLatLng);
      // debugPrint("Distance to ${station.name}: ${dist.toStringAsFixed(2)} meters"); // Can be chatty
      if (dist <= _stationReturnRadiusMeters) {
        return station;
      }
    }
    return null;
  }

  Future<void> _endRide({bool manualEnd = true}) async {
    debugPrint("DEBUG: _endRide called. Manual end: $manualEnd");
    _rideCountdownTimer?.cancel();
    _dummyBikeMovementTimer?.cancel();

    if (_activeRideId == null || _activeBikeLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "❌ Missing ride or bike location data. Cannot end ride.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint(
        "ERROR: Cannot end ride: _activeRideId or _activeBikeLocation is null.",
      );
      // Reset state forcefully if data is missing but ride was somehow active
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

    try {
      debugPrint(
        "DEBUG: Calling _apiService.endRide for ride ID: $_activeRideId",
      );
      final response = await _apiService.endRide(
        rideId: _activeRideId!,
        userLocation: finalEndLocation, // Added missing required argument
        endLat: finalEndLocation.latitude,
        endLng: finalEndLocation.longitude,
      );
      if (!mounted) return; // Check mounted after API call

      // The backend will always decide success, penalty, etc.
      if (response['message'] != null) {
        final String distance = response['distance'] ?? 'N/A';
        final double penaltyAmount =
            (response['penaltyAmount'] as num?)?.toDouble() ?? 0.0;
        final String penaltyReason = response['penaltyReason'] ?? '';
        final double finalFare =
            (response['finalFare'] as num?)?.toDouble() ?? 0.0;
        final String message = response['message'] ?? 'Ride ended';

        setState(() {
          _isRideActive = false;
          _activeBikeCode = null;
          _activeRideId = null;
          _activeBikeLocation = null;
          _rideEndTime = null;
          _remainingRideTime = Duration.zero;
        });
        debugPrint("DEBUG: Ride successfully ended via API.");

        // FIRST DIALOG: Ride Ended Summary
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('✅ Ride Ended'),
              content: Text(
                '$message\n\n'
                '📏 Distance: $distance\n'
                '💰 Fare: Rs. ${finalFare.toStringAsFixed(2)}\n'
                '${penaltyAmount > 0 ? '⚠️ Penalty: Rs. ${penaltyAmount.toStringAsFixed(2)}\nReason: $penaltyReason' : ''}',
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

        // SECOND DIALOG: Payment Deduction (displayed AFTER the first one is dismissed)
        // This block is now correctly placed outside the builder of the first dialog.
        if (mounted) {
          String paymentMessage =
              'Your total fare of Rs. ${finalFare.toStringAsFixed(2)} has been deducted from your account.';
          if (penaltyAmount > 0) {
            paymentMessage +=
                '\n\nAn additional penalty of Rs. ${penaltyAmount.toStringAsFixed(2)} was also deducted.';
          }

          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('💳 Payment Confirmation'),
                content: Text(paymentMessage),
                actions: [
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Handle unexpected response or failure
        final String message = response['error'] ??
            response['message'] ??
            'Ride could not be ended. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Failed to end ride: $message')),
        );
        debugPrint("ERROR: API responded with failure to end ride: $message");
        // If API fails but we thought we could end, restart timers
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
      // If an exception occurs, assume ride is still active and restart timers
      if (_isRideActive) {
        _startRideCountdown();
        _startDummyBikeMovement();
      }
    } finally {
      await _loadStations(); // Always refresh stations at the end
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (duration.isNegative)
      return "00:00"; // Handle negative durations gracefully
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _stationRefreshTimer?.cancel();
    _rideCountdownTimer?.cancel();
    _dummyBikeMovementTimer?.cancel();
    debugPrint(
      "DEBUG: MapScreen disposed. All timers and controllers cancelled.",
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator early
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Handle case where user profile couldn't be loaded (e.g., bad token)
    if (_userProfile == null) {
      debugPrint(
        "WARN: _userProfile is null in build. Displaying login message.",
      );
      return Scaffold(
        appBar: AppBar(title: const Text("Explore Zupito Rides")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Please log in to use the map.",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    // Only attempt to build FlutterMap if _currentLocation is available
    // Otherwise, show an indicator
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 122, 55, 223),
      appBar: AppBar(
        title: const Text("Explore Zupito Rides"),
        backgroundColor: Colors.indigo,
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

      body: _currentLocation == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching your location..."),
                  Text(
                    "Please ensure GPS is enabled and permissions are granted.",
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      retinaMode: RetinaMode.isHighDensity(context),
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.zupito',
                      errorImage:
                          const AssetImage('assets/images/placeholder_map.png'),
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _lalitpurBoundary + [_lalitpurBoundary.first],
                          strokeWidth: 3,
                          color: Colors.red,
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
                                color: station.bikes.isNotEmpty
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
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Time Left: ${_formatDuration(_remainingRideTime)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: () => _endRide(manualEnd: true),
                              icon: const Icon(Icons.lock, color: Colors.black),
                              label: const Text(
                                "End Ride",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

      // <-- Updated FloatingActionButton section starts here
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _moveToNearestStation,
            icon: const Icon(Icons.navigation),
            label: const Text("Nearest Station"),
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: () async {
              String? approvalUrl =
                  await PaymentService.createPayPalOrder(30.0);

              if (approvalUrl != null) {
                if (context.mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => PayPalWebView(approvalUrl: approvalUrl),
                    ),
                  );

                  if (result == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("PayPal Payment Success!")),
                    );
                  } else if (result == 'cancel') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("PayPal Payment Cancelled.")),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to create PayPal order.")),
                );
              }
            },
            icon: const Icon(Icons.payment),
            label: const Text("Test PayPal"),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// Extension to add firstWhereOrNull functionality similar to Kotlin/C#
extension IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
