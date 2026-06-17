// import 'dart:convert';

// class PackageOrderModel {
//   const PackageOrderModel({
//     required this.id,
//     required this.customerName,
//     required this.customerPhone,
//     required this.packageType,
//     required this.pickupAddress,
//     required this.dropAddress,
//     required this.distanceKm,
//     required this.deliveryCharge,
//     required this.totalPrice,
//     required this.status,
//     required this.createdAt,
//     this.pickupLatitude,
//     this.pickupLongitude,
//     this.pickupPlaceId = '',
//     this.dropLatitude,
//     this.dropLongitude,
//     this.dropPlaceId = '',
//     this.dropAddresses = const [],
//     this.dropLatitudes = const [],
//     this.dropLongitudes = const [],
//     this.dropPlaceIds = const [],
//     this.dropReceiverNames = const [],
//     this.dropReceiverPhones = const [],
//     this.dropPaymentAmounts = const [],
//     this.dropPaymentStatuses = const [],
//     this.dropStatuses = const [],
//     this.currentDropIndex = 0,
//     this.totalDrops = 1,
//     this.distanceText = '',
//     this.durationSeconds = 0,
//     this.durationText = '',
//     this.packageOrderType = 'send',
//     this.senderName = '',
//     this.senderPhone = '',
//     this.receiverName = '',
//     this.receiverPhone = '',
//     this.raw = const {},
//   });

//   final String id;
//   final String customerName;
//   final String customerPhone;
//   final String packageType;
//   final String pickupAddress;
//   final String dropAddress;
//   final double? pickupLatitude;
//   final double? pickupLongitude;
//   final String pickupPlaceId;
//   final double? dropLatitude;
//   final double? dropLongitude;
//   final String dropPlaceId;
//   final List<String> dropAddresses;
//   final List<double?> dropLatitudes;
//   final List<double?> dropLongitudes;
//   final List<String> dropPlaceIds;
//   final List<String> dropReceiverNames;
//   final List<String> dropReceiverPhones;
//   final List<double> dropPaymentAmounts;
//   final List<String> dropPaymentStatuses;
//   final List<String> dropStatuses;
//   final int currentDropIndex;
//   final int totalDrops;
//   final double distanceKm;
//   final String distanceText;
//   final int durationSeconds;
//   final String durationText;
//   final double deliveryCharge;
//   final double totalPrice;
//   final String status;
//   final DateTime createdAt;
//   final String packageOrderType;
//   final String senderName;
//   final String senderPhone;
//   final String receiverName;
//   final String receiverPhone;
//   final Map<String, dynamic> raw;

//   Map<String, dynamic> toJson() {
//     final dropCount = _maxInt([
//       dropAddresses.length,
//       dropLatitudes.length,
//       dropLongitudes.length,
//       dropPlaceIds.length,
//       dropReceiverNames.length,
//       dropReceiverPhones.length,
//       dropPaymentAmounts.length,
//       dropPaymentStatuses.length,
//       dropStatuses.length,
//       totalDrops,
//     ]);
//     final dropLocationsPayload = <Map<String, dynamic>>[];
//     final receiverContactsPayload = <Map<String, String>>[];
//     for (var i = 0; i < dropCount; i++) {
//       final name = _stringAt(
//         dropReceiverNames,
//         i,
//         fallback: i == 0 ? receiverName : '',
//       );
//       final phone = _stringAt(
//         dropReceiverPhones,
//         i,
//         fallback: i == 0 ? receiverPhone : '',
//       );
//       final drop = <String, dynamic>{};
//       final address = _stringAt(dropAddresses, i);
//       if (address.isNotEmpty) drop['address'] = address;
//       if (i < dropLatitudes.length && dropLatitudes[i] != null) {
//         drop['latitude'] = dropLatitudes[i];
//       }
//       if (i < dropLongitudes.length && dropLongitudes[i] != null) {
//         drop['longitude'] = dropLongitudes[i];
//       }
//       final placeId = _stringAt(dropPlaceIds, i);
//       if (placeId.isNotEmpty) drop['placeId'] = placeId;
//       if (placeId.isNotEmpty) drop['place_id'] = placeId;
//       if (name.isNotEmpty) drop['receiverName'] = name;
//       if (name.isNotEmpty) drop['receiver_name'] = name;
//       if (phone.isNotEmpty) drop['receiverPhone'] = phone;
//       if (phone.isNotEmpty) drop['receiver_phone'] = phone;
//       final paymentAmount = _doubleAt(dropPaymentAmounts, i);
//       if (paymentAmount != null) {
//         drop['paymentAmount'] = paymentAmount;
//         drop['payment_amount'] = paymentAmount;
//         drop['amountToCollect'] = paymentAmount;
//       }
//       final paymentStatus = _stringAt(dropPaymentStatuses, i);
//       if (paymentStatus.isNotEmpty) {
//         drop['paymentStatus'] = paymentStatus;
//         drop['payment_status'] = paymentStatus;
//       }
//       final dropStatus = _stringAt(dropStatuses, i);
//       if (dropStatus.isNotEmpty) {
//         drop['status'] = dropStatus;
//         drop['dropStatus'] = dropStatus;
//         drop['drop_status'] = dropStatus;
//       }
//       if (drop.isNotEmpty) dropLocationsPayload.add(drop);
//       if (name.isNotEmpty || phone.isNotEmpty) {
//         receiverContactsPayload.add({
//           if (name.isNotEmpty) 'name': name,
//           if (name.isNotEmpty) 'receiverName': name,
//           if (name.isNotEmpty) 'receiver_name': name,
//           if (phone.isNotEmpty) 'phone': phone,
//           if (phone.isNotEmpty) 'receiverPhone': phone,
//           if (phone.isNotEmpty) 'receiver_phone': phone,
//         });
//       }
//     }

