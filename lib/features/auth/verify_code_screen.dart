import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/phone.dart';
import 'auth_scaffold.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.phone,
    required this.isRegister,
    this.name,
  });

  final String phone;
  final bool isRegister;
  final String? name;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestCode(normalizeRuPhone(widget.phone));
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен ещё раз')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map && (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : 'Не удалось отправить код. Попробуйте позже.';
      setState(() => _error = msg);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось отправить код. Попробуйте позже.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var user = await ref
          .read(authRepositoryProvider)
          .verifyCode(normalizeRuPhone(widget.phone), _codeController.text.trim());

      final name = widget.name?.trim();
      if (widget.isRegister && name != null && name.isNotEmpty) {
        try {
          user = await ref.read(userRepositoryProvider).updateProfile(name: name);
        } catch (_) {
          // Session is already valid - profile can be finished later.
        }
      }

      ref.read(authStateProvider.notifier).signIn(user);
      if (!mounted) return;
      context.go(postSignInRoute(user));
    } catch (_) {
      setState(() => _error = 'Неверный код. Проверьте SMS и попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = normalizeRuPhone(widget.phone);

    return AuthScaffold(
      title: 'Код из SMS',
      subtitle: 'Отправили на $phone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            autofocus: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onChanged: (v) {
              if (v.trim().length == 4 && !_loading) _submit();
            },
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.highlight,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '····',
              hintStyle: TextStyle(
                letterSpacing: 14,
                color: AppColors.cool.withValues(alpha: 0.35),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 28),
          AuthPrimaryButton(
            label: 'Подтвердить',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resendIn > 0 || _resending ? null : _resend,
            child: Text(
              _resendIn > 0
                  ? 'Отправить ещё раз через $_resendIn с'
                  : (_resending ? 'Отправляем…' : 'Отправить код ещё раз'),
              style: TextStyle(
                color: _resendIn > 0 || _resending
                    ? AppColors.textTertiary
                    : AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
