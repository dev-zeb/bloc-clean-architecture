import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'network_info.dart';

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker checker;

  const NetworkInfoImpl(this.checker);

  @override
  Future<bool> get isConnected => checker.hasConnection;

  @override
  Stream<bool> get onStatusChange {
    return checker.onStatusChange.map(
      (status) => status == InternetConnectionStatus.connected,
    );
  }
}
