import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/api_errors.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  /// Convenience: maps Dio / network errors to a short Russian message.
  factory ErrorState.fromError(Object error, {Key? key, VoidCallback? onRetry}) {
    return ErrorState(key: key, message: apiErrorMessage(error), onRetry: onRetry);
  }

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить данные',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ],
        ),
      ),
    );
  }
}
