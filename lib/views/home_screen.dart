import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_tile_widget.dart';
import '../widgets/playlist_card_widget.dart';
import '../widgets/mini_player_widget.dart';
import 'auth_screen.dart';
import 'playlist_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final TuneWorldAudioHandler audioHandler;

  const HomeScreen({super.key, required this.audioHandler});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Controllers & Inputs
  final _searchController = TextEditingController();
  final _uploadTitleController = TextEditingController();
  String _uploadVisibility = 'public';
  PlatformFile? _selectedAudioFile;
  PlatformFile? _selectedThumbnailFile;

  final _playlistNameController = TextEditingController();
  String _playlistVisibility = 'public';
  PlatformFile? _selectedPlaylistCover;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  void _fetchInitialData() {
    final audioProv = Provider.of<AudioProvider>(context, listen: false);
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);

    audioProv.fetchPublicAudios(page: 1, pageSize: 50);
    playlistProv.fetchPublicPlaylists(page: 1, pageSize: 50);
  }

  // File Picker Helpers
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result.isNotEmpty) {
      final picked = result.first;
      final filename = picked.name;

      String autoTitle = filename;
      if (autoTitle.contains('.')) {
        autoTitle = autoTitle.substring(0, autoTitle.lastIndexOf('.'));
      }
      autoTitle = autoTitle.replaceAll('_', ' ').replaceAll('-', ' ').trim();

      setState(() {
        _selectedAudioFile = picked;
        _uploadTitleController.text = autoTitle;
      });
    }
  }

  Future<void> _pickThumbnailFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result.isNotEmpty) {
      setState(() {
        _selectedThumbnailFile = result.first;
      });
    }
  }

  Future<void> _pickPlaylistCover() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result.isNotEmpty) {
      setState(() {
        _selectedPlaylistCover = result.first;
      });
    }
  }

  void _handleAudioUpload() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final audioProv = Provider.of<AudioProvider>(context, listen: false);

    if (!auth.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    if (_uploadTitleController.text.trim().isEmpty || _selectedAudioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file and enter a title')),
      );
      return;
    }

    final success = await audioProv.uploadAudio(
      token: auth.token!,
      name: _uploadTitleController.text.trim(),
      visibility: _uploadVisibility,
      audioFile: _selectedAudioFile!,
      thumbnailFile: _selectedThumbnailFile,
    );

    if (mounted) {
      if (success) {
        _uploadTitleController.clear();
        setState(() {
          _selectedAudioFile = null;
          _selectedThumbnailFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio uploaded to Cloudinary successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(audioProv.errorMessage ?? 'Upload failed')),
        );
      }
    }
  }

  void _showCreatePlaylistDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    _playlistNameController.clear();
    _playlistVisibility = 'public';
    _selectedPlaylistCover = null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final playlistProv = Provider.of<PlaylistProvider>(context);

            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: const Text('Create New Playlist', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _playlistNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Playlist Name',
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _playlistVisibility,
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Visibility',
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'public', child: Text('Public')),
                        DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
                        DropdownMenuItem(value: 'private', child: Text('Private')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => _playlistVisibility = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _pickPlaylistCover();
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.image),
                      label: Text(_selectedPlaylistCover != null ? 'Cover Selected' : 'Pick Cover Image'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBgLight),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: playlistProv.isCreating
                      ? null
                      : () async {
                          if (_playlistNameController.text.trim().isEmpty) return;
                          final success = await playlistProv.createPlaylist(
                            token: auth.token!,
                            name: _playlistNameController.text.trim(),
                            visibility: _playlistVisibility,
                            imageFile: _selectedPlaylistCover,
                          );
                          if (ctx.mounted && success) {
                            Navigator.pop(ctx);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                  child: playlistProv.isCreating
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildDiscoverTab() {
    return Consumer2<AudioProvider, PlaylistProvider>(
      builder: (context, audioProv, playlistProv, child) {
        return RefreshIndicator(
          onRefresh: () async => _fetchInitialData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search songs & music...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryAccent),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primaryAccent),
                        onPressed: () {
                          audioProv.fetchPublicAudios(
                            page: 1,
                            pageSize: 50,
                            search: _searchController.text.trim(),
                          );
                        },
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Public Playlists Horizontal Carousel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Featured Playlists',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: playlistProv.isLoadingPublic
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
                      : playlistProv.publicPlaylists.isEmpty
                          ? const Center(child: Text('No playlists found', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: playlistProv.publicPlaylists.length,
                              itemBuilder: (context, index) {
                                return PlaylistCardWidget(
                                  playlist: playlistProv.publicPlaylists[index],
                                  audioHandler: widget.audioHandler,
                                );
                              },
                            ),
                ),

                const SizedBox(height: 24),

                // Public Songs Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Latest Songs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Page ${audioProv.publicPage} of ${audioProv.publicTotalPages}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                audioProv.isLoadingPublic
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                      )
                    : audioProv.publicAudios.isEmpty
                        ? const SizedBox(
                            height: 150,
                            child: Center(
                              child: Text('No public songs available', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: audioProv.publicAudios.length,
                            itemBuilder: (context, index) {
                              final song = audioProv.publicAudios[index];
                              return AudioTileWidget(
                                audio: song,
                                audioHandler: widget.audioHandler,
                                playlistQueue: audioProv.publicAudios,
                                index: index,
                                onFetchMore: () => audioProv.loadMorePublicAudios(),
                              );
                            },
                          ),

                // View More Songs Button
                if (audioProv.publicPage < audioProv.publicTotalPages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: audioProv.isLoadingMorePublic
                          ? const CircularProgressIndicator(color: AppTheme.primaryAccent)
                          : ElevatedButton.icon(
                              onPressed: () => audioProv.loadMorePublicAudios(),
                              icon: const Icon(Icons.expand_more, color: Colors.black),
                              label: const Text('View More Songs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    final auth = Provider.of<AuthProvider>(context);

    return DefaultTabController(
      length: auth.isLoggedIn ? 2 : 1,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.primaryAccent,
            labelColor: AppTheme.primaryAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              const Tab(text: 'Public Playlists'),
              if (auth.isLoggedIn) const Tab(text: 'My Playlists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Public Playlists Tab
                Consumer<PlaylistProvider>(
                  builder: (context, pProv, child) {
                    if (pProv.isLoadingPublic) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pProv.publicPlaylists.length + (pProv.publicPage < pProv.publicTotalPages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == pProv.publicPlaylists.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: pProv.isLoadingMorePublic
                                  ? const CircularProgressIndicator(color: AppTheme.primaryAccent)
                                  : ElevatedButton.icon(
                                      onPressed: () => pProv.loadMorePublicPlaylists(),
                                      icon: const Icon(Icons.expand_more, color: Colors.black),
                                      label: const Text('View More Playlists', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                            ),
                          );
                        }
                        final pl = pProv.publicPlaylists[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          tileColor: AppTheme.cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
                              color: AppTheme.purpleAccent.withOpacity(0.3),
                              child: pl.imageUrl.isNotEmpty
                                  ? Image.network(pl.imageUrl, fit: BoxFit.cover)
                                  : const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                            ),
                          ),
                          title: Text(pl.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('By ${pl.userName ?? "User"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailsScreen(
                                  playlistId: pl.id,
                                  audioHandler: widget.audioHandler,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // My Playlists Tab (Logged in only)
                if (auth.isLoggedIn)
                  Consumer<PlaylistProvider>(
                    builder: (context, pProv, child) {
                      if (pProv.isLoadingMy) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
                      }
                      if (pProv.myPlaylists.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.playlist_play, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No personal playlists created yet', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showCreatePlaylistDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                                child: const Text('Create Playlist', style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pProv.myPlaylists.length + (pProv.myPage < pProv.myTotalPages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == pProv.myPlaylists.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: pProv.isLoadingMoreMy
                                    ? const CircularProgressIndicator(color: AppTheme.primaryAccent)
                                    : ElevatedButton.icon(
                                        onPressed: () => pProv.loadMoreMyPlaylists(auth.token!),
                                        icon: const Icon(Icons.expand_more, color: Colors.black),
                                        label: const Text('View More Playlists', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                      ),
                              ),
                            );
                          }
                          final pl = pProv.myPlaylists[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  color: AppTheme.purpleAccent.withOpacity(0.3),
                                  child: pl.imageUrl.isNotEmpty
                                      ? Image.network(pl.imageUrl, fit: BoxFit.cover)
                                      : const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                                ),
                              ),
                              title: Text(pl.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('Visibility: ${pl.visibility.toUpperCase()}', style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaylistDetailsScreen(
                                      playlistId: pl.id,
                                      audioHandler: widget.audioHandler,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    final auth = Provider.of<AuthProvider>(context);
    final audioProv = Provider.of<AudioProvider>(context);

    if (!auth.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 80, color: AppTheme.primaryAccent),
              const SizedBox(height: 16),
              const Text(
                'Upload Music & Audio',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please log in or register to upload your tracks to Cloudinary and manage your music library.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Login / Register', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Track to Cloudinary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uploadTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Track Title',
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _uploadVisibility,
            dropdownColor: AppTheme.cardBg,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Visibility',
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public (Visible to everyone)')),
              DropdownMenuItem(value: 'unlisted', child: Text('Unlisted (Accessible by link)')),
              DropdownMenuItem(value: 'private', child: Text('Private (Only me)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _uploadVisibility = val);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: const Icon(Icons.audio_file),
                  label: Text(_selectedAudioFile != null ? 'Audio Selected' : 'Select Audio File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAudioFile != null ? Colors.green.withOpacity(0.3) : AppTheme.cardBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickThumbnailFile,
                  icon: const Icon(Icons.image),
                  label: Text(_selectedThumbnailFile != null ? 'Cover Selected' : 'Select Thumbnail'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedThumbnailFile != null ? Colors.green.withOpacity(0.3) : AppTheme.cardBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedAudioFile != null || _selectedThumbnailFile != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedAudioFile != null)
                    Row(
                      children: [
                        const Icon(Icons.music_note, color: AppTheme.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Audio: ${_selectedAudioFile!.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          onPressed: () => setState(() => _selectedAudioFile = null),
                        ),
                      ],
                    ),
                  if (_selectedThumbnailFile != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.purpleAccent.withValues(alpha: 0.3),
                            child: FutureBuilder<Uint8List>(
                              future: _selectedThumbnailFile!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryAccent,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thumbnail Preview',
                                style: TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedThumbnailFile!.name,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _selectedThumbnailFile = null),
                                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                label: const Text('Remove Thumbnail', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: audioProv.isUploading ? null : _handleAudioUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: audioProv.isUploading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Upload to Cloudinary', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'My Uploads',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              audioProv.fetchMyAudios(token: auth.token!, page: 1, pageSize: 50);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh My Uploads'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBgLight),
          ),
          const SizedBox(height: 12),
          audioProv.isLoadingMy
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
              : audioProv.myAudios.isEmpty
                  ? const Text('No uploads found yet.', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: audioProv.myAudios.length,
                          itemBuilder: (context, index) {
                            return AudioTileWidget(
                              audio: audioProv.myAudios[index],
                              audioHandler: widget.audioHandler,
                              playlistQueue: audioProv.myAudios,
                              index: index,
                              onFetchMore: () => audioProv.loadMoreMyAudios(auth.token!),
                            );
                          },
                        ),
                        if (audioProv.myPage < audioProv.myTotalPages)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: audioProv.isLoadingMoreMy
                                  ? const CircularProgressIndicator(color: AppTheme.primaryAccent)
                                  : ElevatedButton.icon(
                                      onPressed: () => audioProv.loadMoreMyAudios(auth.token!),
                                      icon: const Icon(Icons.expand_more, color: Colors.black),
                                      label: const Text('View More Uploads', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.purpleAccent,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                auth.isLoggedIn ? auth.user!.name : 'Guest User',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                auth.isLoggedIn ? auth.user!.email : 'Browsing in Guest Mode',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.verified_user, color: AppTheme.primaryAccent),
                      title: const Text('JWT Auto-Verification', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        auth.isVerifying
                            ? 'Verifying JWT token...'
                            : auth.isLoggedIn
                                ? 'Token verified active'
                                : 'No token found / Guest mode',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.dns, color: AppTheme.primaryAccent),
                      title: const Text('Backend API Base URL', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        ApiService.baseUrl,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (!auth.isLoggedIn)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                  },
                  icon: const Icon(Icons.login, color: Colors.black),
                  label: const Text('Login / Register', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Logout Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'logo/TuneWorld.png',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppTheme.primaryAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TuneWorld',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (!auth.isLoggedIn && !auth.isVerifying)
            TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
              },
              icon: const Icon(Icons.login, color: AppTheme.primaryAccent, size: 18),
              label: const Text('Login', style: TextStyle(color: AppTheme.primaryAccent)),
            ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildDiscoverTab(),
              _buildPlaylistsTab(),
              _buildUploadTab(),
              _buildProfileTab(),
            ],
          ),
          // Floating Mini Player Widget at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(audioHandler: widget.audioHandler),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1 && auth.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _showCreatePlaylistDialog,
              backgroundColor: AppTheme.primaryAccent,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Playlist', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) {
          setState(() {
            _currentIndex = idx;
          });
          if (idx == 1 && auth.isLoggedIn) {
            Provider.of<PlaylistProvider>(context, listen: false).fetchMyPlaylists(token: auth.token!, page: 1, pageSize: 50);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music_rounded), label: 'Playlists'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_upload_rounded), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
