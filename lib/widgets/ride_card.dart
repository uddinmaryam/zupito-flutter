import 'package:flutter/material.dart';
import 'package:zupito/models/ride.dart'; // Import the Ride model

class RideCard extends StatelessWidget {
  final Ride ride;

  const RideCard({super.key, required this.ride});

  // Helper to format date and time
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.toLocal().toString().split(' ')[0]} '
        '${dateTime.toLocal().hour.toString().padLeft(2, '0')}:'
        '${dateTime.toLocal().minute.toString().padLeft(2, '0')}';
  }

  // Helper to format currency with Rs. (Nepali Rupees)
  String _formatCurrency(double? amount) {
    if (amount == null) return 'N/A';
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final String userName = ride.user?.username ?? 'Unknown';
    final String bikeCode = ride.bike?.code ?? 'Unknown';
    final String startStationName = ride.startStation?.name ?? 'Unknown';
    final String destinationStationName =
        ride.destinationStation?.name ?? 'Unknown';
    final String statusText = ride.status ?? 'Unknown';
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
      case 'cancelled':
      case 'cancelled by user':
      case 'canceled':
        statusColor = Colors.redAccent;
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
            // Top row: user, bike, status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // Ensures user/bike text doesn't overflow
                  child: Text(
                    '$userName | Bike: $bikeCode',
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
                    color: statusColor.withOpacity(0.15),
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
            // Start station
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Ensures station name doesn't overflow
                  child: Text(
                    'From: $startStationName',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // End station
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  // Ensures station name doesn't overflow
                  child: Text(
                    'To: $destinationStationName',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Start/End Time, Fare, Penalty
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  // Ensures the time column takes available space
                  flex:
                      3, // Give it a bit more space if needed, adjust as per layout
                  child: Column(
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
                            // Consider adding overflow here if time strings can be very long
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
                            // Consider adding overflow here if time strings can be very long
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // Ensures the fare/penalty column takes available space
                  flex:
                      2, // Give it less space than time column if needed, adjust
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize
                            .min, // Make this row only take up needed space
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            // Use Flexible to allow text to shrink
                            child: Text(
                              'Fare: $fareText',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              overflow: TextOverflow
                                  .ellipsis, // Add ellipsis for long fare text
                            ),
                          ),
                        ],
                      ),
                      if ((ride.penaltyAmount ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize
                              .min, // Make this row only take up needed space
                          children: [
                            const Icon(
                              Icons.money_off,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // Use Flexible to allow text to shrink
                              child: Text(
                                'Penalty: $penaltyText',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                                overflow: TextOverflow
                                    .ellipsis, // Add ellipsis for long penalty text
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Distance, if present
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
