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

Widget buildStationBottomSheet(
  BuildContext context,
  Station station,
  UserProfile userProfile, {
  Function(LatLng)? onUnlockSuccess,
}) {
  void refreshSheet() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
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
  );
}

class _BikeCard extends StatefulWidget {
  final Bike bike;
  final bool isAvailable;
  final VoidCallback onRefresh;
  final Function(LatLng)? onUnlockSuccess;

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
      final otpGen = await http.post(
        Uri.parse(
          'https://backend-bicycle-1.onrender.com/api/v1/bikes/generate-otp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bikeCode': widget.bike.code, 'userId': userId}),
      );

      if (otpGen.statusCode == 200) {
        final responseBody = jsonDecode(otpGen.body);
        final otp = responseBody['otp'];
        showTopNotification(context, "🔐 OTP for ${widget.bike.code}: $otp");

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _OTPDialog(
            onSubmit: (enteredOtp) async {
              final verify = await http.post(
                Uri.parse(
                  'https://backend-bicycle-1.onrender.com/api/v1/bikes/verify-otp',
                ),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'code': widget.bike.code, 'otp': enteredOtp}),
              );
              if (verify.statusCode == 200) {
                if (!mounted) return;
                Navigator.of(context).pop(); // Close OTP dialog first

                Future.delayed(Duration.zero, () {
                  if (!mounted) return;
                  Navigator.of(context).pop(
                    LatLng(widget.bike.lat, widget.bike.lng),
                  ); // Close bottom sheet
                  widget.onRefresh();
                  widget.onUnlockSuccess?.call(
                    LatLng(widget.bike.lat, widget.bike.lng),
                  );
                });
              } else {
                final error = jsonDecode(verify.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ ${error['message']}")),
                );
              }
            },
          ),
        );
      } else {
        final error = jsonDecode(otpGen.body);
        throw Exception('Failed to generate OTP: ${error['message']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: ${e.toString()}")));
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
            : const Text('Unavailable', style: TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _OTPDialog extends StatefulWidget {
  final Future<void> Function(String) onSubmit;

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
