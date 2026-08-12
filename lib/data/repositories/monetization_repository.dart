import 'dart:async';

import '../api/api_client.dart';

class MonetizationProduct {
  const MonetizationProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.amountByn,
    required this.amountRub,
    required this.durationDays,
  });

  final String id;
  final String title;
  final String description;
  final int amountByn;
  final int amountRub;
  final int durationDays;

  int amountFor(String currency) =>
      currency.toUpperCase() == 'RUB' ? amountRub : amountByn;

  factory MonetizationProduct.fromJson(Map<String, dynamic> json) =>
      MonetizationProduct(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        amountByn: json['amountByn'] as int? ?? json['amount'] as int? ?? 0,
        amountRub: json['amountRub'] as int? ?? ((json['amount'] as int? ?? 0) * 30),
        durationDays: json['durationDays'] as int? ?? 0,
      );
}

class MonetizationCatalog {
  const MonetizationCatalog({required this.products});

  final List<MonetizationProduct> products;

  MonetizationProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory MonetizationCatalog.fromJson(Map<String, dynamic> json) =>
      MonetizationCatalog(
        products: (json['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(MonetizationProduct.fromJson)
            .toList(),
      );
}

/// Catalog only — in-app checkout removed; boost / Pro go through admin.
class MonetizationRepository {
  MonetizationRepository(this._api);

  final ApiClient _api;

  Future<MonetizationCatalog> catalog() async {
    final res = await _api.dio.get('/monetization/catalog');
    return MonetizationCatalog.fromJson(res.data as Map<String, dynamic>);
  }
}
