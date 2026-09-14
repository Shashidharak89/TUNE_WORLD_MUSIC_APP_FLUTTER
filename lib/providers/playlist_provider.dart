import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/playlist_model.dart';
import '../models/audio_model.dart';
import '../services/api_service.dart';

class PlaylistProvider extends ChangeNotifier {
  List<PlaylistModel> _publicPlaylists = [];
  List<PlaylistModel> _myPlaylists = [];

  bool _isLoadingPublic = false;
  bool _isLoadingMy = false;
  bool _isLoadingMorePublic = false;
  bool _isLoadingMoreMy = false;
  bool _isCreating = false;
  bool _isLoadingDetails = false;
  bool _isLoadingMoreDetails = false;
  String? _errorMessage;

  int _publicPage = 1;
  int _publicTotalPages = 1;
  int _publicPageSize = 50; // Initial page size set to 50 everywhere
  String _publicSearch = '';

  int _myPage = 1;
  int _myTotalPages = 1;
  int _myPageSize = 50; // Initial page size set to 50 everywhere
  String _mySearch = '';

  PlaylistModel? _currentPlaylist;
  List<AudioModel> _currentPlaylistAudios = [];
  int _detailsPage = 1;
  int _detailsTotalPages = 1;

  List<PlaylistModel> get publicPlaylists => _publicPlaylists;
  List<PlaylistModel> get myPlaylists => _myPlaylists;
  bool get isLoadingPublic => _isLoadingPublic;
  bool get isLoadingMy => _isLoadingMy;
  bool get isLoadingMorePublic => _isLoadingMorePublic;
  bool get isLoadingMoreMy => _isLoadingMoreMy;
  bool get isCreating => _isCreating;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get isLoadingMoreDetails => _isLoadingMoreDetails;
  String? get errorMessage => _errorMessage;

  int get publicPage => _publicPage;
  int get publicTotalPages => _publicTotalPages;
  String get publicSearch => _publicSearch;

  int get myPage => _myPage;
  int get myTotalPages => _myTotalPages;
  String get mySearch => _mySearch;

  PlaylistModel? get currentPlaylist => _currentPlaylist;
  List<AudioModel> get currentPlaylistAudios => _currentPlaylistAudios;
  int get detailsPage => _detailsPage;
  int get detailsTotalPages => _detailsTotalPages;

