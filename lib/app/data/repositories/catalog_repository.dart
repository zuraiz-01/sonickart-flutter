import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class CatalogRepository {
  CatalogRepository(this._apiService, {GetStorage? storage})
    : _storage = storage ?? GetStorage();

  final ApiService _apiService;
  final GetStorage _storage;

  Future<List<CategoryModel>> fetchCategories() async {
    debugPrint('CatalogRepository.fetchCategories: request started');
    try {
      final response = await _apiService.get(
        endpoint: ApiConstants.categories,
        authenticated: false,
      );
      final list = _extractList(response)
          .map(
            (item) =>
                CategoryModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (error) {
      debugPrint('CatalogRepository.fetchCategories: fallback after $error');
    }
    return _fallbackCategories.map(CategoryModel.fromJson).toList();
  }

  Future<List<ProductModel>> fetchProductsByCategory(String categoryId) async {
    debugPrint('CatalogRepository.fetchProductsByCategory: $categoryId');
    try {
      final response = await _apiService.get(
        endpoint: ApiConstants.productsByCategory(categoryId),
        query: {
          'categoryId': categoryId,
          'vendorId': _selectedVendorId,
          'radiusKm': 30,
        },
        authenticated: false,
      );
      final list = _extractList(response)
          .map(
            (item) =>
                ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (error) {
      debugPrint(
        'CatalogRepository.fetchProductsByCategory: fallback after $error',
      );
    }
    return _fallbackProducts
        .where((item) => item['categoryId'] == categoryId)
        .map(ProductModel.fromJson)
        .toList();
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];
    try {
      final response = await _apiService.get(
        endpoint: ApiConstants.productSearch,
        query: {
          'q': normalized,
          'query': normalized,
          'vendorId': _selectedVendorId,
          'radiusKm': 30,
        },
        authenticated: false,
      );
      final list = _extractList(response)
          .map(
            (item) =>
                ProductModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (error) {
      debugPrint('CatalogRepository.searchProducts: fallback after $error');
    }
    final lower = normalized.toLowerCase();
    return _fallbackProducts
        .map(ProductModel.fromJson)
        .where(
          (item) =>
              item.name.toLowerCase().contains(lower) ||
              item.description.toLowerCase().contains(lower) ||
              item.categoryId.toLowerCase().contains(lower),
        )
        .toList();
  }

  List _extractList(Map<String, dynamic> response) {
    final candidates = [
      response['data'],
      response['products'],
      response['categories'],
      response['items'],
      response['result'],
      response['results'],
    ];
    for (final value in candidates) {
      if (value is List) return value;
      if (value is Map) {
        for (final nested in [
          'data',
          'products',
          'categories',
          'items',
          'result',
          'results',
        ]) {
          final nestedValue = value[nested];
          if (nestedValue is List) return nestedValue;
        }
      }
    }
    return const [];
  }

  String? get _selectedVendorId {
    final value = _storage.read('selectedVendorId');
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

const _fallbackCategories = <Map<String, dynamic>>[
  {'id': 'fruits', 'name': 'Fruits', 'emoji': 'A'},
  {'id': 'vegetables', 'name': 'Vegetables', 'emoji': 'V'},
  {'id': 'dairy', 'name': 'Dairy', 'emoji': 'D'},
  {'id': 'snacks', 'name': 'Snacks', 'emoji': 'S'},
  {'id': 'bakery', 'name': 'Bakery', 'emoji': 'B'},
  {'id': 'beverages', 'name': 'Beverages', 'emoji': 'J'},
  {'id': 'frozen', 'name': 'Frozen', 'emoji': 'F'},
  {'id': 'household', 'name': 'Household', 'emoji': 'H'},
];

const _fallbackProducts = <Map<String, dynamic>>[
  {
    'id': 'p1',
    'categoryId': 'fruits',
    'name': 'Royal Gala Apple',
    'description': 'Sweet and crispy fresh apples.',
    'unit': '1 kg',
    'price': '180',
    'mrp': '220',
    'emoji': 'A',
  },
  {
    'id': 'p2',
    'categoryId': 'fruits',
    'name': 'Fresh Banana',
    'description': 'Energy packed ripe bananas.',
    'unit': '12 pcs',
    'price': '120',
    'mrp': '140',
    'emoji': 'B',
  },
  {
    'id': 'p3',
    'categoryId': 'vegetables',
    'name': 'Tomato',
    'description': 'Farm fresh red tomatoes.',
    'unit': '1 kg',
    'price': '70',
    'mrp': '90',
    'emoji': 'T',
  },
  {
    'id': 'p4',
    'categoryId': 'vegetables',
    'name': 'Potato',
    'description': 'Daily kitchen essential potatoes.',
    'unit': '1 kg',
    'price': '60',
    'mrp': '75',
    'emoji': 'P',
  },
  {
    'id': 'p5',
    'categoryId': 'dairy',
    'name': 'Full Cream Milk',
    'description': 'Pure and fresh daily milk.',
    'unit': '1 L',
    'price': '99',
    'mrp': '110',
    'emoji': 'M',
  },
  {
    'id': 'p6',
    'categoryId': 'dairy',
    'name': 'Cheddar Cheese',
    'description': 'Smooth cheese slices.',
    'unit': '200 g',
    'price': '250',
    'mrp': '290',
    'emoji': 'C',
  },
  {
    'id': 'p7',
    'categoryId': 'snacks',
    'name': 'Salted Chips',
    'description': 'Crunchy classic potato chips.',
    'unit': '52 g',
    'price': '35',
    'mrp': '40',
    'emoji': 'S',
  },
  {
    'id': 'p8',
    'categoryId': 'snacks',
    'name': 'Chocolate Cookies',
    'description': 'Rich chocolate chip cookies.',
    'unit': '120 g',
    'price': '85',
    'mrp': '100',
    'emoji': 'C',
  },
  {
    'id': 'p9',
    'categoryId': 'bakery',
    'name': 'Brown Bread',
    'description': 'Soft baked brown bread loaf.',
    'unit': '400 g',
    'price': '65',
    'mrp': '78',
    'emoji': 'B',
  },
  {
    'id': 'p10',
    'categoryId': 'beverages',
    'name': 'Orange Juice',
    'description': 'Refreshing fruit beverage.',
    'unit': '1 L',
    'price': '190',
    'mrp': '220',
    'emoji': 'J',
  },
  {
    'id': 'p11',
    'categoryId': 'frozen',
    'name': 'Frozen Fries',
    'description': 'Crispy golden french fries.',
    'unit': '500 g',
    'price': '280',
    'mrp': '320',
    'emoji': 'F',
  },
  {
    'id': 'p12',
    'categoryId': 'household',
    'name': 'Dish Wash Liquid',
    'description': 'Powerful cleaning for utensils.',
    'unit': '500 ml',
    'price': '210',
    'mrp': '245',
    'emoji': 'H',
  },
];
