import '../../../../core/utils/typedef.dart';
import '../entities/product_page.dart';

abstract class ProductRepository {
  ResultFuture<ProductPage> getProducts({
    required int page,
    required int limit,
    bool forceRefresh = false,
    bool clearCacheOnRefresh = true,
  });
}
