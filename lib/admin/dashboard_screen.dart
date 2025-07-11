import 'package:flutter/material.dart';
// Corrected import path based on your project structure
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/stat_card.dart';
// Assuming StatCard is in lib/widgets/stat_card.dart


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _summaryData; // Renamed to _summaryData for consistency
  bool _isLoading = true; // Renamed to _isLoading for consistency
  String? _error; // Added an error state

  @override
  void initState() {
    super.initState();
    _fetchSummary(); // Renamed to _fetchSummary for consistency
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });
    try {
      final data = await AdminApiService.fetchSummary();
      setState(() {
        _summaryData = data;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load summary: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Error fetching summary: $e'); // Log the error for debugging
      // Show snackbar only if context is still valid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to format currency for penalty
  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'N/A';
    // Basic formatting, consider using intl package for more robust currency formatting
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    // Removed AppBar as it will be handled by AdminHomeScreen
    return RefreshIndicator( // Added RefreshIndicator for pull-to-refresh functionality
      onRefresh: _fetchSummary,
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
                        onPressed: _fetchSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _summaryData == null || _summaryData!.isEmpty
                  ? const Center(child: Text('No dashboard data available.'))
                  : SingleChildScrollView( // Added SingleChildScrollView for better responsiveness on small screens
                      physics: const AlwaysScrollableScrollPhysics(), // Always allow scrolling for RefreshIndicator
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 20),
                          GridView.count(
                            shrinkWrap: true, // Important for GridView inside SingleChildScrollView
                            physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2, // Responsive crossAxisCount
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            children: [
                              // StatCard for Total Users - now with onTap
                              StatCard(
                                title: 'Total Users',
                                value: _summaryData!['totalUsers']?.toString() ?? '0',
                                icon: Icons.people_alt, // Added icon
                                onTap: () {
                                  // Navigate to the UserListScreen using its named route
                                  Navigator.pushNamed(context, '/users');
                                },
                              ),
                              // StatCard for Total Bikes - now with onTap
                              StatCard(
                                title: 'Total Bikes',
                                value: _summaryData!['totalBikes']?.toString() ?? '0',
                                icon: Icons.pedal_bike, // Added icon
                                onTap: () {
                                  // Navigate to the BikeListScreen using its named route
                                  Navigator.pushNamed(context, '/bikes');
                                },
                              ),
                              // StatCard for Total Stations - now with onTap
                              StatCard(
                                title: 'Total Stations',
                                value: _summaryData!['totalStations']?.toString() ?? '0',
                                icon: Icons.location_on, // Added icon
                                onTap: () {
                                  // Navigate to the StationListScreen using its named route
                                  Navigator.pushNamed(context, '/stations');
                                },
                              ),
                              // StatCard for Total Rides - now with onTap
                              StatCard(
                                title: 'Total Rides',
                                value: _summaryData!['totalRides']?.toString() ?? '0',
                                icon: Icons.history, // Added icon
                                onTap: () {
                                  // Navigate to the RideListScreen using its named route
                                  Navigator.pushNamed(context, '/rides');
                                },
                              ),
                              // Other StatCards (Ongoing Rides, Completed Rides, Total Penalty)
                              StatCard(
                                title: 'Ongoing Rides',
                                value: _summaryData!['ongoingRides']?.toString() ?? '0',
                                icon: Icons.directions_bike,
                              ),
                              StatCard(
                                title: 'Completed Rides',
                                value: _summaryData!['completedRides']?.toString() ?? '0',
                                icon: Icons.check_circle_outline,
                              ),
                              StatCard(
                                title: 'Total Penalty',
                                value: _formatCurrency(_summaryData!['totalPenalty']),
                                icon: Icons.money_off,
                                color: Colors.redAccent, // Highlight penalty
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
}