//     return {
//       'id': id,
//       'orderId': id,
//       'orderType': 'package',
//       'customerName': customerName,
//       'customerPhone': customerPhone,
//       'packageType': packageType,
//       'packageOrderType': packageOrderType,
//       'senderName': senderName,
//       'senderPhone': senderPhone,
//       'receiverName': receiverName,
//       'receiverPhone': receiverPhone,
//       'sender': {
//         if (senderName.isNotEmpty) 'name': senderName,
//         if (senderPhone.isNotEmpty) 'phone': senderPhone,
//       },
//       'receiver': {
//         if (receiverName.isNotEmpty) 'name': receiverName,
//         if (receiverPhone.isNotEmpty) 'phone': receiverPhone,
//       },
//       'pickupAddress': pickupAddress,
//       'dropAddress': dropAddress,
//       'pickupLocation': {
//         'address': pickupAddress,
//         if (pickupLatitude != null) 'latitude': pickupLatitude,
//         if (pickupLongitude != null) 'longitude': pickupLongitude,
//         if (pickupPlaceId.isNotEmpty) 'placeId': pickupPlaceId,
//       },
//       'dropLocation': {
//         'address': dropAddress,
//         if (dropLatitude != null) 'latitude': dropLatitude,
//         if (dropLongitude != null) 'longitude': dropLongitude,
//         if (dropPlaceId.isNotEmpty) 'placeId': dropPlaceId,
//       },
//       'dropAddresses': dropAddresses,
//       'dropLatitudes': dropLatitudes,
//       'dropLongitudes': dropLongitudes,
//       'dropPlaceIds': dropPlaceIds,
//       'dropReceiverNames': dropReceiverNames,
//       'dropReceiverPhones': dropReceiverPhones,
//       'dropPaymentAmounts': dropPaymentAmounts,
//       'dropPaymentStatuses': dropPaymentStatuses,
//       'dropStatuses': dropStatuses,
//       'receiverContacts': receiverContactsPayload,
//       'receiver_contacts': receiverContactsPayload,
//       'currentDropIndex': currentDropIndex,
//       'current_drop_index': currentDropIndex,
//       'totalDrops': totalDrops,
//       'total_drops': totalDrops,
//       'dropLocations': dropLocationsPayload,
//       'drop_locations': dropLocationsPayload,
//       'drop_addresses': dropAddresses,
//       'drop_latitudes': dropLatitudes,
//       'drop_longitudes': dropLongitudes,
//       'drop_place_ids': dropPlaceIds,
//       'drop_receiver_names': dropReceiverNames,
//       'drop_receiver_phones': dropReceiverPhones,
//       'drop_payment_amounts': dropPaymentAmounts,
//       'drop_payment_statuses': dropPaymentStatuses,
//       'distanceKm': distanceKm,
//       'distance': (distanceKm * 1000).round(),
//       'distanceText': distanceText.isNotEmpty
//           ? distanceText
//           : '${distanceKm.toStringAsFixed(1)} km',
//       'duration': durationSeconds,
//       'durationText': durationText,
//       'deliveryCharge': deliveryCharge,
//       'totalPrice': totalPrice,
//       'status': status,
//       'createdAt': createdAt.toIso8601String(),
//       'raw': raw,
//     };
//   }

//   factory PackageOrderModel.fromJson(Map<String, dynamic> json) {
//     final pickup = _locationMap(
//       json['pickupLocation'] ??
//           json['pickup_location'] ??
//           json['pickup'] ??
//           json['pickupAddress'],
//     );
//     final drop = _locationMap(
//       json['dropLocation'] ??
//           json['drop_location'] ??
//           json['drop'] ??
//           json['dropAddress'],
//     );
//     final dropLocations = _locationMaps(
//       json['dropLocations'] ?? json['drop_locations'] ?? json['drops'],
//     );
//     final dropAddresses = _dropAddresses(json, dropLocations, drop);
//     final dropLatitudes = _dropNumbers(
//       json['dropLatitudes'] ?? json['drop_latitudes'],
//       dropLocations,
//       const ['latitude', 'lat'],
//     );
//     final dropLongitudes = _dropNumbers(
//       json['dropLongitudes'] ?? json['drop_longitudes'],
//       dropLocations,
//       const ['longitude', 'lng', 'long'],
//     );
//     final dropPlaceIds = _dropStrings(
//       json['dropPlaceIds'] ?? json['drop_place_ids'],
//       dropLocations,
//       const ['placeId', 'place_id'],
//     );
//     final receiverContacts = _personMaps(
//       json['receiverContacts'] ??
//           json['receiver_contacts'] ??
//           json['recipients'] ??
//           json['customers'],
//     );
//     final dropReceiverNames = _dropContactStrings(
//       json['dropReceiverNames'] ?? json['drop_receiver_names'],
//       dropLocations,
//       receiverContacts,
//       const ['receiverName', 'receiver_name', 'name', 'customer_name'],
//       const ['name', 'receiverName', 'receiver_name', 'customer_name'],
//     );
//     final dropReceiverPhones = _dropContactStrings(
//       json['dropReceiverPhones'] ?? json['drop_receiver_phones'],
//       dropLocations,
//       receiverContacts,
//       const [
//         'receiverPhone',
//         'receiver_phone',
//         'phone',
//         'mobile',
//         'customer_phone',
//       ],
//       const ['phone', 'receiverPhone', 'receiver_phone', 'mobile'],
//     );
//     final dropPaymentAmounts = _dropPaymentAmounts(
//       json['dropPaymentAmounts'] ??
//           json['drop_payment_amounts'] ??
//           json['paymentAmounts'] ??
//           json['payment_amounts'],
//       dropLocations,
//       receiverContacts,
//     );
//     final dropPaymentStatuses = _dropContactStrings(
//       json['dropPaymentStatuses'] ??
//           json['drop_payment_statuses'] ??
//           json['paymentStatuses'] ??
//           json['payment_statuses'],
//       dropLocations,
//       receiverContacts,
//       const ['paymentStatus', 'payment_status'],
//       const ['paymentStatus', 'payment_status'],
//     );
//     final dropStatuses = _dropStrings(
//       json['dropStatuses'] ?? json['drop_statuses'],
//       dropLocations,
//       const ['dropStatus', 'drop_status', 'status', 'delivery_status'],
//     );
//     final sender = _personMap(json['sender'] ?? json['senderDetails']);
//     final receiver = _personMap(json['receiver'] ?? json['receiverDetails']);
//     final distanceKm = _distanceKm(json);
//     final deliveryCharge = _number(
//       json['deliveryCharge'] ?? json['delivery_charge'],
//     );
//     final inferredDropCount = _maxInt([
//       dropLocations.length,
//       dropAddresses.length,
//       receiverContacts.length,
//       dropReceiverNames.length,
//       dropReceiverPhones.length,
//       dropPaymentAmounts.length,
//       dropPaymentStatuses.length,
//       dropStatuses.length,
//     ]);
//     final totalDrops =
//         _intOrNull(json['totalDrops'] ?? json['total_drops']) ??
//         (inferredDropCount > 0 ? inferredDropCount : 1);
//     final currentDropIndex = _clampDropIndex(
//       _intOrNull(
//             json['currentDropIndex'] ??
//                 json['current_drop_index'] ??
//                 json['currentStop'] ??
//                 json['current_stop'],
//           ) ??
//           0,
//       totalDrops,
//     );
//     return PackageOrderModel(
//       id:
//           (json['id'] ?? json['_id'] ?? json['orderId'] ?? json['orderNumber'])
//               ?.toString() ??
//           '',
//       customerName:
//           (json['customerName'] ?? json['senderName'] ?? json['receiverName'])
//               ?.toString() ??
//           '',
//       customerPhone:
//           (json['customerPhone'] ??
//                   json['senderPhone'] ??
//                   json['receiverPhone'])
//               ?.toString() ??
//           '',
//       packageType:
//           (json['packageType'] ?? json['type'])?.toString() ?? 'Package',
//       packageOrderType:
//           (json['packageOrderType'] ?? json['package_order_type'])
//               ?.toString() ??
//           'send',
//       pickupAddress: _firstString([
//         pickup['address'],
//         json['pickupAddress'],
//         json['pickup_address'],
//       ]),
//       pickupLatitude: _numberOrNull(
//         pickup['latitude'] ?? pickup['lat'] ?? json['pickupLatitude'],
//       ),
//       pickupLongitude: _numberOrNull(
//         pickup['longitude'] ??
//             pickup['lng'] ??
//             pickup['long'] ??
//             json['pickupLongitude'],
//       ),
//       pickupPlaceId: _firstString([
//         pickup['placeId'],
//         pickup['place_id'],
//         json['pickupPlaceId'],
//       ]),
//       dropAddress: _firstString([
//         drop['address'],
//         json['dropAddress'],
//         json['drop_address'],
//       ]),
//       dropLatitude: _numberOrNull(
//         drop['latitude'] ?? drop['lat'] ?? json['dropLatitude'],
//       ),
//       dropLongitude: _numberOrNull(
//         drop['longitude'] ??
//             drop['lng'] ??
//             drop['long'] ??
//             json['dropLongitude'],
//       ),
//       dropPlaceId: _firstString([
//         drop['placeId'],
//         drop['place_id'],
//         json['dropPlaceId'],
//       ]),
//       dropAddresses: dropAddresses,
//       dropLatitudes: dropLatitudes,
//       dropLongitudes: dropLongitudes,
//       dropPlaceIds: dropPlaceIds,
//       dropReceiverNames: dropReceiverNames,
//       dropReceiverPhones: dropReceiverPhones,
//       dropPaymentAmounts: dropPaymentAmounts,
//       dropPaymentStatuses: dropPaymentStatuses,
//       dropStatuses: dropStatuses,
//       currentDropIndex: currentDropIndex,
//       totalDrops: totalDrops < 1 ? 1 : totalDrops,
//       distanceKm: distanceKm,
//       distanceText:
//           json['distanceText']?.toString() ??
//           (distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : ''),
//       durationSeconds: _number(
//         json['duration'] ?? json['durationSeconds'],
//       ).round(),
//       durationText: json['durationText']?.toString() ?? '',
//       deliveryCharge: deliveryCharge,
//       totalPrice: _number(
//         json['totalPrice'] ??
//             json['grandTotal'] ??
//             json['amount'] ??
//             deliveryCharge,
//       ),
//       status: _status(json),
//       createdAt:
//           DateTime.tryParse(
//             json['createdAt']?.toString() ??
//                 json['created_at']?.toString() ??
//                 '',
//           ) ??
//           DateTime.now(),
//       senderName: _firstString([
//         json['senderName'],
//         json['sender_name'],
//         sender['name'],
//         sender['fullName'],
//         sender['full_name'],
//       ]),
//       senderPhone: _firstString([
//         json['senderPhone'],
//         json['sender_phone'],
//         sender['phone'],
//         sender['phoneNumber'],
//         sender['contactNumber'],
//         sender['mobile'],
//       ]),
//       receiverName: _firstString([
//         json['receiverName'],
//         json['receiver_name'],
//         receiver['name'],
//         receiver['fullName'],
//         receiver['full_name'],
//         _stringAt(dropReceiverNames, currentDropIndex),
//         _stringAt(dropReceiverNames, 0),
//       ]),
//       receiverPhone: _firstString([
//         json['receiverPhone'],
//         json['receiver_phone'],
//         receiver['phone'],
//         receiver['phoneNumber'],
//         receiver['contactNumber'],
//         receiver['mobile'],
//         _stringAt(dropReceiverPhones, currentDropIndex),
//         _stringAt(dropReceiverPhones, 0),
//       ]),
//       raw: Map<String, dynamic>.from(json),
//     );
//   }

