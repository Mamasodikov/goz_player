part of 'music_detailed_bloc.dart';

abstract class MusicDetailedEvent extends Equatable {
  const MusicDetailedEvent();
}

class LoadMusicEvent extends MusicDetailedEvent {

  final Music? music;

  LoadMusicEvent({required this.music});

  @override
  List<Object?> get props => [music];
}

class DownloadMusicEvent extends MusicDetailedEvent {

  final Music? music;

  DownloadMusicEvent({required this.music});

  @override
  List<Object?> get props => [music];
}

class RemoveMusicEvent extends MusicDetailedEvent {

  final Music? music;

  RemoveMusicEvent({required this.music});

  @override
  List<Object?> get props => [music];
}