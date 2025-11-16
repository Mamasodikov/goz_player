part of 'music_home_bloc.dart';

enum MusicHomeStatus {
  initial,
  loading,
  failure,
  success,
  noInternet,
}

class MusicHomeState extends Equatable {
  final MusicHomeStatus status;
  final String? message;
  final List<Music>? songs;

  MusicHomeState({
    required this.status,
    this.message,
    this.songs,
  });

  static MusicHomeState initial() => MusicHomeState(
        status: MusicHomeStatus.initial,
      );

  MusicHomeState copyWith({
    MusicHomeStatus? status,
    String? message,
    List<Music>? songs,
  }) =>
      MusicHomeState(
        status: status ?? this.status,
        message: message ?? this.message,
        songs: songs ?? this.songs,
      );

  @override
  List<Object?> get props => [status, message, songs];
}
