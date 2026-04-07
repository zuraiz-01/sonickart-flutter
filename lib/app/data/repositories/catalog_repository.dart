import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class CatalogRepository {
  CatalogRepository(this._apiService);

  final ApiService _apiService;

  Future<List<CategoryModel>> fetchCategories() async {
    debugPrint('CatalogRepository.fetchCategories: request started');
    final response = await _apiService.get(endpoint: ApiConstants.categories);
    final list = (response['data'] as List? ?? [])
        .map((item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    debugPrint('CatalogRepository.fetchCategories: loaded ${list.length} categories');
    return list;
  }

  Future<List<ProductModel>> fetchProductsByCategory(String categoryId) async {
    debugPrint(
      'CatalogRepository.fetchProductsByCategory: request started for $categoryId',
    );
    final response = await _apiService.get(
      endpoint: ApiConstants.productsByCategory(categoryId),
    );
    final list = (response['data'] as List? ?? [])
        .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    debugPrint(
      'CatalogRepository.fetchProductsByCategory: loaded ${list.length} products for $categoryId',
    );
    return list;
  }
}
