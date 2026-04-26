class ServerException implements Exception {
  final String message;

  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;

  const CacheException(this.message);
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);
}
