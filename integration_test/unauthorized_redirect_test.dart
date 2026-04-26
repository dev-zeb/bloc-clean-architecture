import 'dart:async';

import 'package:bloc_clean_architecture/core/network/api_client.dart';
import 'package:bloc_clean_architecture/core/network/network_info.dart';
import 'package:bloc_clean_architecture/features/products/data/datasources/product_local_data_source.dart';
import 'package:bloc_clean_architecture/features/products/data/datasources/product_remote_data_source.dart';
import 'package:bloc_clean_architecture/features/products/data/models/product_model.dart';
import 'package:bloc_clean_architecture/features/products/data/models/product_page_model.dart';
import 'package:bloc_clean_architecture/features/products/data/repositories/product_repository_impl.dart';
import 'package:bloc_clean_architecture/features/products/domain/usecase/get_products.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_bloc.dart';
import 'package:bloc_clean_architecture/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class AlwaysOnlineNetworkInfo implements NetworkInfo {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> close() => _controller.close();
}

class InMemoryProductLocalDataSource implements ProductLocalDataSource {
  @override
  Future<void> cacheProducts({
    required List<ProductModel> products,
    required int page,
    required int totalItems,
  }) async {}

  @override
  Future<void> clearProducts() async {}

  @override
  Future<ProductPageModel> getCachedProducts({
    required int limit,
    required int skip,
  }) async {
    return ProductPageModel.fromCache(
      products: const [],
      totalItems: 0,
      limit: limit,
      skip: skip,
    );
  }

  @override
  Future<DateTime?> getLastFetchedAt() async => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('redirects to mock login page when API returns 403',
      (tester) async {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://dummyjson.com'),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 403,
                data: {'message': 'Forbidden'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final networkInfo = AlwaysOnlineNetworkInfo();

    final repository = ProductRepositoryImpl(
      remoteDataSource: ProductRemoteDataSourceImpl(ApiClient(dio)),
      localDataSource: InMemoryProductLocalDataSource(),
      networkInfo: networkInfo,
    );

    final bloc = ProductBloc(
      getProducts: GetProducts(repository),
      networkInfo: networkInfo,
    );

    addTearDown(() async {
      await bloc.close();
      await networkInfo.close();
    });

    await tester.pumpWidget(MyApp(productBloc: bloc));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Mock Login Page'), findsOneWidget);
  });
}
