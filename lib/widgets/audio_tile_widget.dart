import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import '../models/audio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../services/audio_handler.dart';
import '../services/file_picker_service.dart';
import '../theme/app_theme.dart';


class AudioTileWidget extends StatelessWidget {
  final AudioModel audio;
  final TuneWorldAudioHandler audioHandler;
  final List<AudioModel> playlistQueue;
  final int? index;
  final Future<bool> Function()? onFetchMore;
  final String? playlistId;
  final bool? isPlaylistOwner;
  final bool isDownloadedScreen;
  final VoidCallback? onDeleteDownloaded;

  const AudioTileWidget({
    super.key,
    required this.audio,
    required this.audioHandler,
    this.playlistQueue = const [],
    this.index,
    this.onFetchMore,
    this.playlistId,
    this.isPlaylistOwner,
    this.isDownloadedScreen = false,
    this.onDeleteDownloaded,
  });

  void _showOptionsMenu(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = auth.isLoggedIn &&
        (auth.user?.id == audio.userId ||
            auth.user?.id == audio.id ||
            audio.userId.isEmpty);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.purpleAccent.withValues(alpha: 0.2),
                        ),
                        child: audio.thumbnailImageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(audio.thumbnailImageUrl, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.music_note, color: AppTheme.primaryAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audio.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              audio.userName ?? 'Tune World Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),

                // Option: Add to Playlist
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: AppTheme.primaryAccent),
                  title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context);
                  },
                ),

                // Option: Download Track
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Colors.greenAccent),
                  title: const Text('Download Track', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Save to TuneWorld downloads', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Starting download for "${audio.name}"...')),
                    );
                    final dlProv = Provider.of<DownloadProvider>(context, listen: false);
                    final success = await dlProv.downloadTrack(audio);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Downloaded "${audio.name}" successfully to Download/TuneWorld!'
                                : (dlProv.errorMessage ?? 'Download failed'),
                          ),
                          backgroundColor: success ? Colors.green : Colors.redAccent,
                        ),
                      );
                    }
                  },
                ),

                // Option: Remove from Playlist (if inside playlist and user is playlist owner)
                if (playlistId != null && (isPlaylistOwner ?? false))
                  ListTile(
                    leading: const Icon(Icons.playlist_remove, color: Colors.orangeAccent),
                    title: const Text('Remove from Playlist', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmRemoveFromPlaylist(context);
                    },
                  ),

                // Option: Edit Track (Owner only)
                if (isOwner)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryAccent),
                    title: const Text('Edit Track Details', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditAudioDialog(context);
                    },
                  ),

                // Option: Delete Track (Owner only)
                if (isOwner)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: const Text('Delete Track', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteAudio(context);
                    },
                  ),

                // Option: Delete Offline Copy (In Downloaded Screen)
                if (isDownloadedScreen && onDeleteDownloaded != null)
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    title: const Text('Remove Offline Download', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDeleteDownloaded!();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);

    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add songs to your playlist'),
        ),
      );
      return;
    }

    playlistProv.fetchMyPlaylists(token: auth.token!, page: 1, pageSize: 50);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<PlaylistProvider>(
          builder: (context, pProv, child) {
            if (pProv.isLoadingMy) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                ),
              );
            }

            if (pProv.myPlaylists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.playlist_play, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No playlists found. Create one first in the Playlists tab!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Add "${audio.name}" to Playlist',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pProv.myPlaylists.length,
                      itemBuilder: (context, index) {
                        final pl = pProv.myPlaylists[index];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.purpleAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                          ),
                          title: Text(
                            pl.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Visibility: ${pl.visibility}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final success = await pProv.addAudioToPlaylist(
                              token: auth.token!,
                              playlistId: pl.id,
                              audioId: audio.id,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Added to playlist successfully!'
                                        : (pProv.errorMessage ?? 'Failed to add to playlist'),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemoveFromPlaylist(BuildContext context) {
    if (playlistId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Remove from Playlist', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${audio.name}" from this playlist?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final pProv = Provider.of<PlaylistProvider>(context, listen: false);
              final success = await pProv.removeAudioFromPlaylist(
                token: auth.token!,
                playlistId: playlistId!,
                audioId: audio.id,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Removed from playlist'
                          : (pProv.errorMessage ?? 'Failed to remove from playlist'),
                    ),
                  ),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditAudioDialog(BuildContext context) {
    final nameController = TextEditingController(text: audio.name);
    String visibility = audio.visibility;
    PlatformFile? selectedThumbnail;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text('Edit Audio Track', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Track Title',
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
                        setState(() => selectedThumbnail = res.first);
                      }

                    },

                    icon: const Icon(Icons.image, color: AppTheme.primaryAccent),
                    label: Text(
                      selectedThumbnail != null ? selectedThumbnail!.name : 'Change Cover Image',
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (selectedThumbnail != null) ...[
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
                              child: selectedThumbnail!.path != null && File(selectedThumbnail!.path!).existsSync()
                                  ? Image.file(File(selectedThumbnail!.path!), fit: BoxFit.cover)
                                  : FutureBuilder<Uint8List>(
                                      future: selectedThumbnail!.readAsBytes(),
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
                                    selectedThumbnail = null;
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
                  final audioProv = Provider.of<AudioProvider>(context, listen: false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updating audio...')),
                  );

                  final success = await audioProv.updateAudio(
                    token: auth.token!,
                    audioId: audio.id,
                    name: nameController.text.trim(),
                    visibility: visibility,
                    thumbnailFile: selectedThumbnail,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Audio updated successfully!'
                              : (audioProv.errorMessage ?? 'Failed to update audio'),
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

  void _confirmDeleteAudio(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Audio Track', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete "${audio.name}"? This action cannot be undone.',
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
              final audioProv = Provider.of<AudioProvider>(context, listen: false);

              final success = await audioProv.deleteAudio(
                token: auth.token!,
                audioId: audio.id,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Audio deleted successfully!'
                          : (audioProv.errorMessage ?? 'Failed to delete audio'),
                    ),
                  ),
                );
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
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnap) {
        final currentMedia = mediaSnap.data;
        final isSelected = currentMedia != null &&
            ((currentMedia.id.isNotEmpty && currentMedia.id == audio.id) ||
                currentMedia.extras?['url'] == audio.audioUrl);

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, stateSnap) {
            final isPlaying = isSelected && (stateSnap.data?.playing ?? false);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryAccent.withValues(alpha: 0.12)
                    : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryAccent
                      : Colors.white.withValues(alpha: 0.05),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        color: AppTheme.purpleAccent.withValues(alpha: 0.2),
                        child: audio.thumbnailImageUrl.isNotEmpty
                            ? Image.network(
                                audio.thumbnailImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note,
                                  color: AppTheme.primaryAccent,
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: AppTheme.primaryAccent,
                              ),
                      ),
                      if (isSelected)
                        Container(
                          width: 50,
                          height: 50,
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Icon(
                            isPlaying
                                ? Icons.graphic_eq_rounded
                                : Icons.play_arrow_rounded,
                            color: AppTheme.primaryAccent,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        audio.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isSelected ? AppTheme.primaryAccent : Colors.white,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPlaying ? 'PLAYING' : 'PAUSED',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        audio.userName ?? 'Tune World Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white70 : Colors.white60,
                        ),
                      ),
                    ),
                    if (audio.visibility != 'public')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: audio.visibility == 'private'
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          audio.visibility,
                          style: TextStyle(
                            fontSize: 10,
                            color: audio.visibility == 'private'
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isSelected
                            ? (isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded)
                            : Icons.play_arrow_rounded,
                        color: isSelected ? AppTheme.primaryAccent : Colors.white70,
                        size: 28,
                      ),
                      onPressed: () {
                        if (isSelected) {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        } else {
                          audioHandler.playTrack(
                            audio,
                            queueList: playlistQueue,
                            index: index,
                            fetchMoreCallback: onFetchMore != null
                                ? () async {
                                    final success = await onFetchMore!();
                                    if (success) {
                                      audioHandler.appendQueue(playlistQueue);
                                    }
                                    return success;
                                  }
                                : null,
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onPressed: () => _showOptionsMenu(context),
                    ),
                  ],
                ),
                onTap: () {
                  if (isSelected) {
                    if (isPlaying) {
                      audioHandler.pause();
                    } else {
                      audioHandler.play();
                    }
                  } else {
                    audioHandler.playTrack(
                      audio,
                      queueList: playlistQueue,
                      index: index,
                      fetchMoreCallback: onFetchMore != null
                          ? () async {
                              final success = await onFetchMore!();
                              if (success) {
                                audioHandler.appendQueue(playlistQueue);
                              }
                              return success;
                            }
                          : null,
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
