// lib/network_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkService {
  final String baseUrl = 'https://quickchat.biz/api/';

  Future<void> storeToken(String userId, String token) async {
    var url = Uri.parse('${baseUrl}token.php');
    var response = await http.post(url, body: {
      'user_id': userId,
      'token': token
    });

    if (response.statusCode == 200) {
      print("Token stored successfully");
    } else {
      print("Failed to store token: ${response.body}");
    }
  }

// Add more methods as needed for other network interactions
}
