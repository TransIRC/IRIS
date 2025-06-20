// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';
import '../models/login_response.dart';
import '../models/channel.dart';

class ApiService {
  String? _token;

  ApiService([this._token]);

  void setToken(String token) {
    _token = token;
  }

  Future<LoginResponse> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    print("[ApiService] login: Calling POST $url");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );
      print("[ApiService] login: Received status code ${response.statusCode}");

      final responseData = json.decode(response.body);
      return LoginResponse.fromJson(responseData);
    } catch (e) {
      print("[ApiService] login Error: $e");
      return LoginResponse(success: false, message: 'Network error during login: $e');
    }
  }

  String _getToken() {
    if (_token == null) {
      throw Exception("Authentication token is not set for ApiService.");
    }
    return _token!;
  }

  Future<void> registerFCMToken(String fcmToken) async {
    final url = Uri.parse('$baseUrl/register-fcm-token');
    print("[ApiService] registerFCMToken: Calling POST $url");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getToken()}',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );
      if (response.statusCode == 200) {
        print("[ApiService] registerFCMToken: Success");
      } else {
        print("[ApiService] registerFCMToken: Failed with status ${response.statusCode}, body: ${response.body}");
      }
    } catch (e) {
      print("[ApiService] registerFCMToken Error: $e");
    }
  }

  Future<List<Channel>> fetchChannels() async {
    final url = Uri.parse('$baseUrl/channels');
    print("[ApiService] fetchChannels: Calling GET $url with token: $_token");
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${_getToken()}'},
      );
      print("[ApiService] fetchChannels: Received status code ${response.statusCode}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final List<dynamic> apiChannels = data['channels'] ?? [];
        return apiChannels.map((c) => Channel.fromJson(c)).toList();
      } else {
        throw Exception(data['message'] ?? "Failed to load channels");
      }
    } catch (e) {
      print("[ApiService] fetchChannels Error: $e");
      throw Exception("Network error fetching channels: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchChannelMessages(String channelName) async {
    print("[ApiService] fetchChannelMessages: Attempting to fetch messages for $channelName");
    if (channelName.isEmpty) {
      print("[ApiService] fetchChannelMessages: Channel name is empty, returning empty list.");
      return [];
    }

    final encodedChannelName = Uri.encodeComponent(channelName);
    final url = Uri.parse('$baseUrl/channels/$encodedChannelName/messages');
    final token = _getToken();
    print("[ApiService] fetchChannelMessages: Calling GET $url with token: $token");

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      print("[ApiService] fetchChannelMessages: Received status code ${response.statusCode} for $channelName");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List<dynamic> receivedMessages = data['messages'] ?? [];
        print("[ApiService] fetchChannelMessages: Successfully fetched ${receivedMessages.length} messages for $channelName");
        return receivedMessages.map((msg) => {
              'from': msg['from'] ?? '',
              'content': msg['content'] ?? '',
              'time': msg['time'] ?? DateTime.now().toIso8601String(),
            }).toList();
      } else {
        print("[ApiService] fetchChannelMessages: API returned non-200 status for $channelName: ${response.statusCode}");
        throw Exception("Failed to load messages: Status ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("[ApiService] fetchChannelMessages Error for $channelName: $e");
      throw Exception("Network error fetching messages: $e");
    }
  }

  Future<Map<String, dynamic>> joinChannel(String channelName) async {
    final url = Uri.parse('$baseUrl/channels/join');
    print("[ApiService] joinChannel: Calling POST $url for channel $channelName");
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_getToken()}',
      },
      body: json.encode({'channel': channelName}),
    );
    final responseData = json.decode(response.body);
    print("[ApiService] joinChannel: Received status code ${response.statusCode}, success: ${responseData['success']}");
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to join channel');
    }
  }

  Future<Map<String, dynamic>> partChannel(String channelName) async {
    final url = Uri.parse('$baseUrl/channels/part');
    print("[ApiService] partChannel: Calling POST $url for channel $channelName");
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_getToken()}',
      },
      body: json.encode({'channel': channelName}),
    );
    final responseData = json.decode(response.body);
    print("[ApiService] partChannel: Received status code ${response.statusCode}, success: ${responseData['success']}");
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to part channel');
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(File imageFile, String token) async {
    final uri = Uri.parse('$baseUrl/upload-avatar');
    print("[ApiService] uploadAvatar: Calling POST $uri for avatar upload.");
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    String? mimeType;
    final String fileExtension = imageFile.path.split('.').last.toLowerCase();
    switch (fileExtension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'gif':
        mimeType = 'image/gif';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print("[ApiService] uploadAvatar: Upload successful, status 200.");
      return json.decode(responseBody);
    } else {
      print("[ApiService] uploadAvatar: Upload failed, status ${response.statusCode}, body: $responseBody");
      final errorData = json.decode(responseBody);
      throw Exception('Failed to upload avatar: ${response.statusCode} - ${errorData['message'] ?? responseBody}');
    }
  }
}