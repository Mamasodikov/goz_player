part of 'music_home_bloc.dart';

abstract class MusicHomeEvent extends Equatable {
  const MusicHomeEvent();
}

class getMusicsEvent extends MusicHomeEvent {
  @override
  List<Object?> get props => [];
}