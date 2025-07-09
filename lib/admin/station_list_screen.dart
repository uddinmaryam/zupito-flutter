import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/station_card.dart';


class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  List<dynamic> stations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStations();
  }

  Future<void> fetchStations() async {
    try {
      final data = await AdminApiService.fetchStations();
      setState(() {
        stations = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch stations')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Stations')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : stations.isEmpty
              ? const Center(child: Text('No stations found.'))
              : ListView.builder(
                  itemCount: stations.length,
                  itemBuilder: (context, index) {
                    return StationCard(station: stations[index]);
                  },
                ),
    );
  }
}
