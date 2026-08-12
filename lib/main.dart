import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/env.dart';
import 'core/mapkit/mapkit_bootstrap.dart';
import 'core/providers/auth_providers.dart';
import 'core/providers/push_invalidate.dart';
import 'core/providers/repository_providers.dart';
import 'core/ritual/pulse_local_reminders.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/api/push_notifications.dart';
import 'data/models/user.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) {
    return Material(
      color: AppColors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Не удалось показать экран.\nПерезапустите приложение.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontFamily: AppTheme.fontFamily),
          ),
        ),
      ),
    );
  };

  await initializeDateFormatting('ru');

  try {
    if (DefaultFirebaseOptions.android.apiKey != 'REPLACE_ME') {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 5));
    }
  } catch (e, st) {
    debugPrint('Firebase init skipped: $e\n$st');
  }

  if (!_runningUnderTest) {
    unawaited(PulseLocalReminders.init());
  }

  if (Env.hasMapkitKey && !_runningUnderTest) {
    await MapKitBootstrap.instance.ensureInitialized();
  }

  runApp(const ProviderScope(child: PulseApp()));
}

bool get _runningUnderTest =>
    Platform.environment.containsKey('FLUTTER_TEST');

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key});

  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      if (!await ApiClient.instance.hasToken()) return;

      final user = await ref
          .read(userRepositoryProvider)
          .me()
          .timeout(const Duration(seconds: 12));
      ref.read(authStateProvider.notifier).signIn(user);

      // Push sync must never log the user out - APNs/FCM often hangs on first launch.
      try {
        await PushNotifications.syncTokenWithBackend(ApiClient.instance)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('FCM sync during restore skipped: $e');
      }
    } catch (e) {
      debugPrint('Session restore skipped: $e');
      // Only clear tokens when /users/me (or refresh) actually failed.
      await ApiClient.instance.clearTokens();
      ref.read(authStateProvider.notifier).signOut();
    } finally {
      if (mounted) setState(() => _sessionReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final router = ref.watch(routerProvider);
    ApiClient.instance.onUnauthorized = () => ref.read(authStateProvider.notifier).signOut();

    PushNotifications.attachOpenHandler((location) {
      if (location.startsWith('/home/')) {
        router.go(location);
      } else {
        router.push(location);
      }
    });
    PulseLocalReminders.attachOpenHandler((location) {
      if (location.startsWith('/home/')) {
        router.go(location);
      } else {
        router.push(location);
      }
    });
    PushNotifications.attachDataHandler((data) {
      invalidateProvidersForPushPayload(
        ProviderScope.containerOf(context),
        data,
      );
    });

    ref.listen<AppUser?>(authStateProvider, (previous, next) {
      if (next != null && previous?.id != next.id) {
        PushNotifications.syncTokenWithBackend(ApiClient.instance);
      }
    });

    return MaterialApp.router(
      title: 'Пульс',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
