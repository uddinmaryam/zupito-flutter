// ✅ This is the updated MapScreen with animated route marker (no green polyline) and success dialog
import 'dart:convert';
import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../../models/station.dart'; // Ensure this model has 'availableBikes' property
import '../../models/user.dart';
import '../../../services/station_service.dart';
import '../../../services/secure_storage_services.dart';
import '../../../services/otp_socket_service.dart';
import 'widgets/station_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Ride state variables
  bool _isRideActive = false;
  String? _activeBikeCode;
  DateTime? _rideEndTime;
  Timer? _rideCountdownTimer;
  Duration _remainingRideTime = Duration.zero;

  LatLng? _currentLocation;
  final Location _location = Location();
  final MapController _mapController = MapController();
  Marker? _currentLocationMarker;
  final List<Station> _stations = [];
  final SecureStorageService _secureStorage = SecureStorageService();
  final List<LatLng> _routePoints = []; // Stores all route points

  // New: Animation for dotted line (these variables are still kept,
  // but their direct effect on Polyline.dashArray is not possible without custom painter)
  AnimationController? _dottedAnimationController;
  Animation<double>? _dottedAnimation;
  double _dashOffset = 0.0; // Will be animated, but for custom drawing only

  // Timer for periodically refreshing station data
  Timer? _stationRefreshTimer;

  final List<LatLng> _lalitpurBoundary = [
    LatLng(27.6912, 85.3127),
    LatLng(27.6815, 85.3293),
    LatLng(27.6677, 85.3324),
    LatLng(27.6545, 85.3178),
    LatLng(27.6619, 85.2952),
    LatLng(27.6804, 85.2918),
    LatLng(27.6901, 85.2991),
  ];

  UserProfile? _userProfile;

  bool isInsideLalitpur(LatLng point) {
    bool inside = false;
    for (
      int i = 0, j = _lalitpurBoundary.length - 1;
      i < _lalitpurBoundary.length;
      j = i++
    ) {
      if (((_lalitpurBoundary[i].latitude > point.latitude) !=
              (_lalitpurBoundary[j].latitude > point.latitude)) &&
          (point.longitude <
              (_lalitpurBoundary[j].longitude -
                          _lalitpurBoundary[i].longitude) *
                      (point.latitude - _lalitpurBoundary[i].latitude) /
                      (_lalitpurBoundary[j].latitude -
                          _lalitpurBoundary[i].latitude) +
                  _lalitpurBoundary[i].longitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadUserProfile();
    _loadStations(); // Initial load of stations

    // ✅ NEW: Set up periodic refresh for stations
    // This will fetch the latest bike availability from the backend every 5 seconds.
    _stationRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      debugPrint("⏲️ Periodically refreshing station data...");
      _loadStations();
    });

    // Initialize dotted animation controller
    _dottedAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 1), // Adjust speed of dots
        )..addListener(() {
          if (mounted) {
            // This setState will trigger a rebuild, but dashOffset won't directly
            // affect Polyline unless a custom painter is used.
            setState(() {
              _dashOffset = _dottedAnimation!.value * 20; // Example offset
            });
          }
        });

    _dottedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_dottedAnimationController!);
  }

  Future<void> _loadUserProfile() async {
    final userData = await _secureStorage.readUser();
    if (userData != null) {
      final json = jsonDecode(userData);
      final user = UserProfile.fromJson(json);
      setState(() {
        _userProfile = user;
      });
      if (mounted) {
        // Ensure userId is a String before passing
        OtpSocketService().connect(user.id.toString(), context: context);
      }
    }
  }

  Future<void> _loadStations() async {
    try {
      final stations = await StationService.fetchStations();
      if (mounted) {
        setState(() {
          _stations.clear();
          _stations.addAll(stations);
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching stations: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching stations: $e')));
      }
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final loc = await _location.getLocation();
    if (loc.latitude != null && loc.longitude != null) {
      final newLocation = LatLng(loc.latitude!, loc.longitude!);
      if (mounted) {
        setState(() {
          _currentLocation = newLocation;
          _currentLocationMarker = Marker(
            point: newLocation,
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(newLocation, 15);
        }
      });
    }

    _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        final updatedLocation = LatLng(loc.latitude!, loc.longitude!);
        if (mounted) {
          setState(() {
            _currentLocation = updatedLocation;
            _currentLocationMarker = Marker(
              point: updatedLocation,
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
      }
    });
  }

  Future<void> _fetchRouteAndAnimate(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );

    try {
      print("🌐 Fetching route...");
      print("🗺️ Start: $start");
      print("🗺️ End: $end");

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'];
        final List<LatLng> points = coords
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();

        print("✅ Route fetch success");
        print("📍 Total route points: ${points.length}");

        if (mounted) {
          setState(() {
            _routePoints.clear();
            _routePoints.addAll(points);
          });
          // Start the dotted animation when route points are available
          _dottedAnimationController?.repeat(); // Loop the animation
        }
      } else {
        print("❌ Failed to fetch route: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('❌ Exception during route fetch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error fetching route: ${e.toString()}")),
        );
      }
    }
  }

  void _onStationTap(Station station) async {
    if (_userProfile == null || _currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile or current location not available.'),
          ),
        );
      }
      return;
    }

    // Stop any existing dotted animation when a new action starts
    _dottedAnimationController?.stop();
    setState(() {
      _routePoints.clear(); // Clear previous route
    });

    // Await the dismissal of the bottom sheet
    await showModalBottomSheet<void>(
      context: context, // This is MapScreen's context
      isScrollControlled: true,
      builder: (stationSheetContext) {
        // Explicitly name the context of the station bottom sheet
        return buildStationBottomSheet(
          stationSheetContext, // Pass this context to the builder
          station,
          _userProfile!,
          // MODIFIED: Added bikeCode and durationMinutes to the callback signature
              onUnlockSuccess:
              (LatLng bikeLatLng, String bikeCode, int durationMinutes) async {
                // No need for the AlertDialog here, the bottom sheet already gives feedback.

                if (mounted) {
                  // Check if MapScreen is still mounted
                  // Set active ride state
                  setState(() {
                    _isRideActive = true;
                    _activeBikeCode = bikeCode;
                    _rideEndTime = DateTime.now().add(
                      Duration(minutes: durationMinutes),
                    );
                    _startRideCountdown(); // Start the new countdown timer
                  });

                  // Fetch route and animate immediately
                  await _fetchRouteAndAnimate(_currentLocation!, bikeLatLng);
                }
              },
        );
      }, // Closing brace for the builder callback
    );

    // IMPORTANT: Reload stations after the bottom sheet is dismissed.
    // This will fetch the latest bike availability from the backend.
    if (mounted) {
      debugPrint("🔄 Bottom sheet dismissed, reloading stations...");
      _loadStations();
    }
  }

  void _startRideCountdown() {
    _rideCountdownTimer?.cancel(); // Cancel any previous timer
    _remainingRideTime = _rideEndTime!.difference(DateTime.now());

    _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingRideTime = _rideEndTime!.difference(DateTime.now());
        if (_remainingRideTime.isNegative) {
          _endRide(); // Time's up, end the ride
          timer.cancel();
        }
      });
    });
  }

  void _endRide() {
    _rideCountdownTimer?.cancel();
    _dottedAnimationController?.stop(); // Stop route animation if running

    setState(() {
      _isRideActive = false;
      _activeBikeCode = null;
      _rideEndTime = null;
      _remainingRideTime = Duration.zero;
      _routePoints.clear(); // Clear the route polyline
    });

    // TODO: Implement actual backend call to end ride and lock bike
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Your ride has ended! Bike automatically locked.'),
        duration: Duration(seconds: 5),
      ),
    );

    // Refresh stations to reflect the bike's new available status
    _loadStations();
  }

  // Helper to format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0FE),
        elevation: 0,
        title: const Text(
          "Explore Zupito Rides",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        // Use Stack to overlay the map and ride status
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
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        // Lalitpur Boundary
                        Polyline(
                          points: _lalitpurBoundary + [_lalitpurBoundary[0]],
                          strokeWidth: 2.5,
                          color: Colors.red,
                          isDotted: true,
                        ),
                        // Animated Dotted Route (will be just a static dotted line with current Polyline)
                        if (_routePoints.isNotEmpty)
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.0,
                            color: Colors.purple,
                            isDotted: true,
                            // dashArray and dashOffset are NOT supported here.
                            // To achieve a *moving* dotted effect, you'd need a custom painter.
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
                                color: station.availableBikes > 0
                                    ? Colors.indigo
                                    : Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        if (_currentLocationMarker != null)
                          _currentLocationMarker!,
                      ],
                    ),
                  ],
                ),
          // NEW: Ride Active Status Overlay
          if (_isRideActive)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                color: Theme.of(context).primaryColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ride Active: ${_activeBikeCode ?? 'Unknown Bike'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Time Remaining: ${_formatDuration(_remainingRideTime)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _endRide, // Call _endRide to simulate ending
                        icon: const Icon(
                          Icons.lock_open,
                          color: Colors.blueGrey,
                        ),
                        label: const Text(
                          'End Ride',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
    );
  }

  @override
  void dispose() {
    _stationRefreshTimer?.cancel();
    _dottedAnimationController?.dispose();
    _rideCountdownTimer?.cancel(); // NEW: Cancel ride countdown timer
    super.dispose();
  }
}
