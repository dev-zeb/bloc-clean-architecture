import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product_page.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_data_source.dart';
import '../datasources/product_remote_data_source.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  const ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ProductPage>> getProducts({
    required int page,
    required int limit,
    bool forceRefresh = false,
    bool clearCacheOnRefresh = true,
  }) async {
    final skip = page * limit;
    final isOnline = await networkInfo.isConnected;

    if (!isOnline) {
      return _getCache(limit: limit, skip: skip);
    }

    final lastFetchedAt = await localDataSource.getLastFetchedAt();
    final isCacheExpired = lastFetchedAt == null ||
        DateTime.now().difference(lastFetchedAt) > AppConstants.cacheDuration;

    final shouldFetchRemote = forceRefresh || isCacheExpired || page > 0;

    if (!shouldFetchRemote) {
      return _getCache(limit: limit, skip: skip);
    }

    try {
      final remotePage = await remoteDataSource.getProducts(
        limit: limit,
        skip: skip,
      );

      if (page == 0 && forceRefresh && clearCacheOnRefresh) {
        await localDataSource.clearProducts();
      }

      await localDataSource.cacheProducts(
        products: remotePage.products.cast<ProductModel>(),
        page: page,
        totalItems: remotePage.totalItems,
      );

      return right(remotePage);
    } on UnauthorizedException {
      return left(const UnauthorizedFailure());
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return left(CacheFailure(e.message));
    } catch (_) {
      return left(
        const ServerFailure('Something went wrong. Please try again.'),
      );
    }
  }

  Future<Either<Failure, ProductPage>> _getCache({
    required int limit,
    required int skip,
  }) async {
    try {
      final cachedPage = await localDataSource.getCachedProducts(
        limit: limit,
        skip: skip,
      );

      if (cachedPage.products.isEmpty) {
        return left(const CacheFailure('No cached products available.'));
      }

      return right(cachedPage);
    } on CacheException catch (e) {
      return left(CacheFailure(e.message));
    } catch (_) {
      return left(const CacheFailure('Unable to load cached products.'));
    }
  }
}
