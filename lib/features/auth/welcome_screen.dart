import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/pulse_wordmark.dart';
import '../../data/api/firebase_social_auth.dart';
import 'telegram_login_screen.dart';
import 'terms_screen.dart';

enum _AuthPanel { actions, login, register }

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _telegramLoading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _phoneLoading = false;
  _AuthPanel _panel = _AuthPanel.actions;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  FirebaseSocialAuth? _firebaseSocial;
  late final AnimationController _enter;
  late final Animation<double> _fadeIn;

  FirebaseSocialAuth get _social => _firebaseSocial ??= FirebaseSocialAuth();

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeIn = CurvedAnimation(parent: _enter, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _showPanel(_AuthPanel panel) {
    FocusScope.of(context).unfocus();
    setState(() => _panel = panel);
    if (panel == _AuthPanel.login || panel == _AuthPanel.register) {
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        if (!mounted || _panel != panel) return;
        final node = panel == _AuthPanel.register ? _nameFocus : _phoneFocus;
        node.requestFocus();
      });
    }
  }

  Future<void> _submitPhone({required bool isRegister}) async {
    final phone = normalizeRuPhone(_phoneController.text);
    final name = _nameController.text.trim();
    if (isRegister && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя')),
      );
      return;
    }
    if (!isPlausiblePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный номер телефона')),
      );
      return;
    }
    if (isRegister && !await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _phoneLoading = true);
    try {
      await ref.read(authRepositoryProvider).requestCode(phone);
      if (!mounted) return;
      final q = StringBuffer('/verify?phone=${Uri.encodeComponent(phone)}');
      if (isRegister) {
        q.write('&mode=register&name=${Uri.encodeComponent(name)}');
      } else {
        q.write('&mode=login');
      }
      context.push(q.toString());
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: 'Не удалось отправить код. Проверьте номер и интернет.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _phoneLoading = false);
    }
  }

  Future<void> _loginWithTelegram() async {
    if (!await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _telegramLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).startTelegramLogin();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => TelegramLoginScreen(
          deepLink: session.deepLink,
          sessionId: session.sessionId,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, fallback: 'Вход через Telegram недоступен'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _telegramLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!_firebaseReady) {
      _showSocialUnavailable();
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _googleLoading = true);
    try {
      final social = await _social.signInWithGoogle();
      final user = await ref
          .read(authRepositoryProvider)
          .loginWithFirebaseIdToken(social.idToken, name: social.name);
      if (!mounted) return;
      ref.read(authStateProvider.notifier).signIn(user);
      context.go(postSignInRoute(user));
    } on FirebaseSocialAuthCancelled {
      // silent
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, fallback: 'Не удалось войти через Google. Попробуйте телефон.'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, fallback: 'Не удалось войти через Google. Попробуйте телефон.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    if (!_firebaseReady) {
      _showSocialUnavailable();
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вход через Apple недоступен на этой платформе')),
      );
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _appleLoading = true);
    try {
      final social = await _social.signInWithApple();
      final user = await ref.read(authRepositoryProvider).loginWithFirebaseIdToken(
            social.idToken,
            name: social.name,
            appleAuthorizationCode: social.appleAuthorizationCode,
          );
      if (!mounted) return;
      ref.read(authStateProvider.notifier).signIn(user);
      context.go(postSignInRoute(user));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Apple: ${e.message}')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: 'Не удалось войти через Apple. Попробуйте телефон.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось войти через Apple. Попробуйте телефон.'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  void _showSocialUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Войдите по номеру телефона или через Telegram'),
      ),
    );
  }

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  bool get _anySocialLoading =>
      _telegramLoading || _googleLoading || _appleLoading;

  /// Apple is required on iOS alongside Google (App Store Guideline 4.8).
  bool get _showApple =>
      _firebaseReady &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _showGoogle => _firebaseReady;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final onForm = _panel != _AuthPanel.actions;

    return PopScope(
      canPop: !onForm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && onForm) _showPanel(_AuthPanel.actions);
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PulseBackdrop(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 16 + bottomInset),
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: onForm
                            ? IconButton(
                                onPressed: () => _showPanel(_AuthPanel.actions),
                                icon: const Icon(PhosphorIconsRegular.caretLeft),
                                color: AppColors.highlight,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: const Center(
                          child: _WelcomeBrand(),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _fadeIn,
                      // Fixed height keeps logo/title pinned while panels crossfade.
                      child: SizedBox(
                        height: 372,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            _panelLayer(
                              visible: _panel == _AuthPanel.actions,
                              child: _buildActions(),
                            ),
                            _panelLayer(
                              visible: _panel != _AuthPanel.actions,
                              child: _buildPhoneForm(
                                isRegister: _panel == _AuthPanel.register,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelLayer({required bool visible, required Widget child}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      key: const ValueKey('actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _anySocialLoading ? null : () => _showPanel(_AuthPanel.login),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.highlight,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Войти по телефону',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _anySocialLoading ? null : () => _showPanel(_AuthPanel.register),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.lilac,
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Создать аккаунт',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Divider(color: AppColors.cool.withValues(alpha: 0.25)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'или через',
                style: TextStyle(
                  color: AppColors.cool.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: AppColors.cool.withValues(alpha: 0.25)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialCircle(
              label: 'Telegram',
              loading: _telegramLoading,
              enabled: !_anySocialLoading,
              background: const Color(0xFF2AABEE),
              onTap: _loginWithTelegram,
              child: Image.asset(
                'assets/icons/telegram.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 22),
            if (_showGoogle)
              _SocialCircle(
                label: 'Google',
                loading: _googleLoading,
                enabled: !_anySocialLoading,
                background: Colors.white,
                onTap: _loginWithGoogle,
                child: Transform.scale(
                  scale: 1.55,
                  child: Image.asset(
                    'assets/icons/google.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            if (_showApple) ...[
              if (_showGoogle) const SizedBox(width: 22),
              _SocialCircle(
                label: 'Apple',
                loading: _appleLoading,
                enabled: !_anySocialLoading,
                background: const Color(0xFF0A0A0A),
                border: AppColors.primaryLight.withValues(alpha: 0.45),
                onTap: _loginWithApple,
                child: const Icon(Icons.apple, size: 38, color: Colors.white),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/home/feed'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            'Смотреть афишу без входа',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(Env.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Конфиденциальность',
                style: TextStyle(
                  color: AppColors.cool.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '·',
              style: TextStyle(color: AppColors.cool.withValues(alpha: 0.4)),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(Env.termsOfUseUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Соглашение',
                style: TextStyle(
                  color: AppColors.cool.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneForm({required bool isRegister}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRegister) ...[
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _phoneFocus.requestFocus(),
            decoration: const InputDecoration(hintText: 'Как вас зовут?'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [RuPhoneInputFormatter()],
          onSubmitted: (_) {
            if (!_phoneLoading) _submitPhone(isRegister: isRegister);
          },
          decoration: const InputDecoration(hintText: 'Номер телефона'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _phoneLoading ? null : () => _submitPhone(isRegister: isRegister),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.highlight,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _phoneLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.white,
                  ),
                )
              : const Text(
                  'Получить код',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _phoneLoading
              ? null
              : () => _showPanel(isRegister ? _AuthPanel.login : _AuthPanel.register),
          child: Text(
            isRegister ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться',
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 148,
                height: 148,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const PulseWordmark(fontSize: 48),
          const SizedBox(height: 12),
          Text(
            'Ночь Минска - концерты и афиша',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.lilac.withValues(alpha: 0.9),
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseBackdrop extends StatelessWidget {
  const _PulseBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.black),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 0.95,
              colors: [
                Color(0xBB3B176F),
                Color(0x337B35D6),
                Color(0x00000000),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialCircle extends StatelessWidget {
  const _SocialCircle({
    required this.label,
    required this.child,
    required this.onTap,
    required this.background,
    required this.loading,
    required this.enabled,
    this.border,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;
  final Color background;
  final bool loading;
  final bool enabled;
  final Color? border;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              customBorder: const CircleBorder(),
              child: Ink(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: border != null ? Border.all(color: border!, width: 1.5) : null,
                ),
                child: ClipOval(
                  child: Center(
                    child: loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: background.computeLuminance() > 0.5
                                  ? Colors.black54
                                  : Colors.white,
                            ),
                          )
                        : child,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.cool.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
