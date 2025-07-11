import 'package:flutter/material.dart';
import 'package:zupito/models/ride.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/ride_card.dart';

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  List<Ride> _rides = []; // Use the Ride model for type safety
  bool _isLoading = true;
  String? _error; // Added an error state

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    try {
      final List<dynamic> rideData = await AdminApiService.fetchRides();
      setState(() {
        // Map the raw JSON data to a list of Ride objects
        _rides = rideData.map((json) => Ride.fromJson(json)).toList();
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to fetch rides: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Error fetching rides: $e'); // Log the error for debugging
      if (mounted) {
        // Check if the widget is still in the tree
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed AppBar as it's handled by AdminHomeScreen
    return RefreshIndicator(
      // Added RefreshIndicator for pull-to-refresh
      onRefresh: _fetchRides,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _fetchRides,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _rides.isEmpty
          ? const Center(
              child: Text(
                'No rides found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _rides.length,
              itemBuilder: (context, index) {
                final ride = _rides[index];
                return RideCard(ride: ride); // Pass the Ride object
              },
            ),
    );
  }
}
