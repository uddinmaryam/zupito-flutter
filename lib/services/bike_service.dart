import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bike.dart';

class BikeService {
  static const String baseUrl =
      'https://backend-bicycle-1.onrender.com/api/v1/bikes';

  // Unlock a bike
  static Future<DateTime> unlockBike(String bikeId) async {
    final response = await http.post(Uri.parse('$baseUrl/$bikeId/unlock'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['startTime'] != null) {
        return DateTime.parse(data['startTime']);
      } else {
        throw Exception('Invalid response format: no startTime');
      }
    } else {
      throw Exception('Failed to unlock bike');
    }
  }

  // Stop a ride and calculate fare
  static Future<double> stopRide(String bikeId, DateTime endTime) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$bikeId/stop'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'endTime': endTime.toIso8601String()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['fare'] != null) {
        return (data['fare'] as num).toDouble();
      } else {
        throw Exception('Invalid response format: no fare');
      }
    } else {
      throw Exception('Failed to stop ride');
    }
  }

  // Fetch all bikes (optional)
  static Future<List<Bike>> getAllBikes() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((json) => Bike.fromJson(json)).toList();
      } else {
        throw Exception('Unexpected bike list format');
      }
    } else {
      throw Exception('Failed to fetch bikes');
    }
  }

  // 🔮 Future-ready: Fetch bikes by station
  static Future<List<Bike>> getBikesByStation(String stationId) async {
    final url = Uri.parse(
        'https://backend-bicycle-1.onrender.com/api/v1/stations/$stationId/bikes');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['bikes'] is List) {
        return (data['bikes'] as List)
            .map((json) => Bike.fromJson(json))
            .toList();
      } else {
        throw Exception('Invalid bikes data in response');
      }
    } else {
      throw Exception('Failed to fetch bikes for station $stationId');
    }
  }
}
