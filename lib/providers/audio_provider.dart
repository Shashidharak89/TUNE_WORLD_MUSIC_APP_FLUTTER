import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/audio_model.dart';
import '../services/api_service.dart';

class AudioProvider extends ChangeNotifier {
  List<AudioModel> _publicAudios = [];
  List<AudioModel> _myAudios = [];

  bool _isLoadingPublic = false;
  bool _isLoadingMy = false;
  bool _isLoadingMorePublic = false;
  bool _isLoadingMoreMy = false;
  bool _isUploading = false;
  String? _errorMessage;

  int _publicPage = 1;
  int _publicTotalPages = 1;
  int _publicPageSize = 50; // Initial page size set to 50 everywhere
  String _publicSearch = '';

  int _myPage = 1;
  int _myTotalPages = 1;
  int _myPageSize = 50; // Initial page size set to 50 everywhere
  String _mySearch = '';

  List<AudioModel> get publicAudios => _publicAudios;
  List<AudioModel> get myAudios => _myAudios;
  bool get isLoadingPublic => _isLoadingPublic;
  bool get isLoadingMy => _isLoadingMy;
  bool get isLoadingMorePublic => _isLoadingMorePublic;
  bool get isLoadingMoreMy => _isLoadingMoreMy;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;

  int get publicPage => _publicPage;
  int get publicTotalPages => _publicTotalPages;
  String get publicSearch => _publicSearch;

  int get myPage => _myPage;
  int get myTotalPages => _myTotalPages;
  String get mySearch => _mySearch;

  // Fetch Public Audios
  Future<void> fetchPublicAudios({
    int? page,
    int? pageSize,
    String? search,
  }) async {
    _isLoadingPublic = true;
    _errorMessage = null;
    if (page != null) _publicPage = page;
    if (pageSize != null) _publicPageSize = pageSize;
    if (search != null) _publicSearch = search;
    notifyListeners();

    try {
      final res = await ApiService.getPublicAudios(
        page: _publicPage,
        pageSize: _publicPageSize,
        search: _publicSearch,
      );

      final List listData = res['audios'] ?? [];
      _publicAudios = listData.map((e) => AudioModel.fromJson(e)).toList();

      if (res['pagination'] != null) {
        _publicTotalPages = res['pagination']['totalPages'] ?? 1;
      }

      _isLoadingPublic = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingPublic = false;
      notifyListeners();
    }
  }

  // Load More Public Audios (Append next page)
  Future<bool> loadMorePublicAudios() async {
    if (_publicPage >= _publicTotalPages || _isLoadingMorePublic) {
      return false;
    }

    _isLoadingMorePublic = true;
    notifyListeners();

    try {
      final nextPage = _publicPage + 1;
      final res = await ApiService.getPublicAudios(
        page: nextPage,
        pageSize: _publicPageSize,
        search: _publicSearch,
      );

      final List listData = res['audios'] ?? [];
      final newItems = listData.map((e) => AudioModel.fromJson(e)).toList();

      if (newItems.isNotEmpty) {
        _publicAudios.addAll(newItems);
        _publicPage = nextPage;
        if (res['pagination'] != null) {
          _publicTotalPages = res['pagination']['totalPages'] ?? _publicTotalPages;
        }
        _isLoadingMorePublic = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error loading more public audios: $e');
    }

    _isLoadingMorePublic = false;
    notifyListeners();
    return false;
  }

  // Fetch User's Uploaded Audios
  Future<void> fetchMyAudios({
    required String token,
    int? page,
    int? pageSize,
    String? search,
  }) async {
    _isLoadingMy = true;
    _errorMessage = null;
    if (page != null) _myPage = page;
    if (pageSize != null) _myPageSize = pageSize;
    if (search != null) _mySearch = search;
    notifyListeners();

    try {
      final res = await ApiService.getMyAudios(
        token: token,
        page: _myPage,
        pageSize: _myPageSize,
        search: _mySearch,
      );

      final List listData = res['audios'] ?? [];
      _myAudios = listData.map((e) => AudioModel.fromJson(e)).toList();

      if (res['pagination'] != null) {
        _myTotalPages = res['pagination']['totalPages'] ?? 1;
      }

      _isLoadingMy = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingMy = false;
      notifyListeners();
    }
  }

  // Load More User Audios (Append next page)
  Future<bool> loadMoreMyAudios(String token) async {
    if (_myPage >= _myTotalPages || _isLoadingMoreMy) {
      return false;
    }

    _isLoadingMoreMy = true;
    notifyListeners();

    try {
      final nextPage = _myPage + 1;
      final res = await ApiService.getMyAudios(
        token: token,
        page: nextPage,
        pageSize: _myPageSize,
        search: _mySearch,
      );

      final List listData = res['audios'] ?? [];
      final newItems = listData.map((e) => AudioModel.fromJson(e)).toList();

      if (newItems.isNotEmpty) {
        _myAudios.addAll(newItems);
        _myPage = nextPage;
        if (res['pagination'] != null) {
          _myTotalPages = res['pagination']['totalPages'] ?? _myTotalPages;
        }
        _isLoadingMoreMy = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error loading more user audios: $e');
    }

    _isLoadingMoreMy = false;
    notifyListeners();
    return false;
  }

  // Upload New Audio
  Future<bool> uploadAudio({
    required String token,
    required String name,
    required String visibility,
    required PlatformFile audioFile,
    PlatformFile? thumbnailFile,
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newAudio = await ApiService.uploadAudio(
        token: token,
        name: name,
        visibility: visibility,
        audioFile: audioFile,
        thumbnailFile: thumbnailFile,
        onProgress: onProgress,
      );

      _myAudios.insert(0, newAudio);
      if (newAudio.visibility == 'public') {
        _publicAudios.insert(0, newAudio);
      }

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  // Update Audio
  Future<bool> updateAudio({
    required String token,
    required String audioId,
    String? name,
    String? visibility,
    PlatformFile? thumbnailFile,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await ApiService.updateAudio(
        token: token,
        audioId: audioId,
        name: name,
        visibility: visibility,
        thumbnailFile: thumbnailFile,
      );

      final myIdx = _myAudios.indexWhere((a) => a.id == audioId);
      if (myIdx != -1) {
        _myAudios[myIdx] = updated;
      }

      final pubIdx = _publicAudios.indexWhere((a) => a.id == audioId);
      if (updated.visibility == 'public') {
        if (pubIdx != -1) {
          _publicAudios[pubIdx] = updated;
        } else {
          _publicAudios.insert(0, updated);
        }
      } else {
        if (pubIdx != -1) {
          _publicAudios.removeAt(pubIdx);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Delete Audio
  Future<bool> deleteAudio({
    required String token,
    required String audioId,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.deleteAudio(token: token, audioId: audioId);
      _myAudios.removeWhere((a) => a.id == audioId);
      _publicAudios.removeWhere((a) => a.id == audioId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Bulk Delete Audios
  Future<bool> bulkDeleteAudios({
    required String token,
    required List<String> audioIds,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.bulkDeleteAudios(token: token, audioIds: audioIds);
      final idSet = Set<String>.from(audioIds);
      _myAudios.removeWhere((a) => idSet.contains(a.id));
      _publicAudios.removeWhere((a) => idSet.contains(a.id));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}

