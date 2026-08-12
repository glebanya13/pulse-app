import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/ritual/pulse_local_reminders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/city_picker.dart';
import '../../data/api/api_client.dart';
import '../../data/api/firebase_social_auth.dart';
import '../../data/api/push_notifications.dart';
import '../../core/providers/city_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;
  bool? _fridayReminder;

  @override
  void initState() {
    super.initState();
    PulseLocalReminders.isEnabled().then((v) {
      if (mounted) setState(() => _fridayReminder = v);
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть $url')),
      );
    }
  }

  Future<void> _signOut() async {
    await PushNotifications.clearBackendToken(ApiClient.instance);
    await ref.read(authRepositoryProvider).logout();
    try {
      await FirebaseSocialAuth().signOutLocal();
    } catch (_) {
      // Firebase may be unconfigured in some builds.
    }
    ref.read(authStateProvider.notifier).signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Аккаунт и связанные с ним данные будут удалены безвозвратно. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await PushNotifications.clearBackendToken(ApiClient.instance);
      await ref.read(userRepositoryProvider).deleteAccount();
      try {
        await FirebaseSocialAuth().signOutLocal();
      } catch (_) {}
      ref.read(authStateProvider.notifier).signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить аккаунт: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsRegular.mapPin),
            title: const Text('Город'),
            subtitle: Text(ref.watch(selectedCityOrDefaultProvider).name),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () => showCityPickerSheet(context, ref),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(PhosphorIconsRegular.bellRinging),
            title: const Text('Напоминания об афише'),
            subtitle: Text(
              'Пятница 18:00 и каждый день 19:00 · ${ref.watch(selectedCityOrDefaultProvider).name}',
            ),
            value: _fridayReminder ?? true,
            onChanged: _fridayReminder == null
                ? null
                : (v) async {
                    setState(() => _fridayReminder = v);
                    await PulseLocalReminders.setEnabled(v);
                  },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.shieldCheck),
            title: const Text('Политика конфиденциальности'),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
            onTap: () => _openUrl(Env.privacyPolicyUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.fileText),
            title: const Text('Пользовательское соглашение'),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
            onTap: () => _openUrl(Env.termsOfUseUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.chatsCircle),
            title: const Text('Поддержка'),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
            onTap: () => _openUrl(Env.supportUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.userMinus),
            title: const Text('Как удалить аккаунт'),
            subtitle: const Text('Инструкция на сайте (для Google Play)'),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
            onTap: () => _openUrl(Env.deleteAccountUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(PhosphorIconsRegular.trash, color: AppColors.danger),
            title: Text(
              'Удалить аккаунт',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Удалить профиль и персональные данные'),
            enabled: !_deleting,
            onTap: _deleting ? null : _deleteAccount,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(PhosphorIconsRegular.signOut, color: AppColors.danger),
            title: Text('Выйти', style: TextStyle(color: AppColors.danger)),
            onTap: _signOut,
          ),
          if (_deleting)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
