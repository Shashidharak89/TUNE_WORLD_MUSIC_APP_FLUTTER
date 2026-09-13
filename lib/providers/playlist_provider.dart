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
  bool _isCreating = false;
  bool _isLoadingDetails = false;
  String? _errorMessage;

  int _publicPage = 1;
  int _publicTotalPages = 1;
  int _publicPageSize = 10;
  String _publicSearch = '';

  int _myPage = 1;
  int _myTotalPages = 1;
  int _myPageSize = 10;
  String _mySearch = '';

  PlaylistModel? _currentPlaylist;
  List<AudioModel> _currentPlaylistAudios = [];
  int _detailsPage = 1;
  int _detailsTotalPages = 1;

  List<PlaylistModel> get publicPlaylists => _publicPlaylists;
  List<PlaylistModel> get myPlaylists => _myPlaylists;
  bool get isLoadingPublic => _isLoadingPublic;
  bool get isLoadingMy => _isLoadingMy;
  bool get isCreating => _isCreating;
  bool get isLoadingDetails => _isLoadingDetails;
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
    int pageSize = 10,
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
}
