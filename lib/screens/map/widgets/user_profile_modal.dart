import 'package:flutter/material.dart';
import '../../../models/user.dart';

void showUserProfileModal(BuildContext context, UserProfile userProfile) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'User Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('Total Rides: ${userProfile.totalRides}'),
          Text(
            'Total Fare Paid: Rs. ${userProfile.totalFare.toStringAsFixed(2)}',
          ),
          const Divider(height: 24),
          const Text(
            'Ride History:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (userProfile.rideHistory.isEmpty)
            const Text('No rides yet.')
          else
            ...userProfile.rideHistory.map(
              (ride) => ListTile(
                title: Text('Bike: ${ride.bikeId}'),
                subtitle: Text('Fare: Rs. ${ride.fare.toStringAsFixed(2)}'),
                trailing: Text(
                  '${ride.date.hour}:${ride.date.minute.toString().padLeft(2, '0')}\n${ride.date.day}/${ride.date.month}',
                  textAlign: TextAlign.right,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
