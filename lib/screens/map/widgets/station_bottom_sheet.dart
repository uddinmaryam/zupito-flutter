// lib/screens/map/widgets/station_bottom_sheet.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/utils/top_notification.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/utils/constants.dart';
import 'package:zupito/screens/login_screen.dart'; // Added for explicit navigation

// This is the top-level function that MapScreen calls.
// It creates a DraggableScrollableSheet and wraps the content in _StationBottomSheetContent.
Widget buildStationBottomSheet(
  BuildContext context,
  Station station,
  User userProfile, {
  required Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )
  onRideStartConfirmed,
}) {
  return DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 0.9,
    builder: (context, scrollController) => _StationBottomSheetContent(
      station: station,
      userProfile: userProfile,
      onRideStartConfirmed: onRideStartConfirmed,
      scrollController: scrollController,
    ),
  );
}

// This is the StatefulWidget that manages the content and state of the bottom sheet.
class _StationBottomSheetContent extends StatefulWidget {
  final Station station;
  final User userProfile;
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )
  onRideStartConfirmed;
  final ScrollController scrollController;

  const _StationBottomSheetContent({
    required this.station,
    required this.userProfile,
    required this.onRideStartConfirmed,
    required this.scrollController,
  });

  @override
  State<_StationBottomSheetContent> createState() =>
      _StationBottomSheetContentState();
}

