import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/stat_card.dart';
// You might not need this second import if it's identical to the first one
// import 'package:zupito/services/admin_api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? summaryData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSummary();
  }

  Future<void> fetchSummary() async {
    try {
      final data = await AdminApiService.fetchSummary();
      setState(() {
        summaryData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // It's good practice to print the error for debugging, in addition to the SnackBar
      print('Error fetching summary: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load summary')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : summaryData == null
          ? const Center(child: Text('No data available'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // StatCard for Total Users - now with onTap
                  StatCard(
                    title: 'Total Users',
                    value: summaryData!['totalUsers'].toString(),
                    onTap: () {
                      // Navigate to the UserListScreen using its named route
                      Navigator.pushNamed(context, '/users');
                    },
                  ),
                  // StatCard for Total Bikes - now with onTap
                  StatCard(
                    title: 'Total Bikes',
                    value: summaryData!['totalBikes'].toString(),
                    onTap: () {
                      // Navigate to the BikeListScreen using its named route
                      Navigator.pushNamed(context, '/bikes');
                    },
                  ),
                  // StatCard for Total Stations - now with onTap
                  StatCard(
                    title: 'Total Stations',
                    value: summaryData!['totalStations'].toString(),
                    onTap: () {
                      // Navigate to the StationListScreen using its named route
                      Navigator.pushNamed(context, '/stations');
                    },
                  ),
                  // StatCard for Total Rides - now with onTap
                  StatCard(
                    title: 'Total Rides',
                    value: summaryData!['totalRides'].toString(),
                    onTap: () {
                      // Navigate to the RideListScreen using its named route
                      Navigator.pushNamed(context, '/rides');
                    },
                  ),
                  // Other StatCards (Ongoing Rides, Completed Rides, Total Penalty)
                  // These don't typically navigate to a full list, so no onTap for them
                  StatCard(
                    title: 'Ongoing Rides',
                    value: summaryData!['ongoingRides'].toString(),
                  ),
                  StatCard(
                    title: 'Completed Rides',
                    value: summaryData!['completedRides'].toString(),
                  ),
                  StatCard(
                    title: 'Total Penalty',
                    value: summaryData!['totalPenalty'].toString(),
                  ),
                ],
              ),
            ),
    );
  }
}
