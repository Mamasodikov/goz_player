import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/player/notifiers/play_button_notifier.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:flutter/material.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

class PlayerControls extends StatelessWidget {
  final PageManager pageManager;

  const PlayerControls({Key? key, required this.pageManager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: pageManager.isFirstSongNotifier,
          builder: (_, isFirst, __) {
            return _ControlButton(
              icon: Icons.skip_previous,
              onTap: isFirst ? null : pageManager.previous,
              isDisabled: isFirst,
            );
          },
        ),
        ValueListenableBuilder<ButtonState>(
          valueListenable: pageManager.playButtonNotifier,
          builder: (_, value, __) {
            return _PlayPauseButton(
              state: value,
              onPlayTap: pageManager.play,
              onPauseTap: pageManager.pause,
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: pageManager.isLastSongNotifier,
          builder: (_, isLast, __) {
            return _ControlButton(
              icon: Icons.skip_next,
              onTap: isLast ? null : pageManager.next,
              isDisabled: isLast,
            );
          },
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return ZoomTapAnimation(
      onTap: onTap ?? () {},
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cWhiteColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cWhiteColor, size: 40),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final ButtonState state;
  final VoidCallback onPlayTap;
  final VoidCallback onPauseTap;

  const _PlayPauseButton({
    required this.state,
    required this.onPlayTap,
    required this.onPauseTap,
  });

  @override
  Widget build(BuildContext context) {
    return ZoomTapAnimation(
      onTap: state == ButtonState.paused ? onPlayTap : onPauseTap,
      child: Container(
        width: 90,
        height: 90,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cWhiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: cBlackColor.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: state == ButtonState.loading
            ? Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(cFirstColor),
                  ),
                ),
              )
            : Center(
                child: Icon(
                  state == ButtonState.paused ? Icons.play_arrow : Icons.pause,
                  color: cFirstColor,
                  size: 48,
                ),
              ),
      ),
    );
  }
}

