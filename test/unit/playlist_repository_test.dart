import 'package:flutter_test/flutter_test.dart';
import 'package:goz_player/core/helper/playlist_repository.dart';

void main() {
  group('DemoPlaylist Tests', () {
    late DemoPlaylist playlist;

    setUp(() {
      playlist = DemoPlaylist();
    });

    test('should return 5 songs when asked for 5', () async {
      final songs = await playlist.fetchInitialPlaylist(length: 5);

      expect(songs.length, 5);
    });

    test('each song should have required fields', () async {
      final songs = await playlist.fetchInitialPlaylist(length: 3);

      for (var song in songs) {
        expect(song['id'], isNotNull);
        expect(song['title'], isNotNull);
        expect(song['album'], 'SoundHelix');
        expect(song['coverUrl'], isNotNull);
        expect(song['url'], isNotNull);
      }
    });

    test('songs should be numbered sequentially', () async {
      final songs = await playlist.fetchInitialPlaylist(length: 3);

      expect(songs[0]['id'], '001');
      expect(songs[0]['title'], 'Song 1');
      expect(songs[1]['id'], '002');
      expect(songs[2]['id'], '003');
    });

    test('fetchAnotherSong should return valid song', () async {
      final song = await playlist.fetchAnotherSong();

      expect(song['id'], isNotNull);
      expect(song['title'], isNotNull);
    });

    test('fetchAnotherSong should continue from where playlist ended', () async {
      await playlist.fetchInitialPlaylist(length: 2);
      final nextSong = await playlist.fetchAnotherSong();

      expect(nextSong['id'], '003');
      expect(nextSong['title'], 'Song 3');
    });

    test('should loop back to song 1 after reaching max songs', () async {
      await playlist.fetchInitialPlaylist(length: 16);
      final wrappedSong = await playlist.fetchAnotherSong();

      expect(wrappedSong['id'], '001');
      expect(wrappedSong['title'], 'Song 1');
    });
  });
}