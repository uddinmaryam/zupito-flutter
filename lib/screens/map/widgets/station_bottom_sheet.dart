import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';
import 'package:zupito/utils/top_notification.dart';
import '../../../models/station.dart';
import '../../../models/user.dart';
import '../../../services/secure_storage_services.dart';
import '../../../utils/constants.dart'; // Ensure you have this import for Constants.apiUrl

// This function builds the main station bottom sheet.
Widget buildStationBottomSheet(
  BuildContext context,
  Station station,
  UserProfile userProfile, {
  Future<void> Function(
    LatLng bikeLatLng,
    String bikeCode,
    int durationMinutes,
  )?
  onUnlockSuccess,
}) {
  final BuildContext rootContext = context;

  void refreshSheet() {
    // This pop closes the current bottom sheet
    Navigator.pop(rootContext);

    // Then, immediately show a new one.
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => buildStationBottomSheet(
        context,
        station,
        userProfile,
        onUnlockSuccess: onUnlockSuccess,
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
    builder: (context, scrollController) => SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            station.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if ((station.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(station.description ?? ''),
            ),
          const SizedBox(height: 20),
          Text(
            'Available Bikes (${availableBikes.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (availableBikes.isEmpty)
            const Center(child: Text('No bikes available.'))
          else
            Column(
              children: availableBikes
                  .map(
                    (bike) => _BikeCard(
                      bike: bike,
                      isAvailable: true,
                      onRefresh: refreshSheet,
                      onUnlockSuccess: onUnlockSuccess,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 20),
          Text(
            'Unavailable Bikes (${unavailableBikes.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          if (unavailableBikes.isEmpty)
            const Center(child: Text('No unavailable bikes.'))
          else
            Column(
              children: unavailableBikes
                  .map(
                    (bike) => _BikeCard(
                      bike: bike,
                      isAvailable: false,
                      onRefresh: refreshSheet,
                      onUnlockSuccess: onUnlockSuccess,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(rootContext),
              icon: const Icon(Icons.close),
              label: const Text("Close"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ------------------- _BikeCard Widget -------------------
class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;
  final VoidCallback onRefresh;
  final Function(LatLng bikeLatLng, String bikeCode, int durationMinutes)?
  onUnlockSuccess;

  const _BikeCard({
    required this.bike,
    required this.isAvailable,
    required this.onRefresh,
    this.onUnlockSuccess,
  });

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;

  // Define a constant for price per minute (e.g., NPR 10)
  static const double _pricePerMinute = 10.0; // Assuming NPR 10 per minute

  // State to hold the currently selected ride duration
  int _selectedDurationMinutes = 30; // Default selection

  // ------------------- _showRideOptionsBottomSheet Function -------------------
  void _showRideOptionsBottomSheet(Bike selectedBike) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take more height
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update UI inside bottom sheet
          builder: (BuildContext context, StateSetter setStateInSheet) {
            double calculatedPrice = _selectedDurationMinutes * _pricePerMinute;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, // Add some top padding
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Ride Duration for ${selectedBike.code}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10, // Horizontal space between buttons
                    runSpacing: 10, // Vertical space between lines of buttons
                    children: [
                      _buildDurationChip(30, setStateInSheet),
                      _buildDurationChip(45, setStateInSheet),
                      _buildDurationChip(60, setStateInSheet),
                      _buildDurationChip(90, setStateInSheet),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Per minute rate: NPR ${_pricePerMinute.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total estimated cost: NPR ${calculatedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement actual payment processing and ride initiation
                        Navigator.pop(
                          context,
                        ); // Dismiss current bottom sheet (ride options)

                        // Show success message
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Simulating payment for $_selectedDurationMinutes minutes... Ride will start soon!',
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );

                        // Dismiss the main station bottom sheet as ride is about to start
                        Navigator.pop(this.context);

                        // If you want to immediately show the polyline, call this
                        final bikeLatLng = LatLng(
                          selectedBike.lat,
                          selectedBike.lng,
                        );
                        widget.onUnlockSuccess?.call(
                          bikeLatLng,
                          selectedBike.code,
                          _selectedDurationMinutes,
                        );

                        // Later: Trigger a backend call to start the ride with selected duration
                        // and update bike state on map.
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        minimumSize: const Size.fromHeight(
                          50,
                        ), // Make button wide
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Pay & Start Ride',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper function to build duration chips for the bottom sheet
  Widget _buildDurationChip(int duration, StateSetter setStateInSheet) {
    final bool isSelected = _selectedDurationMinutes == duration;
    return ChoiceChip(
      label: Text('$duration mins'),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setStateInSheet(() {
            _selectedDurationMinutes = duration;
          });
        }
      },
    );
  }
  // ------------------- END _showRideOptionsBottomSheet Function -------------------

  Future<void> _handleUnlock() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final storage = SecureStorageService();
    final userJson = await storage.readUser();
    final userId = userJson != null ? jsonDecode(userJson)['_id'] : null;

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ User not found.")));
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final otpGen = await http.post(
        Uri.parse(
          '${Constants.apiUrl}/bikes/generate-otp',
        ), // Using Constants.apiUrl
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bikeCode': widget.bike.code, 'userId': userId}),
      );

      if (!mounted) return;

      if (otpGen.statusCode == 200) {
        final responseBody = jsonDecode(otpGen.body);
        final otp = responseBody['otp'];
        showTopNotification(context, "🔐 OTP for ${widget.bike.code}: $otp");

        String? enteredOtp;
        await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _OTPDialog(
            onSubmit: (otpFromDialog) {
              enteredOtp = otpFromDialog;
              Navigator.of(dialogContext).pop();
            },
          ),
        );

        if (!mounted) return;
        if (enteredOtp == null || enteredOtp!.isEmpty) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final verify = await http.post(
          Uri.parse(
            '${Constants.apiUrl}/bikes/verify-otp',
          ), // Using Constants.apiUrl
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': widget.bike.code, 'otp': enteredOtp}),
        );

        if (!mounted) return;

        if (verify.statusCode == 200) {
          // The OTP dialog is already dismissed by _OTPDialogState._verify.
          // We no longer need Navigator.popUntil here, as it was causing the unmounted error.

          // Now, show the ride options bottom sheet
          _showRideOptionsBottomSheet(widget.bike);

          // All other post-unlock logic (like showing AlertDialog and refreshing)
          // has been moved into the _showRideOptionsBottomSheet's 'Pay & Start Ride' logic.
        } else {
          final error = jsonDecode(verify.body);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("❌ ${error['message']}")));
        }
      } else {
        final error = jsonDecode(otpGen.body);
        throw Exception('Failed to generate OTP: ${error['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String unavailableText;
    // Logic to display availableInMinutes for unavailable bikes
    if (!widget.isAvailable) {
      if (widget.bike.availableInMinutes != null &&
          widget.bike.availableInMinutes! > 0) {
        unavailableText =
            'Unavailable (Available in ${widget.bike.availableInMinutes} mins)';
      } else {
        unavailableText = 'Unavailable';
      }
    } else {
      unavailableText = ''; // Should not be reached for available bikes
    }

    return Card(
      child: ListTile(
        title: Text(widget.bike.name ?? 'Bike'),
        subtitle: Text('Code: ${widget.bike.code}'),
        trailing: widget.isAvailable
            ? (_loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleUnlock,
                      child: const Text('Unlock'),
                    ))
            // Use the determined unavailableText here
            : Text(unavailableText, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

// ------------------- _OTPDialog Widget -------------------
class _OTPDialog extends StatefulWidget {
  final void Function(String) onSubmit;

  const _OTPDialog({required this.onSubmit});

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
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        _timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) {
        _timer.cancel();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⏱️ Time expired. Please try again.")),
          );
        }
      }
    });
  }

  void _verify() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;
    _timer.cancel();
    widget.onSubmit(otp);
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpController.dispose();
    super.dispose();
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
