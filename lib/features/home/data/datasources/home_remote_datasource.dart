import 'dart:io';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'music_local_datasource.dart';
import 'package:path/path.dart' as path;

abstract class HomeRemoteDatasource {
  Future<bool> downloadAndAddPlaylist(Music music);
}

class HomeRemoteDatasourceImpl implements HomeRemoteDatasource {
  final Dio client;
  final MusicLocalDatasource database;
  final PageManager pageManager;

  HomeRemoteDatasourceImpl(
      {required this.client,
      required this.database,
      required this.pageManager});

  @override
  Future<bool> downloadAndAddPlaylist(Music music) async {
    try {
      var audioAssetPath = music.audioUrl;

      if (audioAssetPath.startsWith('http')) {
        return await _downloadFromUrl(music, audioAssetPath);
      } else {
        return await _copyFromAssets(music, audioAssetPath);
      }
    } catch (e) {
      debugPrint('Error in downloadAndAddPlaylist: $e');
      return false;
    }
  }

  Future<bool> _copyFromAssets(Music music, String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      var fileName = path.basename(assetPath);
      var nameWithoutExtension = path.basenameWithoutExtension(fileName);
      var extension = path.extension(fileName);

      var directory = await getApplicationDocumentsDirectory();
      var now = DateTime.now();
      var time = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

      var filePath = path.join(directory.path, "${nameWithoutExtension}_$time$extension");

      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      debugPrint('File copied from assets to: $filePath');

      String? coverPath;
      if (music.coverUrl.isNotEmpty) {
        coverPath = await _copyCoverFromAssets(music.coverUrl);
      }

      final updatedMusic = music.copyWith(
        audioUrl: filePath,
        coverUrl: coverPath ?? music.coverUrl,
        isDownloaded: true,
      );

      await database.addToPlaylist(updatedMusic);

      final playlist = pageManager.playlistNotifier.value;
      final songIndex = playlist.indexWhere((item) => item.id == music.trackId);

      if (songIndex != -1) {
        await pageManager.update(updatedMusic.toMap());
      }

      return true;
    } catch (e) {
      debugPrint('Error copying from assets: $e');
      return false;
    }
  }

  Future<String?> _copyCoverFromAssets(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      var fileName = path.basename(assetPath);
      var nameWithoutExtension = path.basenameWithoutExtension(fileName);
      var extension = path.extension(fileName);

      var directory = await getApplicationDocumentsDirectory();
      var coverDir = Directory(path.join(directory.path, 'covers'));

      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }

      var now = DateTime.now();
      var time = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      var uniqueFileName = "${nameWithoutExtension}_$time$extension";

      var filePath = path.join(coverDir.path, uniqueFileName);
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      debugPrint('Cover copied to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error copying cover: $e');
      return null;
    }
  }

  Future<bool> _downloadFromUrl(Music music, String audioUrl) async {
    try {
      var uri = Uri.parse(audioUrl);
      var fileName = path.basename(uri.path);

      var nameWithoutExtension = path.basenameWithoutExtension(fileName);
      var extension = path.extension(fileName);

      var directory = await getApplicationDocumentsDirectory();
      var now = DateTime.now();
      var time = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);

      var filePath = path.join(directory.path, "${nameWithoutExtension}_$time$extension");

      debugPrint('Downloading audio to: $filePath');
      var response = await client.download(audioUrl, filePath);

      if (response.statusCode == 200) {
        try {
          String? coverPath;
          if (music.coverUrl.isNotEmpty && music.coverUrl.startsWith('http')) {
            coverPath = await _downloadCover(music.coverUrl);
          }

          final updatedMusic = music.copyWith(
            audioUrl: filePath,
            coverUrl: coverPath ?? music.coverUrl,
            isDownloaded: true,
          );

          await database.addToPlaylist(updatedMusic);

          final playlist = pageManager.playlistNotifier.value;
          final songIndex = playlist.indexWhere((item) => item.id == music.trackId);

          if (songIndex != -1) {
            await pageManager.update(updatedMusic.toMap());
            debugPrint('Updated existing song in playlist: ${music.title}');
          } else {
            await pageManager.add(updatedMusic.toMap());
            debugPrint('Added new song to playlist: ${music.title}');
          }

          return true;
        } catch (e) {
          debugPrint('Error updating playlist after download: $e');
          return false;
        }
      } else {
        debugPrint('Download failed with status code: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      debugPrint('DioException during download: $e');
      return false;
    } catch (e) {
      debugPrint('Error downloading from URL: $e');
      return false;
    }
  }

  Future<String?> _downloadCover(String coverUrl) async {
    try {
      var uri = Uri.parse(coverUrl);
      var fileName = path.basename(uri.path);
      var directory = await getApplicationDocumentsDirectory();
      var now = DateTime.now();
      var time = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      var filePath = path.join(directory.path, "cover_$time$fileName");

      var response = await client.download(coverUrl, filePath);

      if (response.statusCode == 200) {
        debugPrint('Cover downloaded to: $filePath');
        return filePath;
      } else {
        debugPrint('Cover download failed with status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading cover: $e');
      return null;
    }
  }
}
