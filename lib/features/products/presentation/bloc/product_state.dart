import 'package:equatable/equatable.dart';

import '../../domain/entities/product.dart';

enum ProductStatus { initial, loading, success, empty, failure, unauthorized }

enum ProductNoticeType {
  none,
  connectionLost,
  connectionRestored,
  fetchFailed,
}

class ProductState extends Equatable {
  final ProductStatus status;
  final List<Product> products;
  final String message;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool isOnline;
  final bool isFromCache;
  final int notificationId;
  final ProductNoticeType notificationType;
  final String notificationMessage;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.message = '',
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isOnline = true,
    this.isFromCache = false,
    this.notificationId = 0,
    this.notificationType = ProductNoticeType.none,
    this.notificationMessage = '',
  });

  ProductState copyWith({
    ProductStatus? status,
    List<Product>? products,
    String? message,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isOnline,
    bool? isFromCache,
    int? notificationId,
    ProductNoticeType? notificationType,
    String? notificationMessage,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      message: message ?? this.message,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isOnline: isOnline ?? this.isOnline,
      isFromCache: isFromCache ?? this.isFromCache,
      notificationId: notificationId ?? this.notificationId,
      notificationType: notificationType ?? this.notificationType,
      notificationMessage: notificationMessage ?? this.notificationMessage,
    );
  }

  bool get hasMoreProducts => totalItems == 0 || products.length < totalItems;

  @override
  List<Object?> get props => [
        status,
        products,
        message,
        currentPage,
        totalPages,
        totalItems,
        hasReachedMax,
        isLoadingMore,
        isRefreshing,
        isOnline,
        isFromCache,
        notificationId,
        notificationType,
        notificationMessage,
      ];
}
