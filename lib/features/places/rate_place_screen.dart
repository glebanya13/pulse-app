import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/widgets/error_state.dart';
import '../events/events_providers.dart';

class RatePlaceScreen extends ConsumerStatefulWidget {
  const RatePlaceScreen({
    super.key,
    required this.eventId,
    required this.placeId,
  });

  final String eventId;
  final String placeId;

  @override
  ConsumerState<RatePlaceScreen> createState() => _RatePlaceScreenState();
}

class _RatePlaceScreenState extends ConsumerState<RatePlaceScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();
  final List<String> _photoUrls = [];
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photoUrls.length >= 5 || _uploading) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final social = ref.read(socialRepositoryProvider);
      for (final x in files.take(5 - _photoUrls.length)) {
        final url = await social.uploadImage(File(x.path));
        // uploadImage already resolves media URL
        _photoUrls.add(url);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось загрузить фото'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_stars < 1 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(placesRepositoryProvider).reviewPlace(
            placeId: widget.placeId,
            eventId: widget.eventId,
            stars: _stars,
            comment: _commentController.text.trim(),
            photos: List.of(_photoUrls),
          );
      ref.invalidate(eventByIdProvider(widget.eventId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отзыв о месте отправлен')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Оценить место')),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(eventByIdProvider(widget.eventId)),
        ),
        data: (event) {
          final placeName = event.place?.name ?? event.address;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                placeName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                event.title,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const Text('Оценка', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => _stars = i),
                      icon: Icon(
                        i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i <= _stars ? AppColors.ratingGold : AppColors.textTertiary,
                        size: 36,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Как вам место?',
                  hintText: 'Звук, бар, атмосфера, охрана…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _uploading || _photoUrls.length >= 5 ? null : _pickPhotos,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text('Фото (${_photoUrls.length}/5)'),
                  ),
                ],
              ),
              if (_photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (c, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            Env.resolveMediaUrl(_photoUrls[i]),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _photoUrls.removeAt(i)),
                            icon: const Icon(Icons.close, size: 16, color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _stars >= 1 && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.highlight),
                      )
                    : const Text('Отправить отзыв'),
              ),
            ],
          );
        },
      ),
    );
  }
}
