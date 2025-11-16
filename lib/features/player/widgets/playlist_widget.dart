import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:goz_player/core/widgets/custom_toast.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class Playlist extends StatefulWidget {
  final bool hasInternet;
  final VoidCallback? onRefresh;

  const Playlist({
    Key? key,
    required this.hasInternet,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<Playlist> createState() => _PlaylistState();
}

class _PlaylistState extends State<Playlist> {
  PageManager pageManager = di();
  final networkInfo = di<NetworkInfo>();
  bool hasInternet = true;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _listenToConnectivity();
  }

  Future<void> _checkInternetConnection() async {
    final connected = await networkInfo.isConnected;
    if (mounted) {
      setState(() {
        hasInternet = connected;
      });
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((connected) {
      if (mounted) {
        setState(() {
          hasInternet = connected;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ValueListenableBuilder<List<MediaItem>>(
        valueListenable: pageManager.playlistNotifier,
        builder: (context, playlistItems, _) {
          return ValueListenableBuilder<MediaItem>(
            valueListenable: pageManager.currentSongNotifier,
            builder: (_, currentMusic, __) {
              var currentSongId = currentMusic.id;

              return ReorderableListView(
                onReorder: (int oldIndex, int newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  pageManager.reorderPlaylist(oldIndex, newIndex);
                },
                children: List.generate(playlistItems.length, (index) {
                  final isDownloaded = playlistItems[index].extras?['isDownloaded'] == 'true';
                  final canPlay = hasInternet || isDownloaded;

                  return Column(
                    key: Key('$index'),
                    children: [
                      ZoomTapAnimation(
                        onTap: canPlay ? () {
                          pageManager.skipToQueueItem(index);
                          pageManager.play();
                        } : (){
                          CustomToast.showToast('Cannot play non-downloaded song while offline');
                        },
                        child: Container(
                          color: currentSongId == playlistItems[index].id
                              ? cGrayColor0
                              : cWhiteColor,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 5),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Opacity(
                                    opacity: canPlay ? 1.0 : 0.5,
                                    child: _buildCoverImage(
                                      playlistItems[index].extras?['coverUrl'] ?? '',
                                      playlistItems[index].extras?['coverUrl'] ?? '',
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${playlistItems[index].title}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: canPlay ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    var result = await showAlertText(
                                        context,
                                        "Are you sure to remove?") ??
                                        false;
                                    if (result) {
                                      final database = di<MusicLocalDatasource>();
                                      final trackId = playlistItems[index].id;
                                      final musicFromDb = await database.getMusicById(trackId);

                                      if (musicFromDb != null) {
                                        var resultDB = await deleteFromDBAndPlaylist(
                                            database: database,
                                            pageManager: pageManager,
                                            music: musicFromDb);
                                        if (resultDB)
                                          CustomToast.showToast(
                                              "Successfully removed from playlist");
                                        else
                                          CustomToast.showToast(
                                              "Failed to remove from playlist");
                                      } else {
                                        CustomToast.showToast(
                                            "Failed to remove from playlist");
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.drag_handle,
                                    color: Colors.black,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                    ],
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCoverImage(String coverPath, String fallbackPath) {
    String imagePath = coverPath;

    debugPrint('Playlist cover - coverPath: $coverPath, fallbackPath: $fallbackPath');

    if (imagePath.isNotEmpty && !imagePath.startsWith('assets/')) {
      final file = File(imagePath);
      if (!file.existsSync()) {
        debugPrint('Cover file does not exist: $imagePath, falling back to: $fallbackPath');
        imagePath = fallbackPath;
      } else {
        debugPrint('Cover file exists: $imagePath');
      }
    }

    if (imagePath.isEmpty) {
      imagePath = fallbackPath;
    }

    if (imagePath.isEmpty) {
      return Container(
        height: 50,
        width: 50,
        color: cGrayColor0,
        child: Icon(Icons.music_note, color: cFirstColor),
      );
    }

    debugPrint('Using image path: $imagePath');

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        height: 50,
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 50,
            width: 50,
            color: cGrayColor0,
            child: Icon(Icons.music_note, color: cFirstColor),
          );
        },
      );
    } else {
      return Image.file(
        File(imagePath),
        height: 50,
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 50,
            width: 50,
            color: cGrayColor0,
            child: Icon(Icons.music_note, color: cFirstColor),
          );
        },
      );
    }
  }
}