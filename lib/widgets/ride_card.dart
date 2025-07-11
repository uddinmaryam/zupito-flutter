import 'package:flutter/material.dart';
import 'package:zupito/models/ride.dart'; // Import the Ride model

class RideCard extends StatelessWidget {
  final Ride ride; // Now accepts a Ride object

  const RideCard({super.key, required this.ride});

  // Helper to format date and time
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.toLocal().toString().split(' ')[0]} ${dateTime.toLocal().hour.toString().padLeft(2, '0')}:${dateTime.toLocal().minute.toString().padLeft(2, '0')}';
  }

  // Helper to format currency
  String _formatCurrency(double? amount) {
    if (amount == null) return 'N/A';
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    // Access properties directly from the Ride object, including nested populated data
    final String userName = ride.user.username;
    final String bikeCode = ride.bike.code;
    final String startStationName = ride.startStation?.name ?? 'Unknown';
    final String destinationStationName =
        ride.destinationStation?.name ?? 'Unknown';
    final String statusText = ride.status;
    final String penaltyText = _formatCurrency(ride.penaltyAmount);
    final String fareText = _formatCurrency(ride.fare);
    final String startTimeFormatted = _formatDateTime(ride.startTime);
    final String endTimeFormatted = _formatDateTime(ride.endTime);

    // Determine status color
    Color statusColor;
    switch (statusText.toLowerCase()) {
      case 'ongoing':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

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
                Expanded(
                  child: Text(
                    '${userName} | Bike: ${bikeCode}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
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
                    'From: $startStationName',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To: $destinationStationName',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Start: $startTimeFormatted',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'End: $endTimeFormatted',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fare: $fareText',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (ride.penaltyAmount != null &&
                        ride.penaltyAmount! > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.money_off,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Penalty: $penaltyText',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            // You can add more details like distance if your backend provides it
            if (ride.distance != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.straighten, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Distance: ${ride.distance!.toStringAsFixed(2)} km',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
