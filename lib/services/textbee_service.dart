import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class TextbeeService {
  // IMPORTANT: Replace these with your actual credentials from textbee.dev
  static const String _apiKey = 'txb_vYqHUJEJV23YzWpx0m4SWnZ6ndfQz5Mh';
  static const String _deviceId = '6aa4c1c70eb03ef4ba396c7d';

  static Future<bool> sendSMS(String to, String message) async {
    // Basic validation: ensure number starts with + and has correct format
    String formattedNumber = to.trim();
    if (!formattedNumber.startsWith('+')) {
      // Assuming PH country code if not specified, adjust as needed
      formattedNumber = '+63' + formattedNumber.replaceFirst(RegExp(r'^0'), '');
    }

    final String url = 'https://api.textbee.dev/api/v1/gateway/send-sms';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipients': [formattedNumber],
          'message': message,
          'deviceId': _deviceId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Textbee SMS sent successfully to $formattedNumber");
        return true;
      } else {
        debugPrint("Textbee Error: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Textbee Exception: $e");
      return false;
    }
  }
}
