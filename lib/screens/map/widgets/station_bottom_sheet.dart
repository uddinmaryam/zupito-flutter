// widgets/station_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:zupito/models/bike.dart';
import '../../../models/station.dart';
import '../../../models/user.dart';
import '../../../services/ride_service.dart';

void showStationBottomSheet(BuildContext context, Station station, UserProfile userProfile) {
  final availableBikes = station.bikes.where((b) => b.isAvailable).toList();
  final unavailableBikes = station.bikes.where((b) => !b.isAvailable).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.75,
      initialChildSize: 0.5,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Text(
              station.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(station.description),
            const SizedBox(height: 16),
            Text('Available Bikes (${availableBikes.length})'),
            const SizedBox(height: 12),
            if (availableBikes.isEmpty)
              const Center(child: Text('No bikes available.'))
            else
              ...availableBikes.map(
                (bike) => Card(
                  child: ListTile(
                    title: Text(bike.name),
                    subtitle: Text('Rs. ${bike.pricePerMinute}/min'),
                    trailing: ElevatedButton(
                      onPressed: () => unlockBike(context, bike, userProfile),
                      child: const Text('Unlock'),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Unavailable Bikes (${unavailableBikes.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            if (unavailableBikes.isEmpty)
              const Center(child: Text('No unavailable bikes.'))
            else
              ...unavailableBikes.map(
                (bike) => Card(
                  color: Colors.grey[200],
                  child: ListTile(
                    title: Text(bike.name),
                    subtitle: Text('Available in ${bike.availableInMinutes ?? '?'} mins'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void unlockBike(BuildContext context, Bike bike, UserProfile userProfile) {
}