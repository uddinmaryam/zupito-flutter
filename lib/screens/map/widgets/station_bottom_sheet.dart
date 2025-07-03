// ✅ Premium UI/UX Enhanced `station_bottom_sheet.dart`

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
  final Future<void> Function(
    String bikeCode,
    String rideId,
    DateTime rideEndTime,
    LatLng bikeStartLocation,
  )? onRideStartConfirmed;

  const _BikeCard({
    super.key,
    required this.bike,
    required this.isAvailable,
    required this.onRefresh,
    this.onRideStartConfirmed,
  });

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;
  final ApiService _apiService = ApiService();
  static const double _pricePerMinute = 2.0;

  Future<void> _showPaymentDialog(Bike bike) async {
    final List<int> durations = [30, 45, 60, 90];
    int selectedDuration = durations[0];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text("Dummy eSewa Payment"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select ride duration:"),
                const SizedBox(height: 10),
                DropdownButton<int>(
                  value: selectedDuration,
                  isExpanded: true,
                  onChanged: (value) =>
                      setState(() => selectedDuration = value!),
                  items: durations
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text("$d minutes"),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text("Rate: Rs $_pricePerMinute per minute"),
                Text(
                  "Total: Rs ${(selectedDuration * _pricePerMinute).toStringAsFixed(2)}",
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _startRide(bike, selectedDuration);
                },
                child: const Text("Pay with eSewa"),
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _startRide(Bike bike, int duration) async {
  setState(() => _loading = true);

  try {
    final userJson = await SecureStorageService().readUser();
    final userId = userJson != null ? jsonDecode(userJson)['_id'] : null;
    if (userId == null) throw Exception("User not found");

    final double estimatedCost = duration * _pricePerMinute;

    final response = await _apiService.startRide(
      userId: userId,
      bikeId: bike.id,
      selectedDuration: duration,
      estimatedCost: estimatedCost,
      startLat: bike.lat ?? 0.0,
      startLng: bike.lng ?? 0.0,
    );

    if (response['success'] == true) {
      final String rideId = response['rideId'];
      final String bikeCode = response['bikeCode'];
      final DateTime rideEndTime = DateTime.parse(response['rideEndTime']);
      final LatLng bikeStartLocation = LatLng(
        response['bikeLocation']['latitude'],
        response['bikeLocation']['longitude'],
      );

      if (widget.onRideStartConfirmed != null) {
        await widget.onRideStartConfirmed!(
          bikeCode,
          rideId,
          rideEndTime,
          bikeStartLocation,
        );
      }

      showTopNotification(context, "✅ Payment Successful! Ride started.");

      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      showTopNotification(context, "❌ ${response['message'] ?? 'Failed to start ride'}");
    }
  } catch (e) {
    showTopNotification(context, "❌ Error: ${e.toString()}");
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}




  
  Future<void> _handleUnlock() async {
    setState(() => _loading = true);
    try {
      final userJson = await SecureStorageService().readUser();
      final userId = userJson != null ? jsonDecode(userJson)['_id'] : null;
      if (userId == null) throw Exception("User not found");

      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/bikes/generate-otp'),
        headers: {'Content-Type': 'application/json'},
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

        if (enteredOtp == null) return;

        final verify = await http.post(
          Uri.parse('${Constants.apiUrl}/bikes/verify-otp'),
          headers: {'Content-Type': 'application/json'},
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
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        Navigator.pop(context);
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
