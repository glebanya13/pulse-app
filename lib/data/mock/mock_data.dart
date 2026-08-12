import '../models/application.dart';
import '../models/chat.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/guest_request.dart';
import '../models/notification.dart';
import '../models/review.dart';
import '../models/user.dart';

/// Central place for demo content used while the real backend isn't wired
/// up (see [Env.useMockData]). Every screen in the design is populated from
/// here so the app is fully click-through-able out of the box.
abstract final class MockData {
  static DateTime _today(int hour, [int minute = 0]) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime _inDays(int days, int hour, [int minute = 0]) {
    final d = DateTime.now().add(Duration(days: days));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  // ---------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------

  static final maria = AppUser(
    id: 'u_maria',
    name: 'Мария',
    age: 28,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=47',
    bio: 'Организую вечеринки и клубные ночи в Минске. '
        'Следите за афишей!',
    whatICook: 'DJ sets, house, techno',
    socialLinks: const {
      'instagram': 'marina.pulse.minsk',
      'telegram': '@marina_pulse',
      'vk': 'marina.pulse',
    },
    photos: const [
      'https://picsum.photos/seed/maria1/600/600',
      'https://picsum.photos/seed/maria2/600/600',
      'https://picsum.photos/seed/maria3/600/600',
    ],
    rating: 98,
    eventsCount: 12,
    reviewsCount: 97,
    memberSince: DateTime.now().subtract(const Duration(days: 365 * 2)),
    badges: const [
      Badge(code: 'top_host', title: 'Топ организатор', description: 'Рейтинг 95+', icon: '⭐'),
      Badge(code: 'sociable', title: 'Душа компании', description: '10+ вечеров', icon: '🎉'),
    ],
  );

  static final natalia = AppUser(
    id: 'u_natalia',
    name: 'Наталья',
    age: 45,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=32',
    bio: 'Квизы и камерные вечера в барах.',
    whatICook: 'Quiz, stand-up',
    photos: const [
      'https://picsum.photos/seed/natalia1/600/600',
      'https://picsum.photos/seed/natalia2/600/600',
    ],
    rating: 95,
    eventsCount: 34,
    reviewsCount: 61,
    memberSince: DateTime.now().subtract(const Duration(days: 365 * 3)),
  );

  static final alexey = AppUser(
    id: 'u_alexey',
    name: 'Алексей',
    age: 33,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=13',
    bio: 'Люблю пробовать новое и знакомиться с интересными людьми.',
    photos: const [],
    rating: 89,
    eventsCount: 7,
    reviewsCount: 23,
    memberSince: DateTime.now().subtract(const Duration(days: 365)),
  );

  static final vera = AppUser(
    id: 'u_vera',
    name: 'Вера',
    age: 39,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=45',
    whatICook: 'Домашняя кухня',
    rating: 92,
    eventsCount: 19,
    reviewsCount: 40,
    memberSince: DateTime.now().subtract(const Duration(days: 365)),
  );

  static final igor = AppUser(
    id: 'u_igor',
    name: 'Игорь',
    age: 41,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=14',
    whatICook: 'Мясные блюда, BBQ',
    rating: 90,
    eventsCount: 15,
    reviewsCount: 28,
    memberSince: DateTime.now().subtract(const Duration(days: 200)),
  );

  static final elena = AppUser(
    id: 'u_elena',
    name: 'Елена',
    age: 26,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=25',
    whatICook: 'Десерты',
    rating: 88,
    eventsCount: 9,
    reviewsCount: 17,
    memberSince: DateTime.now().subtract(const Duration(days: 150)),
  );

  static final anna = AppUser(
    id: 'u_anna',
    name: 'Анна',
    age: 27,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=48',
    rating: 91,
    eventsCount: 5,
    reviewsCount: 11,
    memberSince: DateTime.now().subtract(const Duration(days: 90)),
  );

  /// The signed-in demo user - swap for the real /users/me response later.
  static final me = AppUser(
    id: 'u_me',
    name: 'Денис',
    age: 30,
    city: 'Минск',
    avatarUrl: 'https://i.pravatar.cc/300?img=12',
    bio: 'Люблю концерты и ночные сеты.',
    whatICook: 'Live / club',
    rating: 93,
    eventsCount: 8,
    reviewsCount: 19,
    memberSince: DateTime.now().subtract(const Duration(days: 400)),
    isAdmin: true,
  );

  static List<AppUser> get allUsers =>
      [maria, natalia, alexey, vera, igor, elena, anna, me];

  // ---------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------

  static final eventPastaWine = Event(
    id: 'e_pasta_wine',
    host: maria,
    format: EventFormat.inPerson,
    title: 'Techno Night · Pulse',
    description: 'Ночной techno/house сет. Свет, дым, танцпол. 18+.',
    photos: const ['https://picsum.photos/seed/pastawine/900/700'],
    tags: const ['Вечеринка', 'Клуб', '18+'],
    startAt: _today(16, 0),
    endAt: _today(21, 0),
    address: 'Минск, Ok16, ул. Октябрьская',
    location: const GeoPoint(latitude: 53.8901, longitude: 27.5512),
    minGuests: 2,
    maxGuests: 6,
    currentGuests: 3,
    priceType: PriceType.fixed,
    priceAmount: 35,
    requirements: const GuestRequirements(maxAge: 30),
  );

  static final eventBorsch = Event(
    id: 'e_borsch',
    host: vera,
    format: EventFormat.takeaway,
    title: 'Early bird · Techno Night',
    description: 'Предпродажа входа на Techno Night.',
    photos: const ['https://picsum.photos/seed/borsch/900/700'],
    tags: const ['Новое'],
    startAt: _today(12, 0),
    endAt: _today(18, 0),
    address: 'Минск, Ok16',
    location: const GeoPoint(latitude: 53.8901, longitude: 27.5512),
    priceType: PriceType.fixed,
    priceAmount: 25,
    pickupMethod: PickupMethod.pickupOnly,
    pickupAddress: 'Минск, ул. Октябрьская, 16 - касса',
  );

  static final eventPirog = Event(
    id: 'e_pirog',
    host: natalia,
    format: EventFormat.takeaway,
    title: 'Билет на stand-up',
    description: 'Квизы и камерные вечера в барах.',
    photos: const ['https://picsum.photos/seed/pirog/900/700'],
    tags: const ['Билеты', 'Stand-up'],
    startAt: _today(15, 0),
    address: 'Минск, пр. Независимости',
    location: const GeoPoint(latitude: 53.9045, longitude: 27.5615),
    priceType: PriceType.fixed,
    priceAmount: 20,
    pickupMethod: PickupMethod.meetAtDoor,
    pickupAddress: 'Минск, бар у Независимости',
  );

  static final eventBoardGames = Event(
    id: 'e_board_games',
    host: igor,
    format: EventFormat.inPerson,
    title: 'Джаз в Верхнем городе',
    description: 'Живой джаз, вино и мягкий свет.',
    photos: const ['https://picsum.photos/seed/boardgames/900/700'],
    tags: const ['Джаз', 'Live', 'Бар'],
    startAt: _today(19, 0),
    address: 'Минск, пл. Свободы',
    location: const GeoPoint(latitude: 53.9040, longitude: 27.5550),
    minGuests: 2,
    maxGuests: 6,
    currentGuests: 4,
    priceType: PriceType.fixed,
    priceAmount: 35,
  );

  static final eventBreakfast = Event(
    id: 'e_breakfast',
    host: elena,
    format: EventFormat.inPerson,
    title: 'Stand-up вечер',
    description: 'Открытый микрофон и хедлайнеры минской сцены.',
    photos: const ['https://picsum.photos/seed/breakfast/900/700'],
    tags: const ['Stand-up', 'Бар'],
    startAt: _today(11, 0),
    address: 'Минск, пр. Независимости',
    location: const GeoPoint(latitude: 53.9045, longitude: 27.5615),
    minGuests: 2,
    maxGuests: 4,
    currentGuests: 2,
    priceType: PriceType.fixed,
    priceAmount: 15,
  );

  static final eventBbq = Event(
    id: 'e_bbq',
    host: igor,
    format: EventFormat.inPerson,
    title: 'Open-air у Комсомольского озера',
    description: 'Дневной open-air: indie / electronic.',
    photos: const ['https://picsum.photos/seed/bbq/900/700'],
    tags: const ['Open-air', 'Фестиваль'],
    startAt: _inDays(2, 14, 0),
    address: 'Минск, парк Победы',
    location: const GeoPoint(latitude: 53.9275, longitude: 27.5350),
    minGuests: 3,
    maxGuests: 10,
    currentGuests: 5,
    priceType: PriceType.donation,
  );

  static final eventWineTasting = Event(
    id: 'e_wine_tasting',
    host: maria,
    format: EventFormat.inPerson,
    title: 'Большой концерт на арене',
    description: 'Хедлайнер + support на Минск-Арене.',
    photos: const ['https://picsum.photos/seed/wine/900/700'],
    tags: const ['Концерт', 'Арена'],
    startAt: _inDays(1, 20, 0),
    address: 'Минск, Минск-Арена',
    location: const GeoPoint(latitude: 53.9364, longitude: 27.4822),
    minGuests: 2,
    maxGuests: 8,
    currentGuests: 6,
    priceType: PriceType.fixed,
    priceAmount: 90,
  );

  static List<Event> get allEvents => [
        eventPastaWine,
        eventBorsch,
        eventPirog,
        eventBoardGames,
        eventBreakfast,
        eventBbq,
        eventWineTasting,
      ];

  /// Events hosted by the demo user - "Мои события".
  static List<Event> get myEvents => [
        eventPastaWine.copyWith(),
        Event(
          id: 'e_snacks',
          host: me,
          format: EventFormat.inPerson,
          title: 'Настолки и закуски',
          description: 'Вечер настолок с лёгкими закусками и хорошей музыкой.',
          photos: const ['https://picsum.photos/seed/snacks/900/700'],
          tags: const ['Настолки'],
          startAt: _inDays(3, 18, 0),
          address: 'Минск, Ok16',
          location: const GeoPoint(latitude: 53.8901, longitude: 27.5512),
          minGuests: 2,
          maxGuests: 6,
          currentGuests: 3,
          priceType: PriceType.donation,
        ),
        eventBreakfast.copyWith(status: EventStatus.completed),
      ];

  // ---------------------------------------------------------------------
  // Applications (заявки на участие)
  // ---------------------------------------------------------------------

  static final applications = <EventApplication>[
    EventApplication(
      id: 'a1',
      event: eventPastaWine,
      applicant: anna,
      status: ApplicationStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    EventApplication(
      id: 'a2',
      event: eventPastaWine,
      applicant: alexey,
      status: ApplicationStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    EventApplication(
      id: 'a3',
      event: eventBoardGames,
      applicant: me,
      status: ApplicationStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    EventApplication(
      id: 'a4',
      event: eventBreakfast,
      applicant: me,
      status: ApplicationStatus.rejected,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // ---------------------------------------------------------------------
  // Guest requests (запросы)
  // ---------------------------------------------------------------------

  static final requests = <GuestRequest>[
    GuestRequest(
      id: 'r1',
      author: anna,
      type: RequestType.general,
      title: 'Срочно нужен повар на ужин',
      description: 'Нужен повар, который приготовит ужин на 4 персоны у меня '
          'дома сегодня вечером.',
      requestedAt: _today(16, 0),
      address: 'м. Парк культуры',
      budgetType: PriceType.fixed,
      budgetAmount: 1500,
      status: RequestStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      offers: [
        RequestOffer(id: 'o1', host: maria, createdAt: DateTime.now()),
        RequestOffer(id: 'o2', host: vera, createdAt: DateTime.now()),
      ],
    ),
    GuestRequest(
      id: 'r2',
      author: igor,
      type: RequestType.general,
      title: 'Нужно 10 порций борща',
      description: 'Нужно приготовить 10 порций борща для строительной бригады.',
      portionsCount: 10,
      requestedAt: _inDays(1, 12, 0),
      address: 'Минск, Ok16',
      budgetType: PriceType.free,
      status: RequestStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      offers: [
        RequestOffer(id: 'o3', host: vera, createdAt: DateTime.now()),
      ],
    ),
    GuestRequest(
      id: 'r3',
      author: me,
      type: RequestType.personal,
      title: 'Хочу пирог осетинский',
      description: 'Хочу заказать осетинский пирог на семейный ужин.',
      requestedAt: _inDays(8, 15, 0),
      address: 'Минск, Минск-Арена',
      budgetType: PriceType.fixed,
      budgetAmount: 1500,
      targetHost: natalia,
      status: RequestStatus.offered,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      offers: [
        RequestOffer(id: 'o4', host: natalia, createdAt: DateTime.now()),
      ],
    ),
  ];

  static List<AppUser> get requestCandidateHosts => [maria, natalia, vera, igor, elena];

  // ---------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------

  static final eventChat = Chat(
    id: 'c_pasta_wine',
    event: eventPastaWine,
    participants: [maria, alexey, anna, igor, me],
    messages: [
      ChatMessage(
        id: 'm1',
        chatId: 'c_pasta_wine',
        sender: maria,
        text: 'Всем привет! Рада вас видеть в нашем уютном вечере 🍝',
        createdAt: _today(9, 30),
      ),
      ChatMessage(
        id: 'm2',
        chatId: 'c_pasta_wine',
        sender: alexey,
        text: 'Привет! Уже в предвкушении ужина 🍷',
        createdAt: _today(9, 51),
      ),
      ChatMessage(
        id: 'm3',
        chatId: 'c_pasta_wine',
        sender: anna,
        text: 'Привет всем! Я с десертом 🍰',
        createdAt: _today(10, 32),
      ),
      ChatMessage(
        id: 'm4',
        chatId: 'c_pasta_wine',
        sender: igor,
        text: 'До встречи вечером, шеф-повар уже готовит 👨‍🍳',
        createdAt: _today(10, 32),
      ),
    ],
  );

  static List<Chat> get chats => [eventChat];

  // ---------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------

  static final reviews = <Review>[
    Review(
      id: 'rv1',
      eventId: eventBreakfast.id,
      eventTitle: eventBreakfast.title,
      reviewer: me,
      target: elena,
      targetRole: ReviewTargetRole.host,
      scores: const {
        'Вкус': 95,
        'Атмосфера': 98,
        'Гостеприимство': 90,
        'Чистота': 92,
        'Общительность': 93,
        'Соответствие ожиданиям': 96,
        'Организация': 93,
        'Вайб': 94,
      },
      serverOverallScore: 94,
      comment: 'Очень уютно и вкусно, обязательно вернусь ещё!',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  static final notifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      type: NotificationType.orderOffered,
      title: 'Вам предложен заказ',
      body: 'Пирог осетинский от Марии',
      createdAt: _today(11, 20),
      payload: const {'requestId': 'r3'},
    ),
    AppNotification(
      id: 'n2',
      type: NotificationType.applicationAccepted,
      title: 'Ваша заявка принята',
      body: 'Ужин с пастой и вином',
      createdAt: _today(10, 15),
      payload: const {'eventId': 'e_pasta_wine'},
    ),
    AppNotification(
      id: 'n3',
      type: NotificationType.newMessage,
      title: 'Новое сообщение в чате',
      body: 'Ужин с пастой и вином',
      createdAt: _today(9, 45),
      isRead: true,
      payload: const {'chatId': 'c_pasta_wine'},
    ),
    AppNotification(
      id: 'n4',
      type: NotificationType.rateReminder,
      title: 'Оцените встречу',
      body: 'Завтрак на веранде',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      isRead: true,
      payload: const {'eventId': 'e_breakfast'},
    ),
    AppNotification(
      id: 'n5',
      type: NotificationType.applicationRejected,
      title: 'Ваша заявка отклонена',
      body: 'Настолки и закуски',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      isRead: true,
      payload: const {'eventId': 'e_snacks'},
    ),
  ];
}
