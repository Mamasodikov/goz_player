part of 'music_detailed_bloc.dart';

enum MusicDetailedStatus {
  initial,
  loading,
  failure,
  success,
  noInternet,
}

class MusicDetailedState extends Equatable {
  final MusicDetailedStatus status;
  final String? message;
  final bool isDownloaded;
  final Music? localMusic;

  MusicDetailedState({
    required this.status,
    this.message,
    required this.isDownloaded,
    this.localMusic,
  });

  static MusicDetailedState initial() => MusicDetailedState(
        status: MusicDetailedStatus.initial,
        isDownloaded: false,
      );

  MusicDetailedState copyWith(
          {MusicDetailedStatus? status,
          String? message,
          bool? isDownloaded,
          Music? localMusic}) =>
      MusicDetailedState(
          status: status ?? this.status,
          message: message ?? this.message,
          isDownloaded: isDownloaded ?? this.isDownloaded,
          localMusic: localMusic ?? this.localMusic);

  @override
  List<Object?> get props => [status, message, isDownloaded, localMusic];
}
