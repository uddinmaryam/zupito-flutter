// lib/screens/map/widgets/station_bottom_sheet.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/utils/top_notification.dart';
import '../../../models/station.dart';
import '../../../models/user.dart';
import '../../../services/secure_storage_services.dart';
import '../../../utils/constants.dart';

Widget buildStationBottomSheet(
  BuildContext context,
  Station station,
  UserProfile userProfile, {
  // MODIFIED: Removed 'Station selectedDestinationStation' from callback signature
  required Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )
  onRideStartConfirmed,
}) {
  // --- ADD THESE PRINT STATEMENTS HERE ---
  print('--- Debugging Station: ${station.name} (ID: ${station.id}) ---');
  print('Total bikes in station object: ${station.bikes.length}');
  print(
    'Available bikes in object: ${station.bikes.where((b) => b.isAvailable).length}',
  );
  print(
    'Unavailable bikes in object: ${station.bikes.where((b) => !b.isAvailable).length}',
  );
  for (var bike in station.bikes) {
    print(
      '  Bike Code: ${bike.code}, Available: ${bike.isAvailable}, Status: ${bike.status}, Available in: ${bike.availableInMinutes}',
    );
  }
  print('----------------------------------------------------');
  // --- END PRINT STATEMENTS ---

  final BuildContext rootContext = context;

  void refreshSheet() {
    Navigator.pop(rootContext);
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        userProfile,
        onRideStartConfirmed: onRideStartConfirmed,
      ),
    );
  }

  final availableBikes = station.bikes.where((b) => b.isAvailable).toList();
  final unavailableBikes = station.bikes.where((b) => !b.isAvailable).toList();

  return DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 0.9,
    builder: (context, scrollController) => Container(
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
        controller: scrollController,
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
              station.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if ((station.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  station.description ?? '',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Available Bikes (${availableBikes.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                        onRideStartConfirmed: onRideStartConfirmed,
                        stationStartLocation: LatLng(station.lat, station.lng),
                        startStationId: station.id,
                        station: station,
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
                        onRideStartConfirmed: onRideStartConfirmed,
                        stationStartLocation: LatLng(station.lat, station.lng),
                        startStationId: station.id,
                        station: station,
                      ),
                    )
                    .toList(),
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
    ),
  );
}

