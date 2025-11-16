import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:flutter/material.dart';

class PlayerMetadata extends StatelessWidget {
  final MediaItem currentSong;

  const PlayerMetadata({Key? key, required this.currentSong}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          currentSong.title,
          style: TextStyle(
            color: cWhiteColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8),
        Text(
          currentSong.extras?['artist'] ?? '',
          style: TextStyle(
            color: cWhiteColor.withOpacity(0.8),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

