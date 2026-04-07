import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';

class ApiService {
  String buildUrl(String endpoint) => '${ApiConstants.baseUrl}$endpoint';

  Future<Map<String, dynamic>> get({
    required String endpoint,
  }) async {
    debugPrint('ApiService.get: GET ${buildUrl(endpoint)}');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (endpoint == ApiConstants.categories) {
      return {
        'success': true,
        'url': buildUrl(endpoint),
        'data': _categories,
      };
    }

    if (endpoint.startsWith('/categories/') && endpoint.endsWith('/products')) {
      final categoryId = endpoint.split('/')[2];
      return {
        'success': true,
        'url': buildUrl(endpoint),
        'data': _products
            .where((item) => item['categoryId']?.toString() == categoryId)
            .toList(),
      };
    }

    return {
      'success': true,
      'url': buildUrl(endpoint),
      'data': [],
    };
  }

  Future<Map<String, dynamic>> post({
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    debugPrint('ApiService.post: POST ${buildUrl(endpoint)} payload=$data');
    await Future<void>.delayed(const Duration(milliseconds: 700));

    return {
      'success': true,
      'url': buildUrl(endpoint),
      'data': data,
    };
  }
}

const List<Map<String, String>> _categories = [
  {'id': 'fruits', 'name': 'Fruits', 'emoji': '🍎'},
  {'id': 'vegetables', 'name': 'Vegetables', 'emoji': '🥦'},
  {'id': 'dairy', 'name': 'Dairy', 'emoji': '🥛'},
  {'id': 'snacks', 'name': 'Snacks', 'emoji': '🍿'},
  {'id': 'bakery', 'name': 'Bakery', 'emoji': '🥐'},
  {'id': 'beverages', 'name': 'Beverages', 'emoji': '🥤'},
  {'id': 'frozen', 'name': 'Frozen', 'emoji': '🧊'},
  {'id': 'household', 'name': 'Household', 'emoji': '🧽'},
];

const List<Map<String, String>> _products = [
  {
    'id': 'p1',
    'categoryId': 'fruits',
    'name': 'Royal Gala Apple',
    'description': 'Sweet and crispy fresh apples.',
    'unit': '1 kg',
    'price': '180',
    'mrp': '220',
    'emoji': '🍎',
  },
  {
    'id': 'p2',
    'categoryId': 'fruits',
    'name': 'Fresh Banana',
    'description': 'Energy packed ripe bananas.',
    'unit': '12 pcs',
    'price': '120',
    'mrp': '140',
    'emoji': '🍌',
  },
  {
    'id': 'p3',
    'categoryId': 'vegetables',
    'name': 'Tomato',
    'description': 'Farm fresh red tomatoes.',
    'unit': '1 kg',
    'price': '70',
    'mrp': '90',
    'emoji': '🍅',
  },
  {
    'id': 'p4',
    'categoryId': 'vegetables',
    'name': 'Potato',
    'description': 'Daily kitchen essential potatoes.',
    'unit': '1 kg',
    'price': '60',
    'mrp': '75',
    'emoji': '🥔',
  },
  {
    'id': 'p5',
    'categoryId': 'dairy',
    'name': 'Full Cream Milk',
    'description': 'Pure and fresh daily milk.',
    'unit': '1 L',
    'price': '99',
    'mrp': '110',
    'emoji': '🥛',
  },
  {
    'id': 'p6',
    'categoryId': 'dairy',
    'name': 'Cheddar Cheese',
    'description': 'Smooth cheese slices.',
    'unit': '200 g',
    'price': '250',
    'mrp': '290',
    'emoji': '🧀',
  },
  {
    'id': 'p7',
    'categoryId': 'snacks',
    'name': 'Salted Chips',
    'description': 'Crunchy classic potato chips.',
    'unit': '52 g',
    'price': '35',
    'mrp': '40',
    'emoji': '🍟',
  },
  {
    'id': 'p8',
    'categoryId': 'snacks',
    'name': 'Chocolate Cookies',
    'description': 'Rich chocolate chip cookies.',
    'unit': '120 g',
    'price': '85',
    'mrp': '100',
    'emoji': '🍪',
  },
  {
    'id': 'p9',
    'categoryId': 'bakery',
    'name': 'Brown Bread',
    'description': 'Soft baked brown bread loaf.',
    'unit': '400 g',
    'price': '65',
    'mrp': '78',
    'emoji': '🍞',
  },
  {
    'id': 'p10',
    'categoryId': 'bakery',
    'name': 'Butter Croissant',
    'description': 'Flaky fresh butter croissant.',
    'unit': '2 pcs',
    'price': '110',
    'mrp': '135',
    'emoji': '🥐',
  },
  {
    'id': 'p11',
    'categoryId': 'beverages',
    'name': 'Orange Juice',
    'description': 'Refreshing fruit beverage.',
    'unit': '1 L',
    'price': '190',
    'mrp': '220',
    'emoji': '🧃',
  },
  {
    'id': 'p12',
    'categoryId': 'beverages',
    'name': 'Soft Drink',
    'description': 'Chilled fizzy drink.',
    'unit': '1.5 L',
    'price': '130',
    'mrp': '150',
    'emoji': '🥤',
  },
  {
    'id': 'p13',
    'categoryId': 'frozen',
    'name': 'Frozen Fries',
    'description': 'Crispy golden french fries.',
    'unit': '500 g',
    'price': '280',
    'mrp': '320',
    'emoji': '🧊',
  },
  {
    'id': 'p14',
    'categoryId': 'frozen',
    'name': 'Chicken Nuggets',
    'description': 'Quick snack ready nuggets.',
    'unit': '400 g',
    'price': '390',
    'mrp': '430',
    'emoji': '🍗',
  },
  {
    'id': 'p15',
    'categoryId': 'household',
    'name': 'Dish Wash Liquid',
    'description': 'Powerful cleaning for utensils.',
    'unit': '500 ml',
    'price': '210',
    'mrp': '245',
    'emoji': '🧴',
  },
  {
    'id': 'p16',
    'categoryId': 'household',
    'name': 'Tissue Roll Pack',
    'description': 'Soft tissue for daily use.',
    'unit': '4 rolls',
    'price': '175',
    'mrp': '200',
    'emoji': '🧻',
  },
];
