import 'package:bloc_clean_architecture/core/network/network_info.dart';
import 'package:bloc_clean_architecture/features/products/data/datasources/product_local_data_source.dart';
import 'package:bloc_clean_architecture/features/products/data/datasources/product_remote_data_source.dart';
import 'package:bloc_clean_architecture/features/products/data/models/product_model.dart';
import 'package:bloc_clean_architecture/features/products/data/models/product_page_model.dart';
import 'package:bloc_clean_architecture/features/products/data/repositories/product_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProductRemoteDataSource extends Mock
    implements ProductRemoteDataSource {}

class MockProductLocalDataSource extends Mock
    implements ProductLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockProductRemoteDataSource remoteDataSource;
  late MockProductLocalDataSource localDataSource;
  late MockNetworkInfo networkInfo;
  late ProductRepositoryImpl repository;

  const product = ProductModel(
    id: 1,
    title: 'Product',
    description: 'Description',
    category: 'beauty',
    price: 12,
    rating: 4.5,
    thumbnail: 'https://example.com/product.png',
  );

  const page = ProductPageModel(
    products: [product],
    totalItems: 1,
    limit: 10,
    skip: 0,
    isFromCache: false,
  );

  setUp(() {
    remoteDataSource = MockProductRemoteDataSource();
    localDataSource = MockProductLocalDataSource();
    networkInfo = MockNetworkInfo();

    repository = ProductRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
  });

  test('fetches and caches remote data without clearing cache during sync',
      () async {
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => localDataSource.getLastFetchedAt())
        .thenAnswer((_) async => DateTime.now());
    when(() => remoteDataSource.getProducts(limit: 10, skip: 0))
        .thenAnswer((_) async => page);
    when(
      () => localDataSource.cacheProducts(
        products: any(named: 'products'),
        page: any(named: 'page'),
        totalItems: any(named: 'totalItems'),
      ),
    ).thenAnswer((_) async {});

    final result = await repository.getProducts(
      page: 0,
      limit: 10,
      forceRefresh: true,
      clearCacheOnRefresh: false,
    );

    result.match(
      (failure) => fail('Expected products, got ${failure.message}'),
      (pageData) => expect(pageData.products, [product]),
    );

    verifyNever(() => localDataSource.clearProducts());
    final captured = verify(
      () => localDataSource.cacheProducts(
        products: captureAny(named: 'products'),
        page: 0,
        totalItems: 1,
      ),
    ).captured;

    expect(captured.single, [product]);
  });
}
