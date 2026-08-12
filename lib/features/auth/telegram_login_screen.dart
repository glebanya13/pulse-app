import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';

class TelegramLoginScreen extends ConsumerStatefulWidget {
  const TelegramLoginScreen({super.key, this.phone, required this.deepLink, required this.sessionId});

  /// Null for the one-tap "Continue with Telegram" flow, where whatever
  /// phone the shared Telegram contact provides is accepted as-is.
  final String? phone;
  final String deepLink;
  final String sessionId;

  @override
  ConsumerState<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends ConsumerState<TelegramLoginScreen> {
  Timer? _pollTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openTelegram();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse(widget.deepLink);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Не удалось открыть Telegram. Убедитесь, что он установлен.');
    }
  }

  Future<void> _poll() async {
    try {
      final result = await ref.read(authRepositoryProvider).pollTelegramLogin(widget.sessionId);
      if (!mounted) return;
      if (result.isVerified && result.user != null) {
        _pollTimer?.cancel();
        ref.read(authStateProvider.notifier).signIn(result.user!);
        context.go(postSignInRoute(result.user!));
      } else if (result.isExpired) {
        _pollTimer?.cancel();
        setState(() => _error = 'Время ожидания истекло. Вернитесь назад и попробуйте снова.');
      }
    } catch (_) {
      // Transient network hiccup while polling - ignore and retry next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход через Telegram')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error == null) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                widget.phone != null
                    ? 'Открыли Telegram? Подтвердите номер ${widget.phone}, поделившись контактом в чате с ботом - вход произойдёт автоматически.'
                    : 'Открыли Telegram? Поделитесь контактом в чате с ботом - вход произойдёт автоматически.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _openTelegram, child: const Text('Открыть Telegram ещё раз')),
            ] else ...[
              const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Назад'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
