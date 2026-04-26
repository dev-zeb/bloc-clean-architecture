import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_page.dart';
import '../../domain/usecase/get_products.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProducts getProducts;
  final NetworkInfo networkInfo;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _autoFetchTimer;
  bool _offlinePaginationNoticeShown = false;

  ProductBloc({
    required this.getProducts,
    required this.networkInfo,
  }) : super(const ProductState()) {
    on<ProductStarted>(_onStarted);
    on<ProductNextPageRequested>(_onNextPageRequested);
    on<ProductRefreshRequested>(_onRefreshRequested);
    on<ProductManualSyncRequested>(_onManualSyncRequested);
    on<ProductAutoSyncRequested>(_onAutoSyncRequested);
    on<ProductConnectivityChanged>(_onConnectivityChanged);
  }

  Future<void> _onStarted(
    ProductStarted event,
    Emitter<ProductState> emit,
  ) async {
    final isOnline = await networkInfo.isConnected;

    emit(
      state.copyWith(
        status: ProductStatus.loading,
        isOnline: isOnline,
      ),
    );

    _listenToConnectivity();
    _startAutoFetch();

    await _loadPage(
      emit: emit,
      page: 0,
      forceRefresh: false,
      replaceItems: true,
    );
  }

  Future<void> _onNextPageRequested(
    ProductNextPageRequested event,
    Emitter<ProductState> emit,
  ) async {
    if (state.hasReachedMax ||
        state.isLoadingMore ||
        state.isRefreshing ||
        state.status != ProductStatus.success) {
      return;
    }

    if (!state.isOnline && _offlinePaginationNoticeShown) return;

    emit(state.copyWith(isLoadingMore: true));

    final loaded = await _loadPage(
      emit: emit,
      page: state.currentPage,
      forceRefresh: false,
      replaceItems: false,
      keepExistingOnFailure: true,
    );

    if (!state.isOnline && !loaded) {
      _offlinePaginationNoticeShown = true;
    }
  }

  Future<void> _onRefreshRequested(
    ProductRefreshRequested event,
    Emitter<ProductState> emit,
  ) async {
    if (state.isRefreshing) return;

    final isOnline = await networkInfo.isConnected;

    if (!isOnline) {
      emit(
        _withNotice(
          state.copyWith(isOnline: false),
          ProductNoticeType.fetchFailed,
          'Failed to refresh products. Check your internet connection.',
        ),
      );
      return;
    }

    await _syncLoadedPages(emit);
  }

  Future<void> _onManualSyncRequested(
    ProductManualSyncRequested event,
    Emitter<ProductState> emit,
  ) async {
    await _syncLoadedPages(emit);
  }

  Future<void> _onAutoSyncRequested(
    ProductAutoSyncRequested event,
    Emitter<ProductState> emit,
  ) async {
    await _syncLoadedPages(emit);
  }

  Future<void> _onConnectivityChanged(
    ProductConnectivityChanged event,
    Emitter<ProductState> emit,
  ) async {
    final wasOffline = !state.isOnline;

    _offlinePaginationNoticeShown = false;

    if (!event.isOnline) {
      emit(
        _withNotice(
          state.copyWith(isOnline: false, isLoadingMore: false),
          ProductNoticeType.connectionLost,
          'Internet connection lost.',
        ),
      );
      return;
    }

    emit(
      wasOffline
          ? _withNotice(
              state.copyWith(isOnline: true),
              ProductNoticeType.connectionRestored,
              'Internet connection restored.',
            )
          : state.copyWith(isOnline: true),
    );

    if (wasOffline && !state.isRefreshing) {
      await _syncLoadedPages(emit);
    }
  }

  Future<bool> _loadPage({
    required Emitter<ProductState> emit,
    required int page,
    required bool forceRefresh,
    required bool replaceItems,
    bool keepExistingOnFailure = false,
    bool clearCacheOnRefresh = true,
  }) async {
    final result = await getProducts(
      page: page,
      limit: AppConstants.paginationLimit,
      forceRefresh: forceRefresh,
      clearCacheOnRefresh: clearCacheOnRefresh,
    );

    return result.match(
      (failure) {
        _emitFailure(
          emit,
          failure,
          keepExistingProducts: keepExistingOnFailure,
        );
        return false;
      },
      (pageData) {
        final items = replaceItems
            ? List<Product>.from(pageData.products)
            : _mergeProducts(state.products, pageData.products);

        if (items.isEmpty) {
          emit(
            state.copyWith(
              status: ProductStatus.empty,
              products: [],
              isLoadingMore: false,
              isRefreshing: false,
              isFromCache: pageData.isFromCache,
              hasReachedMax: true,
              isOnline: !pageData.isFromCache || state.isOnline,
              message: '',
            ),
          );
          return true;
        }

        emit(
          state.copyWith(
            status: ProductStatus.success,
            products: items,
            currentPage: replaceItems
                ? pageData.currentPage
                : max(state.currentPage, pageData.currentPage),
            totalPages: pageData.totalPages,
            totalItems: pageData.totalItems,
            hasReachedMax: items.length >= pageData.totalItems,
            isLoadingMore: false,
            isRefreshing: false,
            isOnline: !pageData.isFromCache || state.isOnline,
            isFromCache: pageData.isFromCache,
            message: '',
          ),
        );
        return true;
      },
    );
  }

  Future<void> _syncLoadedPages(Emitter<ProductState> emit) async {
    if (state.isRefreshing || state.isLoadingMore) return;

    final isOnline = await networkInfo.isConnected;

    if (!isOnline) {
      emit(
        _withNotice(
          state.copyWith(isOnline: false),
          ProductNoticeType.fetchFailed,
          'Failed to fetch products. Check your internet connection.',
        ),
      );
      return;
    }

    if (state.products.isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.loading,
          isOnline: true,
        ),
      );

      await _loadPage(
        emit: emit,
        page: 0,
        forceRefresh: true,
        replaceItems: true,
        clearCacheOnRefresh: true,
      );
      return;
    }

    final loadedPageCount = max(
      1,
      (state.products.length / AppConstants.paginationLimit).ceil(),
    );

    emit(
      state.copyWith(
        isRefreshing: true,
        isOnline: true,
      ),
    );

    final syncedProducts = <Product>[];
    ProductPage? latestPage;

    for (var page = 0; page < loadedPageCount; page++) {
      final result = await getProducts(
        page: page,
        limit: AppConstants.paginationLimit,
        forceRefresh: page == 0,
        clearCacheOnRefresh: false,
      );

      Failure? pageFailure;
      ProductPage? pageData;

      result.match(
        (failure) => pageFailure = failure,
        (data) => pageData = data,
      );

      if (pageFailure != null) {
        _emitFailure(
          emit,
          pageFailure!,
          keepExistingProducts: true,
        );
        return;
      }

      final data = pageData;
      if (data == null) continue;

      latestPage = data;
      syncedProducts.addAll(data.products);

      if (syncedProducts.length >= data.totalItems) break;
    }

    final pageData = latestPage;

    if (pageData == null || syncedProducts.isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.empty,
          products: [],
          isRefreshing: false,
          hasReachedMax: true,
          message: '',
        ),
      );
      return;
    }

    final items = _mergeProducts(const [], syncedProducts);
    final currentPage = max(
      1,
      (items.length / AppConstants.paginationLimit).ceil(),
    );

    emit(
      state.copyWith(
        status: ProductStatus.success,
        products: items,
        currentPage: currentPage,
        totalPages: pageData.totalPages,
        totalItems: pageData.totalItems,
        hasReachedMax: items.length >= pageData.totalItems,
        isLoadingMore: false,
        isRefreshing: false,
        isOnline: !pageData.isFromCache || state.isOnline,
        isFromCache: pageData.isFromCache,
        message: '',
      ),
    );
  }

  List<Product> _mergeProducts(
    List<Product> existing,
    List<Product> incoming,
  ) {
    final productsById = <int, Product>{
      for (final product in existing) product.id: product,
    };

    for (final product in incoming) {
      productsById[product.id] = product;
    }

    return productsById.values.toList();
  }

  void _emitFailure(
    Emitter<ProductState> emit,
    Failure failure, {
    required bool keepExistingProducts,
  }) {
    if (failure is UnauthorizedFailure) {
      emit(
        state.copyWith(
          status: ProductStatus.unauthorized,
          isLoadingMore: false,
          isRefreshing: false,
          message: failure.message,
        ),
      );
      return;
    }

    final canKeepExistingProducts =
        keepExistingProducts && state.products.isNotEmpty;
    final message = state.isOnline
        ? failure.message
        : 'Failed to fetch products. Check your internet connection.';

    emit(
      _withNotice(
        state.copyWith(
          status: canKeepExistingProducts
              ? ProductStatus.success
              : ProductStatus.failure,
          isLoadingMore: false,
          isRefreshing: false,
          message: message,
        ),
        ProductNoticeType.fetchFailed,
        message,
      ),
    );
  }

  ProductState _withNotice(
    ProductState base,
    ProductNoticeType type,
    String message,
  ) {
    return base.copyWith(
      notificationId: base.notificationId + 1,
      notificationType: type,
      notificationMessage: message,
    );
  }

  void _listenToConnectivity() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = networkInfo.onStatusChange.listen(
      (isOnline) => add(ProductConnectivityChanged(isOnline)),
    );
  }

  void _startAutoFetch() {
    _autoFetchTimer?.cancel();

    _autoFetchTimer = Timer.periodic(
      AppConstants.cacheDuration,
      (_) async {
        final isOnline = await networkInfo.isConnected;

        if (isOnline &&
            state.isOnline &&
            !state.isRefreshing &&
            !state.isLoadingMore) {
          add(const ProductAutoSyncRequested());
        }
      },
    );
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _autoFetchTimer?.cancel();
    return super.close();
  }
}
