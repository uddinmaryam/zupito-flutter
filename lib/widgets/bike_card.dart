import 'package:flutter/material.dart';
import 'package:zupito/models/bike.dart';

class BikeCard extends StatelessWidget {
  final Bike bike;
  final VoidCallback? onDelete;

  const BikeCard({super.key, required this.bike, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final String code = bike.code ?? 'N/A';
    final double? lat = bike.lat;
    final double? lng = bike.lng;
    final String assignedStationText =
        (bike.assignedStation != null && bike.assignedStation!.isNotEmpty)
            ? 'Station ID: ${bike.assignedStation}'
            : 'Not Assigned';

    final bool isAvailable = bike.isAvailable ?? false;

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
                      'Code: $code',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: onDelete,
                    tooltip: 'Delete Bike',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (lat != null && lng != null)
                        ? 'Location: Lat ${lat.toStringAsFixed(4)}, Lng ${lng.toStringAsFixed(4)}'
                        : 'Location: N/A',
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
                    assignedStationText,
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
                  isAvailable ? Icons.lock_open : Icons.lock,
                  color: isAvailable ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isAvailable ? 'Available' : 'In Use',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? Colors.green : Colors.red,
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
