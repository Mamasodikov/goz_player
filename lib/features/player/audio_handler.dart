import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';


Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'uz.flutterdev.gozplayer',
      androidNotificationChannelName: 'Goz Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _prefs = di<SharedPreferences>();
  final _networkInfo = di<NetworkInfo>();
  final _playlist = ConcatenatingAudioSource(children: []);
  bool _isUpdatingQueue = false;

  MyAudioHandler() {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPositionChanges();
    _listenForDurationChanges();
    _listenForCurrentSongIndexChanges();
    _listenForSequenceStateChanges();
    _listenForErrors();
  }

  void _listenForErrors() {
    _player.playbackEventStream.listen(
          (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Playback error: $e');
      },
    );
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      debugPrint("Error loading playlist: $e");
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
        shuffleMode: (_player.shuffleModeEnabled)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  void _listenToPositionChanges() {
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      var index = _player.currentIndex;
      final newQueue = queue.value;

      if (index == null || newQueue.isEmpty) return;

      if (_player.shuffleModeEnabled) {
        index = _player.shuffleIndices!.indexOf(index);
      }

      final oldMediaItem = newQueue[index];

      if (duration != null && duration.inMilliseconds > 0) {
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[index] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
      }
    });
  }

  void _listenForCurrentSongIndexChanges() {
    _player.currentIndexStream.listen((index) {
      if (_isUpdatingQueue) return;

      final playlist = queue.value;
      if (playlist.isEmpty) {
        mediaItem.add(MediaItem(id: '-', title: '-'));
        return;
      }
      if (index == null) return;
      if (_player.shuffleModeEnabled) {
        index = _player.shuffleIndices!.indexOf(index);
      }
      mediaItem.add(playlist[index]);
    });
  }

  void _listenForSequenceStateChanges() {
    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      if (_isUpdatingQueue) return;

      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
      final items = sequence.map((source) => source.tag as MediaItem);
      queue.add(items.toList());
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    // add all items to just_audio in one go
    final audioSources = mediaItems.map(_createAudioSource).toList();
    await _playlist.addAll(audioSources);

    // update the queue
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);

    // try to get durations ahead of time
    _preloadDurations(mediaItems);
  }

  Future<void> _preloadDurations(List<MediaItem> mediaItems) async {
    for (int i = 0; i < mediaItems.length; i++) {
      try {
        final mediaItem = mediaItems[i];
        final audioUrl = mediaItem.extras!['audioUrl'] as String;

        if (audioUrl.isEmpty) continue;

        // spin up a temp player just to read the duration
        final tempPlayer = AudioPlayer();
        final audioSource = _createAudioSource(mediaItem);

        await tempPlayer.setAudioSource(audioSource);
        final duration = tempPlayer.duration;

        if (duration != null && duration.inMilliseconds > 0) {
          final updatedItem = mediaItem.copyWith(duration: duration);
          final currentQueue = queue.value;
          if (i < currentQueue.length) {
            currentQueue[i] = updatedItem;
            queue.add([...currentQueue]);
          }
        }

        await tempPlayer.dispose();
      } catch (e) {
        debugPrint('Failed to preload duration: $e');
      }
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final audioSource = _createAudioSource(mediaItem);
    _playlist.add(audioSource);

    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  UriAudioSource _createAudioSource(MediaItem mediaItem) {
    final audioUrl = mediaItem.extras!['audioUrl'] as String;
    final isDownloaded = mediaItem.extras?['isDownloaded'] == 'true';

    if (isWebUrl(audioUrl)) {
      return AudioSource.uri(
        Uri.parse(audioUrl),
        tag: mediaItem,
      );
    } else if (audioUrl.startsWith('assets/')) {
      if (!isDownloaded) {
        debugPrint('Warning: using asset source for non-downloaded track');
      }
      return AudioSource.asset(
        audioUrl,
        tag: mediaItem,
      );
    } else {
      // local file path
      final file = File(audioUrl);
      if (!file.existsSync()) {
        debugPrint('File not found: $audioUrl');
      }
      return AudioSource.uri(
        Uri.file(audioUrl),
        tag: mediaItem,
      );
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    _playlist.removeAt(index);

    final newQueue = queue.value..removeAt(index);
    queue.add(newQueue);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);

    if (index != -1) {
      final isCurrentlyPlaying = _player.currentIndex == index;
      final wasPlaying = _player.playing;

      if (isCurrentlyPlaying) {
        await _player.pause();
        await Future.delayed(Duration(milliseconds: 100));
      }

      _playlist.removeAt(index);

      final newQueue = List<MediaItem>.from(queue.value)..removeAt(index);
      queue.add(newQueue);

      if (newQueue.isEmpty) {
        this.mediaItem.add(MediaItem(id: '-', title: '-'));
        await _player.stop();
        return;
      }

      // if we just removed the current track, find the next one to play
      if (isCurrentlyPlaying && wasPlaying) {
        final hasInternet = await _networkInfo.isConnected;
        int nextPlayableIndex = -1;

        if (!hasInternet) {
          // look forward first
          for (int i = index; i < newQueue.length; i++) {
            final isDownloaded = newQueue[i].extras?['isDownloaded'] == 'true';
            if (isDownloaded) {
              nextPlayableIndex = i;
              break;
            }
          }

          // wrap around if nothing found
          if (nextPlayableIndex == -1) {
            for (int i = 0; i < index; i++) {
              final isDownloaded = newQueue[i].extras?['isDownloaded'] == 'true';
              if (isDownloaded) {
                nextPlayableIndex = i;
                break;
              }
            }
          }
        } else {
          if (index < newQueue.length) {
            nextPlayableIndex = index;
          } else if (newQueue.isNotEmpty) {
            nextPlayableIndex = 0;
          }
        }

        if (nextPlayableIndex != -1) {
          await Future.delayed(Duration(milliseconds: 200));
          await _player.seek(Duration.zero, index: nextPlayableIndex);
          await _player.play();
        } else {
          this.mediaItem.add(MediaItem(id: '-', title: '-'));
          await _player.stop();
        }
      }
    }
  }

  @override
  Future<void> play() async {
    final currentIndex = _player.currentIndex;
    if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.value.length) {
      final currentSong = queue.value[currentIndex];
      final isDownloaded = currentSong.extras?['isDownloaded'] == 'true';
      final hasInternet = await _networkInfo.isConnected;

      // don't try to play if we're offline and song isn't downloaded
      if (!hasInternet && !isDownloaded) {
        debugPrint('Cannot play - offline and track not downloaded');
        return;
      }
    }

    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    // make sure UI updates immediately, especially when paused
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;

    final targetSong = queue.value[index];
    final isDownloaded = targetSong.extras?['isDownloaded'] == 'true';
    final hasInternet = await _networkInfo.isConnected;

    if (!hasInternet && !isDownloaded) {
      debugPrint('Cannot skip - offline and track not downloaded');
      return;
    }

    if (_player.shuffleModeEnabled) {
      index = _player.shuffleIndices![index];
    }
    _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipToNext() async {
    final currentIndex = _player.currentIndex ?? 0;
    final hasInternet = await _networkInfo.isConnected;
    final queueList = queue.value;

    if (queueList.isEmpty) return;

    if (!hasInternet) {
      int nextPlayableIndex = -1;

      // search forward
      for (int i = currentIndex + 1; i < queueList.length; i++) {
        final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
        if (isDownloaded) {
          nextPlayableIndex = i;
          break;
        }
      }

      // wrap to beginning
      if (nextPlayableIndex == -1) {
        for (int i = 0; i < currentIndex; i++) {
          final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
          if (isDownloaded) {
            nextPlayableIndex = i;
            break;
          }
        }
      }

      if (nextPlayableIndex != -1) {
        await _player.seek(Duration.zero, index: nextPlayableIndex);
      }
      return;
    }

    return _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    final currentIndex = _player.currentIndex ?? 0;
    final hasInternet = await _networkInfo.isConnected;
    final queueList = queue.value;

    if (queueList.isEmpty) return;

    if (!hasInternet) {
      int prevPlayableIndex = -1;

      // search backward
      for (int i = currentIndex - 1; i >= 0; i--) {
        final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
        if (isDownloaded) {
          prevPlayableIndex = i;
          break;
        }
      }

      // wrap to end
      if (prevPlayableIndex == -1) {
        for (int i = queueList.length - 1; i > currentIndex; i--) {
          final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
          if (isDownloaded) {
            prevPlayableIndex = i;
            break;
          }
        }
      }

      if (prevPlayableIndex != -1) {
        await _player.seek(Duration.zero, index: prevPlayableIndex);
      }
      return;
    }

    return _player.seekToPrevious();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _player.setShuffleModeEnabled(false);
    } else {
      await _player.shuffle();
      _player.setShuffleModeEnabled(true);
    }
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await _player.dispose();
      super.stop();
    } else if (name == 'currentIndex') {
      return _player.currentIndex ?? 0;
    } else if (name == 'updateQueueItem') {
      final String songId = extras?['id'] ?? '';
      final MediaItem updatedItem = extras?['mediaItem'];

      final currentQueue = queue.value;
      final index = currentQueue.indexWhere((item) => item.id == songId);

      if (index != -1) {
        final isCurrentlyPlaying = _player.currentIndex == index;
        final wasPlaying = _player.playing;
        final currentPosition = _player.position;

        final newQueue = List<MediaItem>.from(currentQueue);
        newQueue[index] = updatedItem;

        if (isCurrentlyPlaying) {
          // need to rebuild the whole playlist since we can't just swap the source
          _isUpdatingQueue = true;

          await _player.stop();
          await _playlist.clear();

          final audioSources = newQueue.map(_createAudioSource).toList();
          await _playlist.addAll(audioSources);

          queue.add([...newQueue]);

          await _player.seek(Duration.zero, index: index);

          // wait for player to be ready
          int waitCount = 0;
          while (_player.processingState == ProcessingState.loading && waitCount < 50) {
            await Future.delayed(Duration(milliseconds: 50));
            waitCount++;
          }

          if (currentPosition.inMilliseconds > 0) {
            await _player.seek(currentPosition);
          }

          mediaItem.add(updatedItem);
          _isUpdatingQueue = false;

          if (wasPlaying) {
            await _player.play();
          }
        } else {
          // not playing, just swap it out
          final newAudioSource = _createAudioSource(updatedItem);
          await _playlist.removeAt(index);
          await _playlist.insert(index, newAudioSource);
          queue.add([...newQueue]);
        }
      }
    } else if (name == 'reorder') {
      await _playlist.move(extras?['currentIndex'], extras?['newIndex']);

      // workaround to reset position after reorder
      if (_player.playing) {
        await _player.stop();
        await _player.play();
      } else {
        await _player.stop();
        return super.stop();
      }
    } else if (name == 'clearPlaylist') {
      await _playlist.clear();
      return queue.value.clear();
    } else if (name == 'loadLastAudio') {
      // restore last playback position from prefs
      var currentAudioId = _prefs.getString('currentAudioId');
      var positionString = _prefs.getString('positionString');

      if (currentAudioId != null && positionString != null) {
        var list = queue.value;
        final index = list.indexWhere((item) => item.id == currentAudioId);

        if (index != -1) {
          Duration duration = Duration(
            hours: int.parse(positionString.split(":")[0]),
            minutes: int.parse(positionString.split(":")[1]),
            seconds: int.parse(positionString.split(":")[2].split(".")[0]),
            milliseconds: int.parse(
                positionString.split(":")[2].split(".")[1].substring(0, 3)),
          );

          await skipToQueueItem(index);
          await seek(duration);

          return duration;
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    return super.onTaskRemoved();
  }
}