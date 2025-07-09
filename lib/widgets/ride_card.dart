import 'package:flutter/material.dart';

class RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;

  const RideCard({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final user = ride['user']?['name'] ?? 'Unknown User';
    final bike = ride['bike']?['_id'] ?? 'Bike ID';
    final startStation = ride['startStation']?['name'] ?? 'Start';
    final destination = ride['destinationStation']?['name'] ?? 'End';
    final status = ride['status'] ?? 'unknown';
    final penalty = ride['penalty']?.toString() ?? '0';

    final startTime = ride['startTime'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text('$user | Bike $bike'),
        subtitle: Text(
          'From: $startStation\nTo: $destination\nStatus: $status\nPenalty: Rs. $penalty',
        ),
        trailing: Text(startTime.toString().split('T').first),
      ),
    );
  }
}
