import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import '../views/player_screen.dart';

class MiniPlayerWidget extends StatelessWidget {
  final TuneWorldAudioHandler audioHandler;

  const MiniPlayerWidget({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.cardBgLight.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryAccent.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(audioHandler: audioHandler),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Artwork Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: AppTheme.purpleAccent.withOpacity(0.3),
                      child: mediaItem.artUri != null
                          ? Image.network(
                              mediaItem.artUri.toString(),
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
                  const SizedBox(width: 12),
                  // Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mediaItem.title,
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
                          mediaItem.artist ?? 'Tune World',
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
                  // Play/Pause Button
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, stateSnap) {
                      final playing = stateSnap.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 36,
                          color: AppTheme.primaryAccent,
                        ),
                        onPressed: () {
                          if (playing) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      );
                    },
                  ),
                  // Skip Next Button
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      audioHandler.skipToNext();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
