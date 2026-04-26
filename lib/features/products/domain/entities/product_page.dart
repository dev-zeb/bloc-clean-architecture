import 'package:equatable/equatable.dart';

import 'product.dart';

class ProductPage extends Equatable {
  final List<Product> products;
  final int totalItems;
  final int limit;
  final int skip;
  final bool isFromCache;

  const ProductPage({
    required this.products,
    required this.totalItems,
    required this.limit,
    required this.skip,
    required this.isFromCache,
  });

  int get currentPage => limit == 0 ? 1 : (skip ~/ limit) + 1;

  int get totalPages => limit == 0 ? 1 : (totalItems / limit).ceil();

  bool get hasReachedMax => skip + products.length >= totalItems;

  @override
  List<Object?> get props => [products, totalItems, limit, skip, isFromCache];
}
