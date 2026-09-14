import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';
import '../models/playlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../services/file_picker_service.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDetails({int page = 1}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
    playlistProv.fetchPlaylistDetails(
      token: auth.token,
      playlistId: widget.playlistId,
      page: page,
      pageSize: 50,
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

  void _showEditPlaylistDialog(BuildContext context, PlaylistModel playlist) {
    final nameController = TextEditingController(text: playlist.name);
    String visibility = playlist.visibility;
    PlatformFile? selectedCover;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text('Edit Playlist', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Playlist Name',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.primaryAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    dropdownColor: AppTheme.cardBg,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Visibility',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.primaryAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => visibility = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await FilePickerService.pickFiles(type: FileType.image);
                      if (res.isNotEmpty) {
                        setState(() => selectedCover = res.first);
                      }

                    },

                    icon: const Icon(Icons.image, color: AppTheme.primaryAccent),
                    label: Text(
                      selectedCover != null ? selectedCover!.name : 'Change Cover Image',
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (selectedCover != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primaryAccent, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: selectedCover!.path != null && File(selectedCover!.path!).existsSync()
                                  ? Image.file(File(selectedCover!.path!), fit: BoxFit.cover)
                                  : FutureBuilder<Uint8List>(
                                      future: selectedCover!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data != null) {
                                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                        }
                                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                      },
                                    ),
                            ),

                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCover = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final pProv = Provider.of<PlaylistProvider>(context, listen: false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updating playlist...')),
                  );

                  final success = await pProv.updatePlaylist(
                    token: auth.token!,
                    playlistId: playlist.id,
                    name: nameController.text.trim(),
                    visibility: visibility,
                    imageFile: selectedCover,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Playlist updated successfully!'
                              : (pProv.errorMessage ?? 'Failed to update playlist'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Save Changes', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete playlist "${playlist.name}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final pProv = Provider.of<PlaylistProvider>(context, listen: false);

              final success = await pProv.deletePlaylist(
                token: auth.token!,
                playlistId: playlist.id,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Playlist deleted successfully'
                          : (pProv.errorMessage ?? 'Failed to delete playlist'),
                    ),
                  ),
                );
                if (success) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

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

          final isOwner = auth.isLoggedIn &&
              (auth.user?.id == playlist.userId ||
                  auth.user?.id == playlist.id ||
                  playlist.userId.isEmpty);

          return Column(
            children: [
              // Header Card with Actions & Play Button
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.2),
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
                            color: AppTheme.purpleAccent.withValues(alpha: 0.3),
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
                                  color: AppTheme.primaryAccent.withValues(alpha: 0.15),
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
                        if (isOwner)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryAccent),
                                onPressed: () => _showEditPlaylistDialog(context, playlist),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _confirmDeletePlaylist(context, playlist),
                              ),
                            ],
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
                            playlistId: widget.playlistId,
                            isPlaylistOwner: isOwner,
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
