import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/widgets/pulse_sheet.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';

String formatProUntil(DateTime until) {
  return DateFormat('d MMMM yyyy', 'ru').format(until.toLocal());
}

/// Quiet “В топе” mark for viewers (not a loud promo sticker).
class BoostedBadge extends StatelessWidget {
  const BoostedBadge({super.key, this.compact = false, this.until});

  final bool compact;
  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final label = until != null
        ? (compact ? 'В топе' : 'В топе до ${DateFormat('d MMM', 'ru').format(until!.toLocal())}')
        : 'В топе';
    return Text(
      label,
      style: TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class OrganizerProBadge extends StatelessWidget {
  const OrganizerProBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Pro',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryLight,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

Future<void> showPromoteEventSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Event event,
}) async {
  final me = ref.read(authStateProvider);
  if (me == null) return;

  final already = event.isActivelyBoosted;
  final draft =
      '[Продвижение] Хочу «В топе» для «${event.title}» (id: ${event.id}) на 7 дней';

  final sent = await showPulseSheet<bool>(
    context: context,
    heightFactor: 0.62,
    builder: (ctx) => _AdminRequestSheet(
      title: 'Продвинуть',
      headline: 'Выше в «Сегодня» и афише',
      body:
          'Отправьте заявку админу — согласуем условия и вручную поднимем событие в топ. '
          'Оплата в приложении появится позже.',
      detail: '«${event.title}»',
      statusLine: already && event.boostedUntil != null
          ? 'Уже в топе до ${formatProUntil(event.boostedUntil!)}'
          : null,
      initialMessage: draft,
      confirmLabel: 'Отправить заявку',
      onSubmit: (message) async {
        await ref.read(complaintRepositoryProvider).file(
              targetType: ComplaintTargetType.support,
              targetId: me.id,
              reason: message,
            );
      },
    ),
  );

  if (sent != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Заявка отправлена. Админ свяжется с вами'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> showOrganizerProSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final me = ref.read(authStateProvider);
  if (me == null || !me.canHostEvents) return;

  final active = me.hasActiveOrganizerPro;
  final draft =
      '[Organizer Pro] Хочу Pro на 30 дней. Организатор: ${me.name} (id: ${me.id})';

  final sent = await showPulseSheet<bool>(
    context: context,
    heightFactor: 0.62,
    builder: (ctx) => _AdminRequestSheet(
      title: 'Organizer Pro',
      headline: active ? 'Продлить Pro' : 'Инструменты организатора',
      body:
          'Бейдж Pro и приоритет ваших событий. Создание событий бесплатно. '
          'Оформите заявку админу — Pro включат вручную. Оплата в приложении появится позже.',
      statusLine: active && me.organizerProUntil != null
          ? 'Активна до ${formatProUntil(me.organizerProUntil!)}'
          : null,
      initialMessage: draft,
      confirmLabel: 'Отправить заявку',
      onSubmit: (message) async {
        await ref.read(complaintRepositoryProvider).file(
              targetType: ComplaintTargetType.support,
              targetId: me.id,
              reason: message,
            );
      },
    ),
  );

  if (sent != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Заявка отправлена. Админ свяжется с вами'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _AdminRequestSheet extends StatefulWidget {
  const _AdminRequestSheet({
    required this.title,
    required this.headline,
    required this.body,
    required this.initialMessage,
    required this.confirmLabel,
    required this.onSubmit,
    this.detail,
    this.statusLine,
  });

  final String title;
  final String headline;
  final String body;
  final String? detail;
  final String? statusLine;
  final String initialMessage;
  final String confirmLabel;
  final Future<void> Function(String message) onSubmit;

  @override
  State<_AdminRequestSheet> createState() => _AdminRequestSheetState();
}

class _AdminRequestSheetState extends State<_AdminRequestSheet> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final message = _controller.text.trim();
    if (message.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишите коротко, что нужно')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(message);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseSheetScaffold(
      title: widget.title,
      trailing: const PulseSheetCloseButton(),
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Запрос придёт в админ-панель приложения',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.highlight,
                          ),
                        )
                      : Text(widget.confirmLabel),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        children: [
          Text(
            widget.headline,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            widget.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (widget.detail != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.detail!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
          if (widget.statusLine != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.statusLine!,
              style: const TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Сообщение админу',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile block for organizers: create / my events / Pro (flat links, no cards).
class OrganizerToolsBlock extends ConsumerWidget {
  const OrganizerToolsBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (!user.canHostEvents) return const SizedBox.shrink();
    final active = user.hasActiveOrganizerPro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Организатор',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        _OrgLink(
          label: 'Создать событие',
          onTap: () => context.push('/events/create'),
        ),
        _OrgLink(
          label: 'Мои события',
          onTap: () => context.push('/my-events'),
        ),
        _OrgLink(
          label: active ? 'Organizer Pro' : 'Подключить Pro',
          accent: true,
          onTap: () => showOrganizerProSheet(context: context, ref: ref),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            active && user.organizerProUntil != null
                ? 'Pro до ${formatProUntil(user.organizerProUntil!)}'
                : 'Pro: напишите админу, выдадим вручную',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrgLink extends StatelessWidget {
  const _OrgLink({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accent ? AppColors.primaryLight : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizerProCard extends OrganizerToolsBlock {
  const OrganizerProCard({super.key});
}
