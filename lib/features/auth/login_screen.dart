import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/phone.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeRuPhone(_phoneController.text);
    if (!isPlausiblePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректный номер телефона')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).requestCode(phone);
      if (!mounted) return;
      context.push('/verify?phone=${Uri.encodeComponent(phone)}&mode=login');
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Вход',
      subtitle: 'Номер телефона - и вы в пульсе ночи Минска',
      footer: AuthSwitchLink(
        prompt: 'Нет аккаунта?',
        action: 'Зарегистрироваться',
        onTap: () => context.pushReplacement('/register'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Номер телефона'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
            inputFormatters: [RuPhoneInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Номер телефона',
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Получить код',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
