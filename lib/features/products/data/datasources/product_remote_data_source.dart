import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/product_page_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductPageModel> getProducts({required int limit, required int skip});
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final ApiClient apiClient;

  const ProductRemoteDataSourceImpl(this.apiClient);

  @override
  Future<ProductPageModel> getProducts({
    required int limit,
    required int skip,
  }) async {
    final response = await apiClient.get(
      AppConstants.productsEndpoint,
      queryParameters: {'limit': limit, 'skip': skip},
    );

    return ProductPageModel.fromJson(response.data as Map<String, dynamic>);
  }
}