//   static List<String> _stringList(Object? source) {
//     if (source is List) {
//       return source.map((e) => e?.toString() ?? '').toList();
//     }
//     if (source is String && source.trim().isNotEmpty) {
//       try {
//         return _stringList(jsonDecode(source));
//       } catch (_) {
//         return const [];
//       }
//     }
//     return const [];
//   }

//   static List<Map<String, dynamic>> _locationMaps(Object? source) {
//     if (source is String && source.trim().isNotEmpty) {
//       try {
//         return _locationMaps(jsonDecode(source));
//       } catch (_) {
//         return const [];
//       }
//     }
//     if (source is! List) return const [];
//     return source
//         .whereType<Map>()
//         .map((item) => Map<String, dynamic>.from(item))
//         .toList(growable: false);
//   }

//   static List<Map<String, dynamic>> _personMaps(Object? source) {
//     if (source is String && source.trim().isNotEmpty) {
//       try {
//         return _personMaps(jsonDecode(source));
//       } catch (_) {
//         return const [];
//       }
//     }
//     if (source is! List) return const [];
//     return source
//         .whereType<Map>()
//         .map((item) => Map<String, dynamic>.from(item))
//         .toList(growable: false);
//   }

//   static List<String> _dropContactStrings(
//     Object? direct,
//     List<Map<String, dynamic>> dropLocations,
//     List<Map<String, dynamic>> contacts,
//     List<String> dropKeys,
//     List<String> contactKeys,
//   ) {
//     final directValues = _stringList(direct);
//     if (directValues.isNotEmpty) return directValues;
//     final count = _maxInt([dropLocations.length, contacts.length]);
//     if (count == 0) return const [];
//     return List<String>.generate(count, (index) {
//       final drop = index < dropLocations.length
//           ? dropLocations[index]
//           : const <String, dynamic>{};
//       final contact = index < contacts.length
//           ? contacts[index]
//           : const <String, dynamic>{};
//       return _firstString([
//         for (final key in dropKeys) drop[key],
//         for (final key in contactKeys) contact[key],
//       ]);
//     }, growable: false);
//   }

