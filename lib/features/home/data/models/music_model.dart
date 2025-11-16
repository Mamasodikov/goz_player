import 'package:isar_community/isar.dart';

part 'music_model.g.dart';

@collection
class Music {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String trackId;
  
  late String title;
  late String artist;
  late String audioUrl;
  late String coverUrl;
  late int duration;
  late bool isDownloaded;

  Music({
    this.trackId = '',
    this.title = '',
    this.artist = '',
    this.audioUrl = '',
    this.coverUrl = '',
    this.duration = 0,
    this.isDownloaded = false,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      trackId: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      isDownloaded: json['isDownloaded'] == 1 || json['isDownloaded'] == true,
    );
  }

  Map<String, String> toMap() {
    return {
      'id': trackId,
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl,
      'duration': duration.toString(),
      'isDownloaded': isDownloaded.toString(),
    };
  }

  Music copyWith({
    String? trackId,
    String? title,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    int? duration,
    bool? isDownloaded,
  }) {
    return Music(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}