class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;
  final VoidCallback onRefresh;
  // MODIFIED: Removed 'Station selectedDestinationStation' from callback signature
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )?
  onRideStartConfirmed;
  final LatLng stationStartLocation; // Holds the station's geo location
  final String startStationId; // ✅ New: Holds the ID of the start station
  final Station station;

  const _BikeCard({
    super.key,
    required this.bike,
    required this.isAvailable,
    required this.onRefresh,
    this.onRideStartConfirmed,
    required this.stationStartLocation,
    required this.startStationId,
    required this.station, // Initialize in constructor
  });

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;
  final ApiService _apiService = ApiService();
  static const double _pricePerMinute = 2.0;

  // Keep these for display purposes in the dialog, but their selection
  // no longer strictly dictates the *ride end* logic on MapScreen.
  List<Station> _selectableStations = [];
  Station? _selectedDestinationStation; // Keep as Station object for dropdown

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final allStations = await _apiService.getStations();

      // For the dropdown, include all stations except the current one as "other" options
      // And then explicitly add the current station as "Return to Same Station" option.
      // This makes the dropdown cleaner and more intuitive.
      final List<Station> otherStations = allStations
          .where((s) => s.id != widget.startStationId)
          .toList();

      // Create a specific "Return to Same Station" option
      // The actual 'Station' object will be `widget.station`
      // We don't need a separate entry for it in _selectableStations if we handle its name specially
      List<Station> allSelectable = [...otherStations];

      setState(() {
        _selectableStations = allSelectable;
        // Default selection could be the starting station, or just the first available
        _selectedDestinationStation =
            widget.station; // Default to starting station
      });

      if (_selectableStations.isEmpty && widget.station.id.isNotEmpty) {
        // If no other stations, but current station is valid, just use it
        setState(() {
          _selectableStations.add(widget.station);
          _selectedDestinationStation = widget.station;
        });
      } else if (_selectableStations.isEmpty) {
        showTopNotification(context, "No stations available for selection.");
      }
    } catch (e) {
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

  Future<void> _showPaymentDialog(Bike bike) async {
    final List<int> durations = [1, 2, 5, 30, 45, 60];
    int selectedDuration = durations[0];

    // Ensure _selectableStations is populated and _selectedDestinationStation is set
    if (_selectableStations.isEmpty || _selectedDestinationStation == null) {
      await _fetchStations(); // Re-fetch if needed
      if (_selectableStations.isEmpty) {
        showTopNotification(
          context,
          "No destination stations available for selection.",
        );
        return;
      }
      if (_selectedDestinationStation == null) {
        _selectedDestinationStation =
            widget.station; // Fallback to current station
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final selectedStationName = widget.station.name;

            // Prepare list for the dropdown items (using Station object as value)
            List<DropdownMenuItem<Station>> destinationDropdownItems = [];

            // Add the "Return to Same Station" option first
            destinationDropdownItems.add(
              DropdownMenuItem<Station>(
                value: widget.station, // Value is the actual Station object
                child: Text(
                  '${widget.station.name} (Same Station)',
                ), // Display text
              ),
            );

            // Add all other stations from _selectableStations
            for (var s in _selectableStations) {
              // Ensure we don't add the current station again if it's already in _selectableStations
              // and we've added it explicitly as "Return to Same Station"
              if (s.id != widget.station.id) {
                destinationDropdownItems.add(
                  DropdownMenuItem<Station>(
                    value: s, // Value is the actual Station object
                    child: Text(s.name), // Display text
                  ),
                );
              }
            }
            // Ensure _selectedDestinationStation is one of the valid items
            // If it's null or not in the list, default to widget.station
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
                    ), // Clarified
                    const SizedBox(height: 10),
                    // MODIFIED DropdownButton to use Station as its value type
                    DropdownButton<Station>(
                      value:
                          _selectedDestinationStation, // Now a Station object
                      isExpanded: true,
                      onChanged: (Station? newStation) {
                        setState(() {
                          _selectedDestinationStation = newStation;
                        });
                      },
                      items: destinationDropdownItems, // Using the new list
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
                  // _selectedDestinationStation is only for display, so no null check here
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _startRide(
                      widget.bike,
                      selectedDuration,
                      // We still pass a destination ID to the backend if there is one selected,
                      // even if it's not strictly enforced on the client map side.
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
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService().readUser();
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        throw Exception("❌ User ID not found in storage.");
      }

      final double initialEstimatedCost = duration * _pricePerMinute;

      final LatLng confirmedBikeStartLocation = widget.stationStartLocation;

      // Use the API service to call the startRide endpoint
      final Map<String, dynamic> responseData = await _apiService.startRide(
        userId: userId,
        bikeId: bike.id,
        selectedDuration: duration,
        startStationId: widget.startStationId,
        destinationStationId: destinationStationId, // Keep sending to backend
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
        // MODIFIED: Removed 'selectedDestinationStation' from the callback parameters
        await widget.onRideStartConfirmed!(
          bikeCode,
          rideId,
          rideEndTime,
          confirmedBikeStartLocation,
        );
      }

      showTopNotification(context, "✅ Payment Successful! Ride started.");
      Navigator.pop(context); // Close the bottom sheet
    } catch (e) {
      showTopNotification(context, "❌ Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUnlock() async {
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService().readUser();
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        throw Exception("❌ User ID not found in secure storage.");
      }

      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/bikes/generate-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'bikeCode': widget.bike.code, 'userId': userId}),
      );

      if (response.statusCode == 200) {
        final otp = jsonDecode(response.body)['otp'];
        showTopNotification(context, "🔐 OTP for ${widget.bike.code}: $otp");

        String? enteredOtp;
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

        if (enteredOtp == null) {
          // If OTP dialog was dismissed without submitting
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
          showTopNotification(context, "❌ ${err['message']}");
        }
      } else {
        final err = jsonDecode(response.body);
        showTopNotification(context, "❌ ${err['message']}");
      }
    } catch (e) {
      showTopNotification(context, "❌ ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 8.0,
      ), // Added margin for better spacing
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ), // Added padding
        title: Text(widget.bike.name ?? 'Bike'),
        subtitle: Text('Code: ${widget.bike.code ?? 'N/A'}'),
        trailing: widget.isAvailable
            ? (_loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleUnlock,
                      child: const Text('Unlock'),
                    ))
            : Text(
                widget.bike.availableInMinutes != null
                    ? 'Unavailable (Available in ${widget.bike.availableInMinutes} mins)'
                    : 'Unavailable',
                style: const TextStyle(color: Colors.red),
              ),
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
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) {
        _timer.cancel();
        // Check if the dialog is still mounted before popping
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⏱️ Time expired. Please try again.")),
        );
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
