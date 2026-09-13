import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_model.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => TuneWorldAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tuneworld.app.channel.audio',
      androidNotificationChannelName: 'Tune World Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class TuneWorldAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<AudioModel> _playlist = [];
  int _currentIndex = -1;

  // Callback to auto-fetch next page when end of current queue is reached
  Future<bool> Function()? onFetchMore;

  AudioPlayer get player => _player;
  List<AudioModel> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  TuneWorldAudioHandler() {
    _initStreams();
  }

  void _initStreams() {
    // Listen to playback state changes from just_audio and map to AudioService state
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    // Handle auto track progression when song completes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Listen to duration updates
    _player.durationStream.listen((duration) {
      if (mediaItem.value != null && duration != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  void appendQueue(List<AudioModel> newAudios) {
    _playlist.addAll(newAudios);
  }

  Future<void> playTrack(AudioModel audio, {
    List<AudioModel>? queueList,
    int? index,
    Future<bool> Function()? fetchMoreCallback,
  }) async {
    if (fetchMoreCallback != null) {
      onFetchMore = fetchMoreCallback;
    }

    if (queueList != null && queueList.isNotEmpty) {
      _playlist = List.from(queueList);
      _currentIndex = index ??
          _playlist.indexWhere((item) =>
              (item.id.isNotEmpty && item.id == audio.id) ||
              (item.audioUrl.isNotEmpty && item.audioUrl == audio.audioUrl));
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      _playlist = [audio];
      _currentIndex = 0;
    }

    final currentAudio = _playlist[_currentIndex];
    
    // Create MediaItem for system notification controls
    final item = MediaItem(
      id: currentAudio.id.isNotEmpty ? currentAudio.id : currentAudio.audioUrl,
      title: currentAudio.name,
      artist: currentAudio.userName ?? 'Tune World Artist',
      album: 'Tune World',
      artUri: currentAudio.thumbnailImageUrl.isNotEmpty
          ? Uri.tryParse(currentAudio.thumbnailImageUrl)
          : null,
      extras: {'url': currentAudio.audioUrl},
    );

    mediaItem.add(item);
    
    try {
      await _player.stop();
      await _player.setUrl(currentAudio.audioUrl);
      await _player.play();
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
    } else {
      // Reached the end of current local queue - check if more tracks can be fetched automatically
      if (onFetchMore != null) {
        final hasMore = await onFetchMore!();
        if (hasMore && _currentIndex < _playlist.length - 1) {
          _currentIndex++;
          await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
          return;
        }
      }
      // Fallback: Loop back to start if no more pages
      if (_playlist.isNotEmpty) {
        _currentIndex = 0;
        await playTrack(_playlist[0], queueList: _playlist, index: 0);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
    } else if (_playlist.isNotEmpty) {
      _currentIndex = _playlist.length - 1;
      await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
    }
  }
}
