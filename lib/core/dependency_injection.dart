import 'package:audio_service/audio_service.dart';
import 'package:goz_player/features/home/data/datasources/music_local_datasource.dart';
import 'package:goz_player/features/home/data/datasources/home_remote_datasource.dart';
import 'package:goz_player/features/home/data/repositories/home_repository_impl.dart';
import 'package:goz_player/features/home/domain/repositories/home_repository.dart';
import 'package:goz_player/features/home/domain/usecases/u_music_detailed.dart';
import 'package:goz_player/features/home/presentation/bloc/music_detailed/music_detailed_bloc.dart';
import 'package:goz_player/features/home/presentation/bloc/music_home/music_home_bloc.dart';
import 'package:goz_player/features/player/audio_handler.dart';
import 'package:goz_player/features/player/page_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/app_interceptor.dart';
import 'network/network_info.dart';

final di = GetIt.instance;

Future<void> init() async {
  debugPrint('=========== Dependency injection initializing.... ===========');

  ///Register network info
  di.registerLazySingleton(() => InternetConnectionChecker());
  di.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(di()));

  /// Local cache

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  di.registerFactory(() => prefs);

  ///Database
  di.registerSingletonAsync<MusicLocalDatasource>(() async {
    final musicDb = MusicLocalDatasource();
    await musicDb.isar;
    return musicDb;
  });

  ///Audio services
  // services
  final audioHandler = await initAudioService();
  di.registerSingleton<AudioHandler>(audioHandler);
  // page state
  final pageManager = PageManager();
  await pageManager.init();
  di.registerSingleton<PageManager>(pageManager);

  ///Versioning
  // PackageInfo packageInfo = await PackageInfo.fromPlatform();
  // APP_VERSION = packageInfo.version;

  final Dio dio = Dio(BaseOptions(
    // baseUrl: 'baseUrl',
    connectTimeout: Duration(seconds: 60),
    receiveTimeout: Duration(seconds: 60),
  ));
  dio.interceptors.add(AppInterceptor());

  /// Network
  di.registerLazySingleton<Dio>(() => dio);

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  di.registerLazySingleton(() => navigatorKey);

  ///BLOCK

  di.registerFactory(
    () => MusicHomeBloc(
      dio: di(),
      networkInfo: di(),
    ),
  );

  di.registerFactory(
    () => MusicDetailedBloc(
      dio: di(),
      networkInfo: di(),
      pageManager: di(),
      uMusicDetailedDownload: di(),
    ),
  );

  ///Repositories

  di.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(
      homeRemoteDatasourceImpl: di(),
      networkInfo: di()));

  ///Use Cases

  di.registerLazySingleton(() => UMusicDetailedDownload(homeRepository: di()));

  ///Data sources

  //Home remote datasource
  di.registerLazySingleton(() => HomeRemoteDatasourceImpl(
      client: di(), database: di(), pageManager: di()));

  debugPrint('=========== Dependency injection initializing finished ===========');
}
