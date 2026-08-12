import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/price_type_selector.dart';
import '../../core/widgets/rating_badge.dart';
import '../../data/models/enums.dart';
import '../../data/models/guest_request.dart';
import '../../data/models/user.dart';
import 'requests_providers.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  RequestType _type = RequestType.general;
  bool _choosingHost = false;
  AppUser? _selectedHost;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _portionsController = TextEditingController(text: '1');
  PriceType _budgetType = PriceType.free;
  final _budgetController = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  bool _submitting = false;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _portionsController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final updated = await ref.read(userRepositoryProvider).uploadPhotos([File(picked.path)]);
      if (mounted) setState(() => _uploadedPhotoUrl = updated.photos.last);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось загрузить фото: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<DateTime?> _pickOne({
    required DateTime? initial,
    required String helpText,
  }) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      helpText: helpText,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
      helpText: helpText,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickOne(initial: _startAt, helpText: 'С какого времени');
    if (picked == null) return;
    setState(() {
      _startAt = picked;
      if (_endAt == null || !_endAt!.isAfter(picked)) {
        _endAt = picked.add(const Duration(hours: 3));
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickOne(
      initial: _endAt ?? _startAt?.add(const Duration(hours: 3)),
      helpText: 'До какого времени',
    );
    if (picked == null) return;
    setState(() => _endAt = picked);
  }

  void _goToHostPicker() {
    if (_titleController.text.trim().isEmpty || _startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заполните название и окно времени')));
      return;
    }
    setState(() => _choosingHost = true);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final me = ref.read(currentUserProvider);
      if (_startAt == null || _endAt == null) {
        throw StateError('Укажите окно времени');
      }
      if (_endAt!.isBefore(_startAt!)) {
        throw StateError('Конец окна раньше начала');
      }
      final request = GuestRequest(
        id: 'r_${DateTime.now().microsecondsSinceEpoch}',
        author: me,
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        portionsCount: int.tryParse(_portionsController.text),
        budgetType: _budgetType,
        budgetAmount: _budgetType == PriceType.fixed ? double.tryParse(_budgetController.text) : null,
        requestedAt: _startAt!,
        requestedEndAt: _endAt!,
        targetHost: _type == RequestType.personal ? _selectedHost : null,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        status: _type == RequestType.personal ? RequestStatus.offered : RequestStatus.open,
        createdAt: DateTime.now(),
        photos: [?_uploadedPhotoUrl],
      );
      await ref.read(requestRepositoryProvider).create(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Запрос опубликован')));
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_choosingHost) return _buildHostPicker();
    return _buildForm();
  }

  Widget _buildForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Создание запроса')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                _TypeTab(
                  label: 'Общий запрос',
                  selected: _type == RequestType.general,
                  onTap: () => setState(() => _type = RequestType.general),
                ),
                _TypeTab(
                  label: 'Конкретному исполнителю',
                  selected: _type == RequestType.personal,
                  onTap: () => setState(() => _type = RequestType.personal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _RequestPhotoPicker(
            photoUrl: _uploadedPhotoUrl,
            uploading: _uploadingPhoto,
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 16),
          const _Label('Что нужно приготовить?'),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Например: Пирог осетинский'),
          ),
          const SizedBox(height: 16),
          const _Label('Описание заказа'),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Пожелания, состав, детали'),
          ),
          const SizedBox(height: 16),
          const _Label('Когда удобно'),
          const Text(
            'Окно - не нужно привязываться к точному часу',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStart,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _startAt == null ? 'С' : formatEventDateTime(_startAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: _startAt == null ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickEnd,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _endAt == null ? 'По' : formatEventDateTime(_endAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: _endAt == null ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_startAt != null && _endAt != null) ...[
            const SizedBox(height: 6),
            Text(
              formatEventWindow(_startAt!, _endAt),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ],
          const SizedBox(height: 16),
          const _Label('Адрес'),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(hintText: 'Укажите адрес'),
          ),
          const SizedBox(height: 16),
          const _Label('Сколько нужно порций?'),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final v = int.tryParse(_portionsController.text) ?? 1;
                  if (v > 1) setState(() => _portionsController.text = '${v - 1}');
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: TextField(
                  controller: _portionsController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              IconButton(
                onPressed: () {
                  final v = int.tryParse(_portionsController.text) ?? 1;
                  setState(() => _portionsController.text = '${v + 1}');
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Бюджет'),
          PriceTypeSelector(value: _budgetType, onChanged: (t) => setState(() => _budgetType = t)),
          if (_budgetType == PriceType.fixed) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'До какой суммы, ₽'),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _type == RequestType.personal ? _goToHostPicker : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : Text(_type == RequestType.personal ? 'Далее' : 'Опубликовать запрос'),
          ),
        ],
      ),
    );
  }

  Widget _buildHostPicker() {
    final hostsAsync = ref.watch(candidateHostsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор исполнителя'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _choosingHost = false),
        ),
      ),
      body: hostsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить исполнителей.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (hosts) {
          if (hosts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Пока нет доступных исполнителей.\nСоздайте общий запрос - на него смогут откликнуться.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hosts.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final host = hosts[i];
              final selected = _selectedHost?.id == host.id;
              return ListTile(
                onTap: () => setState(() => _selectedHost = host),
                leading: UserAvatar(url: host.avatarUrl, size: 44, name: host.name),
                title: Text(host.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Готовит: ${host.whatICook ?? "-"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : RatingBadge(score: host.rating, compact: true),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selectedHost == null || _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Опубликовать запрос'),
          ),
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestPhotoPicker extends StatelessWidget {
  const _RequestPhotoPicker({required this.photoUrl, required this.uploading, required this.onTap});

  final String? photoUrl;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: Env.resolveMediaUrl(photoUrl!),
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: AppColors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text('Добавить фото', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}
