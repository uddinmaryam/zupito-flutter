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

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    debugPrint("Attempting to fetch user data for ride history...");
    final data = await _secureStorage.readUser();
    if (data != null) {
      debugPrint("User data found: $data");
      final jsonData = jsonDecode(data);
      final user = UserProfile.fromJson(jsonData);

      debugPrint(
        "User ID for API call: ${user.id}",
      ); // Check the actual user ID being used

      try {
        final rides = await ApiService().fetchRideHistory(user.id);
        debugPrint(
          "API returned ${rides.length} rides.",
        ); // Check how many rides came back

        // ✅ Sort newest first
        // Add a check to ensure 'startTime' exists before parsing
        rides.sort((a, b) {
          final startTimeA = a['startTime'];
          final startTimeB = b['startTime'];

          if (startTimeA == null || startTimeB == null) {
            // Handle cases where startTime might be missing,
            // perhaps by placing rides with missing times at the end
            return 0; // Or define a custom sorting logic for nulls
          }
          return DateTime.parse(
            startTimeB,
          ).compareTo(DateTime.parse(startTimeA));
        });

        setState(() {
          rideHistory = rides;
          _isLoading = false;
        });
        debugPrint(
          "Ride history state updated. Total rides: ${rideHistory.length}",
        );
      } catch (e) {
        debugPrint(
          "❌ Error fetching rides in RideHistoryScreen: $e",
        ); // Pay attention to this error
        setState(() => _isLoading = false);
      }
    } else {
      debugPrint(
        "No user data found in secure storage. Cannot fetch ride history.",
      );
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
          : rideHistory.isEmpty
          ? const Center(child: Text("No ride history found."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rideHistory.length,
              itemBuilder: (context, index) {
                final ride = rideHistory[index];
                // Add debug prints for individual ride data
                debugPrint('Displaying Ride: $ride'); // See the full ride map
                debugPrint(
                  'Start Station: ${ride['startStation']}, End Station: ${ride['endStation']}',
                );
                debugPrint(
                  'Start Time: ${ride['startTime']}, End Time: ${ride['endTime']}',
                );

                final start = ride['startStation'] ?? 'Unknown';
                final end = ride['endStation'] ?? 'Unknown';
                final fare = ride['fare'] ?? 0;
                final penalty = ride['penalty'] ?? 0;

                // Safely parse startTime
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

                // ✅ Calculate ride duration if ended and times are valid
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
                    title: Text('$start → $end'),
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
