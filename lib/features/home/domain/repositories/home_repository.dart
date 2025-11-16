import 'package:goz_player/core/error/failures.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:dartz/dartz.dart';

abstract class HomeRepository {
  Future<Either<Failure, bool>> downloadAndAddPlaylist(Music? music);
}