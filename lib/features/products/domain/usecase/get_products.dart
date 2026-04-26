import '../../../../core/utils/typedef.dart';
import '../entities/product_page.dart';
import '../repositories/product_repository.dart';

class GetProducts {
  final ProductRepository repository;

  const GetProducts(this.repository);

  ResultFuture<ProductPage> call({
    required int page,
    required int limit,
    bool forceRefresh = false,
    bool clearCacheOnRefresh = true,
  }) {
    return repository.getProducts(
      page: page,
      limit: limit,
      forceRefresh: forceRefresh,
      clearCacheOnRefresh: clearCacheOnRefresh,
    );
  }
}
