import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/player/notifiers/progress_notifier.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:flutter/material.dart';

class PlayerProgress extends StatelessWidget {
  final PageManager pageManager;

  const PlayerProgress({Key? key, required this.pageManager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProgressBarState>(
      valueListenable: pageManager.progressNotifier,
      builder: (_, value, __) {
        return ProgressBar(
          progress: value.current,
          buffered: value.buffered,
          total: value.total,
          onSeek: pageManager.seek,
          progressBarColor: cWhiteColor,
          baseBarColor: cWhiteColor.withOpacity(0.3),
          bufferedBarColor: cWhiteColor.withOpacity(0.5),
          thumbColor: cWhiteColor,
          barHeight: 4.0,
          timeLabelTextStyle: TextStyle(
            color: cWhiteColor,
            fontSize: 16,
          ),
          thumbRadius: 6.0,
        );
      },
    );
  }
}