//   static List<double> _dropPaymentAmounts(
//     Object? direct,
//     List<Map<String, dynamic>> dropLocations,
//     List<Map<String, dynamic>> contacts,
//   ) {
//     final directValues = _nullableDoubleList(
//       direct,
//     ).map((value) => value ?? 0).toList(growable: false);
//     if (directValues.isNotEmpty) return directValues;
//     final count = _maxInt([dropLocations.length, contacts.length]);
//     if (count == 0) return const [];
//     return List<double>.generate(count, (index) {
//       final drop = index < dropLocations.length
//           ? dropLocations[index]
//           : const <String, dynamic>{};
//       final contact = index < contacts.length
//           ? contacts[index]
//           : const <String, dynamic>{};
//       return _numberOrNull(
//             drop['paymentAmount'] ??
//                 drop['payment_amount'] ??
//                 drop['amountToCollect'] ??
//                 drop['amount_to_collect'] ??
//                 drop['codAmount'] ??
//                 drop['cod_amount'] ??
//                 drop['amount'] ??
//                 contact['paymentAmount'] ??
//                 contact['payment_amount'] ??
//                 contact['amountToCollect'] ??
//                 contact['amount_to_collect'] ??
//                 contact['codAmount'] ??
//                 contact['cod_amount'] ??
//                 contact['amount'],
//           ) ??
//           0;
//     }, growable: false);
//   }

//   static List<String> _dropAddresses(
//     Map<String, dynamic> json,
//     List<Map<String, dynamic>> dropLocations,
//     Map<String, dynamic> firstDrop,
//   ) {
//     final direct = _stringList(json['dropAddresses'] ?? json['drop_addresses']);
//     if (direct.isNotEmpty) {
//       return direct.where((e) => e.trim().isNotEmpty).toList();
//     }
//     final fromLocations = _dropStrings(null, dropLocations, const [
//       'address',
//       'formattedAddress',
//       'description',
//     ]).where((e) => e.trim().isNotEmpty).toList();
//     if (fromLocations.isNotEmpty) return fromLocations;
//     final single = _firstString([
//       firstDrop['address'],
//       json['dropAddress'],
//       json['drop_address'],
//     ]);
//     return single.isEmpty ? const [] : [single];
//   }

//   static List<String> _dropStrings(
//     Object? direct,
//     List<Map<String, dynamic>> dropLocations,
//     List<String> keys,
//   ) {
//     final values = _stringList(direct);
//     if (values.isNotEmpty) return values;
//     return dropLocations
//         .map((drop) {
//           for (final key in keys) {
//             final text = drop[key]?.toString().trim() ?? '';
//             if (text.isNotEmpty && text != '{}') return text;
//           }
//           return '';
//         })
//         .toList(growable: false);
//   }

//   static List<double?> _dropNumbers(
//     Object? direct,
//     List<Map<String, dynamic>> dropLocations,
//     List<String> keys,
//   ) {
//     final values = _nullableDoubleList(direct);
//     if (values.isNotEmpty) return values;
//     return dropLocations
//         .map((drop) {
//           for (final key in keys) {
//             final value = _numberOrNull(drop[key]);
//             if (value != null) return value;
//           }
//           return null;
//         })
//         .toList(growable: false);
//   }

//   static List<double?> _nullableDoubleList(Object? source) {
//     if (source is List) {
//       return source.map((e) => _numberOrNull(e)).toList();
//     }
//     if (source is String && source.trim().isNotEmpty) {
//       try {
//         return _nullableDoubleList(jsonDecode(source));
//       } catch (_) {
//         return const [];
//       }
//     }
//     return const [];
//   }

//   static Map<String, dynamic> _locationMap(Object? source) {
//     if (source is Map) return Map<String, dynamic>.from(source);
//     if (source == null) return const {};
//     return {'address': source.toString()};
//   }

//   static Map<String, dynamic> _personMap(Object? source) {
//     if (source is Map) return Map<String, dynamic>.from(source);
//     return const {};
//   }

//   static String _stringAt(
//     List<String> values,
//     int index, {
//     String fallback = '',
//   }) {
//     if (index < 0 || index >= values.length) return fallback;
//     final text = values[index].trim();
//     return text.isEmpty ? fallback : text;
//   }

//   static double? _doubleAt(List<double> values, int index) {
//     if (index < 0 || index >= values.length) return null;
//     return values[index];
//   }

//   static int _maxInt(Iterable<int> values) {
//     var max = 0;
//     for (final value in values) {
//       if (value > max) max = value;
//     }
//     return max;
//   }

//   static String _firstString(List<Object?> values) {
//     for (final value in values) {
//       final text = value?.toString().trim() ?? '';
//       if (text.isNotEmpty && text != '{}') return text;
//     }
//     return '';
//   }

//   static double _distanceKm(Map<String, dynamic> json) {
//     final direct = _numberOrNull(json['distanceKm'] ?? json['distance_km']);
//     if (direct != null) return direct;
//     final rawDistance = _numberOrNull(json['distance']);
//     if (rawDistance == null) return 0;
//     return rawDistance > 100 ? rawDistance / 1000 : rawDistance;
//   }

//   static double? _numberOrNull(Object? value) {
//     if (value is num) return value.toDouble();
//     return double.tryParse(value?.toString() ?? '');
//   }

//   static int? _intOrNull(Object? value) {
//     if (value is int) return value;
//     if (value is num) return value.toInt();
//     return int.tryParse(value?.toString() ?? '');
//   }

//   static int _clampDropIndex(int value, int totalDrops) {
//     final maxIndex = totalDrops <= 1 ? 0 : totalDrops - 1;
//     if (value < 0) return 0;
//     if (value > maxIndex) return maxIndex;
//     return value;
//   }

//   static double _number(Object? value) {
//     return _numberOrNull(value) ?? 0;
//   }

//   static String _status(Map<String, dynamic> json) {
//     final primary = _normalizeStatus(json['status']?.toString());
//     final delivery = _normalizeStatus(
//       (json['deliveryStatus'] ?? json['delivery_status'])?.toString(),
//     );

//     final hasExplicitCancellation =
//         primary == 'cancelled' ||
//         json['isCancelled'] == true ||
//         json['isCanceled'] == true ||
//         _firstString([
//           json['cancelledAt'],
//           json['canceledAt'],
//           json['cancelled_at'],
//           json['canceled_at'],
//           json['cancellationReason'],
//           json['cancellation_reason'],
//           json['cancelReason'],
//         ]).isNotEmpty;

//     if (primary == 'delivered') return primary;
//     if (delivery == 'cancelled' && !hasExplicitCancellation) {
//       return primary.isNotEmpty ? primary : 'pending';
//     }
//     if (primary.isNotEmpty && primary != 'pending') return primary;
//     if (delivery.isNotEmpty) return delivery;
//     if (primary.isNotEmpty) return primary;
//     return 'pending';
//   }

//   static String _normalizeStatus(String? value) {
//     final normalized = (value ?? '').trim().toLowerCase().replaceAll(
//       RegExp(r'[-\s]+'),
//       '_',
//     );
//     if (normalized == 'cancel') return 'cancelled';
//     if (normalized == 'canceled') return 'cancelled';
//     return normalized;
//   }
// }
import 'dart:convert';