  // Fetch Public Playlists
  Future<void> fetchPublicPlaylists({
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
      final res = await ApiService.getPublicPlaylists(
        page: _publicPage,
        pageSize: _publicPageSize,
        search: _publicSearch,
      );

      final List listData = res['playlists'] ?? [];
      _publicPlaylists =
          listData.map((e) => PlaylistModel.fromJson(e)).toList();

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

  // Load More Public Playlists
  Future<bool> loadMorePublicPlaylists() async {
    if (_publicPage >= _publicTotalPages || _isLoadingMorePublic) return false;

    _isLoadingMorePublic = true;
    notifyListeners();

    try {
      final nextPage = _publicPage + 1;
      final res = await ApiService.getPublicPlaylists(
        page: nextPage,
        pageSize: _publicPageSize,
        search: _publicSearch,
      );

      final List listData = res['playlists'] ?? [];
      final newItems = listData.map((e) => PlaylistModel.fromJson(e)).toList();

      if (newItems.isNotEmpty) {
        _publicPlaylists.addAll(newItems);
        _publicPage = nextPage;
        if (res['pagination'] != null) {
          _publicTotalPages = res['pagination']['totalPages'] ?? _publicTotalPages;
        }
        _isLoadingMorePublic = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error loading more public playlists: $e');
    }

    _isLoadingMorePublic = false;
    notifyListeners();
    return false;
  }

  // Fetch User's Playlists
  Future<void> fetchMyPlaylists({
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
      final res = await ApiService.getMyPlaylists(
        token: token,
        page: _myPage,
        pageSize: _myPageSize,
        search: _mySearch,
      );

      final List listData = res['playlists'] ?? [];
      _myPlaylists = listData.map((e) => PlaylistModel.fromJson(e)).toList();

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

  // Load More User Playlists
  Future<bool> loadMoreMyPlaylists(String token) async {
    if (_myPage >= _myTotalPages || _isLoadingMoreMy) return false;

    _isLoadingMoreMy = true;
    notifyListeners();

    try {
      final nextPage = _myPage + 1;
      final res = await ApiService.getMyPlaylists(
        token: token,
        page: nextPage,
        pageSize: _myPageSize,
        search: _mySearch,
      );

      final List listData = res['playlists'] ?? [];
      final newItems = listData.map((e) => PlaylistModel.fromJson(e)).toList();

      if (newItems.isNotEmpty) {
        _myPlaylists.addAll(newItems);
        _myPage = nextPage;
        if (res['pagination'] != null) {
          _myTotalPages = res['pagination']['totalPages'] ?? _myTotalPages;
        }
        _isLoadingMoreMy = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error loading more user playlists: $e');
    }

    _isLoadingMoreMy = false;
    notifyListeners();
    return false;
  }

  // Create Playlist
  Future<bool> createPlaylist({
    required String token,
    required String name,
    required String visibility,
    PlatformFile? imageFile,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final playlist = await ApiService.createPlaylist(
        token: token,
        name: name,
        visibility: visibility,
        imageFile: imageFile,
      );

      _myPlaylists.insert(0, playlist);
      if (playlist.visibility == 'public') {
        _publicPlaylists.insert(0, playlist);
      }

      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  // Add Audio to Playlist
  Future<bool> addAudioToPlaylist({
    required String token,
    required String playlistId,
    required String audioId,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.addAudioToPlaylist(
        token: token,
        playlistId: playlistId,
        audioId: audioId,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Fetch Playlist Details and its Songs
  Future<void> fetchPlaylistDetails({
    String? token,
    required String playlistId,
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.getPlaylistDetails(
        token: token,
        playlistId: playlistId,
        page: page,
        pageSize: pageSize,
        search: search,
      );

      _currentPlaylist = PlaylistModel.fromJson(res['playlist']);
      final List listData = res['audios'] ?? [];
      _currentPlaylistAudios =
          listData.map((e) => AudioModel.fromJson(e)).toList();

      if (res['pagination'] != null) {
        _detailsPage = res['pagination']['page'] ?? 1;
        _detailsTotalPages = res['pagination']['totalPages'] ?? 1;
      }

      _isLoadingDetails = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  // Load More Playlist Details (Append next page of songs)
  Future<bool> loadMorePlaylistDetails({
    String? token,
    required String playlistId,
    String? search,
  }) async {
    if (_detailsPage >= _detailsTotalPages || _isLoadingMoreDetails) return false;

    _isLoadingMoreDetails = true;
    notifyListeners();

    try {
      final nextPage = _detailsPage + 1;
      final res = await ApiService.getPlaylistDetails(
        token: token,
        playlistId: playlistId,
        page: nextPage,
        pageSize: 50,
        search: search,
      );

      final List listData = res['audios'] ?? [];
      final newAudios = listData.map((e) => AudioModel.fromJson(e)).toList();

      if (newAudios.isNotEmpty) {
        _currentPlaylistAudios.addAll(newAudios);
        _detailsPage = nextPage;
        if (res['pagination'] != null) {
          _detailsTotalPages = res['pagination']['totalPages'] ?? _detailsTotalPages;
        }
        _isLoadingMoreDetails = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error loading more playlist details: $e');
    }

    _isLoadingMoreDetails = false;
    notifyListeners();
    return false;
  }

  // Update Playlist
  Future<bool> updatePlaylist({
    required String token,
    required String playlistId,
    String? name,
    String? visibility,
    PlatformFile? imageFile,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await ApiService.updatePlaylist(
        token: token,
        playlistId: playlistId,
        name: name,
        visibility: visibility,
        imageFile: imageFile,
      );

      if (_currentPlaylist?.id == playlistId) {
        _currentPlaylist = updated;
      }

      final myIdx = _myPlaylists.indexWhere((p) => p.id == playlistId);
      if (myIdx != -1) {
        _myPlaylists[myIdx] = updated;
      }

      final pubIdx = _publicPlaylists.indexWhere((p) => p.id == playlistId);
      if (updated.visibility == 'public') {
        if (pubIdx != -1) {
          _publicPlaylists[pubIdx] = updated;
        } else {
          _publicPlaylists.insert(0, updated);
        }
      } else {
        if (pubIdx != -1) {
          _publicPlaylists.removeAt(pubIdx);
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

  // Delete Playlist
  Future<bool> deletePlaylist({
    required String token,
    required String playlistId,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.deletePlaylist(token: token, playlistId: playlistId);
      _myPlaylists.removeWhere((p) => p.id == playlistId);
      _publicPlaylists.removeWhere((p) => p.id == playlistId);
      if (_currentPlaylist?.id == playlistId) {
        _currentPlaylist = null;
        _currentPlaylistAudios = [];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Remove Audio from Playlist
  Future<bool> removeAudioFromPlaylist({
    required String token,
    required String playlistId,
    required String audioId,
  }) async {
    _errorMessage = null;
    try {
      await ApiService.removeAudioFromPlaylist(
        token: token,
        playlistId: playlistId,
        audioId: audioId,
      );

      if (_currentPlaylist?.id == playlistId) {
        _currentPlaylistAudios.removeWhere((a) => a.id == audioId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}

