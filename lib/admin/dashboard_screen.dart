import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/stat_card.dart';
import 'package:zupito/services/admin_api_service.dart';


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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load summary')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
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
                      StatCard(title: 'Total Users', value: summaryData!['totalUsers'].toString()),
                      StatCard(title: 'Total Bikes', value: summaryData!['totalBikes'].toString()),
                      StatCard(title: 'Total Stations', value: summaryData!['totalStations'].toString()),
                      StatCard(title: 'Total Rides', value: summaryData!['totalRides'].toString()),
                      StatCard(title: 'Ongoing Rides', value: summaryData!['ongoingRides'].toString()),
                      StatCard(title: 'Completed Rides', value: summaryData!['completedRides'].toString()),
                      StatCard(title: 'Total Penalty', value: summaryData!['totalPenalty'].toString()),
                    ],
                  ),
                ),
    );
  }
}
