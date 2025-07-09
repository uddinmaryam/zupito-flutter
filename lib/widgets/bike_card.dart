import 'package:flutter/material.dart';

class BikeCard extends StatelessWidget {
  final Map<String, dynamic> bike;

  const BikeCard({super.key, required this.bike});

  @override
  Widget build(BuildContext context) {
    final station = bike['currentStation'] ?? 'Not assigned';
    final autoUnlock = bike['autoUnlockAt'] ?? 'N/A';
    final isAvailable = bike['isAvailable'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text('Bike ID: ${bike['_id']}'),
        subtitle: Text('Station: $station\nUnlock At: $autoUnlock'),
        trailing: Icon(
          isAvailable ? Icons.lock_open : Icons.lock,
          color: isAvailable ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
