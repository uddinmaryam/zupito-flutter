import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zupito/main.dart'; // for showUnlockNotification
import 'package:zupito/models/bike.dart';
import '../../../models/station.dart';
import '../../../models/user.dart';
import '../../../services/secure_storage_services.dart';

void showStationBottomSheet(
  BuildContext context,
  Station station,
  UserProfile userProfile,
) {
  final availableBikes = station.bikes.where((b) => b.isAvailable).toList();
  final unavailableBikes = station.bikes.where((b) => !b.isAvailable).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
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
            if (station.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(station.description),
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
                children: availableBikes.map((bike) {
                  return _BikeCard(bike: bike, isAvailable: true);
                }).toList(),
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
                children: unavailableBikes.map((bike) {
                  return _BikeCard(bike: bike, isAvailable: false);
                }).toList(),
              ),
            const SizedBox(height: 24),

            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
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
    ),
  );
}

class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;

  const _BikeCard({required this.bike, required this.isAvailable});

  @override
  State<_BikeCard> createState() => _BikeCardState();
}

class _BikeCardState extends State<_BikeCard> {
  bool _loading = false;

  Future<void> _handleUnlock() async {
    setState(() => _loading = true);

    final storage = SecureStorageService();
    final userJson = await storage.readUser();
    final userId = userJson != null ? jsonDecode(userJson)['_id'] : null;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ User not found.")));
      setState(() => _loading = false);
      return;
    }

    try {
      // ✅ STEP 1: Send userId to generate OTP
      final otpGen = await http.post(
        Uri.parse('https://backend-bicycle-1.onrender.com/api/v1/otp/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bikeCode': widget.bike.code, 'userId': userId}),
      );

      if (otpGen.statusCode == 200) {
        // ✅ Now the OTP will come via WebSocket, not from here
        await showUnlockNotification(widget.bike.name);

        // Show dialog to enter OTP manually (from notification or WebSocket message)
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => OTPDialog(
            onSubmit: (enteredOtp) async {
              final verify = await http.post(
                Uri.parse(
                  'https://backend-bicycle-1.onrender.com/api/v1/bikes/verify-otp',
                ),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'code': widget.bike.code, 'otp': enteredOtp}),
              );

              if (verify.statusCode == 200 &&
                  jsonDecode(verify.body)['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ OTP verified. Bike unlocked."),
                  ),
                );
                setState(() {
                  widget.bike.isUnlocked = true;
                  widget.bike.isAvailable = false;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("❌ Incorrect or expired OTP.")),
                );
              }
            },
          ),
        );
      } else {
        throw Exception('Failed to generate OTP: ${otpGen.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error unlocking: $e')));
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isAvailable ? Colors.white : Colors.grey[200],
      child: ListTile(
        title: Text(widget.bike.name),
        subtitle: Text(
          widget.isAvailable
              ? 'Rs. ${widget.bike.pricePerMinute}/min'
              : 'Available in ${widget.bike.availableInMinutes ?? '?'} mins',
        ),
        trailing: widget.isAvailable
            ? _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: _handleUnlock,
                      child: const Text('Unlock'),
                    )
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }

  Future<void> showUnlockNotification(String name) async {}
}

class OTPDialog extends StatefulWidget {
  final Future<void> Function(String) onSubmit;

  const OTPDialog({required this.onSubmit});

  @override
  State<OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<OTPDialog> {
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
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) {
        _timer.cancel();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⏱️ Time expired. Bike locked.")),
        );
      }
    });
  }

  void _verify() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;

    _timer.cancel();
    Navigator.pop(context);
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
