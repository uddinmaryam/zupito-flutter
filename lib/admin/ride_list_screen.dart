import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/ride_card.dart';



class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => _RideListScreenState();
}

class _RideListScreenState extends State<RideListScreen> {
  List<dynamic> rides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRides();
  }

  Future<void> fetchRides() async {
    try {
      final data = await AdminApiService.fetchRides();
      setState(() {
        rides = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch rides')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Rides')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
          ? const Center(child: Text('No rides found.'))
          : ListView.builder(
              itemCount: rides.length,
              itemBuilder: (context, index) {
                return RideCard(ride: rides[index]);
              },
            ),
    );
  }
}
