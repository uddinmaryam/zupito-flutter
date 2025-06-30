import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class StationService {
  static const String baseUrl = 'https://backend-bicycle-1.onrender.com';

  static Future<List<Station>> fetchStations() async {
    final url = Uri.parse('$baseUrl/api/v1/stations');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body); // ✅ Now it's a Map
      final stations = (data['stations'] as List)
          .map((json) => Station.fromJson(json))
          .toList();
      return stations;
    } else {
      print('Error ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load stations');
    }
  }
}
