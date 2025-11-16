import 'package:goz_player/core/error/failures.dart';
import 'package:goz_player/core/usecase/usecase.dart';
import 'package:goz_player/features/home/domain/repositories/home_repository.dart';
import 'package:goz_player/features/home/presentation/bloc/music_detailed/music_detailed_bloc.dart';
import 'package:dartz/dartz.dart';

class UMusicDetailedDownload extends UseCase<bool, DownloadMusicEvent> {
  final HomeRepository homeRepository;

  UMusicDetailedDownload({required this.homeRepository});

  @override
  Future<Either<Failure, bool>> call(DownloadMusicEvent event) {
    return homeRepository.downloadAndAddPlaylist(event.music);
  }
}