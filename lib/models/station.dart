import 'bike.dart';

class Station {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<Bike> bikes;
  final String description;

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.bikes,
    required this.description,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      bikes: (json['bikes'] as List<dynamic>? ?? [])
          .map((bikeJson) => Bike.fromJson(bikeJson))
          .toList(),
      description: json['description'] ?? '',
    );
  }

  // ✅ CONFIRMED: Correctly calculates the number of available bikes
  // This uses the 'isAvailable' property from your Bike model.
  int get availableBikes {
    return bikes.where((bike) => bike.isAvailable).length;
  }

  // You can also add a getter for unavailable bikes if needed for other logic
  int get unavailableBikes {
    return bikes.where((bike) => !bike.isAvailable).length;
  }

  get location => null;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'bikes': bikes.map((bike) => bike.toJson()).toList(),
      'description': description,
    };
  }
}
