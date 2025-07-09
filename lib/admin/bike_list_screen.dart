import 'package:flutter/material.dart';
import 'package:zupito/services/admin_api_service.dart';
import 'package:zupito/widgets/bike_card.dart';


class BikeListScreen extends StatefulWidget {
  const BikeListScreen({super.key});

  @override
  State<BikeListScreen> createState() => _BikeListScreenState();
}

class _BikeListScreenState extends State<BikeListScreen> {
  List<dynamic> bikes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBikes();
  }

  Future<void> fetchBikes() async {
    try {
      final data = await AdminApiService.fetchBikes();
      setState(() {
        bikes = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch bikes')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Bikes')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bikes.isEmpty
          ? const Center(child: Text('No bikes found.'))
          : ListView.builder(
              itemCount: bikes.length,
              itemBuilder: (context, index) {
                return BikeCard(bike: bikes[index]);
              },
            ),
    );
  }
}
