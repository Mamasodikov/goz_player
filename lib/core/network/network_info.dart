import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker dataConnectionChecker;
  final Connectivity _connectivity = Connectivity();

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();

  NetworkInfoImpl(this.dataConnectionChecker) {
    _connectivity.onConnectivityChanged.listen((result) async {
      final hasConnection = await dataConnectionChecker.hasConnection;
      _connectivityController.add(hasConnection);
    });
  }

  @override
  Future<bool> get isConnected => dataConnectionChecker.hasConnection;

  @override
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;
}