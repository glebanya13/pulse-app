import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/models/enums.dart';

/// Shows a "Пожаловаться" dialog and files the complaint (user, event, post, story, support).
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required ComplaintTargetType targetType,
  required String targetId,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Пожаловаться'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 2000,
        decoration: const InputDecoration(
          hintText: 'Опишите, что произошло',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Отправить'),
        ),
      ],
    ),
  );

  if (reason == null) return;
  if (reason.length < 3) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Опишите причину жалобы подробнее')));
    }
    return;
  }

  try {
    await ref
        .read(complaintRepositoryProvider)
        .file(targetType: targetType, targetId: targetId, reason: reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Жалоба отправлена, спасибо')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось отправить жалобу: $e')));
    }
  }
}
