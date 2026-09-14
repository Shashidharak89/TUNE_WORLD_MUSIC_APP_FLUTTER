import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../models/audio_model.dart';
import '../models/playlist_model.dart';

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytesSent, int totalBytes)? onProgress;

  MultipartRequestWithProgress(
    String method,
    Uri url, {
    this.onProgress,
  }) : super(method, url);

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final totalBytes = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        onProgress!(bytesSent, totalBytes);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

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

  static Map<String, String> _authHeaders(String? token) {
    final headers = <String, String>{};
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
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    return await uploadAudioChunked(
      token: token,
      name: name,
      visibility: visibility,
      audioFile: audioFile,
      thumbnailFile: thumbnailFile,
      onProgress: onProgress,
    );
  }

  // Chunk-by-chunk file upload implementation (~1MB per chunk for Nginx compatibility)
  static Future<AudioModel> uploadAudioChunked({
    required String token,
    required String name,
    required String visibility,
    required PlatformFile audioFile,
    PlatformFile? thumbnailFile,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final audioBytes = await audioFile.readAsBytes();
    final totalBytes = audioBytes.length;

    if (totalBytes == 0) {
      throw Exception('Audio file is empty or cannot be read.');
    }

    // Safe 512KB chunk size guarantees request payload (including multipart metadata headers) remains ~524KB, well below Nginx 1MB body limits
    const chunkSize = 512 * 1024;
    final totalChunks = (totalBytes / chunkSize).ceil();
    final uploadId = 'upload_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

    // Upload chunks sequentially chunk-by-chunk with streaming progress
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < totalBytes) ? start + chunkSize : totalBytes;
      final chunkBytes = audioBytes.sublist(start, end);

      final uri = Uri.parse('$baseUrl/audio/upload-chunk');
      final request = MultipartRequestWithProgress(
        'POST',
        uri,
        onProgress: (chunkBytesSent, chunkTotal) {
          if (onProgress != null) {
            final currentTotalSent = start + chunkBytesSent;
            final safeSent = currentTotalSent > totalBytes ? totalBytes : currentTotalSent;
            onProgress(safeSent, totalBytes);
          }
        },
      );

      // Use Authorization headers only (Do NOT set Content-Type: application/json on MultipartRequest!)
      request.headers.addAll(_authHeaders(token));
      request.fields['uploadId'] = uploadId;
      request.fields['chunkIndex'] = i.toString();
      request.fields['totalChunks'] = totalChunks.toString();

      request.files.add(http.MultipartFile.fromBytes(
        'chunk',
        chunkBytes,
        filename: 'chunk_$i.tmp',
      ));

      final streamed = await request.send().timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw Exception('Chunk ${i + 1}/$totalChunks upload timed out. Please check network connection.');
        },
      );

      final response = await http.Response.fromStream(streamed);
      final data = _parseResponse(response);

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to upload chunk ${i + 1}');
      }
    }

    // If thumbnail file is selected, upload thumbnail directly
    String thumbnailImageUrl = '';
    if (thumbnailFile != null) {
      try {
        final sigUri = Uri.parse('$baseUrl/audio/cloudinary-signature').replace(
          queryParameters: {'folder': 'tune_world/thumbnails'},
        );
        final sigResponse = await http.get(sigUri, headers: _headers(token));
        final sigData = _parseResponse(sigResponse);

        if (sigResponse.statusCode == 200 && sigData['success'] == true) {
          final timestamp = sigData['timestamp'].toString();
          final signature = sigData['signature'].toString();
          final apiKey = sigData['apiKey'].toString();
          final cloudName = sigData['cloudName'].toString();

          final tUri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
          final tRequest = http.MultipartRequest('POST', tUri);
          tRequest.fields['api_key'] = apiKey;
          tRequest.fields['timestamp'] = timestamp;
          tRequest.fields['signature'] = signature;
          tRequest.fields['folder'] = 'tune_world/thumbnails';

          tRequest.files.add(await _buildMultipartFile('file', thumbnailFile));
          final tStreamed = await tRequest.send();
          final tResponse = await http.Response.fromStream(tStreamed);
          final tData = jsonDecode(tResponse.body);
          if (tResponse.statusCode == 200 && tData['secure_url'] != null) {
            thumbnailImageUrl = tData['secure_url'].toString();
          }
        }
      } catch (_) {}
    }

    // Call complete-chunked-upload on backend to combine chunks & save metadata
    final completeUri = Uri.parse('$baseUrl/audio/complete-chunked-upload');
    final completeResponse = await http.post(
      completeUri,
      headers: _headers(token),
      body: jsonEncode({
        'uploadId': uploadId,
        'totalChunks': totalChunks,
        'name': name,
        'visibility': visibility,
        'thumbnailImageUrl': thumbnailImageUrl,
      }),
    ).timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw Exception('Completing chunked upload timed out. Please try again.');
      },
    );

    final completeData = _parseResponse(completeResponse);
    if (completeResponse.statusCode == 201 && completeData['success'] == true) {
      return AudioModel.fromJson(completeData['audio']);
    } else {
      throw Exception(completeData['message'] ?? 'Failed to finalize chunked audio upload');
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
    PlatformFile? thumbnailFile,
    String? thumbnailImageUrl,
  }) async {
    String? finalThumbnailUrl = thumbnailImageUrl;

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
          final tApiKey = tSigData['apiKey'].toString();
          final tCloudName = tSigData['cloudName'].toString();

          final tUri = Uri.parse('https://api.cloudinary.com/v1_1/$tCloudName/image/upload');
          final tRequest = http.MultipartRequest('POST', tUri);
          tRequest.fields['api_key'] = tApiKey;
          tRequest.fields['timestamp'] = tTimestamp;
          tRequest.fields['signature'] = tSignature;
          tRequest.fields['folder'] = 'tune_world/thumbnails';


          tRequest.files.add(await _buildMultipartFile('file', thumbnailFile));

          final tStreamed = await tRequest.send().timeout(const Duration(minutes: 2));
          final tResponse = await http.Response.fromStream(tStreamed);
          final tData = jsonDecode(tResponse.body);
          if (tResponse.statusCode == 200 && tData['secure_url'] != null) {
            finalThumbnailUrl = tData['secure_url'].toString();
          }
        }
      } catch (e) {
        print('Thumbnail upload warning on update: $e');
      }
    }

    final response = await http.put(
      Uri.parse('$baseUrl/audio/$audioId'),
      headers: _headers(token),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (visibility != null) 'visibility': visibility,
        if (finalThumbnailUrl != null) 'thumbnailImageUrl': finalThumbnailUrl,
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

  // Bulk Delete Audios
  static Future<void> bulkDeleteAudios({
    required String token,
    required List<String> audioIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/audio/bulk-delete'),
      headers: _headers(token),
      body: jsonEncode({'audioIds': audioIds}),
    );

    final data = _parseResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete audios in bulk');
    }
  }

  // Bulk Add Audio to Playlist
  static Future<void> bulkAddAudioToPlaylist({
    required String token,
    required String playlistId,
    required List<String> audioIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/playlists/$playlistId/bulk-add-audio'),
      headers: _headers(token),
      body: jsonEncode({'audioIds': audioIds}),
    );

    final data = _parseResponse(response);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to bulk add audios to playlist');
    }
  }
}
