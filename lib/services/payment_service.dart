// payment_service.dart
/*
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:convert';

class PaymentService {
  // Step 1: Create payment intent from backend
  static Future<String?> createPaymentIntent(int amount) async {
    final url = Uri.parse(
        'https://your-backend-url.com/api/payment/create-payment-intent');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount, // e.g. 5000 = $50
        'currency': 'usd',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['clientSecret'];
    } else {
      print('Error creating payment intent: ${response.body}');
      return null;
    }
  }

  // Step 2: Show Stripe Payment Sheet and confirm payment
  static Future<bool> payWithStripe(int amountInCents) async {
    try {
      final clientSecret = await createPaymentIntent(amountInCents);
      if (clientSecret == null) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Zupito Bikes',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return true; // Payment success
    } catch (e) {
      if (e is StripeException) {
        print('Stripe error: \${e.error.localizedMessage}');
      } else {
        print('Unexpected error: \$e');
      }
      return false;
    }
  }
}*/
