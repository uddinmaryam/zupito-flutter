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
    final data = await _secureStorage.readUser();
    if (data != null) {
      final jsonData = jsonDecode(data);
      final user = UserProfile.fromJson(jsonData);

      try {
        final rides = await ApiService().fetchRideHistory(user.id);
        setState(() {
          rideHistory = rides;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("❌ Error fetching rides: $e");
        setState(() => _isLoading = false);
      }
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
                final start = ride['startStation'] ?? 'Unknown';
                final end = ride['endStation'] ?? 'Unknown';
                final fare = ride['fare'] ?? 0;
                final penalty = ride['penalty'] ?? 0;
                final dateTime = DateTime.parse(ride['startTime']);

                final dateStr =
                    "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";

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
                    subtitle: Text('📅 $dateStr'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. $fare',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (penalty > 0)
                          Text(
                            '⚠️ Penalty: Rs. $penalty',
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
