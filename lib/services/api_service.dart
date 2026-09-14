import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../models/audio_model.dart';
import '../models/playlist_model.dart';

class ApiService {
  // Default base URL for TuneWorld backend API
  static String baseUrl = const String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://tuneworld.learnix.dev/api',
  );

  static Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.MultipartFile> _buildMultipartFile(
      String fieldName, PlatformFile platformFile) async {
    final bytes = await platformFile.readAsBytes();
    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: platformFile.name,
    );
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    final body = response.body.trim();
    if (body.startsWith('<') || body.contains('<html>') || body.contains('<!DOCTYPE')) {
      throw Exception('Server returned HTML response (${response.statusCode}): ${response.reasonPhrase ?? "Error"}. Please verify backend server.');
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Invalid JSON structure returned from server.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to decode server response: $e');
    }
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

    final data = _parseResponse(response);
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

    final data = _parseResponse(response);
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

    final data = _parseResponse(response);
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
    final data = _parseResponse(response);

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
    final data = _parseResponse(response);

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
    required PlatformFile audioFile,
    PlatformFile? thumbnailFile,
  }) async {
    // Step 1: Request signed upload credentials from backend API
    final sigUri = Uri.parse('$baseUrl/audio/cloudinary-signature').replace(
      queryParameters: {'folder': 'tune_world/audios'},
    );
    final sigResponse = await http.get(sigUri, headers: _headers(token));
    final sigData = _parseResponse(sigResponse);

    if (sigResponse.statusCode != 200 || sigData['success'] != true) {
      throw Exception(sigData['message'] ?? 'Failed to get upload authorization signature');
    }

    final timestamp = sigData['timestamp'].toString();
    final signature = sigData['signature'].toString();
    final apiKey = sigData['apiKey'].toString();
    final cloudName = sigData['cloudName'].toString();

    // Step 2: Upload audio file directly to Cloudinary API (bypasses Nginx proxy payload limits)
    final cUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
    final cRequest = http.MultipartRequest('POST', cUri);
    cRequest.fields['api_key'] = apiKey;
    cRequest.fields['timestamp'] = timestamp;
    cRequest.fields['signature'] = signature;
    cRequest.fields['folder'] = 'tune_world/audios';

    cRequest.files.add(await _buildMultipartFile('file', audioFile));

    final cStreamed = await cRequest.send().timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw Exception('Audio upload to Cloudinary timed out. Please check your internet connection.');
      },
    );
    final cResponse = await http.Response.fromStream(cStreamed);
    final cData = jsonDecode(cResponse.body);

    if (cResponse.statusCode != 200 || cData['secure_url'] == null) {
      final errObj = cData['error'];
      final errMsg = errObj != null && errObj['message'] != null ? errObj['message'] : 'Failed uploading to Cloudinary';
      throw Exception('Cloudinary upload error: $errMsg');
    }

    final audioUrl = cData['secure_url'].toString();
    String thumbnailImageUrl = '';

    // Step 3: If a thumbnail file is selected, upload thumbnail directly to Cloudinary
    if (thumbnailFile != null) {
      try {
        final tSigUri = Uri.parse('$baseUrl/audio/cloudinary-signature').replace(
          queryParameters: {'folder': 'tune_world/thumbnails'},
        );
        final tSigResponse = await http.get(tSigUri, headers: _headers(token));
        final tSigData = _parseResponse(tSigResponse);

        if (tSigResponse.statusCode == 200 && tSigData['success'] == true) {
          final tTimestamp = tSigData['timestamp'].toString();
          final tSignature = tSigData['signature'].toString();

          final tUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
          final tRequest = http.MultipartRequest('POST', tUri);
          tRequest.fields['api_key'] = apiKey;
          tRequest.fields['timestamp'] = tTimestamp;
          tRequest.fields['signature'] = tSignature;
          tRequest.fields['folder'] = 'tune_world/thumbnails';

          tRequest.files.add(await _buildMultipartFile('file', thumbnailFile));

          final tStreamed = await tRequest.send().timeout(const Duration(minutes: 2));
          final tResponse = await http.Response.fromStream(tStreamed);
          final tData = jsonDecode(tResponse.body);
          if (tResponse.statusCode == 200 && tData['secure_url'] != null) {
            thumbnailImageUrl = tData['secure_url'].toString();
          }
        }
      } catch (e) {
        print('Thumbnail upload warning: $e');
      }
    }

    // Step 4: Save metadata to MongoDB via small JSON payload (1KB)
    final metaResponse = await http.post(
      Uri.parse('$baseUrl/audio/save-metadata'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'audioUrl': audioUrl,
        'thumbnailImageUrl': thumbnailImageUrl,
        'visibility': visibility,
      }),
    );

    final metaData = _parseResponse(metaResponse);
    if (metaResponse.statusCode == 201 && metaData['success'] == true) {
      return AudioModel.fromJson(metaData['audio']);
    } else {
      throw Exception(metaData['message'] ?? 'Failed to save audio metadata');
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
    final data = _parseResponse(response);

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
    final data = _parseResponse(response);

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
    PlatformFile? imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/playlists');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['visibility'] = visibility;

    if (imageFile != null) {
      request.files.add(await _buildMultipartFile('image', imageFile));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _parseResponse(response);

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

    final data = _parseResponse(response);
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
    final data = _parseResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch playlist details');
    }
  }

  // Update Audio
  static Future<AudioModel> updateAudio({
    required String token,
    required String audioId,
    String? name,
    String? visibility,
    String? thumbnailImageUrl,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/audio/$audioId'),
      headers: _headers(token),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (visibility != null) 'visibility': visibility,
        if (thumbnailImageUrl != null) 'thumbnailImageUrl': thumbnailImageUrl,
      }),
    );

    final data = _parseResponse(response);
    if (response.statusCode == 200 && data['success'] == true) {
      return AudioModel.fromJson(data['audio']);
    } else {
      throw Exception(data['message'] ?? 'Failed to update audio');
    }
  }

  // Delete Audio
  static Future<void> deleteAudio({
    required String token,
    required String audioId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/audio/$audioId'),
      headers: _headers(token),
    );

    final data = _parseResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete audio');
    }
  }

  // Update Playlist
  static Future<PlaylistModel> updatePlaylist({
    required String token,
    required String playlistId,
    String? name,
    String? visibility,
    PlatformFile? imageFile,
    String? imageUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId');
    final request = http.MultipartRequest('PUT', uri);

    request.headers['Authorization'] = 'Bearer $token';
    if (name != null) request.fields['name'] = name;
    if (visibility != null) request.fields['visibility'] = visibility;
    if (imageUrl != null) request.fields['imageUrl'] = imageUrl;

    if (imageFile != null) {
      request.files.add(await _buildMultipartFile('image', imageFile));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _parseResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return PlaylistModel.fromJson(data['playlist']);
    } else {
      throw Exception(data['message'] ?? 'Failed to update playlist');
    }
  }

  // Delete Playlist
  static Future<void> deletePlaylist({
    required String token,
    required String playlistId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/playlists/$playlistId'),
      headers: _headers(token),
    );

    final data = _parseResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete playlist');
    }
  }

  // Remove Audio from Playlist
  static Future<void> removeAudioFromPlaylist({
    required String token,
    required String playlistId,
    required String audioId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/playlists/$playlistId/remove-audio/$audioId'),
      headers: _headers(token),
    );

    final data = _parseResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to remove audio from playlist');
    }
  }
}
