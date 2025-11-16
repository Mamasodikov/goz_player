import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/widgets/custom_toast.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> deleteFileFromInternalStorage(String fileName,
    {bool withPath = true}) async {
  try {
    // Get the application documents directory
    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();

    // Create a file path
    String filePath;
    if (!withPath) {
      filePath = '${appDocumentsDirectory.path}/$fileName';
    } else {
      filePath = fileName;
    }

    // Check if the file exists before attempting to delete
    if (await File(filePath).exists()) {
      // Delete the file
      await File(filePath).delete(recursive: true);
      print('File deleted successfully: $filePath');
    } else {
      print('File not found: $filePath');
      // CustomToast.showToast('File not found: $filePath');
    }
  } catch (e) {
    print('Error deleting file: $e');
    CustomToast.showToast('Error deleting file: $e');
  }
}

bool isWebUrl(String path) {
  final urlPattern = r'^(http[s]?:\/\/|www\.)';
  final regExp = RegExp(urlPattern);

  return regExp.hasMatch(path);
}

bool isLocalFilePath(String path) {
  // Assuming that if it's not a web URL, it's a local file path
  return !isWebUrl(path);
}

Future<bool> deleteFromDBAndPlaylist(
    {required MusicLocalDatasource database,
    required PageManager pageManager,
    required Music music}) async {
  var trackId = music.trackId;

  try {
    await database.removeFromPlaylist(trackId);
    pageManager.remove(music.toMap());
    return true;
  } catch (e) {
    print(e);
    return false;
  }
}

Future<bool> addToDBAndPlaylist(
    {required MusicLocalDatasource database,
    required PageManager pageManager,
    required Music updatedMusic}) async {
  try {
    ///Add model to local DB
    await database.addToPlaylist(updatedMusic);

    ///Add audio to the playlist
    await pageManager.add(updatedMusic.toMap());
    return true;
  } catch (e) {
    print(e);
    return false;
  }
}

MediaItem convertMusicToMediaItem(Music music) {
  return MediaItem(
    id: music.trackId,
    title: music.title,
    duration: Duration(seconds: music.duration),
    extras: {
      'artist': music.artist,
      'audioUrl': music.audioUrl,
      'coverUrl': music.coverUrl,
      'isDownloaded': music.isDownloaded.toString(),
    },
  );
}

Music convertMediaItemToMusic(MediaItem mediaItem) {
  return Music(
    trackId: mediaItem.id,
    audioUrl: mediaItem.extras?['audioUrl'] as String? ?? '',
    coverUrl: mediaItem.extras?['coverUrl'] as String? ?? '',
    title: mediaItem.title,
    artist: mediaItem.extras?['artist'] as String? ?? '',
    duration: mediaItem.duration?.inSeconds ?? 0,
    isDownloaded: mediaItem.extras?['isDownloaded'] == 'true',
  );
}

Future<bool?> showAlertText(BuildContext context, String question) async {
  return await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: Text("Confirmation"),
          content: Text(question),
          actions: [
            // The "Yes" button
            CupertinoDialogAction(
                onPressed: () {
                  // Close the dialog
                  Navigator.of(context).pop(true);
                },
                child: Text("Yes", style: TextStyle(color: cRedColor))),
            CupertinoDialogAction(
                onPressed: () {
                  // Close the dialog
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  "No",
                  style: TextStyle(color: cFirstColor),
                ))
          ],
        );
      });
}

// Function to launch a URL
Future<void> launchCustomUrl(Uri uri) async {
  try {
    await launchUrl(uri);
  } catch (e) {
    print(e);
    CustomToast.showToast('This action is not supported');
  }
}
