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
      androidShowNotificationBadge: true,
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
    // Listen to playback state changes from just_audio and update AudioService playbackState
    _player.playbackEventStream.listen((PlaybackEvent event) {
      _broadcastState();
    });

    _player.playerStateStream.listen((state) {
      _broadcastState();
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

  void _broadcastState() {
    final playing = _player.playing;
    final state = _player.processingState;

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
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[state]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  void appendQueue(List<AudioModel> newAudios) {
    _playlist.addAll(newAudios);
    _updateQueueItems();
  }

  void _updateQueueItems() {
    final items = _playlist.map((audio) => MediaItem(
      id: audio.id.isNotEmpty ? audio.id : audio.audioUrl,
      title: audio.name,
      artist: audio.userName ?? 'Tune World Artist',
      album: 'Tune World',
      artUri: audio.thumbnailImageUrl.isNotEmpty
          ? Uri.tryParse(audio.thumbnailImageUrl)
          : null,
      extras: {'url': audio.audioUrl},
    )).toList();

    queue.add(items);
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

    _updateQueueItems();

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
      if (currentAudio.audioUrl.startsWith('http://') || currentAudio.audioUrl.startsWith('https://')) {
        await _player.setUrl(currentAudio.audioUrl);
      } else {
        await _player.setFilePath(currentAudio.audioUrl);
      }
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
  Future<void> fastForward() async {
    final newPos = _player.position + const Duration(seconds: 10);
    await _player.seek(newPos);
  }

  @override
  Future<void> rewind() async {
    final newPos = _player.position - const Duration(seconds: 10);
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
    } else {
      if (onFetchMore != null) {
        final hasMore = await onFetchMore!();
        if (hasMore && _currentIndex < _playlist.length - 1) {
          _currentIndex++;
          await playTrack(_playlist[_currentIndex], queueList: _playlist, index: _currentIndex);
          return;
        }
      }
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
