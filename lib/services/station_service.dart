import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class StationService {
  static const String baseUrl = 'https://backend-bicycle-1.onrender.com';

  static Future<List<Station>> fetchStations() async {
    final url = Uri.parse('$baseUrl/api/v1/stations');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List rawList;

      // Accept either a wrapped or raw array
      if (decoded is Map<String, dynamic> && decoded.containsKey('stations')) {
        rawList = decoded['stations'] as List;
      } else if (decoded is List) {
        rawList = decoded;
      } else {
        throw Exception('Unexpected stations response format.');
      }

      // Optional: Print any bad entry
      for (var item in rawList) {
        if (item is! Map<String, dynamic>) {
          print('❌ Bad station entry: $item (${item.runtimeType})');
        }
      }

      // Filter out non-maps and map to Station
      final stations = rawList
          .where((item) => item is Map<String, dynamic>)
          .map((stationJson) {
            final bikes = (stationJson['bikes'] as List?) ?? [];
            for (var bike in bikes) {
              print("📦 Bike JSON: ${jsonEncode(bike)}");
            }
            return Station.fromJson(stationJson as Map<String, dynamic>);
          })
          .toList();

      return stations;
    } else {
      print('❌ Error ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load stations');
    }
  }
}
