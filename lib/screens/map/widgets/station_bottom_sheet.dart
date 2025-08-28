// lib/screens/map/widgets/station_bottom_sheet.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';
import 'package:zupito/screens/payment_service.dart';
import 'package:zupito/screens/paypal_webview.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/utils/top_notification.dart';
import 'package:zupito/models/station.dart';
import 'package:zupito/models/user.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/utils/constants.dart';
import 'package:zupito/screens/login_screen.dart';
// Removed payment service import as it's no longer used
// import 'package:zupito/services/payment_service.dart';

// TOP-LEVEL FUNCTION (called by MapScreen)
Widget buildStationBottomSheet(
  BuildContext context,
  Station station,
  User userProfile,
  ApiService apiService, {
  required Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  ) onRideStartConfirmed,
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
      apiService: apiService,
    ),
  );
}

// Sheet Content Widget
class _StationBottomSheetContent extends StatefulWidget {
  final Station station;
  final User userProfile;
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  ) onRideStartConfirmed;
  final ScrollController scrollController;
  final ApiService apiService;

  const _StationBottomSheetContent({
    required this.station,
    required this.userProfile,
    required this.onRideStartConfirmed,
    required this.scrollController,
    required this.apiService,
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

  @override
  void initState() {
    super.initState();
    _fetchFullBikesForStation();
  }

  Future<void> _fetchFullBikesForStation() async {
    if (!mounted) return;
    setState(() {
      _bikesLoading = true;
      _bikesError = null;
    });
    try {
      // Assumes backend sends full Bike objects in station.bikes
      _fullBikesInStation = widget.station.bikes;
    } catch (e) {
      _bikesError =
          'Failed to load bike details: ${e.toString().replaceFirst('Exception: ', '')}';
      print('Error fetching full bike details for station: $e');
      if (mounted) {
        showTopNotification(context, _bikesError!);
      }
    } finally {
      if (mounted) {
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
    final availableBikes =
        _fullBikesInStation.where((b) => b.isAvailable).toList();
    final unavailableBikes =
        _fullBikesInStation.where((b) => !b.isAvailable).toList();

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
                                      apiService: widget.apiService,
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
                                      apiService: widget.apiService,
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
  )? onRideStartConfirmed;
  final LatLng stationStartLocation;
  final String startStationId;
  final Station station;
  final ApiService apiService;

  const _BikeCard({
    super.key,
    required this.bike,
    required this.isAvailable,
    required this.onRefresh,
    this.onRideStartConfirmed,
    required this.stationStartLocation,
    required this.startStationId,
    required this.station,
    required this.apiService,
  });

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;
  // Re-introducing a price per minute for "estimated cost" display
  static const double _pricePerMinute = 2.0;

  List<Station> _selectableStations = [];
  Station? _selectedDestinationStation;

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final allStations = await widget.apiService.getStations();
      if (!mounted) return;

      final List<Station> otherStations =
          allStations.where((s) => s.id != widget.startStationId).toList();

      List<Station> allSelectable = [...otherStations];

      setState(() {
        _selectableStations = allSelectable;
        // Default to current station if no other stations are available or selected destination is invalid
        _selectedDestinationStation = widget.station;
      });

      // Ensure the current station is always an option if no other stations are found
      if (_selectableStations.isEmpty && widget.station.id.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _selectableStations.add(widget.station);
          _selectedDestinationStation =
              widget.station; // Default to current station
        });
      } else if (_selectableStations.isEmpty) {
        if (!mounted) return;
        showTopNotification(context, "No stations available for selection.");
      }
    } catch (e) {
      if (mounted) {
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

  // Re-introducing a simplified dialog for ride details (duration and destination)
  Future<void> _showRideDetailsDialog(Bike bike) async {
    final List<int> durations = [2, 5, 10, 20, 25, 30, 45, 60];
    int selectedDuration = durations[0]; // Default to first duration

    // Ensure stations are fetched before showing the dialog
    if (_selectableStations.isEmpty || _selectedDestinationStation == null) {
      await _fetchStations();
      if (_selectableStations.isEmpty) {
        if (!mounted) return;
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

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            List<DropdownMenuItem<Station>> destinationDropdownItems = [];

            // Always include the current station as an option
            destinationDropdownItems.add(
              DropdownMenuItem<Station>(
                value: widget.station,
                child: Text('${widget.station.name} (Same Station)'),
              ),
            );

            // Add other selectable stations, excluding the current one if already added
            for (var s in _selectableStations) {
              if (s.id != widget.station.id) {
                destinationDropdownItems.add(
                  DropdownMenuItem<Station>(value: s, child: Text(s.name)),
                );
              }
            }

            // Ensure _selectedDestinationStation is a valid option in the dropdown
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
                // Dummy Pay Button - now the only confirmation button
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop(); // Close dialog
                    double amount = selectedDuration * _pricePerMinute;

                    // 1. Create PayPal order on backend
                    String? approvalUrl =
                        await PaymentService.createPayPalOrder(amount);
                    if (approvalUrl == null) {
                      showTopNotification(
                          context, "❌ Failed to create PayPal order.");
                      return;
                    }

                    // 2. Open PayPal WebView and wait for payment result
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) =>
                            PayPalWebView(approvalUrl: approvalUrl),
                      ),
                    );

                    // 3. If payment was successful, start ride
                    if (result == 'success') {
                      showTopNotification(
                          context, "✅ PayPal Payment Successful!");
                      await _startRide(
                        bike,
                        selectedDuration, // Pass selected duration
                        amount,
                        _selectedDestinationStation?.id ?? widget.station.id,
                      );
                    } else {
                      showTopNotification(
                          context, "❌ Payment cancelled or failed.");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Pay with PayPal & Start Ride"),
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
    int duration, // Now dynamically passed from dialog
    double estimatedCost, // Now dynamically passed from dialog
    String destinationStationId,
  ) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService().readUserProfile();
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        if (mounted) {
          showTopNotification(
            context,
            "❌ User ID not found in storage. Please log in again.",
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }

      final LatLng confirmedBikeStartLocation = widget.stationStartLocation;

      final Map<String, dynamic> responseData =
          await widget.apiService.startRide(
        userId: userId,
        bikeId: bike.id,
        selectedDuration: duration, // Use dynamic duration
        estimatedCost: estimatedCost, // Use dynamic estimated cost
        startStationId: widget.startStationId,
        destinationStationId: destinationStationId,
        startLat: confirmedBikeStartLocation.latitude,
        startLng: confirmedBikeStartLocation.longitude,
      );

      final String rideId = responseData['rideId'] ?? '';
      final String bikeCode = bike.code ?? 'Unknown';

      final DateTime rideEndTime = responseData['rideEndTime'] != null
          ? DateTime.parse(responseData['rideEndTime'])
          : DateTime.now()
              .add(Duration(minutes: duration)); // Use selected duration

      if (widget.onRideStartConfirmed != null) {
        await widget.onRideStartConfirmed!(
          bikeCode,
          rideId,
          rideEndTime,
          confirmedBikeStartLocation,
        );
      }

      if (mounted) {
        showTopNotification(context, "✅ Ride started successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "❌ Error starting ride: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUnlock() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService().readUserProfile();
      final decoded = userJson != null ? jsonDecode(userJson) : null;
      final String? userId = decoded != null && decoded['_id'] != null
          ? decoded['_id'].toString()
          : null;

      if (userId == null) {
        if (mounted) {
          showTopNotification(
            context,
            "❌ User ID not found in secure storage. Please log in again.",
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/bikes/generate-otp'),
        headers: widget.apiService.getHeaders(),
        body: jsonEncode({
          'bikeCode': widget.bike.code ?? '',
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final otp = jsonDecode(response.body)['otp'];
        if (mounted) {
          showTopNotification(
            context,
            "🔐 OTP for ${widget.bike.code ?? 'N/A'}: $otp",
          );
        }

        String? enteredOtp;
        if (mounted) {
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
          headers: widget.apiService.getHeaders(),
          body: jsonEncode({
            'code': widget.bike.code ?? '',
            'otp': enteredOtp ?? '',
          }),
        );

        if (verify.statusCode == 200) {
          // Call the new ride details dialog after OTP verification
          await _showRideDetailsDialog(widget.bike);
        } else {
          final err = jsonDecode(verify.body);
          showTopNotification(
            context,
            "❌ ${err['message'] ?? 'OTP verification failed.'}",
          );
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          showTopNotification(context, "❌ ${err['message']}");
        }
      }
    } catch (e) {
      if (mounted) {
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
                    onPressed:
                        _handleUnlock, // This will now lead to the dialog
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
