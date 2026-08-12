import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/city_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/price_type_selector.dart';
import '../../core/widgets/tag_chip.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../../data/models/event_stickers.dart';
import '../map/pick_location_screen.dart';
import 'events_providers.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    this.initialFormat = EventFormat.inPerson,
    this.eventId,
  });

  final EventFormat initialFormat;
  final String? eventId;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  late EventFormat _format = widget.initialFormat;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _minGuestsController = TextEditingController(text: '4');
  final _maxGuestsController = TextEditingController(text: '10');
  final _priceController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _portionWeightController = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;
  GenderFilter _genderFilter = GenderFilter.any;
  PriceType _priceType = PriceType.free;
  PickupMethod _pickupMethod = PickupMethod.pickupOnly;
  final Set<String> _stickers = {};
  GeoPoint? _location;
  String? _placeName;
  bool _submitting = false;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;
  bool _loadingEdit = false;
  String? _editingId;
  List<String> _existingPhotos = const [];

  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    final id = widget.eventId;
    if (id != null && id.isNotEmpty) {
      _editingId = id;
      _loadingEdit = true;
      _loadForEdit(id);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final me = ref.read(authStateProvider);
        if (me == null || !me.canHostEvents) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала станьте организатором в профиле')),
          );
          context.pop();
        }
      });
    }
  }

  Future<void> _loadForEdit(String id) async {
    try {
      final event = await ref.read(eventRepositoryProvider).byId(id);
      if (!mounted) return;
      final me = ref.read(authStateProvider);
      if (me == null || event.host.id != me.id) {
        setState(() => _loadingEdit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Редактировать может только организатор')),
        );
        context.pop();
        return;
      }
      setState(() {
        _format = event.format;
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _addressController.text = event.address;
        _minGuestsController.text = '${event.minGuests}';
        _maxGuestsController.text = '${event.maxGuests}';
        _priceController.text = event.priceAmount?.toStringAsFixed(0) ?? '';
        _pickupAddressController.text = event.pickupAddress ?? '';
        _portionWeightController.text = event.portionWeightGrams?.toString() ?? '';
        _startAt = event.startAt;
        _endAt = event.endAt ?? event.startAt.add(const Duration(hours: 3));
        _genderFilter = event.requirements.gender;
        _priceType = event.priceType;
        _pickupMethod = event.pickupMethod ?? PickupMethod.pickupOnly;
        _stickers
          ..clear()
          ..addAll(event.tags.where((t) => EventStickers.all.contains(t)));
        _location = event.location;
        _existingPhotos = List.of(event.photos);
        _uploadedPhotoUrl = event.coverPhoto;
        _loadingEdit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEdit = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить событие: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _minGuestsController.dispose();
    _maxGuestsController.dispose();
    _priceController.dispose();
    _pickupAddressController.dispose();
    _portionWeightController.dispose();
    super.dispose();
  }

  bool get _isTakeaway => _format == EventFormat.takeaway;

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

  Future<DateTime?> _pickDateTime({
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
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
      helpText: helpText,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(
      initial: _startAt,
      helpText: 'С какого момента ждать гостей',
    );
    if (picked == null) return;
    setState(() {
      _startAt = picked;
      if (_endAt == null || !_endAt!.isAfter(picked)) {
        _endAt = picked.add(const Duration(hours: 3));
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(
      initial: _endAt ?? _startAt?.add(const Duration(hours: 3)),
      helpText: 'До какого момента ждать гостей',
    );
    if (picked == null) return;
    setState(() {
      _endAt = picked;
      if (_startAt != null && picked.isBefore(_startAt!)) {
        _startAt = picked.subtract(const Duration(hours: 3));
      }
    });
  }

  Widget _buildWindowField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(_isTakeaway ? 'Окно выдачи' : 'Когда жду гостей'),
        const Text(
          'Укажите промежуток - не нужно привязываться к точному часу',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.3),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _WindowTile(
                label: 'С',
                value: _startAt == null ? 'Дата и время' : formatEventDateTime(_startAt!),
                empty: _startAt == null,
                onTap: _pickStart,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WindowTile(
                label: 'По',
                value: _endAt == null ? 'Дата и время' : formatEventDateTime(_endAt!),
                empty: _endAt == null,
                onTap: _pickEnd,
              ),
            ),
          ],
        ),
        if (_startAt != null && _endAt != null) ...[
          const SizedBox(height: 8),
          Text(
            formatEventWindow(_startAt!, _endAt),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPickupMethodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Способ получения'),
        Row(
          children: PickupMethod.values.map((m) {
            final selected = _pickupMethod == m;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: m == PickupMethod.values.first ? 8 : 0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    backgroundColor: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                    foregroundColor: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                  onPressed: () => setState(() => _pickupMethod = m),
                  child: Text(
                    m.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickLocation() async {
    final city = ref.read(selectedCityOrDefaultProvider);
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initial: _location ??
              GeoPoint(latitude: city.lat, longitude: city.lng),
          initialAddress: _isTakeaway
              ? _pickupAddressController.text.trim()
              : _addressController.text.trim(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = picked.point;
      _placeName = picked.placeName;
      final label = picked.address?.trim();
      if (label != null && label.isNotEmpty) {
        if (_isTakeaway) {
          _pickupAddressController.text = label;
        } else {
          _addressController.text = label;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Введите название');
      return;
    }
    if (_startAt == null || _endAt == null) {
      _showError('Укажите окно: с какого и по какое время ждать гостей');
      return;
    }
    if (_endAt!.isBefore(_startAt!)) {
      _showError('Время окончания должно быть не раньше начала');
      return;
    }
    if (_addressController.text.trim().isEmpty && !_isTakeaway) {
      _showError('Укажите адрес');
      return;
    }
    if (_location == null && !_isTakeaway) {
      _showError('Отметьте место на карте');
      return;
    }
    if (_isTakeaway && _pickupAddressController.text.trim().isEmpty) {
      _showError('Укажите адрес выдачи');
      return;
    }
    final minGuests = int.tryParse(_minGuestsController.text) ?? 0;
    final maxGuests = int.tryParse(_maxGuestsController.text) ?? 0;
    if (!_isTakeaway) {
      if (minGuests < 1 || maxGuests < 1) {
        _showError('Укажите минимум для старта и максимум мест, например 8-12');
        return;
      }
      if (minGuests > maxGuests) {
        _showError('«От» не может быть больше «До»');
        return;
      }
    } else if (maxGuests < 1) {
      _showError('Укажите количество мест');
      return;
    }
    setState(() => _submitting = true);
    try {
      final me = ref.read(currentUserProvider);
      final photos = _buildPhotos();
      final event = Event(
        id: _editingId ?? 'e_${DateTime.now().microsecondsSinceEpoch}',
        host: me,
        format: _format,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photos: photos,
        tags: EventStickers.ordered(_stickers.toList()),
        startAt: _startAt!,
        endAt: _endAt!,
        address: _isTakeaway
            ? _pickupAddressController.text.trim()
            : _addressController.text.trim(),
        location: _location ??
            GeoPoint(
              latitude: ref.read(selectedCityOrDefaultProvider).lat,
              longitude: ref.read(selectedCityOrDefaultProvider).lng,
            ),
        citySlug: ref.read(selectedCityOrDefaultProvider).slug,
        placeName: _placeName,
        minGuests: _isTakeaway ? 1 : minGuests,
        maxGuests: maxGuests,
        priceType: _priceType,
        priceAmount: _priceType == PriceType.fixed ? double.tryParse(_priceController.text) : null,
        requirements: GuestRequirements(gender: _genderFilter),
        pickupMethod: _isTakeaway ? _pickupMethod : null,
        pickupAddress: _isTakeaway ? _pickupAddressController.text.trim() : null,
        portionWeightGrams: _isTakeaway ? int.tryParse(_portionWeightController.text) : null,
      );
      final saved = _isEditing
          ? await ref.read(eventRepositoryProvider).update(_editingId!, event)
          : await ref.read(eventRepositoryProvider).create(event);
      ref.invalidate(eventByIdProvider(saved.id));
      ref.invalidate(eventsProvider);
      ref.invalidate(myHostedEventsProvider);
      if (!mounted) return;
      if (saved.status == EventStatus.pendingReview) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отправлено на проверку. Появится в афише после одобрения'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      context.pushReplacement('/events/${saved.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<String> _buildPhotos() {
    final cover = _uploadedPhotoUrl;
    if (cover == null || cover.isEmpty) return const [];
    if (_existingPhotos.isEmpty) return [cover];
    if (_existingPhotos.first == cover) return List.of(_existingPhotos);
    return [cover, ..._existingPhotos.where((p) => p != cover)];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEdit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (_isTakeaway ? 'Редактирование билетов' : 'Редактирование события')
              : (_isTakeaway ? 'Продажа билетов' : 'Новое событие'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_isEditing)
            _FormatTabs(
              value: _format,
              onChanged: (f) => setState(() => _format = f),
            ),
          if (!_isEditing) const SizedBox(height: 20),
          _PhotoPicker(
            isTakeaway: _isTakeaway,
            photoUrl: _uploadedPhotoUrl,
            uploading: _uploadingPhoto,
            onTap: _pickPhoto,
          ),
          const SizedBox(height: 20),
          _Label(_isTakeaway ? 'Название предложения' : 'Название'),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: _isTakeaway ? 'Например: Early bird на вечер в Ok16' : 'Например: Techno night в Ok16',
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Описание'),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _isTakeaway ? 'Что входит, как забрать' : 'Расскажите о вашем событии',
            ),
          ),
          const SizedBox(height: 16),
          _buildWindowField(),
          if (_isTakeaway) ...[
            const SizedBox(height: 16),
            _buildPickupMethodField(),
            const SizedBox(height: 16),
            const _Label('Адрес выдачи'),
            TextField(
              controller: _pickupAddressController,
              decoration: const InputDecoration(hintText: 'Укажите адрес'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: Text(
                _location == null
                    ? 'Отметить на карте (необязательно)'
                    : (_pickupAddressController.text.trim().isNotEmpty
                        ? 'Место выбрано на карте'
                        : 'На карте: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}'),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Количество мест / билетов'),
            TextField(
              controller: _maxGuestsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Например, 10'),
            ),
            const SizedBox(height: 16),
            const _Label('Вес / доп. параметр, г (необязательно)'),
            TextField(
              controller: _portionWeightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Ориентировочно, например 250'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const _Label('Место'),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                hintText: 'Укажите адрес',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: Text(
                _location == null
                    ? 'Отметить на карте'
                    : (_addressController.text.trim().isNotEmpty
                        ? 'Место выбрано на карте'
                        : 'На карте: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}'),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Количество гостей'),
            const Text(
              'От - минимум гостей для старта. До - сколько мест максимум.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _minGuestsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '8',
                      labelText: 'Мин. для старта',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxGuestsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '12',
                      labelText: 'Макс. мест',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Пока минимум не набран - гости видят прогресс. Когда наберётся - всем придёт уведомление.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.3),
            ),
            const SizedBox(height: 16),
            const _Label('Кого вы хотите видеть?'),
            const Text(
              'Семейный - можно с детьми',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.3),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GenderFilter.values.map((g) {
                final selected = _genderFilter == g;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _genderFilter = g),
                );
              }).toList(),
            ),
          ],
          if (_isTakeaway) ...[] else const SizedBox.shrink(),
          const SizedBox(height: 16),
          const _Label('Особенности'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EventStickers.all.map((tag) {
              final selected = _stickers.contains(tag);
              return TagChip(
                label: tag,
                selected: selected,
                outlined: true,
                onTap: () => setState(() {
                  final next = EventStickers.toggle(_stickers, tag);
                  _stickers
                    ..clear()
                    ..addAll(next);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _Label(_isTakeaway ? 'Стоимость билета' : 'Стоимость'),
          PriceTypeSelector(value: _priceType, onChanged: (t) => setState(() => _priceType = t)),
          if (_priceType == PriceType.fixed) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _isTakeaway ? 'Цена за билет, BYN' : 'Сумма, BYN',
              ),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : Text(_isEditing ? 'Сохранить' : 'Опубликовать'),
          ),
        ],
      ),
    );
  }
}

class _FormatTabs extends StatelessWidget {
  const _FormatTabs({required this.value, required this.onChanged});

  final EventFormat value;
  final ValueChanged<EventFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: EventFormat.values.map((f) {
          final selected = value == f;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                  ),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.isTakeaway,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  final bool isTakeaway;
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    isTakeaway ? 'Добавить обложку' : 'Добавить фото',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  const _WindowTile({
    required this.label,
    required this.value,
    required this.empty,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: empty ? AppColors.textTertiary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
              ],
            ),
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
