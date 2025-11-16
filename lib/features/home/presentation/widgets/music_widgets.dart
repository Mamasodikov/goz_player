import 'dart:io';

import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:goz_player/core/widgets/custom_toast.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/home/presentation/bloc/music_home/music_home_bloc.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:goz_player/features/player/pages/full_screen_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../data/models/music_model.dart';

class MusicGridCard extends StatelessWidget {
  final Music song;

  const MusicGridCard({Key? key, required this.song}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final networkInfo = di<NetworkInfo>();
    final pageManager = di<PageManager>();
    final database = di<MusicLocalDatasource>();

    return ZoomTapAnimation(
      onTap: () async {
        final hasInternet = await networkInfo.isConnected;

        if (!hasInternet && !song.isDownloaded) {
          CustomToast.showToast('Cannot play non-downloaded song while offline');
          return;
        }

        // Start playing the song before navigation for instant playback
        final playlist = pageManager.playlistNotifier.value;
        final currentSong = pageManager.currentSongNotifier.value;

        // Only change song if it's not already the current song
        if (currentSong.id != song.trackId) {
          final songIndex = playlist.indexWhere((item) => item.id == song.trackId);

          if (songIndex != -1) {
            // Song is already in playlist, just skip to it
            pageManager.skipToQueueItem(songIndex);
            pageManager.play();
          } else {
            // Song not in playlist, add it first
            final dbMusic = await database.getMusicById(song.trackId);

            if (dbMusic != null) {
              await pageManager.add(dbMusic.toMap());
            } else {
              await addToDBAndPlaylist(
                database: database,
                pageManager: pageManager,
                updatedMusic: song,
              );
            }

            // Wait a bit for the song to be added to the playlist
            await Future.delayed(Duration(milliseconds: 50));

            final newPlaylist = pageManager.playlistNotifier.value;
            final newIndex = newPlaylist.indexWhere((item) => item.id == song.trackId);

            if (newIndex != -1) {
              pageManager.skipToQueueItem(newIndex);
              pageManager.play();
            }
          }
        }

        // Navigate to full screen player
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenPlayer(song: song),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cWhiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: _buildCoverImage(
                      song.coverUrl,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: cWhiteColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title ?? '-',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: cBlackColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    song.artist ?? '-',
                    style: TextStyle(
                      fontSize: 13.0,
                      color: cGrayColor1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(String coverPath, {double? width, double? height}) {
    if (coverPath.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cFirstColor.withOpacity(0.3),
              cFirstColorDark.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.music_note,
            size: 50,
            color: cGrayColor1,
          ),
        ),
      );
    }

    if (coverPath.startsWith('assets/')) {
      return Image.asset(
        coverPath,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cFirstColor.withOpacity(0.3),
                  cFirstColorDark.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 50,
                color: cGrayColor1,
              ),
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(coverPath),
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cFirstColor.withOpacity(0.3),
                  cFirstColorDark.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 50,
                color: cGrayColor1,
              ),
            ),
          );
        },
      );
    }
  }
}
