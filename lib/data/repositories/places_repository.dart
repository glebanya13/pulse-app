import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../models/place.dart';

class PlacesRepository {
  PlacesRepository(this._api);

  final ApiClient _api;

  Future<PlaceDetail> byId(String id) async {
    final res = await _api.dio.get('/places/$id');
    return PlaceDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PlaceSummary> upsert({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String citySlug = 'minsk',
    String? externalId,
  }) async {
    final res = await _api.dio.post('/places/upsert', data: {
      'name': name,
      'lat': lat,
      'lng': lng,
      if (address != null) 'address': address,
      'citySlug': citySlug,
      if (externalId != null) 'externalId': externalId,
    });
    return PlaceSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PlaceReview> reviewPlace({
    required String placeId,
    required String eventId,
    required int stars,
    String? comment,
    List<String> photos = const [],
  }) async {
    final res = await _api.dio.post('/places/$placeId/reviews', data: {
      'eventId': eventId,
      'stars': stars,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (photos.isNotEmpty) 'photos': photos,
    });
    return PlaceReview.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PlaceReview?> myReviewForEvent(String eventId) async {
    if (Env.useMockData) return null;
    final res = await _api.dio.get('/events/$eventId/place-review/mine');
    if (res.data == null) return null;
    return PlaceReview.fromJson(res.data as Map<String, dynamic>);
  }
}