class _StationBottomSheetContentState
    extends State<_StationBottomSheetContent> {
  List<Bike> _fullBikesInStation = [];
  bool _bikesLoading = true;
  String? _bikesError;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchFullBikesForStation();
  }

  // Ensure mounted check before setState
  Future<void> _fetchFullBikesForStation() async {
    if (!mounted) return; // Crucial mounted check
    setState(() {
      _bikesLoading = true;
      _bikesError = null;
    });
    try {
      // This assumes your backend's /stations endpoint now returns full Bike objects
      // nested within the station JSON (as per our Option 1 discussion).
      // If not, you'd need a separate API call per bike ID, or a bulk fetch.
      // For now, we are relying on the Station model having List<Bike> bikes.
      // The bikes property of the station object should already contain the full Bike objects
      // if the backend is populating them and the Station.fromJson is updated.
      _fullBikesInStation =
          widget.station.bikes; // Directly use bikes from the station object

      // If you still need to fetch bikes separately (e.g., if station.bikes only contains IDs):
      // final List<Bike> allFetchedBikes = await _apiService.getBikes();
      // _fullBikesInStation = allFetchedBikes
      //     .where((bike) => widget.station.bikes.contains(bike.id)) // This assumes widget.station.bikes is List<String>
      //     .toList();
    } catch (e) {
      _bikesError =
          'Failed to load bike details: ${e.toString().replaceFirst('Exception: ', '')}';
      print('Error fetching full bike details for station: $e');
      if (mounted) {
        showTopNotification(context, _bikesError!);
      }
    } finally {
      if (mounted) {
        // Crucial mounted check
        setState(() {
          _bikesLoading = false;
        });
      }
    }
  }

  void refreshSheet() {
    _fetchFullBikesForStation();
  }

  @override
  Widget build(BuildContext context) {
    final availableBikes = _fullBikesInStation
        .where((b) => b.isAvailable)
        .toList();
    final unavailableBikes = _fullBikesInStation
        .where((b) => !b.isAvailable)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.station.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _bikesLoading
                ? const Center(child: CircularProgressIndicator())
                : _bikesError != null
                ? Center(
                    child: Text(
                      _bikesError!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Bikes (${availableBikes.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (availableBikes.isEmpty)
                        const Center(child: Text('No bikes available.'))
                      else
                        Wrap(
                          runSpacing: 12,
                          children: availableBikes
                              .map(
                                (bike) => _BikeCard(
                                  bike: bike,
                                  isAvailable: true,
                                  onRefresh: refreshSheet,
                                  onRideStartConfirmed:
                                      widget.onRideStartConfirmed,
                                  stationStartLocation: LatLng(
                                    widget.station.latitude,
                                    widget.station.longitude,
                                  ),
                                  startStationId: widget.station.id,
                                  station: widget.station,
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Unavailable Bikes (${unavailableBikes.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (unavailableBikes.isEmpty)
                        const Center(child: Text('No unavailable bikes.'))
                      else
                        Wrap(
                          runSpacing: 12,
                          children: unavailableBikes
                              .map(
                                (bike) => _BikeCard(
                                  bike: bike,
                                  isAvailable: false,
                                  onRefresh: refreshSheet,
                                  onRideStartConfirmed:
                                      widget.onRideStartConfirmed,
                                  stationStartLocation: LatLng(
                                    widget.station.latitude,
                                    widget.station.longitude,
                                  ),
                                  startStationId: widget.station.id,
                                  station: widget.station,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
            const SizedBox(height: 30),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;
  final VoidCallback onRefresh;
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )?
  onRideStartConfirmed;
  final LatLng stationStartLocation;
  final String startStationId;
  final Station station;

  const _BikeCard({
    super.key,
    required this.bike,
    required this.isAvailable,
    required this.onRefresh,
    this.onRideStartConfirmed,
    required this.stationStartLocation,
    required this.startStationId,
    required this.station,
  });

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;
  final ApiService _apiService = ApiService();
  static const double _pricePerMinute = 2.0;

  List<Station> _selectableStations = [];
  Station? _selectedDestinationStation;

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final allStations = await _apiService.getStations();
      if (!mounted) return; // Mounted check

      final List<Station> otherStations = allStations
          .where((s) => s.id != widget.startStationId)
          .toList();

      List<Station> allSelectable = [...otherStations];

      setState(() {
        _selectableStations = allSelectable;
        _selectedDestinationStation =
            widget.station; // Default to current station
      });

      if (_selectableStations.isEmpty && widget.station.id.isNotEmpty) {
        if (!mounted) return; // Mounted check
        setState(() {
          _selectableStations.add(widget.station);
          _selectedDestinationStation = widget.station;
        });
      } else if (_selectableStations.isEmpty) {
        if (!mounted) return; // Mounted check
        showTopNotification(context, "No stations available for selection.");
      }
    } catch (e) {
      if (mounted) {
        // Mounted check
        showTopNotification(
          context,
          "❌ Error fetching stations: ${e.toString()}",
        );
        setState(() {
          _selectableStations = [];
          _selectedDestinationStation = null;
        });
      }
    }
  }

  Future<void> _showPaymentDialog(Bike bike) async {
    final List<int> durations = [1, 2, 5, 30, 45, 60];
    int selectedDuration = durations[0];

    if (_selectableStations.isEmpty || _selectedDestinationStation == null) {
      await _fetchStations();
      if (_selectableStations.isEmpty) {
        if (!mounted) return; // Mounted check
        showTopNotification(
          context,
          "No destination stations available for selection.",
        );
        return;
      }
      if (_selectedDestinationStation == null) {
        _selectedDestinationStation = widget.station;
      }
    }

    if (!mounted) return; // Mounted check
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // final selectedStationName = widget.station.name; // Not used, can remove

            List<DropdownMenuItem<Station>> destinationDropdownItems = [];

            destinationDropdownItems.add(
              DropdownMenuItem<Station>(
                value: widget.station,
                child: Text('${widget.station.name} (Same Station)'),
              ),
            );

            for (var s in _selectableStations) {
              if (s.id != widget.station.id) {
                destinationDropdownItems.add(
                  DropdownMenuItem<Station>(value: s, child: Text(s.name)),
                );
              }
            }
            if (_selectedDestinationStation == null ||
                !destinationDropdownItems.any(
                  (item) => item.value?.id == _selectedDestinationStation?.id,
                )) {
              _selectedDestinationStation = widget.station;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Confirm Ride Details"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select ride duration:"),
                    const SizedBox(height: 10),
                    DropdownButton<int>(
                      value: selectedDuration,
                      isExpanded: true,
                      onChanged: (value) =>
                          setState(() => selectedDuration = value!),
                      items: durations.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text("$d minutes"),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Choose destination station: (Optional, you can return to any station or within Lalitpur)",
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<Station>(
                      value: _selectedDestinationStation,
                      isExpanded: true,
                      onChanged: (Station? newStation) {
                        setState(() {
                          _selectedDestinationStation = newStation;
                        });
                      },
                      items: destinationDropdownItems,
                    ),
                    const SizedBox(height: 20),
                    Text("Rate: Rs $_pricePerMinute per minute"),
                    Text(
                      "Estimated Cost: Rs ${(selectedDuration * _pricePerMinute).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "(Final cost may vary based on actual ride duration and drop-off location)",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _startRide(
                      widget.bike,
                      selectedDuration,
                      _selectedDestinationStation?.id ?? widget.station.id,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Confirm & Pay with eSewa"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startRide(
    Bike bike,
    int duration,
    String destinationStationId,
  ) async {
    if (!mounted) return; // Mounted check
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService()
          .readUserProfile(); // FIX: Use readUserProfile
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        if (mounted) {
          // Mounted check
          showTopNotification(
            context,
            "❌ User ID not found in storage. Please log in again.",
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return; // Exit if userId is null
      }

      final double initialEstimatedCost = duration * _pricePerMinute;

      final LatLng confirmedBikeStartLocation = widget.stationStartLocation;

      final Map<String, dynamic> responseData = await _apiService.startRide(
        userId: userId,
        bikeId: bike.id,
        selectedDuration: duration,
        startStationId: widget.startStationId,
        destinationStationId: destinationStationId,
        estimatedCost: initialEstimatedCost,
        startLat: confirmedBikeStartLocation.latitude,
        startLng: confirmedBikeStartLocation.longitude,
      );

      final String rideId = responseData['rideId'] ?? '';
      final String bikeCode = bike.code ?? 'Unknown';

      final DateTime rideEndTime = responseData['rideEndTime'] != null
          ? DateTime.parse(responseData['rideEndTime'])
          : DateTime.now().add(Duration(minutes: duration));

      if (widget.onRideStartConfirmed != null) {
        await widget.onRideStartConfirmed!(
          bikeCode,
          rideId,
          rideEndTime,
          confirmedBikeStartLocation,
        );
      }

      if (mounted) {
        // Mounted check
        showTopNotification(context, "✅ Payment Successful! Ride started.");
        Navigator.pop(context); // Close the bottom sheet
      }
    } catch (e) {
      if (mounted) {
        // Mounted check
        showTopNotification(context, "❌ Error starting ride: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUnlock() async {
    if (!mounted) return; // Mounted check
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService()
          .readUserProfile(); // FIX: Use readUserProfile
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        if (mounted) {
          // Mounted check
          showTopNotification(
            context,
            "❌ User ID not found in secure storage. Please log in again.",
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return; // Exit if userId is null
      }

      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/bikes/generate-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'bikeCode': widget.bike.code, 'userId': userId}),
      );

      if (response.statusCode == 200) {
        final otp = jsonDecode(response.body)['otp'];
        if (mounted) {
          // Mounted check
          showTopNotification(context, "🔐 OTP for ${widget.bike.code}: $otp");
        }

        String? enteredOtp;
        if (mounted) {
          // Mounted check
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _OTPDialog(
              onSubmit: (otpInput) {
                enteredOtp = otpInput;
                Navigator.of(ctx).pop();
              },
            ),
          );
        }

        if (enteredOtp == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final verify = await http.post(
          Uri.parse('${Constants.apiUrl}/bikes/verify-otp'),
          headers: _jsonHeaders,
          body: jsonEncode({'code': widget.bike.code, 'otp': enteredOtp}),
        );

        if (verify.statusCode == 200) {
          await _showPaymentDialog(widget.bike);
        } else {
          final err = jsonDecode(verify.body);
          if (mounted) {
            // Mounted check
            showTopNotification(context, "❌ ${err['message']}");
          }
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          // Mounted check
          showTopNotification(context, "❌ ${err['message']}");
        }
      }
    } catch (e) {
      if (mounted) {
        // Mounted check
        showTopNotification(context, "❌ Error unlocking bike: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String subtitleText;
    if (widget.isAvailable) {
      subtitleText = 'Available';
    } else {
      String bikeStatus = widget.bike.status ?? 'N/A';
      String availabilityTime = widget.bike.availableInMinutes != null
          ? ', Available in ${widget.bike.availableInMinutes} mins'
          : '';
      subtitleText = 'Unavailable (Status: $bikeStatus$availabilityTime)';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        title: Text(widget.bike.code ?? 'N/A'),
        subtitle: Text(subtitleText),
        trailing: widget.isAvailable
            ? (_loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleUnlock,
                      child: const Text('Unlock'),
                    ))
            : const Icon(Icons.lock, color: Colors.red),
      ),
    );
  }
}

class _OTPDialog extends StatefulWidget {
  final void Function(String) onSubmit;

  const _OTPDialog({super.key, required this.onSubmit});

  @override
  State<_OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<_OTPDialog> {
  final TextEditingController _otpController = TextEditingController();
  late Timer _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        // Mounted check
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) {
        _timer.cancel();
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
        if (mounted) {
          // Mounted check
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⏱️ Time expired. Please try again.")),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _verify() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;
    _timer.cancel();
    widget.onSubmit(otp);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Enter OTP"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("⏳ You have $_secondsLeft seconds"),
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "OTP",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [TextButton(onPressed: _verify, child: const Text("Submit"))],
    );
  }
}
