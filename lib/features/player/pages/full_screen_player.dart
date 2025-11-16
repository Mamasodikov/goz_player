import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:goz_player/features/home/data/datasources/home_remote_datasource.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:goz_player/features/player/widgets/player_actions.dart';
import 'package:goz_player/features/player/widgets/player_controls.dart';
import 'package:goz_player/features/player/widgets/player_cover.dart';
import 'package:goz_player/features/player/widgets/player_metadata.dart';
import 'package:goz_player/features/player/widgets/player_progress.dart';
import 'package:flutter/material.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../notifiers/play_button_notifier.dart';

class FullScreenPlayer extends StatefulWidget {
  final Music song;

  const FullScreenPlayer({Key? key, required this.song}) : super(key: key);

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  final pageManager = di<PageManager>();
  final database = di<MusicLocalDatasource>();
  final remoteDatasource = di<HomeRemoteDatasourceImpl>();
  final networkInfo = di<NetworkInfo>();
  bool isInPlaylist = false;
  bool isDownloaded = false;
  bool isDownloading = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _playThisSong();
    _listenToCurrentSong();
    _listenToConnectivity();
  }

  void _listenToCurrentSong() {
    pageManager.currentSongNotifier.addListener(_updateSongStatus);
    pageManager.playlistNotifier.addListener(_checkPlaylistEmpty);
    pageManager.playlistNotifier.addListener(_updateSongStatus);
    _updateSongStatus();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((hasInternet) async {
      if (!hasInternet) {
        final currentSong = pageManager.currentSongNotifier.value;
        final music = await database.getMusicById(currentSong.id);
        final isCurrentDownloaded = music?.isDownloaded ?? false;

        if (!isCurrentDownloaded && pageManager.playButtonNotifier.value == ButtonState.playing) {
          pageManager.pause();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No internet connection. Download songs to play offline.')),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    pageManager.currentSongNotifier.removeListener(_updateSongStatus);
    pageManager.playlistNotifier.removeListener(_checkPlaylistEmpty);
    pageManager.playlistNotifier.removeListener(_updateSongStatus);
    super.dispose();
  }

  void _checkPlaylistEmpty() async {
    final playlist = pageManager.playlistNotifier.value;

    if (playlist.isEmpty) {
      final dbPlaylist = await database.getPlaylist();

      if (dbPlaylist.isEmpty && mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _updateSongStatus() async {
    final currentSong = pageManager.currentSongNotifier.value;
    final currentSongId = currentSong.id;

    final playlist = await database.getPlaylist();
    final music = await database.getMusicById(currentSongId);

    if (mounted) {
      setState(() {
        isInPlaylist = playlist.any((b) => b.trackId == currentSongId);
        isDownloaded = music?.isDownloaded ?? false;
        isDownloading = false;
      });
    }
  }

  Future<void> _playThisSong() async {
    final hasInternet = await networkInfo.isConnected;

    if (!hasInternet && !widget.song.isDownloaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot play non-downloaded song while offline')),
        );
      }
      return;
    }

    final playlist = pageManager.playlistNotifier.value;
    final currentSong = pageManager.currentSongNotifier.value;

    if (currentSong.id == widget.song.trackId) {
      if (pageManager.playButtonNotifier.value == ButtonState.paused) {
        pageManager.play();
      }
      return;
    }

    final songIndex = playlist.indexWhere((item) => item.id == widget.song.trackId);

    if (songIndex != -1) {
      pageManager.skipToQueueItem(songIndex);
      await Future.delayed(Duration(milliseconds: 100));
      pageManager.play();
    } else {
      final dbMusic = await database.getMusicById(widget.song.trackId);

      if (dbMusic != null) {
        await pageManager.add(dbMusic.toMap());

        await Future.delayed(Duration(milliseconds: 100));

        final newPlaylist = pageManager.playlistNotifier.value;
        final newIndex = newPlaylist.indexWhere((item) => item.id == widget.song.trackId);

        if (newIndex != -1) {
          pageManager.skipToQueueItem(newIndex);
          await Future.delayed(Duration(milliseconds: 100));
          pageManager.play();
        }
      } else {
        await addToDBAndPlaylist(
          database: database,
          pageManager: pageManager,
          updatedMusic: widget.song,
        );

        await Future.delayed(Duration(milliseconds: 100));

        final newPlaylist = pageManager.playlistNotifier.value;
        final newIndex = newPlaylist.indexWhere((item) => item.id == widget.song.trackId);

        if (newIndex != -1) {
          pageManager.skipToQueueItem(newIndex);
          await Future.delayed(Duration(milliseconds: 100));
          pageManager.play();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cFirstColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(height: 40),
                      ValueListenableBuilder<MediaItem>(
                        valueListenable: pageManager.currentSongNotifier,
                        builder: (context, currentSong, _) {
                          return PlayerCover(currentSong: currentSong);
                        },
                      ),
                      SizedBox(height: 40),
                      ValueListenableBuilder<MediaItem>(
                        valueListenable: pageManager.currentSongNotifier,
                        builder: (context, currentSong, _) {
                          return PlayerMetadata(currentSong: currentSong);
                        },
                      ),
                      SizedBox(height: 40),
                      PlayerProgress(pageManager: pageManager),
                      SizedBox(height: 30),
                      PlayerControls(pageManager: pageManager),
                      SizedBox(height: 30),
                      PlayerActions(
                        isDownloaded: isDownloaded,
                        isDownloading: isDownloading,
                        isInPlaylist: isInPlaylist,
                        onDownloadTap: isDownloading ? null : (isDownloaded ? _deleteDownload : _downloadSong),
                        onPlaylistTap: isInPlaylist ? _removeFromPlaylist : _addToPlaylist,
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ZoomTapAnimation(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cWhiteColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.keyboard_arrow_down, color: cWhiteColor, size: 28),
            ),
          ),
          Text(
            'Now Playing',
            style: TextStyle(
              color: cWhiteColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 44),
        ],
      ),
    );
  }



  Future<void> _downloadSong() async {
    setState(() {
      isDownloading = true;
    });

    try {
      final currentSong = pageManager.currentSongNotifier.value;
      final currentMusic = convertMediaItemToMusic(currentSong);

      final success = await remoteDatasource.downloadAndAddPlaylist(currentMusic);

      if (success) {
        await _updateSongStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${currentSong.title} downloaded successfully!')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            isDownloading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download ${currentSong.title}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading: $e')),
        );
      }
    }
  }

  Future<void> _addToPlaylist() async {
    final currentSong = pageManager.currentSongNotifier.value;
    final currentMusic = convertMediaItemToMusic(currentSong);

    await addToDBAndPlaylist(
      database: database,
      pageManager: pageManager,
      updatedMusic: currentMusic,
    );

    await _updateSongStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${currentSong.title} added to playlist')),
    );
  }

  Future<void> _removeFromPlaylist() async {
    final currentSong = pageManager.currentSongNotifier.value;
    final currentMusic = convertMediaItemToMusic(currentSong);

    try {
      await database.removeFromPlaylist(currentMusic.trackId);
      pageManager.remove(currentMusic.toMap());

      await _updateSongStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${currentSong.title} removed from playlist')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove ${currentSong.title}')),
      );
    }
  }

  Future<void> _deleteDownload() async {
    final currentSong = pageManager.currentSongNotifier.value;
    final currentMusic = convertMediaItemToMusic(currentSong);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Download'),
        content: Text('Are you sure you want to delete the downloaded file for "${currentSong.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dbMusic = await database.getMusicById(currentMusic.trackId);
      if (dbMusic != null && dbMusic.isDownloaded) {
        deleteFileFromInternalStorage(dbMusic.audioUrl);
        deleteFileFromInternalStorage(dbMusic.coverUrl);

        await database.removeFromPlaylist(currentMusic.trackId);
        pageManager.remove(currentMusic.toMap());

        await _updateSongStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded file deleted for ${currentSong.title}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete download')),
      );
    }
  }

}

