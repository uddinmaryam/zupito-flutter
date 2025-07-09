import 'package:flutter/material.dart';

class StationCard extends StatelessWidget {
  final Map<String, dynamic> station;

  const StationCard({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final name = station['name'] ?? 'Unnamed Station';
    final location = station['location'] ?? 'Unknown';
    final capacity = station['capacity']?.toString() ?? 'N/A';
    final bikeCount = (station['bikes'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(name),
        subtitle: Text('Location: $location\nCapacity: $capacity'),
        trailing: Text('$bikeCount Bikes'),
      ),
    );
  }
}
