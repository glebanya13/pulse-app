// Every enum here mirrors a Prisma enum on the backend (UPPER_SNAKE_CASE
// string values over the wire) while keeping idiomatic lowerCamelCase Dart
// enum members for the rest of the app. `backend` / `fromBackend` are the
// single source of truth for that translation - always go through them when
// talking to the API instead of `.name` / `byName`, which would send the
// wrong casing.

/// Формат события: очное / билетный вход (legacy takeaway slot).
enum EventFormat {
  inPerson('IN_PERSON'),
  takeaway('TAKEAWAY');

  const EventFormat(this.backend);
  final String backend;

  static EventFormat fromBackend(String value) =>
      EventFormat.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        EventFormat.inPerson => 'Живое',
        EventFormat.takeaway => 'Билеты',
      };
}

enum PriceType {
  free('FREE'),
  fixed('FIXED'),
  donation('DONATION');

  const PriceType(this.backend);
  final String backend;

  static PriceType fromBackend(String value) =>
      PriceType.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        PriceType.free => 'Бесплатно',
        PriceType.fixed => 'За деньги',
        PriceType.donation => 'Донат',
      };

  String get description => switch (this) {
        PriceType.free => '0 BYN',
        PriceType.fixed => 'Укажите сумму',
        PriceType.donation => 'Вход по донату',
      };
}

/// Maps to the backend's `GenderRequirement` enum (used for event guest
/// requirements) - separate from the plain [Gender] a user profile has.
enum GenderFilter {
  any('ANY'),
  male('MALE'),
  female('FEMALE'),
  family('FAMILY');

  const GenderFilter(this.backend);
  final String backend;

  static GenderFilter fromBackend(String value) =>
      GenderFilter.values.firstWhere(
        (e) => e.backend == value,
        orElse: () => GenderFilter.any,
      );

  String get label => switch (this) {
        GenderFilter.any => 'Все',
        GenderFilter.male => 'Мужчины',
        GenderFilter.female => 'Женщины',
        GenderFilter.family => 'Семейный',
      };

  /// Short hint under chips on create / filters.
  String get hint => switch (this) {
        GenderFilter.any => 'Без ограничений',
        GenderFilter.male => 'Только мужчины',
        GenderFilter.female => 'Только женщины',
        GenderFilter.family => 'Можно с детьми',
      };
}

enum Gender {
  male,
  female;

  String get label => switch (this) {
        Gender.male => 'Мужской',
        Gender.female => 'Женский',
      };
}

enum PickupMethod {
  pickupOnly('PICKUP_ONLY'),
  meetAtDoor('MEET_AT_DOOR');

  const PickupMethod(this.backend);
  final String backend;

  static PickupMethod fromBackend(String value) =>
      PickupMethod.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        PickupMethod.pickupOnly => 'Самовывоз',
        PickupMethod.meetAtDoor => 'Доставка',
      };
}

enum EventStatus {
  active('ACTIVE'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  pendingReview('PENDING_REVIEW');

  const EventStatus(this.backend);
  final String backend;

  static EventStatus fromBackend(String value) =>
      EventStatus.values.firstWhere(
        (e) => e.backend == value,
        orElse: () => EventStatus.active,
      );

  String get label => switch (this) {
        EventStatus.active => 'Активно',
        EventStatus.completed => 'Завершено',
        EventStatus.cancelled => 'Отменено',
        EventStatus.pendingReview => 'На проверке',
      };
}

enum ApplicationStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  rejected('REJECTED');

  const ApplicationStatus(this.backend);
  final String backend;

  static ApplicationStatus fromBackend(String value) =>
      ApplicationStatus.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        ApplicationStatus.pending => 'На рассмотрении',
        ApplicationStatus.accepted => 'Принята',
        ApplicationStatus.rejected => 'Отклонена',
      };
}

/// Maps to the backend's `GuestRequestType`.
enum RequestType {
  general('GENERAL'),
  personal('PERSONAL');

  const RequestType(this.backend);
  final String backend;

  static RequestType fromBackend(String value) =>
      RequestType.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        RequestType.general => 'Общий',
        RequestType.personal => 'Персональный',
      };
}

/// Maps to the backend's `GuestRequestStatus`.
enum RequestStatus {
  open('OPEN'),
  offered('OFFERED'),
  accepted('ACCEPTED'),
  declined('DECLINED'),
  closed('CLOSED');

  const RequestStatus(this.backend);
  final String backend;

