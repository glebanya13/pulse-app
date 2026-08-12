import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';

/// "Войти через Яндекс"/"Войти через VK" - opens the provider's login page
/// in an external browser (the callback that finishes the login is hit
/// directly by that browser, never by the app), then polls the session the
/// same way [TelegramLoginScreen] does.
class OAuthLoginScreen extends ConsumerStatefulWidget {
  const OAuthLoginScreen({
    super.key,
    required this.provider,
    required this.providerLabel,
    required this.authorizeUrl,
    required this.sessionId,
  });

  /// `yandex` or `vk` - matches the backend's `/auth/<provider>/*` routes.
  final String provider;
  final String providerLabel;
  final String authorizeUrl;
  final String sessionId;

  @override
  ConsumerState<OAuthLoginScreen> createState() => _OAuthLoginScreenState();
}

class _OAuthLoginScreenState extends ConsumerState<OAuthLoginScreen> {
  Timer? _pollTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openBrowser();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    final uri = Uri.parse(widget.authorizeUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Не удалось открыть страницу входа.');
    }
  }

  Future<void> _poll() async {
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .pollOAuthLogin(widget.provider, widget.sessionId);
      if (!mounted) return;
      if (result.isVerified && result.user != null) {
        _pollTimer?.cancel();
        ref.read(authStateProvider.notifier).signIn(result.user!);
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
      appBar: AppBar(title: Text('Вход через ${widget.providerLabel}')),
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
                'Откроется страница входа ${widget.providerLabel} в браузере - после подтверждения '
                'вы автоматически вернётесь в приложение уже авторизованным.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _openBrowser, child: const Text('Открыть ещё раз')),
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
