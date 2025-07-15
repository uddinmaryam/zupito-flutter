import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  static Future<String?> createPayPalOrder(double amount) async {
    final url = Uri.parse('https://backend-bicycle-1.onrender.com/api/v1/payment/create-order');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"amount": amount.toStringAsFixed(2)}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List links = data['links'];
      // Find the approval link
      final approveLink = links.firstWhere(
        (link) => link['rel'] == 'approve',
        orElse: () => null,
      );
      return approveLink?['href'];
    } else {
      // You can show an error message here
      return null;
    }
  }
}

