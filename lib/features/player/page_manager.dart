import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/dependency_injection.dart';
import '../home/data/datasources/music_local_datasource.dart';
import '../home/data/models/music_model.dart';
import 'notifiers/play_button_notifier.dart';
import 'notifiers/progress_notifier.dart';
import 'notifiers/repeat_button_notifier.dart';

class PageManager {
  final currentSongNotifier =
      ValueNotifier<MediaItem>(MediaItem(id: '-', title: '-'));
  final playlistNotifier = ValueNotifier<List<MediaItem>>([]);
  final progressNotifier = ProgressNotifier();
  final repeatButtonNotifier = RepeatButtonNotifier();
  final isFirstSongNotifier = ValueNotifier<bool>(true);
  final playButtonNotifier = PlayButtonNotifier();
  final isLastSongNotifier = ValueNotifier<bool>(true);
  final isShuffleModeEnabledNotifier = ValueNotifier<bool>(false);

  final _audioHandler = di<AudioHandler>();
  final _prefs = di<SharedPreferences>();

  Future<void> init() async {
    await _loadPlaylist();
    _listenToChangesInPlaylist();
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    await Future.delayed(Duration(milliseconds: 500));
    await loadLastAudio();
  }

  Future<void> _loadPlaylist() async {
    await di.isReady<MusicLocalDatasource>();

    MusicLocalDatasource database = di();
    final List<Music> playlist = await database.getPlaylist();

    final List<Map<String, String>> playlistAsMapList =
        playlist.map((music) => music.toMap()).toList();

    final mediaItems = playlistAsMapList
        .map((song) {
          final durationSeconds = int.tryParse(song['duration'] ?? '0') ?? 0;
          return MediaItem(
            id: song['id'] ?? '',
            title: song['title'] ?? '',
            duration: durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
            extras: {
              'artist': song['artist'],
              'audioUrl': song['audioUrl'],
              'coverUrl': song['coverUrl'],
              'isDownloaded': song['isDownloaded'],
            },
          );
        })
        .toList();
    await _audioHandler.customAction('clearPlaylist');
    await _audioHandler.addQueueItems(mediaItems);
  }

  void _listenToChangesInPlaylist() {
    _audioHandler.queue.listen((playlist) {
      if (playlist.isEmpty) {
        playlistNotifier.value = [];
        currentSongNotifier.value = MediaItem(id: '', title: '');
      } else {
        playlistNotifier.value = playlist;
      }
      _updateSkipButtons();
    });
  }

