import 'package:audio_service/audio_service.dart';
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

  ///Audio services

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

  ///Repositories

  ///Use Cases

  ///Data sources

  //Home remote datasource

  debugPrint('=========== Dependency injection initializing finished ===========');
}
