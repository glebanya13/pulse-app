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
import '../../core/widgets/avatar.dart';
import '../../core/widgets/city_picker.dart';
import '../../data/models/social_networks.dart';
import '../../data/models/user.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final AppUser _initial = ref.read(currentUserProvider);
  late final _nameController = TextEditingController(
    text: _initial.name == 'Новый пользователь' ? '' : _initial.name,
  );
  late final _ageController = TextEditingController(text: _initial.age > 0 ? '${_initial.age}' : '');
  late final _cityController = TextEditingController(text: _initial.city);
  late final _bioController = TextEditingController(text: _initial.bio ?? '');
  late final Map<String, TextEditingController> _socialControllers = {
    for (final key in SocialNetworks.keys)
      key: TextEditingController(text: _initial.socialLinks[key] ?? ''),
  };

  File? _pendingAvatar;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    for (final c in _socialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) setState(() => _pendingAvatar = File(picked.path));
  }

  Future<void> _addGalleryPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final updated = await ref.read(userRepositoryProvider).uploadPhotos([File(picked.path)]);
      ref.read(authStateProvider.notifier).updateProfile(updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось загрузить фото: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    try {
      final updated = await ref.read(userRepositoryProvider).deletePhoto(url);
      ref.read(authStateProvider.notifier).updateProfile(updated);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить фото: $e')));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == 'Новый пользователь') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? newAvatarUrl;
      if (_pendingAvatar != null) {
        final withPhoto = await ref.read(userRepositoryProvider).uploadPhotos([_pendingAvatar!]);
        newAvatarUrl = withPhoto.photos.isNotEmpty ? withPhoto.photos.last : null;
      }
      final updated = await ref.read(userRepositoryProvider).updateProfile(
            name: name,
            age: int.tryParse(_ageController.text.trim()),
            city: _cityController.text.trim(),
            bio: _bioController.text.trim(),
            avatarUrl: newAvatarUrl,
            socialLinks: SocialNetworks.sanitize({
              for (final e in _socialControllers.entries) e.key: e.value.text,
            }),
          );
      ref.read(authStateProvider.notifier).updateProfile(updated);
      if (!mounted) return;
      if (widget.onboarding) {
        context.go('/home/feed');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onboarding ? 'Расскажите о себе' : 'Редактировать профиль'),
        automaticallyImplyLeading: !widget.onboarding,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  _pendingAvatar != null
                      ? ClipOval(
                          child: Image.file(_pendingAvatar!, width: 96, height: 96, fit: BoxFit.cover),
                        )
                      : UserAvatar(url: user.avatarUrl, size: 96, name: user.name),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: AppColors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _Label('Имя'),
          TextField(controller: _nameController),
          const SizedBox(height: 16),
          const _Label('Возраст'),
          TextField(controller: _ageController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const _Label('Город'),
          TextField(
            controller: _cityController,
            readOnly: true,
            onTap: () async {
              await showCityPickerSheet(context, ref);
              if (!mounted) return;
              final city = ref.read(selectedCityOrDefaultProvider);
              setState(() => _cityController.text = city.name);
            },
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.expand_more),
            ),
          ),
          const SizedBox(height: 16),
          const _Label('О себе'),
          TextField(controller: _bioController, maxLines: 3),
          const SizedBox(height: 24),
          const Text('Соцсети', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Другие пользователи увидят эти ссылки в вашем профиле',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...SocialNetworks.keys.map((key) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(SocialNetworks.labels[key]!),
                  TextField(
                    controller: _socialControllers[key],
                    decoration: InputDecoration(hintText: SocialNetworks.hints[key]),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Фото', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (_uploadingPhoto)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _addGalleryPhoto,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: user.photos.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Пока нет фотографий', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: user.photos.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                    itemBuilder: (c, i) {
                      final url = user.photos[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: Env.resolveMediaUrl(url),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(url),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: AppColors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: AppColors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Сохранить'),
          ),
        ],
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
