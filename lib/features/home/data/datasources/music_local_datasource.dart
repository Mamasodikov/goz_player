import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/music_model.dart';

class MusicLocalDatasource {
  static Isar? _isar;

  Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    _isar = await _initIsar();
    return _isar!;
  }

  Future<Isar> _initIsar() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [MusicSchema],
        directory: dir.path,
        name: 'goz_player',
      );
    } catch (e) {
      debugPrint('Error initializing Isar: $e');
      rethrow;
    }
  }

  Future<void> addToPlaylist(Music music) async {
    try {
      final db = await isar;
      await db.writeTxn(() async {
        final existing = await db.musics.filter().trackIdEqualTo(music.trackId).findFirst();
        if (existing != null) {
          music.id = existing.id;
        }
        await db.musics.put(music);
      });
      debugPrint('Added to playlist: ${music.title}');
    } catch (e) {
      debugPrint('Error adding to playlist: $e');
    }
  }

  Future<void> removeFromPlaylist(String trackId) async {
    try {
      final db = await isar;
      await db.writeTxn(() async {
        final music = await db.musics.filter().trackIdEqualTo(trackId).findFirst();
        if (music != null) {
          await db.musics.delete(music.id);
        }
      });
      debugPrint('Removed from playlist: $trackId');
    } catch (e) {
      debugPrint('Error removing from playlist: $e');
    }
  }

  Future<List<Music>> getPlaylist() async {
    try {
      final db = await isar;
      final playlist = await db.musics.where().findAll();
      debugPrint('=== Isar playlist retrieved: ${playlist.length} items ===');
      for (var music in playlist) {
        debugPrint('Music: id=${music.trackId}, title=${music.title}, coverUrl=${music.coverUrl}');
      }
      return playlist;
    } catch (e) {
      debugPrint('Error getting playlist: $e');
      return [];
    }
  }

  Future<List<Music>> getDownloadedSongs() async {
    try {
      final db = await isar;
      final downloadedSongs = await db.musics.filter().isDownloadedEqualTo(true).findAll();
      debugPrint('=== Downloaded songs retrieved: ${downloadedSongs.length} items ===');
      return downloadedSongs;
    } catch (e) {
      debugPrint('Error getting downloaded songs: $e');
      return [];
    }
  }

  Future<Music?> getMusicById(String trackId) async {
    try {
      final db = await isar;
      return await db.musics.filter().trackIdEqualTo(trackId).findFirst();
    } catch (e) {
      debugPrint('Error getting music by id: $e');
      return null;
    }
  }

  Future<bool> isInPlaylist(String trackId) async {
    try {
      final music = await getMusicById(trackId);
      return music != null;
    } catch (e) {
      debugPrint('Error checking if in playlist: $e');
      return false;
    }
  }

  Future<void> clearPlaylist() async {
    try {
      final db = await isar;
      await db.writeTxn(() async {
        await db.musics.clear();
      });
      debugPrint('Playlist cleared');
    } catch (e) {
      debugPrint('Error clearing playlist: $e');
    }
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}

