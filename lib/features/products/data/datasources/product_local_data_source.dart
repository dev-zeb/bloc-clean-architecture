import 'package:hive/hive.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/product_model.dart';
import '../models/product_page_model.dart';

abstract class ProductLocalDataSource {
  Future<ProductPageModel> getCachedProducts({
    required int limit,
    required int skip,
  });

  Future<DateTime?> getLastFetchedAt();

  Future<void> cacheProducts({
    required List<ProductModel> products,
    required int page,
    required int totalItems,
  });

  Future<void> clearProducts();
}

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final Box<Map> productsBox;
  final Box<Map> metaBox;

  const ProductLocalDataSourceImpl({
    required this.productsBox,
    required this.metaBox,
  });

  @override
  Future<ProductPageModel> getCachedProducts({
    required int limit,
    required int skip,
  }) async {
    try {
      final cachedMaps = productsBox.values.toList();

      cachedMaps.sort((a, b) {
        final pageA = a['page'] as int? ?? 0;
        final pageB = b['page'] as int? ?? 0;

        if (pageA != pageB) return pageA.compareTo(pageB);

        final idA = a['id'] as int? ?? 0;
        final idB = b['id'] as int? ?? 0;

        return idA.compareTo(idB);
      });

      final allProducts = cachedMaps.map(ProductModel.fromMap).toList();

      final meta = metaBox.get(AppConstants.productsMetaKey);
      final totalItems = meta?['totalItems'] as int? ?? allProducts.length;

      final start = skip.clamp(0, allProducts.length);
      final end = (skip + limit).clamp(0, allProducts.length);
      final paginatedProducts = allProducts.sublist(start, end);

      return ProductPageModel.fromCache(
        products: paginatedProducts,
        totalItems: totalItems,
        limit: limit,
        skip: skip,
      );
    } catch (_) {
      throw const CacheException('Failed to read cached products.');
    }
  }

  @override
  Future<DateTime?> getLastFetchedAt() async {
    final meta = metaBox.get(AppConstants.productsMetaKey);
    final rawDate = meta?['lastFetchedAt']?.toString();

    if (rawDate == null) return null;

    return DateTime.tryParse(rawDate);
  }

  @override
  Future<void> cacheProducts({
    required List<ProductModel> products,
    required int page,
    required int totalItems,
  }) async {
    try {
      final now = DateTime.now();

      final entries = <dynamic, Map<String, dynamic>>{
        for (final product in products)
          product.id: product.toMap(
            page: page,
            cachedAt: now,
          ),
      };

      final staleKeys = productsBox.keys.where((key) {
        final cachedProduct = productsBox.get(key);

        return cachedProduct?['page'] == page;
      }).toList();

      await productsBox.deleteAll(staleKeys);
      await productsBox.putAll(entries);

      await metaBox.put(
        AppConstants.productsMetaKey,
        {
          'totalItems': totalItems,
          'lastFetchedAt': now.toIso8601String(),
        },
      );
    } catch (_) {
      throw const CacheException('Failed to cache products.');
    }
  }

  @override
  Future<void> clearProducts() async {
    try {
      await productsBox.clear();
    } catch (_) {
      throw const CacheException('Failed to clear cached products.');
    }
  }
}
