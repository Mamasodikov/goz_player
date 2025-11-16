import 'package:goz_player/core/dependency_injection.dart';
import 'package:goz_player/core/widgets/custom_toast.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:goz_player/core/utils/functions.dart';
import 'package:goz_player/features/home/data/models/music_model.dart';
import 'package:goz_player/features/home/presentation/bloc/music_detailed/music_detailed_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MusicDetailedPage extends StatefulWidget {
  final Music? music;

  const MusicDetailedPage({super.key, required this.music});

  static Widget screen(Music? music) {
    return BlocProvider(
      create: (context) => di<MusicDetailedBloc>(),
      child: MusicDetailedPage(music: music),
    );
  }

  @override
  State<MusicDetailedPage> createState() => _MusicDetailedPageState();
}

class _MusicDetailedPageState extends State<MusicDetailedPage> {
  @override
  void initState() {
    super.initState();
    BlocProvider.of<MusicDetailedBloc>(context)
        .add(LoadMusicEvent(music: widget.music));
  }

  @override
  Widget build(BuildContext context) {
    final music = widget.music;

    return Scaffold(
      appBar: AppBar(
        title: Text("Music Details"),
        iconTheme: IconThemeData(color: cWhiteColor),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20.0),
            Center(
              child: Container(
                decoration: BoxDecoration(boxShadow: [boxShadow60]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    music?.coverUrl ?? '',
                    height: 250.0,
                    width: 200.0,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              music?.title ?? '-',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            BlocConsumer<MusicDetailedBloc, MusicDetailedState>(
              listener: (context, state) {
                if (state.status == MusicDetailedStatus.failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Operation failed. Please try again.')),
                  );
                } else if (state.status == MusicDetailedStatus.noInternet) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No internet connection.')),
                  );
                } else if (state.status == MusicDetailedStatus.success &&
                    state.isDownloaded) {
                  CustomToast.showToast(
                      '${music?.title} downloaded successfully!');
                }
              },
              builder: (context, state) {
                return Column(
                  children: [
                    if (!state.isDownloaded)
                      ElevatedButton(
                        onPressed: state.status == MusicDetailedStatus.loading
                            ? null
                            : () {
                                BlocProvider.of<MusicDetailedBloc>(context)
                                    .add(DownloadMusicEvent(music: music));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: Size(200, 45),
                        ),
                        child: state.status == MusicDetailedStatus.loading
                            ? const CupertinoActivityIndicator()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.download, color: cWhiteColor),
                                  SizedBox(width: 8),
                                  Text(
                                    'Download',
                                    style: TextStyle(color: cWhiteColor),
                                  ),
                                ],
                              ),
                      ),
                    if (state.isDownloaded) ...[
                      ElevatedButton(
                        onPressed: state.status == MusicDetailedStatus.loading
                            ? null
                            : () async {
                                var result = await showAlertText(
                                        context, "Delete downloaded file?") ??
                                    false;
                                if (result) {
                                  BlocProvider.of<MusicDetailedBloc>(context)
                                      .add(RemoveMusicEvent(music: music));
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: Size(200, 45),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: cWhiteColor),
                            SizedBox(width: 8),
                            Text(
                              'Delete Download',
                              style: TextStyle(color: cWhiteColor),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Downloaded',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20.0),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                loremIpsumText,
                style: const TextStyle(
                    fontSize: 15.0, fontStyle: FontStyle.italic),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
