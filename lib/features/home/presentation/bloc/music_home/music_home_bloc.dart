import 'dart:convert';

import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

part 'music_home_event.dart';
part 'music_home_state.dart';

class MusicHomeBloc extends Bloc<MusicHomeEvent, MusicHomeState> {
  final NetworkInfo networkInfo;
  final Dio dio;

  MusicHomeBloc({required this.networkInfo, required this.dio})
      : super(MusicHomeState.initial()) {
    on<getMusicsEvent>(loadMusics);
  }

  loadMusics(getMusicsEvent event, Emitter<MusicHomeState> emit) async {
    emit(state.copyWith(status: MusicHomeStatus.loading));

    final hasInternet = await networkInfo.isConnected;

    if (!hasInternet) {
      try {
        final database = di<MusicLocalDatasource>();
        final downloadedSongs = await database.getDownloadedSongs();

        if (downloadedSongs.isEmpty) {
          emit(state.copyWith(
            status: MusicHomeStatus.noInternet,
            message: "No internet connection and no downloaded songs",
            songs: [],
          ));
        } else {
          emit(state.copyWith(
            status: MusicHomeStatus.noInternet,
            songs: downloadedSongs,
          ));
        }
        return;
      } catch (e) {
        print('Error loading downloaded songs: $e');
        emit(state.copyWith(
          status: MusicHomeStatus.noInternet,
          message: "No internet connection",
          songs: [],
        ));
        return;
      }
    }

    try {
      final String catalogString = await rootBundle.loadString(APIPath.getCatalog);
      final List<dynamic> jsonResponse = jsonDecode(catalogString);

      final List<Music> songs = jsonResponse.map((json) => Music.fromJson(json)).toList();

      emit(state.copyWith(status: MusicHomeStatus.success, songs: songs));
    } catch (e) {
      print('Error loading catalog: $e');
      emit(state.copyWith(status: MusicHomeStatus.failure, message: "Error loading catalog"));
    }
  }
}
