import 'dart:async';

import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/network/network_info.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/features/player/widgets/playlist_widget.dart';
import 'package:flutter/material.dart';

class PlaylistPage extends StatefulWidget {
  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final networkInfo = di<NetworkInfo>();
  bool hasInternet = true;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((connected) {
      if (mounted) {
        setState(() {
          hasInternet = connected;
        });
      }
    });
  }

  Future<void> _checkInternetConnection() async {
    final connected = await networkInfo.isConnected;
    if (mounted) {
      setState(() {
        hasInternet = connected;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("My playlist (favourites)"),
          iconTheme: IconThemeData(color: cWhiteColor),
          backgroundColor: cFirstColor,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.featured_play_list_outlined,
                        size: 200,
                        color: Colors.black.withAlpha(10),
                      )),
                  Column(
                    children: [
                      Playlist(hasInternet: hasInternet),
                    ],
                  ),
                ],
              )),
        ));
  }
}