  static RequestStatus fromBackend(String value) =>
      RequestStatus.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        RequestStatus.open => 'Открыт',
        RequestStatus.offered => 'Предложено',
        RequestStatus.accepted => 'Принят',
        RequestStatus.declined => 'Отклонён',
        RequestStatus.closed => 'Закрыт',
      };
}

/// Maps to the backend's `RequestOfferStatus` (PENDING/ACCEPTED/DECLINED) -
/// distinct enum from [ApplicationStatus] on the backend even though the
/// values happen to read similarly; kept separate here too so a future
/// divergence (e.g. offers gaining a WITHDRAWN state) doesn't require
/// re-splitting a shared type.
enum OfferStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  declined('DECLINED');

  const OfferStatus(this.backend);
  final String backend;

  static OfferStatus fromBackend(String value) =>
      OfferStatus.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        OfferStatus.pending => 'На рассмотрении',
        OfferStatus.accepted => 'Принято',
        OfferStatus.declined => 'Отклонено',
      };
}

enum ReviewTargetRole {
  host('HOST'),
  guest('GUEST');

  const ReviewTargetRole(this.backend);
  final String backend;

  static ReviewTargetRole fromBackend(String value) =>
      ReviewTargetRole.values.firstWhere((e) => e.backend == value);
}

/// Mirrors the backend's `NotificationType` in full, even though
/// only some are currently emitted server-side - an unrecognized/future
/// value falls back to [newMessage] rather than throwing.
enum NotificationType {
  applicationReceived('APPLICATION_RECEIVED'),
  applicationAccepted('APPLICATION_ACCEPTED'),
  applicationRejected('APPLICATION_REJECTED'),
  newMessage('NEW_MESSAGE'),
  orderOffered('ORDER_OFFERED'),
  offerAccepted('OFFER_ACCEPTED'),
  offerDeclined('OFFER_DECLINED'),
  rateReminder('RATE_REMINDER'),
  requestMatch('NEW_REQUEST_MATCH'),
  newReview('NEW_REVIEW'),
  complaintResolved('COMPLAINT_RESOLVED'),
  eventThresholdReached('EVENT_THRESHOLD_REACHED'),
  eventCancelled('EVENT_CANCELLED'),
  hostNewEvent('HOST_NEW_EVENT'),
  attendanceNoShow('ATTENDANCE_NO_SHOW'),
  authorLevelUp('AUTHOR_LEVEL_UP'),
  authorOfMonth('AUTHOR_OF_MONTH'),
  specialProject('SPECIAL_PROJECT');

  const NotificationType(this.backend);
  final String backend;

  static NotificationType fromBackend(String value) => NotificationType.values.firstWhere(
        (e) => e.backend == value,
        orElse: () => NotificationType.newMessage,
      );
}

/// App role. PERFORMER/ADMIN may publish events; USER browses and goes.
enum UserRole {
  user('USER'),
  performer('PERFORMER'),
  admin('ADMIN');

  const UserRole(this.backend);
  final String backend;

  static UserRole fromBackend(String? value) => UserRole.values.firstWhere(
        (e) => e.backend == value,
        orElse: () => UserRole.user,
      );

  String get label => switch (this) {
        UserRole.user => 'Пользователь',
        UserRole.performer => 'Организатор',
        UserRole.admin => 'Администратор',
      };

  bool get canHostEvents => this == UserRole.performer || this == UserRole.admin;
}

enum ComplaintTargetType {
  user('USER'),
  event('EVENT'),
  support('SUPPORT'),
  post('POST'),
  story('STORY');

  const ComplaintTargetType(this.backend);
  final String backend;

  static ComplaintTargetType fromBackend(String value) =>
      ComplaintTargetType.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        ComplaintTargetType.user => 'Пользователь',
        ComplaintTargetType.event => 'Событие',
        ComplaintTargetType.support => 'Запрос',
        ComplaintTargetType.post => 'Пост',
        ComplaintTargetType.story => 'История',
      };
}

enum ComplaintStatus {
  open('OPEN'),
  resolved('RESOLVED'),
  dismissed('DISMISSED');

  const ComplaintStatus(this.backend);
  final String backend;

  static ComplaintStatus fromBackend(String value) =>
      ComplaintStatus.values.firstWhere((e) => e.backend == value);

  String get label => switch (this) {
        ComplaintStatus.open => 'Открыта',
        ComplaintStatus.resolved => 'Решена',
        ComplaintStatus.dismissed => 'Отклонена',
      };
}