  void _listenToPlaybackState() {
    _audioHandler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      final processingState = playbackState.processingState;
      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        playButtonNotifier.value = ButtonState.loading;
      } else if (!isPlaying) {
        playButtonNotifier.value = ButtonState.paused;
      } else if (processingState != AudioProcessingState.completed) {
        playButtonNotifier.value = ButtonState.playing;
      } else {
        _audioHandler.seek(Duration.zero);
        _audioHandler.pause();
      }
    });
  }

  void _listenToCurrentPosition() async {
    _audioHandler.playbackState.listen((playbackState) async {
      final position = playbackState.updatePosition;
      final buffered = playbackState.bufferedPosition;

      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: position,
        buffered: buffered,
        total: oldState.total,
      );

      final currentIndex = await _audioHandler.customAction('currentIndex');
      final currentAudioId = currentSongNotifier.value.id;
      final positionString = position.toString();

      final existingIndex = _prefs.getInt('currentIndex');
      final existingPositionString = _prefs.getString('positionString');

      if (existingIndex == null || existingPositionString == null) {
        _prefs.setString('currentAudioId', currentAudioId);
        _prefs.setString('positionString', Duration.zero.toString());
        _prefs.setInt('currentIndex', 0);
      } else {
        if (currentIndex != 0 || position.inMilliseconds != 0) {
          _prefs.setString('currentAudioId', currentAudioId);
          _prefs.setString('positionString', positionString);
          _prefs.setInt('currentIndex', currentIndex);
        }
      }
    });
  }

  void _listenToBufferedPosition() {}

  void _listenToTotalDuration() {
    _audioHandler.mediaItem.listen((mediaItem) {
      final oldState = progressNotifier.value;
      final newDuration = mediaItem?.duration ?? Duration.zero;

      if (newDuration.inMilliseconds > 0 || oldState.total.inMilliseconds == 0) {
        progressNotifier.value = ProgressBarState(
          current: Duration.zero,
          buffered: Duration.zero,
          total: newDuration,
        );
      }
    });
  }

  void _listenToChangesInSong() {
    _audioHandler.mediaItem.listen((mediaItem) {
      currentSongNotifier.value = mediaItem ?? MediaItem(id: '-', title: '-');
      _updateSkipButtons();
    });
  }

  void _updateSkipButtons() async {

    final mediaItem = _audioHandler.mediaItem.value;
    final playlist = _audioHandler.queue.value;
    if (playlist.length < 2 || mediaItem == null) {
      isFirstSongNotifier.value = true;
      isLastSongNotifier.value = true;
    } else {
      isFirstSongNotifier.value = playlist.first == mediaItem;
      isLastSongNotifier.value = playlist.last == mediaItem;
    }
  }

  void play() => _audioHandler.play();

  void pause() => _audioHandler.pause();

  void seek(Duration position) => _audioHandler.seek(position);

  void previous() => _audioHandler.skipToPrevious();

  void next() => _audioHandler.skipToNext();

  void repeat() {
    repeatButtonNotifier.nextState();
    final repeatMode = repeatButtonNotifier.value;
    switch (repeatMode) {
      case RepeatState.off:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
      case RepeatState.repeatSong:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatState.repeatPlaylist:
        _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
    }
  }

  void shuffle() {
    final enable = !isShuffleModeEnabledNotifier.value;
    isShuffleModeEnabledNotifier.value = enable;
    if (enable) {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    } else {
      _audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    }
  }

  Future<void> add(Map<String, String> audioMap) async {
    final durationSeconds = int.tryParse(audioMap['duration'] ?? '0') ?? 0;
    final mediaItem = MediaItem(
      id: audioMap['id'] ?? '',
      title: audioMap['title'] ?? '',
      duration: durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
      extras: {
        'artist': audioMap['artist'],
        'audioUrl': audioMap['audioUrl'],
        'coverUrl': audioMap['coverUrl'],
        'isDownloaded': audioMap['isDownloaded'],
      },
    );
    _audioHandler.addQueueItem(mediaItem);
  }

  void remove(Map<String, String> audioMap) async {
    final durationSeconds = int.tryParse(audioMap['duration'] ?? '0') ?? 0;
    final mediaItem = MediaItem(
      id: audioMap['id'] ?? '',
      title: audioMap['title'] ?? '',
      duration: durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
      extras: {
        'artist': audioMap['artist'],
        'audioUrl': audioMap['audioUrl'],
        'coverUrl': audioMap['coverUrl'],
        'isDownloaded': audioMap['isDownloaded'],
      },
    );
    try {
      _audioHandler.removeQueueItem(mediaItem);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> update(Map<String, String> audioMap) async {
    final id = audioMap['id'] ?? '';
    final currentQueue = _audioHandler.queue.value;
    final existingIndex = currentQueue.indexWhere((item) => item.id == id);
    MediaItem? existingItem;
    if (existingIndex != -1) {
      existingItem = currentQueue[existingIndex];
    }

    Duration? duration;
    if (existingItem?.duration != null && existingItem!.duration! > Duration.zero) {
      duration = existingItem.duration;
    } else {
      final durationSeconds = int.tryParse(audioMap['duration'] ?? '0') ?? 0;
      if (durationSeconds > 0) {
        duration = Duration(seconds: durationSeconds);
      }
    }

    final mediaItem = MediaItem(
      id: id,
      title: audioMap['title'] ?? existingItem?.title ?? '',
      duration: duration,
      extras: {
        'artist': audioMap['artist'] ?? existingItem?.extras?['artist'],
        'audioUrl': audioMap['audioUrl'] ?? existingItem?.extras?['audioUrl'],
        'coverUrl': audioMap['coverUrl'] ?? existingItem?.extras?['coverUrl'],
        'isDownloaded': audioMap['isDownloaded'] ?? existingItem?.extras?['isDownloaded'],
      },
    );

    await _audioHandler.customAction('updateQueueItem', {
      'id': id,
      'mediaItem': mediaItem,
    });
  }

  void reorderPlaylist(int currentIndex, int newIndex) {
    _audioHandler.customAction(
        'reorder', {'currentIndex': currentIndex, 'newIndex': newIndex});
  }

  void dispose() {
    _audioHandler.customAction('dispose');
  }

  void stop() {
    _audioHandler.stop();
  }

  Future<dynamic> loadLastAudio() async {

    Duration? duration = await _audioHandler.customAction('loadLastAudio');

    if (duration != null) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: duration,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    }
  }

  void skipToQueueItem(int index) {
    _audioHandler.skipToQueueItem(index);
  }
}
