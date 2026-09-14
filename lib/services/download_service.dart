import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_model.dart';

class DownloadService {
  static const String _prefsKey = 'tuneworld_downloaded_tracks';

  // Get path to TuneWorld folder in Downloads directory
  static Future<String?> getTuneWorldDownloadDirPath() async {
    if (kIsWeb) return null;

    try {
      if (Platform.isAndroid) {
        final Directory downloadDir = Directory('/storage/emulated/0/Download/TuneWorld');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        final Directory systemDownload = Directory('${Platform.environment['HOME']}/Downloads/TuneWorld');
        if (!await systemDownload.exists()) {
          await systemDownload.create(recursive: true);
        }
        return systemDownload.path;
      }
    } catch (e) {
      print('Error getting TuneWorld download path: $e');
    }
    return null;
  }

  // Download audio track to disk and persist offline metadata
  static Future<bool> downloadAudioTrack(AudioModel audio, {Function(double progress)? onProgress}) async {
    try {
      final response = await http.get(Uri.parse(audio.audioUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download audio bytes (HTTP ${response.statusCode})');
      }

      final bytes = response.bodyBytes;
      String sanitizedName = audio.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (sanitizedName.isEmpty) sanitizedName = 'audio_${audio.id}';

      String localFilePath = audio.audioUrl;

      if (!kIsWeb) {
        final dirPath = await getTuneWorldDownloadDirPath();
        if (dirPath != null) {
          final ext = audio.audioUrl.toLowerCase().contains('.m4a') ? '.m4a' : '.mp3';
          final file = File('$dirPath/$sanitizedName$ext');
          await file.writeAsBytes(bytes);
          localFilePath = file.path;
        }
      }

      // Save to SharedPreferences offline metadata
      final prefs = await SharedPreferences.getInstance();
      final String? existingJson = prefs.getString(_prefsKey);
      List<dynamic> list = existingJson != null ? jsonDecode(existingJson) : [];

      // Check if already downloaded
      final index = list.indexWhere((item) => item['id'] == audio.id);
      final downloadItem = {
        'id': audio.id,
        'name': audio.name,
        'userId': audio.userId,
        'userName': audio.userName ?? 'Tune World Artist',
        'audioUrl': localFilePath, // Points to local file path when offline
        'remoteAudioUrl': audio.audioUrl,
        'thumbnailImageUrl': audio.thumbnailImageUrl,
        'visibility': audio.visibility,
        'downloadedAt': DateTime.now().toIso8601String(),
      };

      if (index != -1) {
        list[index] = downloadItem;
      } else {
        list.add(downloadItem);
      }

      await prefs.setString(_prefsKey, jsonEncode(list));
      return true;
    } catch (e) {
      print('Download service error: $e');
      return false;
    }
  }

  // Get list of all offline downloaded audio tracks
  static Future<List<AudioModel>> getDownloadedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingJson = prefs.getString(_prefsKey);
      if (existingJson == null || existingJson.isEmpty) return [];

      final List<dynamic> list = jsonDecode(existingJson);
      List<AudioModel> result = [];

      for (var item in list) {
        String localUrl = item['audioUrl'] ?? '';
        // If file exists locally or is remote, keep it
        if (!kIsWeb && localUrl.startsWith('/') && !File(localUrl).existsSync()) {
          // If local file was deleted manually from file manager, fall back to remote URL if available
          localUrl = item['remoteAudioUrl'] ?? localUrl;
        }

        result.add(AudioModel(
          id: item['id'] ?? '',
          name: item['name'] ?? 'Downloaded Track',
          userId: item['userId'] ?? '',
          userName: item['userName'] ?? 'Tune World Artist',
          audioUrl: localUrl,
          thumbnailImageUrl: item['thumbnailImageUrl'] ?? '',
          visibility: item['visibility'] ?? 'public',
          createdAt: item['downloadedAt'] != null ? DateTime.tryParse(item['downloadedAt']) : null,
        ));
      }
      return result;
    } catch (e) {
      print('Error reading downloaded tracks: $e');
      return [];
    }
  }

  // Delete downloaded track
  static Future<bool> deleteDownloadedTrack(String audioId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingJson = prefs.getString(_prefsKey);
      if (existingJson == null) return false;

      List<dynamic> list = jsonDecode(existingJson);
      final index = list.indexWhere((item) => item['id'] == audioId);
      if (index != -1) {
        final localUrl = list[index]['audioUrl'] ?? '';
        if (!kIsWeb && localUrl.startsWith('/')) {
          final file = File(localUrl);
          if (await file.exists()) {
            await file.delete();
          }
        }
        list.removeAt(index);
        await prefs.setString(_prefsKey, jsonEncode(list));
        return true;
      }
    } catch (e) {
      print('Error deleting downloaded track: $e');
    }
    return false;
  }
}
