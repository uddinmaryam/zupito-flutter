class Bike {
  final String code;
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double pricePerMinute;
  final bool isAvailable;
  final int? availableInMinutes; // nullable
  bool isUnlocked; // for UI state (default false)

  Bike({
    required this.code,
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.pricePerMinute,
    required this.isAvailable,
    this.availableInMinutes,
    this.isUnlocked = false,
  });

  factory Bike.fromJson(Map<String, dynamic> json) {
    return Bike(
      code: json['code'] as String,
      id: json['_id'] as String,
      name: json['name'] ?? json['code'], // fallback to code if name missing
      lat: (json['location']['lat'] as num).toDouble(),
      lng: (json['location']['lng'] as num).toDouble(),
      pricePerMinute: (json['pricePerMinute'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool,
      availableInMinutes: json['availableInMinutes'] as int?,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    '_id': id,
    'name': name,
    'location': {'lat': lat, 'lng': lng},
    'pricePerMinute': pricePerMinute,
    'isAvailable': isAvailable,
    'availableInMinutes': availableInMinutes,
    'isUnlocked': isUnlocked,
  };
}
