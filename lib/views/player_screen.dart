import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatelessWidget {
  final TuneWorldAudioHandler audioHandler;

  const PlayerScreen({super.key, required this.audioHandler});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnap) {
          final mediaItem = mediaSnap.data;

          if (mediaItem == null) {
            return const Center(
              child: Text(
                'No audio selected',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Artwork Card / Vinyl Art
                Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.width * 0.75,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.purpleAccent.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: mediaItem.artUri != null
                        ? Image.network(
                            mediaItem.artUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.cardBg,
                              child: const Icon(
                                Icons.music_note,
                                size: 100,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          )
                        : Container(
                            color: AppTheme.cardBg,
                            child: const Icon(
                              Icons.music_note,
                              size: 100,
                              color: AppTheme.primaryAccent,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Title & Artist
                Column(
                  children: [
                    Text(
                      mediaItem.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mediaItem.artist ?? 'Tune World Artist',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),

                // Progress Bar & Duration Timers
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnap) {
                    final position = stateSnap.data?.position ?? Duration.zero;
                    final totalDuration = mediaItem.duration ?? Duration.zero;

                    double maxVal = totalDuration.inMilliseconds.toDouble();
                    double currentVal = position.inMilliseconds.toDouble();

                    if (currentVal > maxVal) currentVal = maxVal;
                    if (maxVal <= 0) maxVal = 1.0;

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryAccent,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: AppTheme.primaryAccent,
                            overlayColor: AppTheme.primaryAccent.withOpacity(0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentVal.clamp(0.0, maxVal),
                            min: 0.0,
                            max: maxVal,
                            onChanged: (val) {
                              audioHandler.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              Text(
                                _formatDuration(totalDuration),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Playback Control Buttons
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnap) {
                    final playing = stateSnap.data?.playing ?? false;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous_rounded,
                              color: Colors.white),
                          onPressed: () => audioHandler.skipToPrevious(),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: IconButton(
                            iconSize: 48,
                            icon: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              if (playing) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next_rounded,
                              color: Colors.white),
                          onPressed: () => audioHandler.skipToNext(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
