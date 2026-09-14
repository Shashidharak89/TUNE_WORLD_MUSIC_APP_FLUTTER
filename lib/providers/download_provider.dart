import 'package:flutter/foundation.dart';
import '../models/audio_model.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  List<AudioModel> _downloadedTracks = [];
  bool _isLoading = false;
  final Set<String> _downloadingIds = {};
  String? _errorMessage;

  List<AudioModel> get downloadedTracks => _downloadedTracks;
  bool get isLoading => _isLoading;
  Set<String> get downloadingIds => _downloadingIds;
  String? get errorMessage => _errorMessage;

  bool isDownloaded(String audioId) {
    return _downloadedTracks.any((item) => item.id == audioId);
  }

  bool isDownloading(String audioId) {
    return _downloadingIds.contains(audioId);
  }

  // Fetch all downloaded offline tracks
  Future<void> fetchDownloadedTracks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _downloadedTracks = await DownloadService.getDownloadedTracks();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Download track to TuneWorld folder
  Future<bool> downloadTrack(AudioModel audio) async {
    if (_downloadingIds.contains(audio.id)) return false;

    _downloadingIds.add(audio.id);
    notifyListeners();

    final success = await DownloadService.downloadAudioTrack(audio);

    _downloadingIds.remove(audio.id);
    if (success) {
      await fetchDownloadedTracks();
    } else {
      _errorMessage = 'Failed to download ${audio.name}';
      notifyListeners();
    }
    return success;
  }

  // Delete downloaded track from device storage
  Future<bool> deleteTrack(String audioId) async {
    final success = await DownloadService.deleteDownloadedTrack(audioId);
    if (success) {
      _downloadedTracks.removeWhere((item) => item.id == audioId);
      notifyListeners();
    }
    return success;
  }
}
