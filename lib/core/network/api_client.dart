import 'package:dio/dio.dart';

import '../error/exceptions.dart';

class ApiClient {
  final Dio dio;

  const ApiClient(this.dio);

  Future<Response<dynamic>> get(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) async {
    try {
      return await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 401 || statusCode == 403) {
        throw const UnauthorizedException();
      }

      throw ServerException(_getErrorMessage(e));
    } catch (_) {
      throw const ServerException('Unexpected error occurred.');
    }
  }

  String _getErrorMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? 'Server error occurred.';
    }

    return e.message ?? 'Server error occurred.';
  }
}