class PackageOrderModel {
  const PackageOrderModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.packageType,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distanceKm,
    required this.deliveryCharge,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupPlaceId = '',
    this.dropLatitude,
    this.dropLongitude,
    this.dropPlaceId = '',
    this.dropAddresses = const [],
    this.dropLatitudes = const [],
    this.dropLongitudes = const [],
    this.dropPlaceIds = const [],
    this.dropReceiverNames = const [],
    this.dropReceiverPhones = const [],
    this.dropPaymentAmounts = const [],
    this.dropPaymentStatuses = const [],
    this.dropStatuses = const [],
    this.currentDropIndex = 0,
    this.totalDrops = 1,
    this.distanceText = '',
    this.durationSeconds = 0,
    this.durationText = '',
    this.packageOrderType = 'send',
    this.senderName = '',
    this.senderPhone = '',
    this.receiverName = '',
    this.receiverPhone = '',
    this.raw = const {},
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String packageType;
  final String pickupAddress;
  final String dropAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String pickupPlaceId;
  final double? dropLatitude;
  final double? dropLongitude;
  final String dropPlaceId;

  final List<String> dropAddresses;
  final List<double?> dropLatitudes;
  final List<double?> dropLongitudes;
  final List<String> dropPlaceIds;
  final List<String> dropReceiverNames;
  final List<String> dropReceiverPhones;
  final List<double> dropPaymentAmounts;
  final List<String> dropPaymentStatuses;
  final List<String> dropStatuses;

  final int currentDropIndex;
  final int totalDrops;

  final double distanceKm;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final double deliveryCharge;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String packageOrderType;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final Map<String, dynamic> raw;

  int? get deliveryRating {
    final parsed = _intOrNull(
      raw['rating'] ??
          raw['deliveryRating'] ??
          raw['delivery_rating'] ??
          raw['deliveryPartnerRating'] ??
          raw['delivery_partner_rating'],
    );
    if (parsed == null || parsed < 1 || parsed > 5) return null;
    return parsed;
  }

  String get deliveryRatingFeedback {
    return _firstString([
      raw['ratingFeedback'],
      raw['rating_feedback'],
      raw['deliveryFeedback'],
      raw['delivery_feedback'],
      raw['feedback'],
    ]);
  }

