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
  required Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
    Station selectedDestinationStation,
  )
  onRideStartConfirmed,
}) {
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

// The rest of the _BikeCard class remains unchanged and correct as per your latest code.

class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;
  final VoidCallback onRefresh;
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
    Station selectedDestinationStation, // Updated to pass Station object
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

  List<Station> _selectableStations = []; // ✅ New list for dropdown items
  Station? _selectedDestinationStation; // Keep as Station object

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final allStations = await _apiService.getStations();

      final List<Station> otherStations = allStations
          .where((s) => s.id != widget.startStationId)
          .toList();

      Station? currentStartStation;
      if (allStations.any((s) => s.id == widget.startStationId)) {
        currentStartStation = allStations.firstWhere(
          (s) => s.id == widget.startStationId,
        );
      }

      // ⚠️ Must use `setState` only once to prevent rebuild confusion
      List<Station> allSelectable = [...otherStations];
      if (currentStartStation != null) {
        allSelectable.add(currentStartStation);
      }

      Station? preselectStation = allSelectable.isNotEmpty
          ? allSelectable.first
          : null;

      setState(() {
        _selectableStations = allSelectable;
        _selectedDestinationStation = preselectStation;
      });

      if (_selectableStations.isEmpty) {
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

    if (_selectableStations.isEmpty) {
      await _fetchStations();
      if (_selectableStations.isEmpty) {
        showTopNotification(context, "No destination stations available.");
        return;
      }
    }

    if (_selectedDestinationStation == null && _selectableStations.isNotEmpty) {
      setState(() {
        _selectedDestinationStation = _selectableStations.first;
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final selectedStationName = widget.station.name;
            final predefinedNames = [
              'Pulchowk',
              'Jawalakhel',
              'Dhobighat',
              'Ekantakuna',
              'Sanepa Chowk',
            ];

            final destinationNames = predefinedNames
                .where((name) => name != selectedStationName)
                .toList();
            destinationNames.add('Return to Same Station');

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
                    const Text("Choose destination station:"),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value:
                          _selectedDestinationStation?.name ==
                              selectedStationName
                          ? 'Return to Same Station'
                          : _selectedDestinationStation?.name,
                      isExpanded: true,
                      onChanged: (String? selectedName) {
                        setState(() {
                          if (selectedName == 'Return to Same Station') {
                            _selectedDestinationStation = widget.station;
                          } else {
                            _selectedDestinationStation = _selectableStations
                                .firstWhere(
                                  (s) => s.name == selectedName,
                                  orElse: () => widget.station,
                                );
                          }
                        });
                      },
                      items: destinationNames.map((name) {
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
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
                  onPressed: _selectedDestinationStation == null
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          await _startRide(
                            widget.bike,
                            selectedDuration,
                            _selectedDestinationStation!.id,
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
    // Updated parameter to take ID
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
        startStationId: widget
            .startStationId, // ✅ Pass the actual start station ID from widget
        destinationStationId:
            destinationStationId, // ✅ Pass the selected destination ID
        estimatedCost: initialEstimatedCost,

        startLat: confirmedBikeStartLocation.latitude, // <--- ADDED
        startLng: confirmedBikeStartLocation.longitude, // <--- ADDED
      ); // Send client's initial estimate

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
          _selectedDestinationStation!, // ✅ Pass the full Station object
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
