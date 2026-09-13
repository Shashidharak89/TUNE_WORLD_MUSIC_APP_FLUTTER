import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_model.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';

class AudioTileWidget extends StatelessWidget {
  final AudioModel audio;
  final TuneWorldAudioHandler audioHandler;
  final List<AudioModel> playlistQueue;

  const AudioTileWidget({
    super.key,
    required this.audio,
    required this.audioHandler,
    required this.playlistQueue,
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
                              color: AppTheme.purpleAccent.withOpacity(0.3),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 50,
            height: 50,
            color: AppTheme.purpleAccent.withOpacity(0.2),
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
        ),
        title: Text(
          audio.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                audio.userName ?? 'Tune World Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
            ),
            if (audio.visibility != 'public')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: audio.visibility == 'private'
                      ? Colors.red.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
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
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onPressed: () => _showAddToPlaylistDialog(context),
        ),
        onTap: () {
          audioHandler.playTrack(audio, queueList: playlistQueue);
        },
      ),
    );
  }
}
