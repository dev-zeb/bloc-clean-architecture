import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/usecase/get_products.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProducts getProducts;
  final NetworkInfo networkInfo;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _autoFetchTimer;

  ProductBloc({
    required this.getProducts,
    required this.networkInfo,
  }) : super(const ProductState()) {
    on<ProductStarted>(_onStarted);
    on<ProductNextPageRequested>(_onNextPageRequested);
    on<ProductRefreshRequested>(_onRefreshRequested);
    on<ProductManualSyncRequested>(_onManualSyncRequested);
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
    if (!state.isOnline) return;

    if (state.hasReachedMax ||
        state.isLoadingMore ||
        state.isRefreshing ||
        state.status != ProductStatus.success) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    await _loadPage(
      emit: emit,
      page: state.currentPage,
      forceRefresh: false,
      replaceItems: false,
    );
  }

  Future<void> _onRefreshRequested(
      ProductRefreshRequested event,
      Emitter<ProductState> emit,
      ) async {
    if (state.isRefreshing) return;

    emit(state.copyWith(isRefreshing: true));

    await _loadPage(
      emit: emit,
      page: 0,
      forceRefresh: true,
      replaceItems: true,
    );
  }

  Future<void> _onManualSyncRequested(
      ProductManualSyncRequested event,
      Emitter<ProductState> emit,
      ) async {
    if (state.isRefreshing) return;

    emit(state.copyWith(isRefreshing: true));

    await _loadPage(
      emit: emit,
      page: 0,
      forceRefresh: true,
      replaceItems: true,
    );
  }

  Future<void> _onConnectivityChanged(
      ProductConnectivityChanged event,
      Emitter<ProductState> emit,
      ) async {
    final wasOffline = !state.isOnline;

    emit(state.copyWith(isOnline: event.isOnline));

    if (wasOffline && event.isOnline && !state.isRefreshing) {
      add(const ProductManualSyncRequested());
    }
  }

  Future<void> _loadPage({
    required Emitter<ProductState> emit,
    required int page,
    required bool forceRefresh,
    required bool replaceItems,
  }) async {
    final result = await getProducts(
      page: page,
      limit: AppConstants.paginationLimit,
      forceRefresh: forceRefresh,
    );

    result.match(
          (failure) {
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

        emit(
          state.copyWith(
            status: ProductStatus.failure,
            isLoadingMore: false,
            isRefreshing: false,
            message: failure.message,
          ),
        );
      },
          (pageData) {
        final items = pageData.isFromCache || replaceItems
            ? pageData.products
            : [...state.products, ...pageData.products];

        if (items.isEmpty) {
          emit(
            state.copyWith(
              status: ProductStatus.empty,
              products: [],
              isLoadingMore: false,
              isRefreshing: false,
              isFromCache: pageData.isFromCache,
              hasReachedMax: true,
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: ProductStatus.success,
            products: items,
            currentPage: pageData.currentPage,
            totalPages: pageData.totalPages,
            totalItems: pageData.totalItems,
            hasReachedMax: pageData.isFromCache || items.length >= pageData.totalItems,
            isLoadingMore: false,
            isRefreshing: false,
            isFromCache: pageData.isFromCache,
            message: '',
          ),
        );
      },
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

        if (isOnline && !state.isRefreshing && !state.isLoadingMore) {
          add(const ProductRefreshRequested());
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