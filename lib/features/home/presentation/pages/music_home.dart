import 'dart:async';

import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/home/presentation/bloc/music_home/music_home_bloc.dart';
import 'package:goz_player/features/home/presentation/pages/about.dart';
import 'package:goz_player/features/home/presentation/pages/playlist_page.dart';
import 'package:goz_player/features/home/presentation/widgets/custom_cards_row.dart';
import 'package:goz_player/features/home/presentation/widgets/music_home_header.dart';
import 'package:goz_player/features/home/presentation/widgets/songs_grid.dart';
import 'package:goz_player/features/player/widgets/draggable_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  static Widget screen() {
    return BlocProvider(
        create: (context) => di<MusicHomeBloc>(), child: MusicHomePage());
  }

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final networkInfo = di<NetworkInfo>();
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    reInitialize();
    _listenToConnectivity();
    super.initState();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((hasInternet) {
      reInitialize();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> reInitialize() async {
    return BlocProvider.of<MusicHomeBloc>(context).add(getMusicsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cFirstColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            BlocConsumer<MusicHomeBloc, MusicHomeState>(
              builder: (BuildContext context, state) {
                if (state.status == MusicHomeStatus.loading) {
                  return Center(
                    child: CupertinoActivityIndicator(
                      radius: 20,
                      color: cWhiteColor,
                    ),
                  );
                } else if (state.status == MusicHomeStatus.success) {
                  final songs = state.songs ?? [];
                  return _buildSuccessView(context, songs);
                } else if (state.status == MusicHomeStatus.noInternet) {
                  final songs = state.songs ?? [];
                  return _buildNoInternetView(songs);
                } else {
                  return Center(
                    child: Text(
                      'Initializing...',
                      style: TextStyle(color: cWhiteColor),
                    ),
                  );
                }
              },
              listener: (BuildContext context, MusicHomeState state) {
                if (state.status == MusicHomeStatus.failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load books')),
                  );
                }
              },
            ),
            DraggableBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, List<Music> songs) {
    return RefreshIndicator(
      onRefresh: reInitialize,
      color: cWhiteColor,
      backgroundColor: cFirstColor,
      child: CustomScrollView(
        physics: BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          MusicHomeHeader(title: 'Player'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: CardRow(
                onCard1Tap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlaylistPage()),
                  );
                },
                onCard2Tap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
                  );
                },
              ),
            ),
          ),
          SongsHeader(songCount: songs.length),
          SongsGrid(songs: songs),
        ],
      ),
    );
  }

  Widget _buildNoInternetView(List<Music> downloadedSongs) {
    return RefreshIndicator(
      onRefresh: reInitialize,
      color: cWhiteColor,
      backgroundColor: cFirstColor,
      child: CustomScrollView(
        physics: BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          MusicHomeHeader(title: 'Player', subtitle: 'Offline Mode'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: CardRow(
                onCard1Tap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlaylistPage()),
                  );
                },
                onCard2Tap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
                  );
                },
              ),
            ),
          ),
          OfflineHeader(),
          if (downloadedSongs.isEmpty)
            EmptyState()
          else
            SongsGrid(songs: downloadedSongs),
        ],
      ),
    );
  }
}
