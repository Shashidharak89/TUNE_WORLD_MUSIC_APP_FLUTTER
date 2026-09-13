import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../models/audio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';

class AudioTileWidget extends StatelessWidget {
  final AudioModel audio;
  final TuneWorldAudioHandler audioHandler;
  final List<AudioModel> playlistQueue;
  final int? index;
  final Future<bool> Function()? onFetchMore;

  const AudioTileWidget({
    super.key,
    required this.audio,
    required this.audioHandler,
    required this.playlistQueue,
    this.index,
    this.onFetchMore,
  });

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

    // Fetch user's playlists
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? AppTheme.primaryAccent
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                        color: isSelected
                            ? AppTheme.primaryAccent
                            : Colors.white70,
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
                      onPressed: () => _showAddToPlaylistDialog(context),
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
