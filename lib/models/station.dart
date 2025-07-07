import 'bike.dart';

class Station {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<Bike> bikes;
  final String description;
  final int capacity; // ✅ Add this field properly

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.bikes,
    this.description = '',
    required this.capacity, // ✅ Correctly required now
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
      capacity: json['capacity'] ?? 10, // ✅ Default fallback if null
    );
  }

  int get availableBikes {
    return bikes.where((bike) => bike.isAvailable).length;
  }

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
      'capacity': capacity, // ✅ Include it in toJson
    };
  }
}
