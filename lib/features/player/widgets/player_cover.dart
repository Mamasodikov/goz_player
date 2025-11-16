import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:flutter/material.dart';

class PlayerCover extends StatelessWidget {
  final MediaItem currentSong;

  const PlayerCover({Key? key, required this.currentSong}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coverUrl = currentSong.extras?['coverUrl'] as String? ?? '';

    return Hero(
      tag: 'song_${currentSong.id}',
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cBlackColor.withOpacity(0.3),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _buildCoverImage(coverUrl),
        ),
      ),
    );
  }

  Widget _buildCoverImage(String coverPath) {
    String imagePath = coverPath;

    if (imagePath.isNotEmpty && !imagePath.startsWith('assets/')) {
      final file = File(imagePath);
      if (!file.existsSync()) {
        imagePath = '';
      }
    }

    if (imagePath.isEmpty) {
      return Container(
        color: cWhiteColor,
        child: Icon(Icons.music_note, size: 100, color: cFirstColor),
      );
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: cWhiteColor,
            child: Icon(Icons.music_note, size: 100, color: cFirstColor),
          );
        },
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: cWhiteColor,
            child: Icon(Icons.music_note, size: 100, color: cFirstColor),
          );
        },
      );
    }
  }
}

