import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/phone.dart';
import 'auth_scaffold.dart';
import 'terms_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = normalizeRuPhone(_phoneController.text);
    if (name.isEmpty || !isPlausiblePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните имя и номер телефона')),
      );
      return;
    }
    if (!await ensureTermsAccepted(context)) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).requestCode(phone);
      if (!mounted) return;
      context.push(
        '/verify?phone=${Uri.encodeComponent(phone)}'
        '&mode=register&name=${Uri.encodeComponent(name)}',
      );
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
      title: 'Регистрация',
      subtitle: 'Имя и телефон - дальше код из SMS',
      footer: AuthSwitchLink(
        prompt: 'Уже есть аккаунт?',
        action: 'Войти',
        onTap: () => context.pushReplacement('/login'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFieldLabel('Имя'),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _phoneFocus.requestFocus(),
            decoration: const InputDecoration(
              hintText: 'Как вас зовут?',
            ),
          ),
          const SizedBox(height: 20),
          const AuthFieldLabel('Номер телефона'),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
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
