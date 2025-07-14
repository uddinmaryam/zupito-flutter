// lib/screens/ride_history_screen.dart

import 'package:flutter/material.dart';
import 'package:zupito/services/api_service.dart';
import 'package:zupito/services/secure_storage_services.dart';
import 'package:zupito/models/user.dart';
import 'dart:convert';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();
  List<Map<String, dynamic>> rideHistory = [];
  bool _isLoading = true;
  String? _error; // Added error state

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    debugPrint("Attempting to fetch user data for ride history...");
    try {
      final data = await _secureStorage.readUser();
      if (data != null) {
        debugPrint("User data found: $data");
        final jsonData = jsonDecode(data);
        // FIX: Change UserProfile.fromJson to User.fromJson
        final user = User.fromJson(jsonData); // Use your custom User model

        debugPrint("User ID for API call: ${user.id}");

        final rides = await ApiService().fetchRideHistory(user.id);
        debugPrint("API returned ${rides.length} rides.");

        // Sort newest first
        rides.sort((a, b) {
          final startTimeA = a['startTime'];
          final startTimeB = b['startTime'];

          if (startTimeA == null || startTimeB == null) {
            return 0;
          }
          return DateTime.parse(
            startTimeB,
          ).compareTo(DateTime.parse(startTimeA));
        });

        setState(() {
          rideHistory = rides;
        });
        debugPrint(
          "Ride history state updated. Total rides: ${rideHistory.length}",
        );
      } else {
        debugPrint(
          "No user data found in secure storage. Cannot fetch ride history.",
        );
        setState(() {
          _error = 'User not logged in. Please log in to view history.';
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching rides in RideHistoryScreen: $e");
      setState(() {
        _error =
            'Failed to load ride history: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride History"),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _fetchRideHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : rideHistory.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 320,
                  child: Center(
                    child: Text(
                      "No ride history found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rideHistory.length,
              itemBuilder: (context, index) {
                final ride = rideHistory[index];
                // ... rest of your code remains unchanged ...
                final startStationName =
                    ride['startStation']?['name'] ?? 'Unknown';
                final destinationStationName =
                    ride['destinationStation']?['name'] ?? 'Unknown';
                final fare = (ride['fare'] as num?)?.toDouble() ?? 0.0;
                final penalty =
                    (ride['penaltyAmount'] as num?)?.toDouble() ?? 0.0;

                DateTime? startTime;
                if (ride['startTime'] is String) {
                  try {
                    startTime = DateTime.parse(ride['startTime']);
                  } catch (e) {
                    debugPrint(
                      "Error parsing startTime for ride: ${ride['startTime']} - $e",
                    );
                  }
                }

                final endTimeStr = ride['endTime'];
                String durationStr = '';

                if (startTime != null && endTimeStr is String) {
                  try {
                    final endTime = DateTime.parse(endTimeStr);
                    final duration = endTime.difference(startTime).inMinutes;
                    durationStr = '⏱️ $duration min';
                  } catch (e) {
                    debugPrint(
                      "Error parsing endTime for ride: $endTimeStr - $e",
                    );
                  }
                }

                final dateStr = startTime != null
                    ? "${startTime.day}/${startTime.month}/${startTime.year} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}"
                    : 'Invalid Date';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.pedal_bike,
                      size: 30,
                      color: Colors.indigo,
                    ),
                    title: Text('$startStationName → $destinationStationName'),
                    subtitle: Text(
                      '📅 $dateStr${durationStr.isNotEmpty ? '\n$durationStr' : ''}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${fare.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (penalty > 0)
                          Text(
                            '⚠️ Penalty: Rs. ${penalty.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
