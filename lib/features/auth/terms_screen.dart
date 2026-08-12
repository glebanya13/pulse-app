import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/terms_acceptance.dart';

/// Gate before registering or first-time social sign-in: shows [TermsScreen]
/// if not accepted yet, and returns whether the caller may proceed.
Future<bool> ensureTermsAccepted(BuildContext context) async {
  if (await TermsAcceptance.isAccepted()) return true;
  if (!context.mounted) return false;
  final accepted = await context.push<bool>('/terms');
  return accepted ?? false;
}

/// Shown once before a user can register/sign in for the first time - an
/// explicit in-app acceptance step, not just a passive external link (App
/// Store Guideline 1.2). Pops `true` if the user accepted, `false`/nothing
/// if they backed out.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;
  bool _isAdult = false;

  Future<void> _continue() async {
    if (!_accepted || !_isAdult) return;
    await TermsAcceptance.markAccepted();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Правила использования')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Прежде чем продолжить',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Пульс - сервис афиши тусовок, концертов и мероприятий. '
                      'Сервис предназначен для пользователей 18+. Регистрируясь, вы соглашаетесь:\n\n'
                      '• вам исполнилось 18 лет;\n'
                      '• не публиковать оскорбительный, незаконный или иным образом '
                      'недопустимый контент;\n'
                      '• уважительно относиться к другим пользователям;\n'
                      '• нести ответственность за организуемые и посещаемые встречи.\n\n'
                      'Мы удаляем контент и блокируем пользователей, нарушающих правила. '
                      'Пожаловаться можно на пост, историю, событие, пользователя или в чате; '
                      'заблокировать обидчика - на его профиле: его контент сразу '
                      'перестанет быть вам виден.\n\n'
                      'Полные условия - в Пользовательском соглашении и Политике '
                      'конфиденциальности по ссылкам ниже.',
                      style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(Env.termsOfUseUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Пользовательское соглашение (полный текст)'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(Env.privacyPolicyUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Политика конфиденциальности (полный текст)'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _isAdult,
                    onChanged: (v) => setState(() => _isAdult = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Мне исполнилось 18 лет',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CheckboxListTile(
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Я принимаю условия Пользовательского соглашения и Политики конфиденциальности',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (_accepted && _isAdult) ? _continue : null,
                    child: const Text('Принимаю и продолжаю'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
