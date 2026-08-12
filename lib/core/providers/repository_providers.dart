import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/monetization_repository.dart';
import '../../data/repositories/cities_repository.dart';
import '../../data/repositories/places_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(apiClientProvider)));

final eventRepositoryProvider =
    Provider<EventRepository>((ref) => EventRepository(ref.watch(apiClientProvider)));

final requestRepositoryProvider =
    Provider<RequestRepository>((ref) => RequestRepository(ref.watch(apiClientProvider)));

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(apiClientProvider)));

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => NotificationRepository(ref.watch(apiClientProvider)));

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(apiClientProvider)));

final complaintRepositoryProvider = Provider<ComplaintRepository>(
    (ref) => ComplaintRepository(ref.watch(apiClientProvider)));

final socialRepositoryProvider =
    Provider<SocialRepository>((ref) => SocialRepository(ref.watch(apiClientProvider)));

final monetizationRepositoryProvider = Provider<MonetizationRepository>(
    (ref) => MonetizationRepository(ref.watch(apiClientProvider)));

final citiesRepositoryProvider = Provider<CitiesRepository>(
    (ref) => CitiesRepository(ref.watch(apiClientProvider)));

final placesRepositoryProvider = Provider<PlacesRepository>(
    (ref) => PlacesRepository(ref.watch(apiClientProvider)));
