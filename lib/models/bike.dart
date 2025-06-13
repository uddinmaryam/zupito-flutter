class Bike {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double pricePerMinute;
  final bool isAvailable;

  Bike({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.pricePerMinute,
    required this.isAvailable,
  });
}
