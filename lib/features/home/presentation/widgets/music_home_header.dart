import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/generated/assets.dart';
import 'package:flutter/material.dart';

class MusicHomeHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showGradient;

  const MusicHomeHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.showGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: cFirstColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: subtitle != null ? _buildTitleWithSubtitle() : _buildSimpleTitle(),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cFirstColor,
                cFirstColorDark,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(Assets.assetsGooseIcon, height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "G'oz",
          style: TextStyle(
            fontSize: 24,
            color: cWhiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            color: cWhiteColor.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleWithSubtitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "G'oz",
              style: TextStyle(
                fontSize: 24,
                color: cWhiteColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                color: cWhiteColor.withOpacity(0.9),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Flexible(
          child: Text(
            subtitle ?? '',
            style: TextStyle(
              fontSize: 12,
              color: cWhiteColor.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

