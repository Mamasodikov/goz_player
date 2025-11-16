import 'package:goz_player/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class PlayerActions extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isInPlaylist;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onPlaylistTap;

  const PlayerActions({
    Key? key,
    required this.isDownloaded,
    required this.isDownloading,
    required this.isInPlaylist,
    required this.onDownloadTap,
    required this.onPlaylistTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: isDownloaded
              ? Icons.delete
              : (isDownloading ? Icons.downloading : Icons.download),
          label: isDownloaded
              ? 'Delete Download'
              : (isDownloading ? 'Downloading...' : 'Download'),
          onTap: isDownloading ? null : onDownloadTap,
        ),
        _ActionButton(
          icon: isInPlaylist ? Icons.playlist_remove : Icons.playlist_add,
          label: isInPlaylist ? 'Remove from Playlist' : 'Add to Playlist',
          onTap: onPlaylistTap,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ZoomTapAnimation(
      onTap: onTap ?? () {},
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cWhiteColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cWhiteColor, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: cWhiteColor.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

