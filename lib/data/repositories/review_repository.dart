import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/review.dart';

class ReviewRepository {
  ReviewRepository(this._api) : _reviews = List.of(MockData.reviews);

  final ApiClient _api;
  final List<Review> _reviews;

  Future<Review> submit(Review review) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _reviews.insert(0, review);
      return review;
    }
    final res = await _api.dio.post('/events/${review.eventId}/reviews', data: review.toCreateJson());
    return Review.fromJson(
      res.data as Map<String, dynamic>,
      fallbackEventTitle: review.eventTitle,
      fallbackTarget: review.target,
    );
  }

  Future<List<Review>> forUser(String userId) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _reviews.where((r) => r.target.id == userId).toList();
    }
    final res = await _api.dio.get('/users/$userId/reviews');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((r) => Review.fromJson(r)).toList();
  }
}
