import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/home/domain/usecases/u_music_detailed.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'music_detailed_event.dart';

part 'music_detailed_state.dart';

/// Domain layer is not fully implemented yet for instant testing and possible changes of functions

class MusicDetailedBloc extends Bloc<MusicDetailedEvent, MusicDetailedState> {
  final NetworkInfo networkInfo;
  final Dio dio;
  final PageManager pageManager;
  final UMusicDetailedDownload uMusicDetailedDownload;

  MusicDetailedBloc(
      {required this.pageManager,
      required this.networkInfo,
      required this.dio,
      required this.uMusicDetailedDownload})
      : super(MusicDetailedState.initial()) {
    on<LoadMusicEvent>(getInitialState);
    on<DownloadMusicEvent>(downloadAndAddPlaylist);
    on<RemoveMusicEvent>(removeFileAndPlaylist);
  }

  getInitialState(LoadMusicEvent event, Emitter<MusicDetailedState> emit) async {
    try {
      MusicLocalDatasource database = di();
      var music = event.music ?? Music();
      var musicId = music.trackId;

      emit(state.copyWith(status: MusicDetailedStatus.loading));

      var result = await database.getMusicById(musicId);
      if (result != null) {
        emit(state.copyWith(
            status: MusicDetailedStatus.initial,
            isDownloaded: true,
            localMusic: result));
      } else {
        emit(state.copyWith(
            status: MusicDetailedStatus.initial, isDownloaded: false));
      }
    } catch (e) {
      debugPrint(e.toString());
      emit(
          state.copyWith(status: MusicDetailedStatus.failure, message: "Error"));
    }
  }

  downloadAndAddPlaylist(
      DownloadMusicEvent event, Emitter<MusicDetailedState> emit) async {
    if (await networkInfo.isConnected) {
      emit(state.copyWith(status: MusicDetailedStatus.loading));

      var result = await uMusicDetailedDownload(event);
      result.fold(
          (failure) => {
                emit(state.copyWith(
                    status: MusicDetailedStatus.failure,
                    message: failure.errorMessage))
              },
          (r) async {
                if (r) {
                  MusicLocalDatasource database = di();
                  var updatedMusic = await database.getMusicById(event.music?.trackId ?? '');
                  emit(state.copyWith(
                      status: MusicDetailedStatus.success,
                      isDownloaded: true,
                      localMusic: updatedMusic));
                } else {
                  emit(state.copyWith(
                      status: MusicDetailedStatus.failure,
                      message: 'Download failed'));
                }
              });
    } else {
      emit(state.copyWith(
          status: MusicDetailedStatus.noInternet, message: "No internet"));
    }
  }

  removeFileAndPlaylist(
      RemoveMusicEvent event, Emitter<MusicDetailedState> emit) async {
    emit(state.copyWith(status: MusicDetailedStatus.loading));

    MusicLocalDatasource database = di();
    var music = event.music ?? Music();
    var musicId = music.trackId;

    var dbMusic = await database.getMusicById(musicId);
    if (dbMusic != null && dbMusic.isDownloaded) {
      deleteFileFromInternalStorage(dbMusic.audioUrl);
      deleteFileFromInternalStorage(dbMusic.coverUrl);

      await database.removeFromPlaylist(musicId);
      pageManager.remove(music.toMap());
    }

    emit(state.copyWith(
        status: MusicDetailedStatus.success, isDownloaded: false));
  }
}