  DateTime? get deliveryRatedAt {
    final value =
        raw['ratedAt'] ??
        raw['rated_at'] ??
        raw['deliveryRatedAt'] ??
        raw['delivery_rated_at'];
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  bool get hasDeliveryRating => deliveryRating != null;

  Map<String, dynamic> toJson() {
    final dropCount = _maxInt([
      dropAddresses.length,
      dropLatitudes.length,
      dropLongitudes.length,
      dropPlaceIds.length,
      dropReceiverNames.length,
      dropReceiverPhones.length,
      dropPaymentAmounts.length,
      dropPaymentStatuses.length,
      dropStatuses.length,
      totalDrops,
    ]);

    final dropLocationsPayload = <Map<String, dynamic>>[];
    final receiverContactsPayload = <Map<String, String>>[];

    for (var i = 0; i < dropCount; i++) {
      final name = _stringAt(
        dropReceiverNames,
        i,
        fallback: i == 0 ? receiverName : '',
      );

      final phone = _stringAt(
        dropReceiverPhones,
        i,
        fallback: i == 0 ? receiverPhone : '',
      );

      final drop = <String, dynamic>{};

      final address = _stringAt(dropAddresses, i);
      if (address.isNotEmpty) drop['address'] = address;

      if (i < dropLatitudes.length && dropLatitudes[i] != null) {
        drop['latitude'] = dropLatitudes[i];
      }

      if (i < dropLongitudes.length && dropLongitudes[i] != null) {
        drop['longitude'] = dropLongitudes[i];
      }

      final placeId = _stringAt(dropPlaceIds, i);
      if (placeId.isNotEmpty) {
        drop['placeId'] = placeId;
        drop['place_id'] = placeId;
      }

      if (name.isNotEmpty) {
        drop['receiverName'] = name;
        drop['receiver_name'] = name;
      }

      if (phone.isNotEmpty) {
        drop['receiverPhone'] = phone;
        drop['receiver_phone'] = phone;
      }

      final paymentAmount = _doubleAt(dropPaymentAmounts, i);
      if (paymentAmount != null) {
        drop['paymentAmount'] = paymentAmount;
        drop['payment_amount'] = paymentAmount;
        drop['amountToCollect'] = paymentAmount;
      }

      final paymentStatus = _stringAt(dropPaymentStatuses, i);
      if (paymentStatus.isNotEmpty) {
        drop['paymentStatus'] = paymentStatus;
        drop['payment_status'] = paymentStatus;
      }

      final dropStatus = _stringAt(dropStatuses, i);
      if (dropStatus.isNotEmpty) {
        drop['status'] = dropStatus;
        drop['dropStatus'] = dropStatus;
        drop['drop_status'] = dropStatus;
      }

      if (drop.isNotEmpty) dropLocationsPayload.add(drop);

      if (name.isNotEmpty || phone.isNotEmpty) {
        receiverContactsPayload.add({
          if (name.isNotEmpty) 'name': name,
          if (name.isNotEmpty) 'receiverName': name,
          if (name.isNotEmpty) 'receiver_name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (phone.isNotEmpty) 'receiverPhone': phone,
          if (phone.isNotEmpty) 'receiver_phone': phone,
        });
      }
    }

    final rating = deliveryRating;
    final feedback = deliveryRatingFeedback;
    final ratedAt = deliveryRatedAt;

    final payload = <String, dynamic>{
      'id': id,
      'orderId': id,
      'orderType': 'package',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'packageType': packageType,
      'packageOrderType': packageOrderType,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'dropAddresses': dropAddresses,
      'dropLatitudes': dropLatitudes,
      'dropLongitudes': dropLongitudes,
      'dropPlaceIds': dropPlaceIds,
      'dropReceiverNames': dropReceiverNames,
      'dropReceiverPhones': dropReceiverPhones,
      'dropPaymentAmounts': dropPaymentAmounts,
      'dropPaymentStatuses': dropPaymentStatuses,
      'dropStatuses': dropStatuses,
      'currentDropIndex': currentDropIndex,
      'current_drop_index': currentDropIndex,
      'totalDrops': totalDrops,
      'total_drops': totalDrops,
      'dropLocations': dropLocationsPayload,
      'drop_locations': dropLocationsPayload,
      'receiverContacts': receiverContactsPayload,
      'receiver_contacts': receiverContactsPayload,
      'distanceKm': distanceKm,
      'distance': (distanceKm * 1000).round(),
      'distanceText': distanceText.isNotEmpty
          ? distanceText
          : '${distanceKm.toStringAsFixed(1)} km',
      'duration': durationSeconds,
      'durationText': durationText,
      'deliveryCharge': deliveryCharge,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'raw': raw,
    };

    if (rating != null) {
      payload['rating'] = rating;
      payload['deliveryRating'] = rating;
      payload['delivery_rating'] = rating;
    }
    if (feedback.isNotEmpty) {
      payload['ratingFeedback'] = feedback;
      payload['rating_feedback'] = feedback;
      payload['deliveryFeedback'] = feedback;
      payload['delivery_feedback'] = feedback;
    }
    if (ratedAt != null) {
      final submittedAt = ratedAt.toIso8601String();
      payload['ratedAt'] = submittedAt;
      payload['rated_at'] = submittedAt;
    }

    return payload;
  }

  factory PackageOrderModel.fromJson(Map<String, dynamic> json) {
    final pickup = _locationMap(
      json['pickupLocation'] ??
          json['pickup_location'] ??
          json['pickup'] ??
          json['pickupAddress'],
    );

    final drop = _locationMap(
      json['dropLocation'] ??
          json['drop_location'] ??
          json['drop'] ??
          json['dropAddress'],
    );

    final dropLocations = _locationMaps(
      json['dropLocations'] ?? json['drop_locations'] ?? json['drops'],
    );

    final dropAddresses = _dropAddresses(json, dropLocations, drop);

    final dropLatitudes = _dropNumbers(
      json['dropLatitudes'] ?? json['drop_latitudes'],
      dropLocations,
      const ['latitude', 'lat'],
    );

    final dropLongitudes = _dropNumbers(
      json['dropLongitudes'] ?? json['drop_longitudes'],
      dropLocations,
      const ['longitude', 'lng', 'long'],
    );

    final dropPlaceIds = _dropStrings(
      json['dropPlaceIds'] ?? json['drop_place_ids'],
      dropLocations,
      const ['placeId', 'place_id'],
    );

    final receiverContacts = _personMaps(
      json['receiverContacts'] ??
          json['receiver_contacts'] ??
          json['recipients'] ??
          json['customers'],
    );

    final dropReceiverNames = _dropContactStrings(
      json['dropReceiverNames'] ?? json['drop_receiver_names'],
      dropLocations,
      receiverContacts,
      const ['receiverName', 'receiver_name', 'name', 'customer_name'],
      const ['name', 'receiverName', 'receiver_name', 'customer_name'],
    );

    final dropReceiverPhones = _dropContactStrings(
      json['dropReceiverPhones'] ?? json['drop_receiver_phones'],
      dropLocations,
      receiverContacts,
      const [
        'receiverPhone',
        'receiver_phone',
        'phone',
        'mobile',
        'customer_phone',
      ],
      const ['phone', 'receiverPhone', 'receiver_phone', 'mobile'],
    );

    final dropPaymentAmounts = _dropPaymentAmounts(
      json['dropPaymentAmounts'] ??
          json['drop_payment_amounts'] ??
          json['paymentAmounts'] ??
          json['payment_amounts'],
      dropLocations,
      receiverContacts,
    );

    final dropPaymentStatuses = _dropContactStrings(
      json['dropPaymentStatuses'] ??
          json['drop_payment_statuses'] ??
          json['paymentStatuses'] ??
          json['payment_statuses'],
      dropLocations,
      receiverContacts,
      const ['paymentStatus', 'payment_status'],
      const ['paymentStatus', 'payment_status'],
    );

    final dropStatuses = _dropStrings(
      json['dropStatuses'] ?? json['drop_statuses'],
      dropLocations,
      const ['dropStatus', 'drop_status', 'status', 'delivery_status'],
    );

    final sender = _personMap(json['sender'] ?? json['senderDetails']);
    final receiver = _personMap(json['receiver'] ?? json['receiverDetails']);

    final distanceKm = _distanceKm(json);
    final deliveryCharge = _number(
      json['deliveryCharge'] ?? json['delivery_charge'],
    );

    final inferredDropCount = _maxInt([
      dropLocations.length,
      dropAddresses.length,
      receiverContacts.length,
      dropReceiverNames.length,
      dropReceiverPhones.length,
      dropPaymentAmounts.length,
      dropPaymentStatuses.length,
      dropStatuses.length,
    ]);

    final totalDrops =
        _intOrNull(json['totalDrops'] ?? json['total_drops']) ??
        (inferredDropCount > 0 ? inferredDropCount : 1);

    // FIX: agar backend currentDropIndex na bheje,
    // The next pending drop is calculated from dropStatuses.
    final calculatedDropIndex = _calculateCurrentDropIndex(dropStatuses);

    final currentDropIndex = _clampDropIndex(
      _intOrNull(
            json['currentDropIndex'] ??
                json['current_drop_index'] ??
                json['currentStop'] ??
                json['current_stop'],
          ) ??
          calculatedDropIndex,
      totalDrops,
    );

    return PackageOrderModel(
      id:
          (json['id'] ?? json['_id'] ?? json['orderId'] ?? json['orderNumber'])
              ?.toString() ??
          '',
      customerName:
          (json['customerName'] ?? json['senderName'] ?? json['receiverName'])
              ?.toString() ??
          '',
      customerPhone:
          (json['customerPhone'] ??
                  json['senderPhone'] ??
                  json['receiverPhone'])
              ?.toString() ??
          '',
      packageType:
          (json['packageType'] ?? json['type'])?.toString() ?? 'Package',
      packageOrderType:
          (json['packageOrderType'] ?? json['package_order_type'])
              ?.toString() ??
          'send',
      pickupAddress: _firstString([
        pickup['address'],
        json['pickupAddress'],
        json['pickup_address'],
      ]),
      pickupLatitude: _numberOrNull(
        pickup['latitude'] ?? pickup['lat'] ?? json['pickupLatitude'],
      ),
      pickupLongitude: _numberOrNull(
        pickup['longitude'] ??
            pickup['lng'] ??
            pickup['long'] ??
            json['pickupLongitude'],
      ),
      pickupPlaceId: _firstString([
        pickup['placeId'],
        pickup['place_id'],
        json['pickupPlaceId'],
      ]),
      dropAddress: _firstString([
        drop['address'],
        json['dropAddress'],
        json['drop_address'],
      ]),
      dropLatitude: _numberOrNull(
        drop['latitude'] ?? drop['lat'] ?? json['dropLatitude'],
      ),
      dropLongitude: _numberOrNull(
        drop['longitude'] ??
            drop['lng'] ??
            drop['long'] ??
            json['dropLongitude'],
      ),
      dropPlaceId: _firstString([
        drop['placeId'],
        drop['place_id'],
        json['dropPlaceId'],
      ]),
      dropAddresses: dropAddresses,
      dropLatitudes: dropLatitudes,
      dropLongitudes: dropLongitudes,
      dropPlaceIds: dropPlaceIds,
      dropReceiverNames: dropReceiverNames,
      dropReceiverPhones: dropReceiverPhones,
      dropPaymentAmounts: dropPaymentAmounts,
      dropPaymentStatuses: dropPaymentStatuses,
      dropStatuses: dropStatuses,
      currentDropIndex: currentDropIndex,
      totalDrops: totalDrops < 1 ? 1 : totalDrops,
      distanceKm: distanceKm,
      distanceText:
          json['distanceText']?.toString() ??
          (distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : ''),
      durationSeconds: _number(
        json['duration'] ?? json['durationSeconds'],
      ).round(),
      durationText: json['durationText']?.toString() ?? '',
      deliveryCharge: deliveryCharge,
      totalPrice: _number(
        json['totalPrice'] ??
            json['grandTotal'] ??
            json['amount'] ??
            deliveryCharge,
      ),
      status: _status(json),
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      senderName: _firstString([
        json['senderName'],
        json['sender_name'],
        sender['name'],
        sender['fullName'],
        sender['full_name'],
      ]),
      senderPhone: _firstString([
        json['senderPhone'],
        json['sender_phone'],
        sender['phone'],
        sender['phoneNumber'],
        sender['contactNumber'],
        sender['mobile'],
      ]),
      receiverName: _firstString([
        json['receiverName'],
        json['receiver_name'],
        receiver['name'],
        receiver['fullName'],
        receiver['full_name'],
        _stringAt(dropReceiverNames, currentDropIndex),
        _stringAt(dropReceiverNames, 0),
      ]),
      receiverPhone: _firstString([
        json['receiverPhone'],
        json['receiver_phone'],
        receiver['phone'],
        receiver['phoneNumber'],
        receiver['contactNumber'],
        receiver['mobile'],
        _stringAt(dropReceiverPhones, currentDropIndex),
        _stringAt(dropReceiverPhones, 0),
      ]),
      raw: Map<String, dynamic>.from(json),
    );
  }

  static int _calculateCurrentDropIndex(List<String> dropStatuses) {
    for (var i = 0; i < dropStatuses.length; i++) {
      final status = _normalizeStatus(dropStatuses[i]);

      if (status != 'delivered' &&
          status != 'completed' &&
          status != 'complete') {
        return i;
      }
    }

    return dropStatuses.isEmpty ? 0 : dropStatuses.length - 1;
  }

  static List<String> _stringList(Object? source) {
    if (source is List) {
      return source.map((e) => e?.toString() ?? '').toList();
    }

    if (source is String && source.trim().isNotEmpty) {
      try {
        return _stringList(jsonDecode(source));
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  static List<Map<String, dynamic>> _locationMaps(Object? source) {
    if (source is String && source.trim().isNotEmpty) {
      try {
        return _locationMaps(jsonDecode(source));
      } catch (_) {
        return const [];
      }
    }

    if (source is! List) return const [];

    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _personMaps(Object? source) {
    if (source is String && source.trim().isNotEmpty) {
      try {
        return _personMaps(jsonDecode(source));
      } catch (_) {
        return const [];
      }
    }

    if (source is! List) return const [];

    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static List<String> _dropContactStrings(
    Object? direct,
    List<Map<String, dynamic>> dropLocations,
    List<Map<String, dynamic>> contacts,
    List<String> dropKeys,
    List<String> contactKeys,
  ) {
    final directValues = _stringList(direct);
    if (directValues.isNotEmpty) return directValues;

    final count = _maxInt([dropLocations.length, contacts.length]);
    if (count == 0) return const [];

    return List<String>.generate(count, (index) {
      final drop = index < dropLocations.length
          ? dropLocations[index]
          : const <String, dynamic>{};

      final contact = index < contacts.length
          ? contacts[index]
          : const <String, dynamic>{};

      return _firstString([
        for (final key in dropKeys) drop[key],
        for (final key in contactKeys) contact[key],
      ]);
    }, growable: false);
  }

  static List<double> _dropPaymentAmounts(
    Object? direct,
    List<Map<String, dynamic>> dropLocations,
    List<Map<String, dynamic>> contacts,
  ) {
    final directValues = _nullableDoubleList(
      direct,
    ).map((value) => value ?? 0).toList(growable: false);

    if (directValues.isNotEmpty) return directValues;

    final count = _maxInt([dropLocations.length, contacts.length]);
    if (count == 0) return const [];

    return List<double>.generate(count, (index) {
      final drop = index < dropLocations.length
          ? dropLocations[index]
          : const <String, dynamic>{};

      final contact = index < contacts.length
          ? contacts[index]
          : const <String, dynamic>{};

      return _numberOrNull(
            drop['paymentAmount'] ??
                drop['payment_amount'] ??
                drop['amountToCollect'] ??
                drop['amount_to_collect'] ??
                drop['codAmount'] ??
                drop['cod_amount'] ??
                drop['amount'] ??
                contact['paymentAmount'] ??
                contact['payment_amount'] ??
                contact['amountToCollect'] ??
                contact['amount_to_collect'] ??
                contact['codAmount'] ??
                contact['cod_amount'] ??
                contact['amount'],
          ) ??
          0;
    }, growable: false);
  }

  static List<String> _dropAddresses(
    Map<String, dynamic> json,
    List<Map<String, dynamic>> dropLocations,
    Map<String, dynamic> firstDrop,
  ) {
    final direct = _stringList(json['dropAddresses'] ?? json['drop_addresses']);

    if (direct.isNotEmpty) {
      return direct.where((e) => e.trim().isNotEmpty).toList();
    }

    final fromLocations = _dropStrings(null, dropLocations, const [
      'address',
      'formattedAddress',
      'description',
    ]).where((e) => e.trim().isNotEmpty).toList();

    if (fromLocations.isNotEmpty) return fromLocations;

    final single = _firstString([
      firstDrop['address'],
      json['dropAddress'],
      json['drop_address'],
    ]);

    return single.isEmpty ? const [] : [single];
  }

  static List<String> _dropStrings(
    Object? direct,
    List<Map<String, dynamic>> dropLocations,
    List<String> keys,
  ) {
    final values = _stringList(direct);
    if (values.isNotEmpty) return values;

    return dropLocations
        .map((drop) {
          for (final key in keys) {
            final text = drop[key]?.toString().trim() ?? '';
            if (text.isNotEmpty && text != '{}') return text;
          }
          return '';
        })
        .toList(growable: false);
  }

  static List<double?> _dropNumbers(
    Object? direct,
    List<Map<String, dynamic>> dropLocations,
    List<String> keys,
  ) {
    final values = _nullableDoubleList(direct);
    if (values.isNotEmpty) return values;

    return dropLocations
        .map((drop) {
          for (final key in keys) {
            final value = _numberOrNull(drop[key]);
            if (value != null) return value;
          }
          return null;
        })
        .toList(growable: false);
  }

  static List<double?> _nullableDoubleList(Object? source) {
    if (source is List) {
      return source.map((e) => _numberOrNull(e)).toList();
    }

    if (source is String && source.trim().isNotEmpty) {
      try {
        return _nullableDoubleList(jsonDecode(source));
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  static Map<String, dynamic> _locationMap(Object? source) {
    if (source is Map) return Map<String, dynamic>.from(source);
    if (source == null) return const {};
    return {'address': source.toString()};
  }

  static Map<String, dynamic> _personMap(Object? source) {
    if (source is Map) return Map<String, dynamic>.from(source);
    return const {};
  }

  static String _stringAt(
    List<String> values,
    int index, {
    String fallback = '',
  }) {
    if (index < 0 || index >= values.length) return fallback;

    final text = values[index].trim();
    return text.isEmpty ? fallback : text;
  }

  static double? _doubleAt(List<double> values, int index) {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }

  static int _maxInt(Iterable<int> values) {
    var max = 0;

    for (final value in values) {
      if (value > max) max = value;
    }

    return max;
  }

  static String _firstString(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '{}') return text;
    }

    return '';
  }

  static double _distanceKm(Map<String, dynamic> json) {
    final direct = _numberOrNull(json['distanceKm'] ?? json['distance_km']);
    if (direct != null) return direct;

    final rawDistance = _numberOrNull(json['distance']);
    if (rawDistance == null) return 0;

    return rawDistance > 100 ? rawDistance / 1000 : rawDistance;
  }

  static double? _numberOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int _clampDropIndex(int value, int totalDrops) {
    final maxIndex = totalDrops <= 1 ? 0 : totalDrops - 1;

    if (value < 0) return 0;
    if (value > maxIndex) return maxIndex;

    return value;
  }

  static double _number(Object? value) {
    return _numberOrNull(value) ?? 0;
  }

  static String _status(Map<String, dynamic> json) {
    final primary = _normalizePrimaryStatus(json['status']?.toString());

    final delivery = _normalizeStatus(
      (json['deliveryStatus'] ?? json['delivery_status'])?.toString(),
    );
    final packageStatus = _normalizeStatus(
      (json['packageStatus'] ?? json['package_status'])?.toString(),
    );

    final hasExplicitCancellation =
        primary == 'cancelled' ||
        json['isCancelled'] == true ||
        json['isCanceled'] == true ||
        _firstString([
          json['cancelledAt'],
          json['canceledAt'],
          json['cancelled_at'],
          json['canceled_at'],
          json['cancellationReason'],
          json['cancellation_reason'],
          json['cancelReason'],
        ]).isNotEmpty;
    final safeDelivery = delivery == 'cancelled' && !hasExplicitCancellation
        ? ''
        : delivery;
    final safePackageStatus =
        packageStatus == 'cancelled' && !hasExplicitCancellation
        ? ''
        : packageStatus;

    if (!hasExplicitCancellation) {
      if (_isCompletionStatus(primary)) {
        return _canonicalCompletionStatus(primary);
      }

      final hasCompletionEvidence = _hasCompletionEvidence(json);
      for (final status in [safeDelivery, safePackageStatus]) {
        if (status.isEmpty || status == 'cancelled') {
          continue;
        }
        if (_isCompletionStatus(status)) {
          if (hasCompletionEvidence) return _canonicalCompletionStatus(status);
          continue;
        }
        return status;
      }
    }

    if (_isCompletionStatus(primary)) {
      return _canonicalCompletionStatus(primary);
    }
    if (_isCompletionStatus(safeDelivery) && _hasCompletionEvidence(json)) {
      return _canonicalCompletionStatus(safeDelivery);
    }
    if (_isCompletionStatus(safePackageStatus) &&
        _hasCompletionEvidence(json)) {
      return _canonicalCompletionStatus(safePackageStatus);
    }
    if (safeDelivery == 'cancelled' && hasExplicitCancellation) {
      return safeDelivery;
    }
    if (safePackageStatus == 'cancelled' && hasExplicitCancellation) {
      return safePackageStatus;
    }
    if (primary.isNotEmpty && primary != 'pending') return primary;
    if (safeDelivery.isNotEmpty && !_isCompletionStatus(safeDelivery)) {
      return safeDelivery;
    }
    if (safePackageStatus.isNotEmpty &&
        !_isCompletionStatus(safePackageStatus)) {
      return safePackageStatus;
    }
    if (primary.isNotEmpty) return primary;

    return 'pending';
  }

  static String _normalizePrimaryStatus(String? value) {
    final normalized = _normalizeStatus(value);
    return const {'success', 'ok'}.contains(normalized) ? '' : normalized;
  }

  static bool _isCompletionStatus(String status) {
    return const {
      'delivered',
      'completed',
      'complete',
      'finished',
      'done',
    }.contains(status);
  }

  static String _canonicalCompletionStatus(String status) {
    return status == 'delivered' ? 'delivered' : 'completed';
  }

  static bool _hasCompletionEvidence(Map<String, dynamic> json) {
    if (json['isDelivered'] == true ||
        json['delivered'] == true ||
        json['isCompleted'] == true ||
        json['completed'] == true) {
      return true;
    }

    if (_firstString([
      json['deliveredAt'],
      json['delivered_at'],
      json['completedAt'],
      json['completed_at'],
      json['deliveryCompletedAt'],
      json['delivery_completed_at'],
    ]).isNotEmpty) {
      return true;
    }

    final dropLocations = _locationMaps(
      json['dropLocations'] ?? json['drop_locations'] ?? json['drops'],
    );
    final dropStatuses =
        _dropStrings(
              json['dropStatuses'] ?? json['drop_statuses'],
              dropLocations,
              const ['dropStatus', 'drop_status', 'status', 'delivery_status'],
            )
            .map(_normalizeStatus)
            .where((status) => status.isNotEmpty)
            .toList(growable: false);

    final totalDrops = _intOrNull(json['totalDrops'] ?? json['total_drops']);
    final hasEveryDropStatus =
        totalDrops == null ||
        totalDrops <= 0 ||
        dropStatuses.length >= totalDrops;
    if (dropStatuses.isNotEmpty &&
        hasEveryDropStatus &&
        dropStatuses.every(_isCompletionStatus)) {
      return true;
    }

    final currentDropIndex = _intOrNull(
      json['currentDropIndex'] ?? json['current_drop_index'],
    );
    return totalDrops != null &&
        totalDrops > 0 &&
        currentDropIndex != null &&
        currentDropIndex >= totalDrops;
  }

  static String _normalizeStatus(String? value) {
    final normalized = (value ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[-\s]+'),
      '_',
    );

    if (normalized == 'cancel') return 'cancelled';
    if (normalized == 'canceled') return 'cancelled';

    return normalized;
  }
}
