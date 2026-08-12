import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/chats_providers.dart';
import '../../features/events/events_providers.dart';
import '../../features/notifications/notifications_providers.dart';

/// Invalidate list/detail providers when a push arrives (foreground or opened).
void invalidateProvidersForPushPayload(ProviderContainer container, Map<String, dynamic> data) {
  container.invalidate(notificationsProvider);
  container.invalidate(chatsProvider);

  final eventId = data['eventId']?.toString();
  if (eventId != null && eventId.isNotEmpty) {
    container.invalidate(eventByIdProvider(eventId));
    container.invalidate(eventApplicationsProvider(eventId));
    container.invalidate(myApplicationsProvider);
    container.invalidate(myHostedEventsProvider);
    container.invalidate(hostedPendingApplicationsProvider);
  }
}
