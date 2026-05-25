import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';

import '../../../firebase_options.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_service.dart';
import '../models/address_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class CatalogRepository {
  CatalogRepository(this._apiService, {GetStorage? storage})
    : _storage = storage ?? GetStorage();

  static const _defaultProductRadiusKm = 5.0;
  static const _defaultFeaturedProductsLimit = 8;

  final ApiService _apiService;
  final GetStorage _storage;
  double _productRadiusKm = _defaultProductRadiusKm;
  int _featuredProductsLimit = _defaultFeaturedProductsLimit;
  bool _settingsLoaded = false;
  Future<ProductCatalogSettings>? _settingsLoadFuture;
  Future<List<CategoryModel>>? _categoriesLoadFuture;
  List<CategoryModel>? _cachedCategories;
  DateTime? _categoriesCachedAt;
  final _productCache = <String, _TimedCache<List<ProductModel>>>{};
  final _productLoadFutures = <String, Future<List<ProductModel>>>{};
  final _visibleProductsById = <String, ProductModel>{};

  static const _catalogCacheTtl = Duration(minutes: 2);

  List<ProductModel> get visibleProducts =>
      List.unmodifiable(_visibleProductsById.values);

  void invalidateProductScope() {
    _productCache.clear();
    _productLoadFutures.clear();
    _visibleProductsById.clear();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final cached = _cachedCategories;
    if (cached != null && !_isExpired(_categoriesCachedAt)) {
      return cached;
    }
    final inFlight = _categoriesLoadFuture;
    if (inFlight != null) return inFlight;

    debugPrint('CatalogRepository.fetchCategories: request started');
    final future = () async {
      final response = await _apiService.get(
        endpoint: ApiConstants.categories,
        authenticated: false,
      );
      final categories = _extractList(response)
          .whereType<Map>()
          .map(
            (item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
      _cachedCategories = categories;
      _categoriesCachedAt = DateTime.now();
      return categories;
    }();
    _categoriesLoadFuture = future;
    try {
      return await future;
    } catch (error) {
      debugPrint('CatalogRepository.fetchCategories: failed $error');
      return const [];
    } finally {
      _categoriesLoadFuture = null;
    }
  }

  Future<List<ProductModel>> fetchProductsByCategory(
    String categoryId, {
    List<String>? vendorIds,
    String? preferredVendorId,
    double? latitude,
    double? longitude,
  }) async {
    debugPrint('CatalogRepository.fetchProductsByCategory: $categoryId');
    final context = await _resolveProductContext(
      vendorIds: vendorIds,
      latitude: latitude,
      longitude: longitude,
    );
    final cacheKey = _productCacheKey(
      categoryId: categoryId,
      preferredVendorId: preferredVendorId,
      context: context,
    );
    final cached = _productCache[cacheKey];
    if (cached != null && !_isExpired(cached.cachedAt)) {
      return cached.value;
    }
    final inFlight = _productLoadFutures[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _fetchProductsByCategoryWithContext(
      categoryId,
      context,
      preferredVendorId: preferredVendorId,
    );
    _productLoadFutures[cacheKey] = future;
    try {
      final products = await future;
      _productCache[cacheKey] = _TimedCache(products);
      return products;
    } finally {
      _productLoadFutures.remove(cacheKey);
    }
  }

  Future<List<ProductModel>> _fetchProductsByCategoryWithContext(
    String categoryId,
    ProductCatalogContext context, {
    String? preferredVendorId,
  }) async {
    final scopedVendorIds = _selectScopedVendorIds(
      context.vendorIds,
      preferredVendorId,
    );
    if (scopedVendorIds.isEmpty) {
      debugPrint(
        'CatalogRepository.fetchProductsByCategory: no matching vendors in active scope',
      );
      return const [];
    }

    final lists = await Future.wait(
      scopedVendorIds.map(
        (vendorId) =>
            _fetchProductsByCategoryForVendor(categoryId, vendorId, context),
      ),
    );
    return _dedupeProducts(lists.expand((items) => items));
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final context = await _resolveProductContext();
    if (context.vendorIds.isEmpty) {
      debugPrint(
        'CatalogRepository.searchProducts: no matching vendors in active scope',
      );
      return const [];
    }

    final lists = await Future.wait(
      context.vendorIds.map(
        (vendorId) => _searchProductsForVendor(normalized, vendorId, context),
      ),
    );
    final selectedVendorIds = context.vendorIds.toSet();
    return _dedupeProducts(lists.expand((items) => items)).where((product) {
      final productVendorIds = _collectVendorIds(product.raw, product.vendorId);
      return productVendorIds.any(selectedVendorIds.contains);
    }).toList();
  }

  Future<ProductSearchResult> searchProductsInActiveScope(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const ProductSearchResult();

    final context = await _resolveProductContext();
    if (context.vendorIds.isEmpty) {
      return const ProductSearchResult(vendorContextMissing: true);
    }

    final lists = await Future.wait(
      context.vendorIds.map(
        (vendorId) => _searchProductsForVendor(normalized, vendorId, context),
      ),
    );
    final selectedVendorIds = context.vendorIds.toSet();
    final products = _dedupeProducts(lists.expand((items) => items)).where((
      product,
    ) {
      final productVendorIds = _collectVendorIds(product.raw, product.vendorId);
      if (productVendorIds.isEmpty) return false;
      return productVendorIds.any(selectedVendorIds.contains);
    }).toList();

    _rememberVisibleProducts(products);
    return ProductSearchResult(products: products);
  }

  Future<List<ProductModel>> fetchFeaturedProducts(
    List<CategoryModel> categories,
  ) async {
    if (categories.isEmpty) return const [];

    final context = await _resolveProductContext();

    final random = Random();
    final target = max(1, _featuredProductsLimit);

    final categoryPool = [...categories]..shuffle(random);
    final productMap = <String, ProductModel>{};

    Future<void> appendFromCategories(List<CategoryModel> batch) async {
      final lists = await Future.wait(
        batch.map(
          (category) =>
              _fetchProductsByCategoryWithContext(category.id, context),
        ),
      );
      final randomized = lists.expand((items) => items).toList()
        ..shuffle(random);
      for (final product in randomized) {
        if (productMap.length >= target) break;
        productMap.putIfAbsent(product.id, () => product);
      }
    }

    const batchSize = 4;
    for (
      var start = 0;
      start < categoryPool.length && productMap.length < target;
      start += batchSize
    ) {
      await appendFromCategories(
        categoryPool.skip(start).take(batchSize).toList(growable: false),
      );
    }

    final result = productMap.values.toList()..shuffle(random);
    return result.take(target).toList();
  }

  Future<ProductCatalogSettings> loadDeliverySettings({
    bool force = false,
  }) async {
    if (_settingsLoaded && !force) {
      return ProductCatalogSettings(
        productRadiusKm: _productRadiusKm,
        featuredProductsLimit: _featuredProductsLimit,
      );
    }
    if (!force && _settingsLoadFuture != null) {
      return _settingsLoadFuture!;
    }

    final future = () async {
      final firebaseHeaders = await _firebaseAuthHeaders();
      if (firebaseHeaders == null) {
        _settingsLoaded = true;
        return ProductCatalogSettings(
          productRadiusKm: _productRadiusKm,
          featuredProductsLimit: _featuredProductsLimit,
        );
      }
      final options = DefaultFirebaseOptions.currentPlatform;
      final endpoint =
          'https://firestore.googleapis.com/v1/projects/${options.projectId}/databases/(default)/documents/adminSettings/deliveryRadius?key=${options.apiKey}';
      final response = await _apiService.get(
        endpoint: endpoint,
        authenticated: false,
        headers: firebaseHeaders,
      );
      final fields = _decodeFirestoreFields(response['fields']);
      _productRadiusKm = max(
        1,
        _readNumber(fields, const [
          'productVisibilityRadiusKm',
          'productRadiusKm',
          'product_radius_km',
          'products.radiusKm',
          'products.visibilityRadiusKm',
          'products.productVisibilityRadiusKm',
        ], _defaultProductRadiusKm),
      );
      _featuredProductsLimit = max(
        1,
        _readNumber(fields, const [
          'featuredProductsLimit',
          'featured_products_limit',
          'products.featuredProductsLimit',
          'products.featuredLimit',
        ], _defaultFeaturedProductsLimit.toDouble()).round(),
      );
      _settingsLoaded = true;
      return ProductCatalogSettings(
        productRadiusKm: _productRadiusKm,
        featuredProductsLimit: _featuredProductsLimit,
      );
    }();
    _settingsLoadFuture = future;
    try {
      return await future;
    } catch (_) {
      _settingsLoaded = true;
      return ProductCatalogSettings(
        productRadiusKm: _productRadiusKm,
        featuredProductsLimit: _featuredProductsLimit,
      );
    } finally {
      _settingsLoadFuture = null;
    }
  }

  Future<List<ProductModel>> _fetchProductsByCategoryForVendor(
    String categoryId,
    String? vendorId,
    ProductCatalogContext context,
  ) async {
    try {
      final query = <String, dynamic>{
        'categoryId': categoryId,
        'latitude': context.latitude,
        'longitude': context.longitude,
        'radiusKm': context.radiusKm,
      };
      if (vendorId != null && vendorId.trim().isNotEmpty) {
        query['vendorId'] = vendorId;
      }
      final response = await _apiService.get(
        endpoint: ApiConstants.productsByCategory(categoryId),
        query: query,
        authenticated: false,
      );
      final products = _extractList(response)
          .whereType<Map>()
          .map(
            (item) => ProductModel.fromJson(
              _normalizeProductJson(
                Map<String, dynamic>.from(item),
                categoryId: categoryId,
                fallbackVendorId: vendorId,
              ),
            ),
          )
          .where((item) => item.id.isNotEmpty && !_isRemovedProduct(item.raw))
          .toList();
      _rememberVisibleProducts(products);
      return products;
    } catch (error) {
      debugPrint(
        'CatalogRepository.fetchProductsByCategory: failed after $error',
      );
      return const [];
    }
  }

  Future<List<ProductModel>> _searchProductsForVendor(
    String query,
    String? vendorId,
    ProductCatalogContext context,
  ) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'query': query,
        'latitude': context.latitude,
        'longitude': context.longitude,
        'radiusKm': context.radiusKm,
      };
      if (vendorId != null && vendorId.trim().isNotEmpty) {
        params['vendorId'] = vendorId;
      }
      final response = await _apiService.get(
        endpoint: ApiConstants.productSearch,
        query: params,
        authenticated: false,
      );
      return _extractList(response)
          .whereType<Map>()
          .map(
            (item) => ProductModel.fromJson(
              _normalizeProductJson(
                Map<String, dynamic>.from(item),
                fallbackVendorId: vendorId,
              ),
            ),
          )
          .where((item) => item.id.isNotEmpty && !_isRemovedProduct(item.raw))
          .toList();
    } catch (error) {
      debugPrint('CatalogRepository.searchProducts: failed after $error');
      return const [];
    }
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

  Future<ProductCatalogContext> _resolveProductContext({
    List<String>? vendorIds,
    double? latitude,
    double? longitude,
  }) async {
    await loadDeliverySettings();
    final directVendorIds = _uniqueVendorIds(vendorIds ?? const []);
    if (directVendorIds.isNotEmpty) {
      return ProductCatalogContext(
        vendorIds: directVendorIds,
        latitude: latitude,
        longitude: longitude,
        radiusKm: _productRadiusKm,
      );
    }

    final selectedAddress = _selectedAddress;
    var scopedLatitude = latitude ?? selectedAddress?.latitude;
    var scopedLongitude = longitude ?? selectedAddress?.longitude;
    final storedVendorIds = _uniqueVendorIds(
      _selectedVendorId?.split(',') ?? const [],
    );
    if (storedVendorIds.isNotEmpty) {
      if (!_hasValidCoordinates(scopedLatitude, scopedLongitude)) {
        final deviceCoordinate = await _readDeviceCoordinate();
        scopedLatitude = deviceCoordinate?.latitude;
        scopedLongitude = deviceCoordinate?.longitude;
      }
      return ProductCatalogContext(
        vendorIds: storedVendorIds,
        latitude: scopedLatitude,
        longitude: scopedLongitude,
        radiusKm: _productRadiusKm,
      );
    }

    var lat = scopedLatitude;
    var lng = scopedLongitude;
    if (!_hasValidCoordinates(lat, lng)) {
      final deviceCoordinate = await _readDeviceCoordinate();
      lat = deviceCoordinate?.latitude;
      lng = deviceCoordinate?.longitude;
    }

    final resolvedVendorIds = await _resolveVendorIds(lat, lng);
    return ProductCatalogContext(
      vendorIds: resolvedVendorIds,
      latitude: lat,
      longitude: lng,
      radiusKm: _productRadiusKm,
    );
  }

  List<String> _selectScopedVendorIds(
    List<String> vendorIds,
    String? preferredVendorId,
  ) {
    final preferred = _uniqueVendorIds(preferredVendorId?.split(',') ?? []);
    if (preferred.isEmpty) return vendorIds;
    final matched = preferred.where(vendorIds.contains).toList();
    return matched.isNotEmpty ? matched : vendorIds;
  }

  Future<List<String>> _resolveVendorIds(
    double? latitude,
    double? longitude,
  ) async {
    if (!_hasValidCoordinates(latitude, longitude)) return const [];
    try {
      final response = await _apiService.get(
        endpoint: ApiConstants.resolveVendor,
        query: {
          'latitude': latitude,
          'longitude': longitude,
          'radiusKm': _productRadiusKm,
        },
        authenticated: false,
      );
      final vendorIds = _resolveNearbyVendorIds(response, _productRadiusKm);
      if (vendorIds.isNotEmpty) {
        await _storage.write('selectedVendorId', vendorIds.join(','));
      } else {
        await _storage.remove('selectedVendorId');
      }
      return vendorIds;
    } catch (error) {
      debugPrint('CatalogRepository._resolveVendorIds: failed $error');
      return const [];
    }
  }

  Future<({double latitude, double longitude})?> _readDeviceCoordinate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      for (final accuracy in [LocationAccuracy.low, LocationAccuracy.medium]) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: accuracy,
              timeLimit: const Duration(seconds: 12),
            ),
          );
          return (latitude: position.latitude, longitude: position.longitude);
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (error) {
      debugPrint('CatalogRepository._readDeviceCoordinate: failed $error');
      return null;
    }
  }

  AddressModel? get _selectedAddress {
    final value = _storage.read('selectedAddress');
    if (value is Map) {
      return AddressModel.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  String? get _selectedVendorId {
    final value = _storage.read('selectedVendorId');
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, dynamic> _normalizeProductJson(
    Map<String, dynamic> json, {
    String? categoryId,
    String? fallbackVendorId,
  }) {
    final next = Map<String, dynamic>.from(json);
    if ((next['categoryId'] ?? next['category_id']) == null &&
        categoryId != null) {
      next['categoryId'] = categoryId;
      next['category_id'] = categoryId;
    }
    if ((next['vendorId'] ?? next['vendor_id']) == null &&
        fallbackVendorId != null) {
      next['vendorId'] = fallbackVendorId;
      next['vendor_id'] = fallbackVendorId;
    }
    return next;
  }

  List<ProductModel> _dedupeProducts(Iterable<ProductModel> products) {
    final map = <String, ProductModel>{};
    for (final product in products) {
      if (product.id.isEmpty) continue;
      map.putIfAbsent(product.id, () => product);
    }
    return map.values.toList();
  }

  void _rememberVisibleProducts(Iterable<ProductModel> products) {
    for (final product in products) {
      if (product.id.isEmpty) continue;
      _visibleProductsById[product.id] = product;
    }
  }

  bool _isRemovedProduct(Map<String, dynamic> product) {
    final deletedAt = product['deletedAt'] ?? product['deleted_at'];
    if (product['isDeleted'] == true ||
        product['is_deleted'] == true ||
        product['deleted'] == true ||
        (deletedAt != null && deletedAt.toString().trim().isNotEmpty)) {
      return true;
    }
    final status =
        (product['status'] ??
                product['productStatus'] ??
                product['product_status'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    return status == 'deleted' || status == 'removed' || status == 'archived';
  }

  List<String> _collectVendorIds(
    Map<String, dynamic> product,
    String fallbackVendorId,
  ) {
    final vendor = product['vendor'] is Map
        ? Map<String, dynamic>.from(product['vendor'] as Map)
        : const <String, dynamic>{};
    return _uniqueVendorIds([
      product['vendorId'],
      product['vendor_id'],
      vendor['id'],
      vendor['vendorId'],
      fallbackVendorId,
    ]);
  }

  List<String> _resolveNearbyVendorIds(
    Map<String, dynamic> response,
    double radiusKm,
  ) {
    final vendors = _extractVendorMaps(response);
    if (vendors.isNotEmpty) {
      final nearbyVendors = vendors.where((vendor) {
        final distance = _distanceKmFrom(vendor);
        return distance == null || distance <= radiusKm;
      }).toList();
      return _uniqueVendorIds(nearbyVendors.map(_vendorIdentifier));
    }

    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : const <String, dynamic>{};
    final result = response['result'] is Map
        ? Map<String, dynamic>.from(response['result'] as Map)
        : const <String, dynamic>{};
    final nearestVendorSource =
        response['nearestVendor'] ??
        data['nearestVendor'] ??
        result['nearestVendor'];
    final nearestVendor = nearestVendorSource is Map
        ? Map<String, dynamic>.from(nearestVendorSource)
        : const <String, dynamic>{};
    final nearestDistance =
        _distanceKmFrom(nearestVendor) ?? _distanceKmFrom(response);
    if (nearestDistance != null && nearestDistance > radiusKm) {
      return const [];
    }

    return _uniqueVendorIds([
      if (response['vendorIds'] is List) ...(response['vendorIds'] as List),
      response['vendorId'],
      response['vendor_id'],
      if (response['data'] is Map &&
          (response['data'] as Map)['vendorIds'] is List)
        ...((response['data'] as Map)['vendorIds'] as List),
      if (response['data'] is Map) (response['data'] as Map)['vendorId'],
      if (response['data'] is Map) (response['data'] as Map)['vendor_id'],
      if (response['result'] is Map &&
          (response['result'] as Map)['vendorIds'] is List)
        ...((response['result'] as Map)['vendorIds'] as List),
      if (response['result'] is Map) (response['result'] as Map)['vendorId'],
      if (response['result'] is Map) (response['result'] as Map)['vendor_id'],
      _vendorIdentifier(nearestVendor),
    ]);
  }

  List<Map<String, dynamic>> _extractVendorMaps(Map<String, dynamic> response) {
    final candidates = [
      response['vendors'],
      if (response['data'] is Map) (response['data'] as Map)['vendors'],
      if (response['result'] is Map) (response['result'] as Map)['vendors'],
      if (response['data'] is Map) (response['data'] as Map)['data'],
      if (response['result'] is Map) (response['result'] as Map)['data'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  String? _vendorIdentifier(Map<String, dynamic> vendor) {
    final value =
        vendor['vendorId'] ??
        vendor['vendor_id'] ??
        vendor['id'] ??
        vendor['_id'];
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  double? _distanceKmFrom(Map<String, dynamic> source) {
    for (final key in [
      'distanceKm',
      'distance_km',
      'distanceKM',
      'distance',
      'distanceInKm',
      'distance_in_km',
    ]) {
      final parsed = _numberFrom(source[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _numberFrom(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final direct = double.tryParse(raw);
    if (direct != null) return direct;
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  List<String> _uniqueVendorIds(Iterable<Object?> values) {
    return values
        .expand((value) => value?.toString().split(',') ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _hasValidCoordinates(double? lat, double? lng) {
    return lat != null && lng != null && lat.isFinite && lng.isFinite;
  }

  bool _isExpired(DateTime? cachedAt) =>
      cachedAt == null ||
      DateTime.now().difference(cachedAt) > _catalogCacheTtl;

  String _productCacheKey({
    required String categoryId,
    required String? preferredVendorId,
    required ProductCatalogContext context,
  }) {
    final vendors = [...context.vendorIds]..sort();
    String coordinate(double? value) =>
        value == null ? '-' : value.toStringAsFixed(3);
    return [
      categoryId,
      preferredVendorId ?? '',
      vendors.join(','),
      coordinate(context.latitude),
      coordinate(context.longitude),
      context.radiusKm.toStringAsFixed(1),
    ].join('|');
  }

  Future<Map<String, String>?> _firebaseAuthHeaders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      if (token == null || token.trim().isEmpty) return null;
      return {'Authorization': 'Bearer $token'};
    } catch (error) {
      debugPrint(
        'CatalogRepository._firebaseAuthHeaders: unavailable after $error',
      );
      return null;
    }
  }

  Map<String, dynamic> _decodeFirestoreFields(Object? fields) {
    if (fields is! Map) return const {};
    return fields.map(
      (key, value) => MapEntry(key.toString(), _decodeFirestoreValue(value)),
    );
  }

  Object? _decodeFirestoreValue(Object? value) {
    if (value is! Map) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return num.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return num.tryParse(value['doubleValue'].toString());
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue'] is Map
          ? (value['mapValue'] as Map)['fields']
          : null;
      return _decodeFirestoreFields(fields);
    }
    return null;
  }

  Object? _readPath(Map<String, dynamic> source, String path) {
    Object? current = source;
    for (final segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  double _readNumber(
    Map<String, dynamic> source,
    List<String> paths,
    double fallback,
  ) {
    for (final path in paths) {
      final value = _readPath(source, path);
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }
}

class _TimedCache<T> {
  _TimedCache(this.value) : cachedAt = DateTime.now();

  final T value;
  final DateTime cachedAt;
}

class ProductCatalogSettings {
  const ProductCatalogSettings({
    required this.productRadiusKm,
    required this.featuredProductsLimit,
  });

  final double productRadiusKm;
  final int featuredProductsLimit;
}

class ProductSearchResult {
  const ProductSearchResult({
    this.products = const [],
    this.vendorContextMissing = false,
  });

  final List<ProductModel> products;
  final bool vendorContextMissing;
}

class ProductCatalogContext {
  const ProductCatalogContext({
    required this.vendorIds,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final List<String> vendorIds;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
}
