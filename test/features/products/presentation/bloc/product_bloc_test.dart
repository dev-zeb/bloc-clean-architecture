import 'dart:async';

import 'package:bloc_clean_architecture/core/network/network_info.dart';
import 'package:bloc_clean_architecture/features/products/domain/entities/product.dart';
import 'package:bloc_clean_architecture/features/products/domain/entities/product_page.dart';
import 'package:bloc_clean_architecture/features/products/domain/usecase/get_products.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_bloc.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_event.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetProducts extends Mock implements GetProducts {}

class TestNetworkInfo implements NetworkInfo {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool connected;

  TestNetworkInfo({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

void main() {
  late MockGetProducts getProducts;
  late TestNetworkInfo networkInfo;
  late ProductBloc bloc;

  setUp(() {
    getProducts = MockGetProducts();
    networkInfo = TestNetworkInfo();
    bloc = ProductBloc(
      getProducts: getProducts,
      networkInfo: networkInfo,
    );

    when(
      () => getProducts(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        forceRefresh: any(named: 'forceRefresh'),
        clearCacheOnRefresh: any(named: 'clearCacheOnRefresh'),
      ),
    ).thenAnswer((invocation) async {
      final page = invocation.namedArguments[#page] as int;
      final limit = invocation.namedArguments[#limit] as int;

      return right(_productPage(page: page, limit: limit));
    });
  });

  tearDown(() async {
    await bloc.close();
    await networkInfo.close();
  });

  test('keeps already loaded products after connection is restored', () async {
    bloc.add(const ProductStarted());
    await pumpEventQueue();

    expect(bloc.state.status, ProductStatus.success);
    expect(bloc.state.products.length, 10);

    for (var i = 0; i < 4; i++) {
      bloc.add(const ProductNextPageRequested());
      await pumpEventQueue();
    }

    expect(bloc.state.products.length, 50);
    expect(bloc.state.currentPage, 5);

    networkInfo.emit(false);
    await pumpEventQueue();

    expect(bloc.state.isOnline, isFalse);
    expect(bloc.state.products.length, 50);

    networkInfo.emit(true);
    await pumpEventQueue(times: 10);

    expect(bloc.state.isOnline, isTrue);
    expect(bloc.state.status, ProductStatus.success);
    expect(bloc.state.products.length, 50);
    expect(bloc.state.currentPage, 5);
  });

  test('pull refresh refreshes loaded pages without shrinking the list',
      () async {
    await _startAndLoadPages(bloc, pageCount: 6);

    expect(bloc.state.products.length, 60);
    expect(bloc.state.currentPage, 6);

    bloc.add(const ProductRefreshRequested());
    await pumpEventQueue(times: 20);

    expect(bloc.state.status, ProductStatus.success);
    expect(bloc.state.products.length, 60);
    expect(bloc.state.currentPage, 6);
  });

  test('can load the next page after reconnect sync finishes', () async {
    await _startAndLoadPages(bloc, pageCount: 8);

    networkInfo.emit(false);
    await pumpEventQueue();

    networkInfo.emit(true);
    await pumpEventQueue(times: 20);

    expect(bloc.state.products.length, 80);
    expect(bloc.state.currentPage, 8);

    bloc.add(const ProductNextPageRequested());
    await pumpEventQueue();

    expect(bloc.state.status, ProductStatus.success);
    expect(bloc.state.products.length, 90);
    expect(bloc.state.currentPage, 9);
  });
}

Future<void> _startAndLoadPages(
  ProductBloc bloc, {
  required int pageCount,
}) async {
  bloc.add(const ProductStarted());
  await pumpEventQueue();

  for (var page = 1; page < pageCount; page++) {
    bloc.add(const ProductNextPageRequested());
    await pumpEventQueue();
  }
}

ProductPage _productPage({required int page, required int limit}) {
  final skip = page * limit;
  final products = List<Product>.generate(
    limit,
    (index) {
      final id = skip + index + 1;

      return Product(
        id: id,
        title: 'Product $id',
        description: 'Description $id',
        category: 'category',
        price: id.toDouble(),
        rating: 4,
        thumbnail: 'https://example.com/product-$id.png',
      );
    },
  );

  return ProductPage(
    products: products,
    totalItems: 194,
    limit: limit,
    skip: skip,
    isFromCache: false,
  );
}
