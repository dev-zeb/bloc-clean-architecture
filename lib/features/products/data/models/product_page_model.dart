import '../../domain/entities/product_page.dart';
import 'product_model.dart';

class ProductPageModel extends ProductPage {
  const ProductPageModel({
    required List<ProductModel> super.products,
    required super.totalItems,
    required super.limit,
    required super.skip,
    required super.isFromCache,
  });

  factory ProductPageModel.fromJson(Map<String, dynamic> json) {
    final productsJson = json['products'] as List<dynamic>? ?? [];

    return ProductPageModel(
      products: productsJson
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalItems: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 10,
      skip: json['skip'] as int? ?? 0,
      isFromCache: false,
    );
  }

  factory ProductPageModel.fromCache({
    required List<ProductModel> products,
    required int totalItems,
    required int limit,
    required int skip,
  }) {
    return ProductPageModel(
      products: products,
      totalItems: totalItems,
      limit: limit,
      skip: skip,
      isFromCache: true,
    );
  }
}
