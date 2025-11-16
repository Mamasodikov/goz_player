import 'package:goz_player/core/error/failures.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:dartz/dartz.dart';

import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';
import '../models/music_model.dart';

class HomeRepositoryImpl extends HomeRepository {
  final HomeRemoteDatasourceImpl homeRemoteDatasourceImpl;
  final NetworkInfo networkInfo;

  HomeRepositoryImpl(
      {required this.homeRemoteDatasourceImpl,
      required this.networkInfo});

  @override
  Future<Either<Failure, bool>> downloadAndAddPlaylist(Music? music) async {
    try {
      if (music == null) {
        return Left(Failure(errorMessage: 'Music is null'));
      }
      final result = await homeRemoteDatasourceImpl.downloadAndAddPlaylist(music);
      return Right(result);
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }
}
