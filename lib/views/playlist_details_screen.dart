import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_tile_widget.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;
  final TuneWorldAudioHandler audioHandler;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
    required this.audioHandler,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  void _loadDetails({int page = 1}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
    playlistProv.fetchPlaylistDetails(
      token: auth.token,
      playlistId: widget.playlistId,
      page: page,
      pageSize: 50, // Initial page size set to 50 everywhere
      search: _searchController.text.trim(),
    );
  }

  void _playPlaylist() {
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (playlistProv.currentPlaylistAudios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs in this playlist to play')),
      );
      return;
    }

    widget.audioHandler.playTrack(
      playlistProv.currentPlaylistAudios[0],
      queueList: playlistProv.currentPlaylistAudios,
      index: 0,
      fetchMoreCallback: () async {
        final success = await playlistProv.loadMorePlaylistDetails(
          token: auth.token,
          playlistId: widget.playlistId,
          search: _searchController.text.trim(),
        );
        if (success) {
          widget.audioHandler.appendQueue(playlistProv.currentPlaylistAudios);
        }
        return success;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Playlist Details'),
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, pProv, child) {
          if (pProv.isLoadingDetails) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            );
          }

          if (pProv.errorMessage != null && pProv.currentPlaylist == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  pProv.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final playlist = pProv.currentPlaylist;
          if (playlist == null) return const SizedBox.shrink();

          return Column(
            children: [
              // Header Card with Play Playlist Button
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryAccent.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.purpleAccent.withOpacity(0.3),
                            child: playlist.imageUrl.isNotEmpty
                                ? Image.network(
                                    playlist.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.queue_music,
                                      size: 40,
                                      color: AppTheme.primaryAccent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.queue_music,
                                    size: 40,
                                    color: AppTheme.primaryAccent,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created by ${playlist.userName ?? "User"}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Visibility: ${playlist.visibility.toUpperCase()}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Play Playlist Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _playPlaylist,
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                        label: const Text(
                          'Play Playlist',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search inside playlist
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search songs in playlist...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.primaryAccent),
                      onPressed: () => _loadDetails(page: 1),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Songs List
              Expanded(
                child: pProv.currentPlaylistAudios.isEmpty
                    ? const Center(
                        child: Text(
                          'No songs found in this playlist',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: pProv.currentPlaylistAudios.length + 1,
                        itemBuilder: (context, index) {
                          if (index == pProv.currentPlaylistAudios.length) {
                            // View More Button at bottom of list
                            if (pProv.detailsPage < pProv.detailsTotalPages) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    onPressed: pProv.isLoadingMoreDetails
                                        ? null
                                        : () {
                                            final auth = Provider.of<AuthProvider>(context, listen: false);
                                            pProv.loadMorePlaylistDetails(
                                              token: auth.token,
                                              playlistId: widget.playlistId,
                                              search: _searchController.text.trim(),
                                            );
                                          },
                                    icon: const Icon(Icons.expand_more, color: Colors.black),
                                    label: pProv.isLoadingMoreDetails
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                          )
                                        : const Text(
                                            'View More Songs',
                                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox(height: 80);
                          }

                          final song = pProv.currentPlaylistAudios[index];
                          return AudioTileWidget(
                            audio: song,
                            audioHandler: widget.audioHandler,
                            playlistQueue: pProv.currentPlaylistAudios,
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
