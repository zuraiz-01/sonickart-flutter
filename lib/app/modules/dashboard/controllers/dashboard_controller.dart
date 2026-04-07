import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class DashboardController extends GetxController {
  final currentIndex = 0.obs;
  final currentPromoIndex = 0.obs;
  final currentSearchHintIndex = 0.obs;

  Timer? _promoTimer;
  Timer? _searchHintTimer;

  final searchHints = const [
    'Search "sweets"',
    'Search "milk"',
    'Search for ata, dal, coke',
    'Search "chips"',
    'Search "pooja thali"',
  ];

  final promoCards = const [
    {
      'title': 'Freshest picks in minutes',
      'subtitle': 'Daily essentials, snacks and dairy delivered fast.',
      'highlight': 'UP TO 30% OFF',
    },
    {
      'title': 'Weekend savings are live',
      'subtitle': 'Stock up on groceries, drinks and home basics.',
      'highlight': 'FREE DELIVERY',
    },
  ];

  final featuredProducts = const [
    {
      'categoryId': 'dairy',
      'name': 'Fresh Milk',
      'unit': '1 L',
      'price': '99',
      'emoji': '🥛',
    },
    {
      'categoryId': 'snacks',
      'name': 'Potato Chips',
      'unit': '52 g',
      'price': '35',
      'emoji': '🍟',
    },
    {
      'categoryId': 'bakery',
      'name': 'Brown Bread',
      'unit': '400 g',
      'price': '65',
      'emoji': '🍞',
    },
    {
      'categoryId': 'dairy',
      'name': 'Farm Eggs',
      'unit': '6 pcs',
      'price': '120',
      'emoji': '🥚',
    },
    {
      'categoryId': 'fruits',
      'name': 'Apples',
      'unit': '1 kg',
      'price': '180',
      'emoji': '🍎',
    },
    {
      'categoryId': 'household',
      'name': 'Cooking Oil',
      'unit': '1 L',
      'price': '320',
      'emoji': '🫒',
    },
    {
      'categoryId': 'household',
      'name': 'Basmati Rice',
      'unit': '1 kg',
      'price': '240',
      'emoji': '🍚',
    },
    {
      'categoryId': 'snacks',
      'name': 'Chocolate',
      'unit': '90 g',
      'price': '150',
      'emoji': '🍫',
    },
  ];

  final categories = const [
    {'id': 'fruits', 'name': 'Fruits', 'emoji': '🍎'},
    {'id': 'vegetables', 'name': 'Vegetables', 'emoji': '🥦'},
    {'id': 'dairy', 'name': 'Dairy', 'emoji': '🥛'},
    {'id': 'snacks', 'name': 'Snacks', 'emoji': '🍿'},
    {'id': 'bakery', 'name': 'Bakery', 'emoji': '🥐'},
    {'id': 'beverages', 'name': 'Beverages', 'emoji': '🥤'},
    {'id': 'frozen', 'name': 'Frozen', 'emoji': '🧊'},
    {'id': 'household', 'name': 'Household', 'emoji': '🧽'},
  ];

  final activeOrder = const {
    'id': 'SK1024',
    'items': 3,
    'title': 'Your order is on the way',
    'subtitle': 'Tap to track the delivery live.',
  };

  void changeTab(int index) {
    debugPrint('DashboardController.changeTab: switching to index $index');
    currentIndex.value = index;
  }

  void setTabFromNavigation(int index) {
    debugPrint(
      'DashboardController.setTabFromNavigation: received requested tab index $index',
    );
    currentIndex.value = index;
  }

  void nextPromo() {
    if (promoCards.isEmpty) return;
    final nextIndex = (currentPromoIndex.value + 1) % promoCards.length;
    currentPromoIndex.value = nextIndex;
  }

  @override
  void onInit() {
    super.onInit();
    final requestedIndex = (Get.arguments?['tabIndex'] as num?)?.toInt();
    if (requestedIndex != null && requestedIndex >= 0 && requestedIndex <= 4) {
      setTabFromNavigation(requestedIndex);
    }
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) => nextPromo());
    _searchHintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      currentSearchHintIndex.value =
          (currentSearchHintIndex.value + 1) % searchHints.length;
    });
  }

  @override
  void onClose() {
    _promoTimer?.cancel();
    _searchHintTimer?.cancel();
    super.onClose();
  }
}
