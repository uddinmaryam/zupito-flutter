import 'bike.dart';

class Station {
  final String id;
  final String name;
  final String description;
  final double lat;
  final double lng;
  final List<Bike> bikes;

  Station({
    required this.id,
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    required this.bikes,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      lat: (json['location']['lat'] as num).toDouble(),
      lng: (json['location']['lng'] as num).toDouble(),
      bikes: (json['bikes'] as List<dynamic>)
          .map((bike) => Bike.fromJson(bike))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'location': {
        'lat': lat,
        'lng': lng,
      },
      'bikes': bikes.map((bike) => bike.toJson()).toList(),
    };
  }
}
