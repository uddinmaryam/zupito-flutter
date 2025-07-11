import 'package:flutter/material.dart';
import 'package:zupito/models/bike.dart'; // Import the Bike model

class BikeCard extends StatelessWidget {
  final Bike bike; // Now accepts a Bike object
  final VoidCallback? onDelete; // Callback for delete action

  const BikeCard({
    super.key,
    required this.bike,
    this.onDelete, // Initialize the onDelete callback
  });

  @override
  Widget build(BuildContext context) {
    // Access properties directly from the Bike object
    final String assignedStationText = bike.assignedStation != null && bike.assignedStation!.isNotEmpty
        ? 'Station ID: ${bike.assignedStation}'
        : 'Not Assigned';

    // The backend's Bike model doesn't seem to have 'currentStation' or 'autoUnlockAt'
    // It has 'location' (lat, lng) and 'isAvailable'.
    // If you need 'currentStation' or 'autoUnlockAt', your backend's Bike model needs to include them.
    // For now, I'll use the available fields.

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
                    const Icon(Icons.qr_code, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Code: ${bike.code}', // Display bike code
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
                // Delete button
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: onDelete, // Trigger the onDelete callback
                    tooltip: 'Delete Bike',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location: Lat ${bike.location['lat']?.toStringAsFixed(4)}, Lng ${bike.location['lng']?.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.ev_station, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assignedStationText, // Display assigned station
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  bike.isAvailable ? Icons.lock_open : Icons.lock,
                  color: bike.isAvailable ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  bike.isAvailable ? 'Available' : 'In Use',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: bike.isAvailable ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
