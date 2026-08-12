import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/guest_request.dart';

final requestsProvider =
    FutureProvider.family<List<GuestRequest>, RequestType?>((ref, type) {
  return ref.watch(requestRepositoryProvider).list(type: type);
});

final myRequestsProvider = FutureProvider<List<GuestRequest>>((ref) {
  final me = ref.watch(currentUserProvider);
  return ref.watch(requestRepositoryProvider).mine(me.id, me: me);
});

final myComplaintsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(complaintRepositoryProvider).mine();
});

final candidateHostsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(userRepositoryProvider).listCandidateHosts();
});
