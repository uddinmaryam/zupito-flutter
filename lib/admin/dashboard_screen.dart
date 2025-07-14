import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/stat_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _summaryData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await AdminApiService.fetchSummary();
      setState(() {
        _summaryData = data;
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to load summary: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      if (mounted) {
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchSummary,
        child: _isLoading
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
                                onPressed: _fetchSummary,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _summaryData == null || _summaryData!.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 300,
                            child: Center(
                              child: Text(
                                'No dashboard data available.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount:
                                  MediaQuery.of(context).size.width > 600
                                      ? 3
                                      : 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                StatCard(
                                  title: 'Pending Users',
                                  value: _summaryData!['pendingUsers']
                                          ?.toString() ??
                                      '0',
                                  icon: Icons.hourglass_top,
                                  onTap: () => Navigator.pushNamed(
                                      context, '/pending-users'),
                                ),
                                StatCard(
                                  title: 'Total Users',
                                  value:
                                      _summaryData!['totalUsers']?.toString() ??
                                          '0',
                                  icon: Icons.people_alt,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/users'),
                                ),
                                StatCard(
                                  title: 'Total Rides',
                                  value:
                                      _summaryData!['totalRides']?.toString() ??
                                          '0',
                                  icon: Icons.directions_bike,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/rides'),
                                ),
                                StatCard(
                                  title: 'Ongoing Rides',
                                  value: _summaryData!['ongoingRides']
                                          ?.toString() ??
                                      '0',
                                  icon: Icons.loop,
                                  onTap: () {},
                                ),
                                StatCard(
                                  title: 'Completed Rides',
                                  value: _summaryData!['completedRides']
                                          ?.toString() ??
                                      '0',
                                  icon: Icons.check_circle,
                                  onTap: () {},
                                ),
                                StatCard(
                                  title: 'Total Stations',
                                  value: _summaryData!['totalStations']
                                          ?.toString() ??
                                      '0',
                                  icon: Icons.location_on,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/stations'),
                                ),
                                StatCard(
                                  title: 'Total Bikes',
                                  value:
                                      _summaryData!['totalBikes']?.toString() ??
                                          '0',
                                  icon: Icons.pedal_bike,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/bikes'),
                                ),
                                StatCard(
                                  title: 'Total Penalty',
                                  value: _summaryData!['totalPenalty']
                                          ?.toString() ??
                                      '0',
                                  icon: Icons.warning,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}
