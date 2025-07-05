class Bike {
  final String? code;
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double pricePerMinute;
  bool isAvailable;

  final int? availableInMinutes;
  bool isUnlocked;

  Bike({
    this.code,
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
      code: json['code'] ?? '',
      id: json['_id'] ?? '',
      name: json['name'] ?? json['code'], // fallback to code
      lat: (json['location']?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['location']?['lng'] as num?)?.toDouble() ?? 0.0,

      pricePerMinute: (json['pricePerMinute'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] ?? false,
      availableInMinutes: json['availableInMinutes'] as int?,
      isUnlocked: false, // set from UI, not from API
    );
  }

  Map<String, dynamic> toJson() {
    return {
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

  Bike copyWith({bool? isUnlocked}) {
    return Bike(
      code: code,
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      pricePerMinute: pricePerMinute,
      isAvailable: isAvailable,
      availableInMinutes: availableInMinutes,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}
