import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/audio_model.dart';
import '../services/api_service.dart';

class AudioProvider extends ChangeNotifier {
  List<AudioModel> _publicAudios = [];
  List<AudioModel> _myAudios = [];

  bool _isLoadingPublic = false;
  bool _isLoadingMy = false;
  bool _isUploading = false;
  String? _errorMessage;

  int _publicPage = 1;
  int _publicTotalPages = 1;
  int _publicPageSize = 10;
  String _publicSearch = '';

  int _myPage = 1;
  int _myTotalPages = 1;
  int _myPageSize = 10;
  String _mySearch = '';

  List<AudioModel> get publicAudios => _publicAudios;
  List<AudioModel> get myAudios => _myAudios;
  bool get isLoadingPublic => _isLoadingPublic;
  bool get isLoadingMy => _isLoadingMy;
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

  // Upload New Audio
  Future<bool> uploadAudio({
    required String token,
    required String name,
    required String visibility,
    required File audioFile,
    File? thumbnailFile,
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
}
