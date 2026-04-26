import 'dart:async';

import 'package:bloc_clean_architecture/core/network/network_info.dart';
import 'package:bloc_clean_architecture/features/products/domain/entities/product.dart';
import 'package:bloc_clean_architecture/features/products/domain/entities/product_page.dart';
import 'package:bloc_clean_architecture/features/products/domain/usecase/get_products.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_bloc.dart';
import 'package:bloc_clean_architecture/features/products/presentation/bloc/product_event.dart';
import 'package:bloc_clean_architecture/main.dart';
import 'package:flutter/widgets.dart';
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
  testWidgets('shows fetched products and pagination info', (tester) async {
    final getProducts = MockGetProducts();
    final networkInfo = TestNetworkInfo();
    final bloc = ProductBloc(
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
    ).thenAnswer(
      (_) async => right(
        const ProductPage(
          products: [
            Product(
              id: 1,
              title: 'Test Product',
              description: 'A clean product card',
              category: 'beauty',
              price: 20,
              rating: 4.8,
              thumbnail: '',
            ),
          ],
          totalItems: 1,
          limit: 10,
          skip: 0,
          isFromCache: false,
        ),
      ),
    );

    await tester.pumpWidget(MyApp(productBloc: bloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('Showing 1 of 1 products • Page 1 of 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(bloc.close());
    await networkInfo.close();
  });

  testWidgets(
    'loads the next page after reconnect when already near the list end',
    (tester) async {
      final getProducts = MockGetProducts();
      final networkInfo = TestNetworkInfo();
      final bloc = ProductBloc(
        getProducts: getProducts,
        networkInfo: networkInfo,
      );

      _stubPagedProducts(getProducts);

      await tester.pumpWidget(MyApp(productBloc: bloc));
      await _pumpUntil(tester, () => bloc.state.products.length == 10);

      for (var page = 1; page < 8; page++) {
        bloc.add(const ProductNextPageRequested());
        await _pumpUntil(
            tester, () => bloc.state.products.length == (page + 1) * 10);
      }

      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pump();

      networkInfo.emit(false);
      await tester.pump();

      networkInfo.emit(true);
      await _pumpUntil(tester, () => bloc.state.products.length == 90);

      expect(bloc.state.currentPage, 9);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      unawaited(bloc.close());
      await networkInfo.close();
    },
  );

  testWidgets('scrolling near the bottom loads only one page at a time',
      (tester) async {
    final getProducts = MockGetProducts();
    final networkInfo = TestNetworkInfo();
    final bloc = ProductBloc(
      getProducts: getProducts,
      networkInfo: networkInfo,
    );

    _stubPagedProducts(getProducts);

    await tester.pumpWidget(MyApp(productBloc: bloc));
    await _pumpUntil(tester, () => bloc.state.products.length == 10);

    for (var page = 1; page < 4; page++) {
      bloc.add(const ProductNextPageRequested());
      await _pumpUntil(
        tester,
        () => bloc.state.products.length == (page + 1) * 10,
      );
    }

    expect(bloc.state.products.length, 40);

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await _pumpUntil(tester, () => bloc.state.products.length == 50);
    await tester.pump(const Duration(seconds: 1));

    expect(bloc.state.products.length, 50);
    expect(bloc.state.currentPage, 5);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(bloc.close());
    await networkInfo.close();
  });
}

void _stubPagedProducts(MockGetProducts getProducts) {
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
          thumbnail: '',
        );
      },
    );

    return right(
      ProductPage(
        products: products,
        totalItems: 194,
        limit: limit,
        skip: skip,
        isFromCache: false,
      ),
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 40; i++) {
    if (condition()) return;

    await tester.pump(const Duration(milliseconds: 50));
  }

  fail('Condition was not met before the pump limit.');
}
