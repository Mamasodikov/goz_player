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
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && state.playing == false) {
        debugPrint('Player state: IDLE');
      }
    });

    _player.playbackEventStream.listen(
          (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Playback error: $e');
        debugPrint('Stack trace: $st');
      },
    );
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      debugPrint("Error: $e");
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
      debugPrint('=== Position Stream Update ===');
      debugPrint('Position: $position');
      debugPrint('Playing: ${_player.playing}');
      debugPrint('Duration: ${_player.duration}');
      debugPrint('Current Index: ${_player.currentIndex}');
      debugPrint('Processing State: ${_player.processingState}');
      debugPrint('Buffered Position: ${_player.bufferedPosition}');

      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      debugPrint('=== Duration Stream Update ===');
      debugPrint('Duration: $duration');
      debugPrint('Current Index: ${_player.currentIndex}');

      var index = _player.currentIndex;
      final newQueue = queue.value;
      debugPrint('Queue size: ${newQueue.length}');

      if (index == null || newQueue.isEmpty) {
        debugPrint('Skipping duration update - index is null or queue is empty');
        return;
      }

      if (_player.shuffleModeEnabled) {
        index = _player.shuffleIndices!.indexOf(index);
      }

      final oldMediaItem = newQueue[index];

      if (duration != null && duration.inMilliseconds > 0) {
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        newQueue[index] = newMediaItem;
        queue.add(newQueue);
        mediaItem.add(newMediaItem);
        debugPrint('Duration updated for ${oldMediaItem.title}: $duration');
      } else {
        debugPrint('Skipping duration update - duration is null or zero');
      }
    });
  }

  void _listenForCurrentSongIndexChanges() {
    _player.currentIndexStream.listen((index) {
      if (_isUpdatingQueue) {
        debugPrint('Skipping index change event during queue update');
        return;
      }

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
      if (_isUpdatingQueue) {
        debugPrint('Skipping sequence state change event during queue update');
        return;
      }

      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
      final items = sequence.map((source) => source.tag as MediaItem);
      queue.add(items.toList());
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    debugPrint('Adding ${mediaItems.length} items to queue');

    // manage Just Audio - add items all at once
    final audioSources = mediaItems.map(_createAudioSource).toList();
    await _playlist.addAll(audioSources);
    debugPrint('Added ${audioSources.length} audio sources to playlist');

    // notify system
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
    debugPrint('Queue updated with ${mediaItems.length} items');

    // Pre-load durations for all songs
    _preloadDurations(mediaItems);
  }

  Future<void> _preloadDurations(List<MediaItem> mediaItems) async {
    debugPrint('Pre-loading durations for ${mediaItems.length} songs...');
    for (int i = 0; i < mediaItems.length; i++) {
      try {
        final mediaItem = mediaItems[i];
        final audioUrl = mediaItem.extras!['audioUrl'] as String;

        if (audioUrl.isEmpty) continue;

        debugPrint('Pre-loading duration for: ${mediaItem.title}');

        // Create a temporary player to read duration
        final tempPlayer = AudioPlayer();
        final audioSource = _createAudioSource(mediaItem);

        await tempPlayer.setAudioSource(audioSource);
        final duration = tempPlayer.duration;

        debugPrint('Pre-loaded duration for ${mediaItem.title}: $duration');

        if (duration != null && duration.inMilliseconds > 0) {
          // Update the mediaItem with the duration
          final updatedItem = mediaItem.copyWith(duration: duration);
          final currentQueue = queue.value;
          if (i < currentQueue.length) {
            currentQueue[i] = updatedItem;
            queue.add([...currentQueue]);
          }
        }

        await tempPlayer.dispose();
      } catch (e) {
        debugPrint('Error pre-loading duration: $e');
      }
    }
    debugPrint('Duration pre-loading complete');
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // manage Just Audio
    final audioSource = _createAudioSource(mediaItem);
    _playlist.add(audioSource);

    // notify system
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  UriAudioSource _createAudioSource(MediaItem mediaItem) {
    final audioUrl = mediaItem.extras!['audioUrl'] as String;
    final isDownloaded = mediaItem.extras?['isDownloaded'] == 'true';

    debugPrint('=== Creating audio source ===');
    debugPrint('Title: ${mediaItem.title}');
    debugPrint('Audio URL: $audioUrl');
    debugPrint('Is web URL: ${isWebUrl(audioUrl)}');
    debugPrint('Is downloaded: ${mediaItem.extras?['isDownloaded']}');
    debugPrint('MediaItem duration: ${mediaItem.duration}');

    if (isWebUrl(audioUrl)) {
      debugPrint('✓ Using AudioSource.uri (web)');
      return AudioSource.uri(
        Uri.parse(audioUrl),
        tag: mediaItem,
      );
    } else if (audioUrl.startsWith('assets/')) {
      if (!isDownloaded) {
        debugPrint('⚠️ Asset source detected for non-downloaded song - this should only be used when online');
      }
      debugPrint('✓ Using AudioSource.asset');
      return AudioSource.asset(
        audioUrl,
        tag: mediaItem,
      );
    } else {
      debugPrint('✓ Using AudioSource.uri (local file)');
      final file = File(audioUrl);
      debugPrint('File exists: ${file.existsSync()}');
      if (!file.existsSync()) {
        debugPrint('❌ ERROR: File does not exist at path: $audioUrl');
      }

      final fileUri = Uri.file(audioUrl);
      debugPrint('File URI: $fileUri');

      return AudioSource.uri(
        fileUri,
        tag: mediaItem,
      );
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // manage Just Audio
    _playlist.removeAt(index);

    // notify system
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

      if (isCurrentlyPlaying && wasPlaying) {
        final hasInternet = await _networkInfo.isConnected;
        int nextPlayableIndex = -1;

        if (!hasInternet) {
          for (int i = index; i < newQueue.length; i++) {
            final isDownloaded = newQueue[i].extras?['isDownloaded'] == 'true';
            if (isDownloaded) {
              nextPlayableIndex = i;
              break;
            }
          }

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
          debugPrint('No playable songs available');
        }
      }
    }
  }

  @override
  Future<void> play() async {
    debugPrint('=== PLAY called ===');
    debugPrint('Current index: ${_player.currentIndex}');
    debugPrint('Current position: ${_player.position}');
    debugPrint('Duration: ${_player.duration}');
    debugPrint('Processing state: ${_player.processingState}');

    final currentIndex = _player.currentIndex;
    if (currentIndex != null && currentIndex >= 0 && currentIndex < queue.value.length) {
      final currentSong = queue.value[currentIndex];
      final isDownloaded = currentSong.extras?['isDownloaded'] == 'true';
      final hasInternet = await _networkInfo.isConnected;

      if (!hasInternet && !isDownloaded) {
        debugPrint('❌ Cannot play non-downloaded song while offline: ${currentSong.title}');
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
    // Immediately update playback state with new position
    // This is important when paused, as position stream may not emit immediately
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
      debugPrint('Cannot play non-downloaded song while offline: ${targetSong.title}');
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

      for (int i = currentIndex + 1; i < queueList.length; i++) {
        final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
        if (isDownloaded) {
          nextPlayableIndex = i;
          break;
        }
      }

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
        debugPrint('Skipped to next downloaded song at index: $nextPlayableIndex');
      } else {
        debugPrint('No downloaded songs available to skip to');
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

      for (int i = currentIndex - 1; i >= 0; i--) {
        final isDownloaded = queueList[i].extras?['isDownloaded'] == 'true';
        if (isDownloaded) {
          prevPlayableIndex = i;
          break;
        }
      }

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
        debugPrint('Skipped to previous downloaded song at index: $prevPlayableIndex');
      } else {
        debugPrint('No downloaded songs available to skip to');
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

      debugPrint('=== UPDATE QUEUE ITEM ===');
      debugPrint('Song ID: $songId');
      debugPrint('Title: ${updatedItem.title}');
      debugPrint('New audioUrl: ${updatedItem.extras?['audioUrl']}');
      debugPrint('New isDownloaded: ${updatedItem.extras?['isDownloaded']}');

      final currentQueue = queue.value;
      final index = currentQueue.indexWhere((item) => item.id == songId);

      if (index != -1) {
        final isCurrentlyPlaying = _player.currentIndex == index;
        final wasPlaying = _player.playing;
        final currentPosition = _player.position;

        debugPrint('Index in queue: $index');
        debugPrint('Is currently playing: $isCurrentlyPlaying');
        debugPrint('Was playing: $wasPlaying');
        debugPrint('Current position: $currentPosition');

        final newQueue = List<MediaItem>.from(currentQueue);
        newQueue[index] = updatedItem;

        if (isCurrentlyPlaying) {
          debugPrint('Song is currently playing - performing full playlist rebuild...');

          _isUpdatingQueue = true;

          await _player.stop();
          debugPrint('Player stopped');

          await _playlist.clear();
          debugPrint('Playlist cleared');

          debugPrint('Creating new audio sources for entire playlist...');
          final audioSources = newQueue.map(_createAudioSource).toList();
          await _playlist.addAll(audioSources);
          debugPrint('New audio sources added to playlist');

          queue.add([...newQueue]);
          debugPrint('Queue updated');

          debugPrint('Seeking to index $index...');
          await _player.seek(Duration.zero, index: index);
          debugPrint('Index seek completed, current index: ${_player.currentIndex}');

          debugPrint('Waiting for player to load audio source...');
          int waitCount = 0;
          while (_player.processingState == ProcessingState.loading && waitCount < 50) {
            await Future.delayed(Duration(milliseconds: 50));
            waitCount++;
            debugPrint('Waiting for ready state... attempt $waitCount, state: ${_player.processingState}');
          }
          debugPrint('Player processing state: ${_player.processingState}');

          if (currentPosition.inMilliseconds > 0) {
            debugPrint('Seeking to position $currentPosition...');
            await _player.seek(currentPosition);
            debugPrint('Position seek completed');
          }

          mediaItem.add(updatedItem);
          debugPrint('MediaItem updated');

          _isUpdatingQueue = false;

          if (wasPlaying) {
            debugPrint('Resuming playback...');
            await _player.play();
            debugPrint('Playback resumed');
          }

          debugPrint('✓ Full rebuild complete');
        } else {
          debugPrint('Song is not currently playing - updating audio source in place');

          debugPrint('Creating new audio source...');
          final newAudioSource = _createAudioSource(updatedItem);

          debugPrint('Replacing audio source at index $index...');
          await _playlist.removeAt(index);
          await _playlist.insert(index, newAudioSource);

          queue.add([...newQueue]);

          debugPrint('✓ Audio source update complete');
        }

        debugPrint('✓ Update complete');
      } else {
        debugPrint('❌ Song not found in queue');
      }
    } else if (name == 'reorder') {
      await _playlist.move(extras?['currentIndex'], extras?['newIndex']);

      ///Workaround for resetting playback position
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
      // await _player.stop();
      // return super.stop();
    } else if (name == 'loadLastAudio') {

      ///Read prefs for the current saved audio data
      var currentAudioId = _prefs.getString('currentAudioId');
      var positionString = _prefs.getString('positionString');

      if (currentAudioId != null && positionString != null) {
        // Get the current list of media items in the queue
        var list = queue.value;

        // Find the index of the media item to be removed
        final index = list.indexWhere((item) => item.id == currentAudioId);

        debugPrint("================= positionString: $positionString");
        if (index != -1) {
          debugPrint("=== loadLastAudio: setting last position");

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

        } else {
          debugPrint("=== loadLastAudio: couldn't find data or ID");
        }
      } else {
        debugPrint("=== loadLastAudio: no audio data");
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
