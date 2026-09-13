import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/audio_model.dart';
import '../models/playlist_model.dart';

class ApiService {
  // Default base URL uses localhost:5000/api. On Android emulator, 10.0.2.2 maps to host localhost.
  static String baseUrl = const String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  static Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Auth Endpoints
  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(null),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to register');
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(null),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to login');
    }
  }

  static Future<UserModel> getMe(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers(token),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return UserModel.fromJson(data['user']);
    } else {
      throw Exception(data['message'] ?? 'Invalid token verification');
    }
  }

  // Audio Endpoints
  static Future<Map<String, dynamic>> getPublicAudios({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/audio/public').replace(queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final response = await http.get(uri, headers: _headers(null));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch public audios');
    }
  }

  static Future<Map<String, dynamic>> getMyAudios({
    required String token,
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/audio/my-audios').replace(queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final response = await http.get(uri, headers: _headers(token));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch user audios');
    }
  }

  static Future<AudioModel> uploadAudio({
    required String token,
    required String name,
    required String visibility,
    required File audioFile,
    File? thumbnailFile,
  }) async {
    final uri = Uri.parse('$baseUrl/audio/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['visibility'] = visibility;

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
    ));

    if (thumbnailFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailFile.path,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      return AudioModel.fromJson(data['audio']);
    } else {
      throw Exception(data['message'] ?? 'Failed to upload audio');
    }
  }

  // Playlist Endpoints
  static Future<Map<String, dynamic>> getPublicPlaylists({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri =
        Uri.parse('$baseUrl/playlists/public').replace(queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final response = await http.get(uri, headers: _headers(null));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch public playlists');
    }
  }

  static Future<Map<String, dynamic>> getMyPlaylists({
    required String token,
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri =
        Uri.parse('$baseUrl/playlists/my-playlists').replace(queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    });

    final response = await http.get(uri, headers: _headers(token));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch my playlists');
    }
  }

  static Future<PlaylistModel> createPlaylist({
    required String token,
    required String name,
    required String visibility,
    File? imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/playlists');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['visibility'] = visibility;

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      return PlaylistModel.fromJson(data['playlist']);
    } else {
      throw Exception(data['message'] ?? 'Failed to create playlist');
    }
  }

  static Future<void> addAudioToPlaylist({
    required String token,
    required String playlistId,
    required String audioId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/playlists/$playlistId/add-audio'),
      headers: _headers(token),
      body: jsonEncode({'audioId': audioId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to add audio to playlist');
    }
  }

  static Future<Map<String, dynamic>> getPlaylistDetails({
    String? token,
    required String playlistId,
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId').replace(
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final response = await http.get(uri, headers: _headers(token));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch playlist details');
    }
  }
}
