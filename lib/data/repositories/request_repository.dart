import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/enums.dart';
import '../models/guest_request.dart';
import '../models/user.dart';

class RequestRepository {
  RequestRepository(this._api) : _requests = List.of(MockData.requests);

  final ApiClient _api;
  final List<GuestRequest> _requests;

  Future<List<GuestRequest>> list({RequestType? type}) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (type == null) return List.of(_requests);
      return _requests.where((r) => r.type == type).toList();
    }
    final res = await _api.dio.get(
      '/requests',
      queryParameters: {if (type != null) 'type': type.backend},
    );
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((r) => GuestRequest.fromJson(r)).toList();
  }

  Future<GuestRequest> byId(String id) async {
    if (Env.useMockData) {
      return _requests.firstWhere((r) => r.id == id);
    }
    final res = await _api.dio.get('/requests/$id');
    return GuestRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<GuestRequest>> mine(String userId, {AppUser? me}) async {
    if (Env.useMockData) {
      return _requests.where((r) => r.author.id == userId).toList();
    }
    final res = await _api.dio.get('/users/me/requests');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((r) => GuestRequest.fromJson(r, fallbackAuthor: me)).toList();
  }

  Future<GuestRequest> create(GuestRequest request) async {
    if (Env.useMockData) {
      _requests.insert(0, request);
      return request;
    }
    final res = await _api.dio.post('/requests', data: {
      'type': request.type.backend,
      'title': request.title,
      'description': request.description,
      if (request.portionsCount != null) 'portionsCount': request.portionsCount,
      'budgetType': request.budgetType.backend,
      if (request.budgetAmount != null) 'budgetAmount': request.budgetAmount!.toInt(),
      'requestedAt': request.requestedAt.toIso8601String(),
      if (request.requestedEndAt != null)
        'requestedEndAt': request.requestedEndAt!.toIso8601String(),
      if (request.targetHost != null) 'targetHostId': request.targetHost!.id,
      if (request.address != null) 'address': request.address,
      if (request.photos.isNotEmpty) 'photos': request.photos,
    });
    return GuestRequest.fromJson(res.data as Map<String, dynamic>, fallbackAuthor: request.author);
  }

  /// A host offers to fulfil [requestId].
  Future<void> offer(String requestId, AppUser host, {String? message}) async {
    if (Env.useMockData) {
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx == -1) return;
      final r = _requests[idx];
      _requests[idx] = GuestRequest(
        id: r.id,
        author: r.author,
        type: r.type,
        title: r.title,
        description: r.description,
        portionsCount: r.portionsCount,
        budgetType: r.budgetType,
        budgetAmount: r.budgetAmount,
        requestedAt: r.requestedAt,
        requestedEndAt: r.requestedEndAt,
        targetHost: r.targetHost,
        status: RequestStatus.offered,
        createdAt: r.createdAt,
        address: r.address,
        offers: [
          ...r.offers,
          RequestOffer(id: 'o_${DateTime.now().microsecondsSinceEpoch}', host: host, createdAt: DateTime.now()),
        ],
      );
      return;
    }
    await _api.dio.post('/requests/$requestId/offers', data: {'message': ?message});
  }

  /// The request author accepts or declines one of the offers made on their
  /// request - this is the "выбор исполнителя" step, persisted server-side
  /// (accepting one auto-declines the rest, and the request itself moves to
  /// ACCEPTED - see backend RequestsService.updateOfferStatus).
  Future<void> respondToOffer(String offerId, OfferStatus status) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    await _api.dio.patch('/request-offers/$offerId', data: {'status': status.backend});
  }

  /// The offering host withdraws their own still-pending offer.
  Future<void> withdrawOffer(String offerId) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    await _api.dio.delete('/request-offers/$offerId');
  }
}
