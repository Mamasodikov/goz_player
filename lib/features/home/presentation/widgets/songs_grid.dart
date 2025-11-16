import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/home/presentation/widgets/music_widgets.dart';
import 'package:flutter/material.dart';

class SongsGrid extends StatelessWidget {
  final List<Music> songs;

  const SongsGrid({Key? key, required this.songs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 250),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            return MusicGridCard(song: song);
          },
          childCount: songs.length,
        ),
      ),
    );
  }
}

class SongsHeader extends StatelessWidget {
  final int songCount;

  const SongsHeader({Key? key, required this.songCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All Songs',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cWhiteColor,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cWhiteColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$songCount songs',
                style: TextStyle(
                  fontSize: 14,
                  color: cWhiteColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: cWhiteColor.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cWhiteColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No downloaded songs available',
              style: TextStyle(
                fontSize: 14,
                color: cWhiteColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineHeader extends StatelessWidget {
  const OfflineHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: cWhiteColor, size: 20),
            SizedBox(width: 8),
            Text(
              'Downloaded Songs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cWhiteColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

