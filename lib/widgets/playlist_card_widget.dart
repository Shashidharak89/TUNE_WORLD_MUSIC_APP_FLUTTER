import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import '../views/playlist_details_screen.dart';

class PlaylistCardWidget extends StatelessWidget {
  final PlaylistModel playlist;
  final TuneWorldAudioHandler audioHandler;

  const PlaylistCardWidget({
    super.key,
    required this.playlist,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistDetailsScreen(
                playlistId: playlist.id,
                audioHandler: audioHandler,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  width: double.infinity,
                  color: AppTheme.purpleAccent.withOpacity(0.3),
                  child: playlist.imageUrl.isNotEmpty
                      ? Image.network(
                          playlist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.queue_music,
                            size: 48,
                            color: AppTheme.primaryAccent,
                          ),
                        )
                      : const Icon(
                          Icons.queue_music,
                          size: 48,
                          color: AppTheme.primaryAccent,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By ${playlist.userName ?? "User"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
