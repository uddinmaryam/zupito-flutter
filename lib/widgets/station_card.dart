import 'package:flutter/material.dart';
import 'package:zupito/models/station.dart';

class StationCard extends StatelessWidget {
  final Station station; // Now accepts a Station object
  final VoidCallback? onDelete; // Callback for delete action

  const StationCard({
    super.key,
    required this.station,
    this.onDelete, // Initialize the onDelete callback
  });

  @override
  Widget build(BuildContext context) {
    // Access properties directly from the Station object
    final String locationText =
        'Lat: ${station.latitude.toStringAsFixed(4)}, Lng: ${station.longitude.toStringAsFixed(4)}';
    final int bikeCount =
        station.bikes.length; // Number of bike IDs in the array

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        station.name, // Display station name
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Delete button
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: onDelete, // Trigger the onDelete callback
                    tooltip: 'Delete Station',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.map, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location: $locationText', // Display formatted location
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storage, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Capacity: ${station.capacity}', // Display capacity
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.pedal_bike, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Bikes Parked: $bikeCount', // Display number of bikes
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
            // You could add more details here, like a button to view bikes at this station
          ],
        ),
      ),
    );
  }
}
