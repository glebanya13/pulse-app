import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/place_search.dart';
import '../../data/models/city.dart';
import '../../data/models/event.dart';
import '../../data/models/place.dart';
import '../map/pick_location_screen.dart';
import 'feed_providers.dart';
import 'ping_pong_video.dart';
import 'story_compose.dart';

enum CreateMediaMode { post, story }

/// Instagram-style create with swipe/tap transitions between Post ↔ Story.
class CreateMediaScreen extends ConsumerStatefulWidget {
  const CreateMediaScreen({
    super.key,
    this.initialMode = CreateMediaMode.post,
    this.prefillPlaceId,
    this.prefillPlaceName,
    this.prefillPlaceAddress,
    this.prefillStoryText,
    this.prefillImageUrl,
  });

  final CreateMediaMode initialMode;
  final String? prefillPlaceId;
  final String? prefillPlaceName;
  final String? prefillPlaceAddress;
  final String? prefillStoryText;
  /// Remote or `/uploads/...` image to open as story media (share visit).
  final String? prefillImageUrl;

  @override
  ConsumerState<CreateMediaScreen> createState() => _CreateMediaScreenState();
}

class _CreateMediaScreenState extends ConsumerState<CreateMediaScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final PageController _pager;
  late CreateMediaMode _mode;
  bool _publishing = false;
  bool _flashOn = false;
  bool _squareCrop = true;
  bool _defaultFrontCamera = false;
  bool _toolsOnLeft = true;
  bool _allowCameraRollSuggest = true;
  bool _postComposeStep = false;
  bool _storyComposeStep = false;
  final _captionCtrl = TextEditingController();
  PlaceSummary? _selectedPlace;

  // Story edit tools
  String _storyText = '';
  StoryFilter _storyFilter = StoryFilter.none;
  StoryEffect _storyEffect = StoryEffect.none;
  StoryLayout _storyLayout = StoryLayout.fill;
  bool _boomerangMode = false;
  List<File> _boomerangFrames = const [];
  File? _boomerangVideo;
  late final AnimationController _boomerangAnim;

  // Gallery
  PermissionState _permission = PermissionState.notDetermined;
  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  List<AssetEntity> _assets = const [];
  AssetEntity? _selected;
  File? _selectedFile;
  Uint8List? _lastThumb;
  bool _loadingGallery = true;
  bool _loadingMore = false;
  int _page = 0;
  static const _pageSize = 60;

  // Camera (story)
  List<CameraDescription> _cameras = const [];
  CameraController? _camera;
  int _cameraIndex = 0;
  bool _cameraBusy = false;
  String? _cameraError;

  bool get _storyReview =>
      _mode == CreateMediaMode.story &&
      _selectedFile != null &&
      !_storyComposeStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    _pager = PageController(
      initialPage: widget.initialMode == CreateMediaMode.story ? 1 : 0,
    );
    _boomerangAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final placeId = widget.prefillPlaceId;
    final placeName = widget.prefillPlaceName;
    if (placeId != null &&
        placeId.isNotEmpty &&
        placeName != null &&
        placeName.isNotEmpty) {
      _selectedPlace = PlaceSummary(
        id: placeId,
        name: placeName,
        address: widget.prefillPlaceAddress,
        lat: 53.9023,
        lng: 27.5619,
      );
    }
    final storyText = widget.prefillStoryText?.trim();
    if (storyText != null && storyText.isNotEmpty) {
      _storyText = storyText;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapGallery();
      await _applyPrefillImage();
      if (_mode == CreateMediaMode.story && _selectedFile == null) {
        await _ensureCamera();
      }
    });
  }

  Future<void> _applyPrefillImage() async {
    final raw = widget.prefillImageUrl?.trim();
    if (raw == null || raw.isEmpty || _mode != CreateMediaMode.story) return;
    try {
      final url = Env.resolveMediaUrl(raw);
      final dio = ref.read(apiClientProvider).dio;
      final res = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty || !mounted) return;
      final dir = await Directory.systemTemp.createTemp('pulse_story_prefill');
      final file = File(
        '${dir.path}/prefill_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selected = null;
        _boomerangFrames = const [];
        _boomerangVideo = null;
        _storyComposeStep = false;
      });
      await _disposeCamera();
    } catch (_) {
      // Keep camera path if download fails.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pager.dispose();
    _boomerangAnim.dispose();
    _captionCtrl.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed &&
        _mode == CreateMediaMode.story &&
        !_storyReview) {
      _ensureCamera();
    }
  }

  Future<void> _disposeCamera() async {
    final c = _camera;
    _camera = null;
    await c?.dispose();
  }

  Future<void> _ensureCamera() async {
    if (_storyReview) return;
    setState(() {
      _cameraError = null;
      _cameraBusy = true;
    });
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraBusy = false;
            _cameraError = 'Камера недоступна';
          });
        }
        return;
      }
      // Prefer front if user set default.
      if (_defaultFrontCamera) {
        final front = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (front >= 0) _cameraIndex = front;
      } else if (_cameraIndex >= _cameras.length) {
        _cameraIndex = 0;
      }
      await _disposeCamera();
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraBusy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraBusy = false;
          _cameraError = 'Нет доступа к камере';
        });
      }
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _ensureCamera();
  }

  Future<void> _captureStory() async {
    if (_boomerangMode) {
      await _captureBoomerang();
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _cameraBusy) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _selectedFile = File(picked.path);
        _selected = null;
        _boomerangFrames = const [];
        _boomerangVideo = null;
      });
      await _disposeCamera();
      return;
    }
    setState(() => _cameraBusy = true);
    try {
      final shot = await cam.takePicture();
      if (!mounted) return;
      setState(() {
        _selectedFile = File(shot.path);
        _selected = null;
        _boomerangFrames = const [];
        _boomerangVideo = null;
        _cameraBusy = false;
      });
      await _disposeCamera();
    } catch (_) {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _captureBoomerang() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _cameraBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Камера нужна для бумеранга')),
      );
      return;
    }
    setState(() => _cameraBusy = true);
    try {
      // Cover still for feed ring + API imageUrl.
      final still = await cam.takePicture();
      await cam.startVideoRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!cam.value.isRecordingVideo) {
        throw StateError('recording did not start');
      }
      final video = await cam.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _boomerangVideo = File(video.path);
        _boomerangFrames = const [];
        _selectedFile = File(still.path);
        _selected = null;
        _cameraBusy = false;
      });
      _boomerangAnim.stop();
      await _disposeCamera();
    } catch (_) {
      try {
        if (cam.value.isRecordingVideo) await cam.stopVideoRecording();
      } catch (_) {}
      if (mounted) {
        setState(() => _cameraBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось записать бумеранг')),
        );
      }
    }
  }

  Future<void> _bootstrapGallery() async {
    setState(() => _loadingGallery = true);
    final state = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    _permission = state;
    if (!state.isAuth && !state.hasAccess) {
      setState(() => _loadingGallery = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (!mounted) return;
    final album = albums.isEmpty
        ? null
        : albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
    setState(() {
      _albums = albums;
      _album = album;
    });
    await _loadAssets(reset: true);
  }

  Future<File?> _originalFile(AssetEntity asset) async {
    return await asset.originFile ?? await asset.file;
  }

  Future<void> _loadAssets({bool reset = false}) async {
    final album = _album;
    if (album == null) {
      setState(() {
        _assets = const [];
        _selected = null;
        if (_mode == CreateMediaMode.post) _selectedFile = null;
        _loadingGallery = false;
      });
      return;
    }
    if (reset) {
      _page = 0;
      setState(() => _loadingGallery = true);
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    final page = await album.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;
    final merged = reset ? page : [..._assets, ...page];

    Uint8List? thumb = _lastThumb;
    if (merged.isNotEmpty) {
      thumb = await merged.first.thumbnailDataWithSize(
        const ThumbnailSize.square(160),
        quality: 90,
      );
    }

    AssetEntity? selected = _selected;
    File? file = _selectedFile;
    if (_mode == CreateMediaMode.post && selected == null && merged.isNotEmpty) {
      selected = merged.first;
      file = await _originalFile(selected);
    }
    if (!mounted) return;
    setState(() {
      _assets = merged;
      _page += 1;
      _selected = selected;
      if (_mode == CreateMediaMode.post) _selectedFile = file;
      _lastThumb = thumb;
      _loadingGallery = false;
      _loadingMore = false;
    });
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    if (_selected?.id == asset.id && _selectedFile != null) return;
    setState(() {
      _selected = asset;
      _selectedFile = null;
    });
    final file = await _originalFile(asset);
    if (!mounted || _selected?.id != asset.id) return;
    setState(() => _selectedFile = file);
  }

  Future<void> _openCameraForPost() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedFile = File(picked.path);
      _selected = null;
    });
    await _bootstrapGallery();
  }

  Future<void> _pickFromGalleryForStory() async {
    if (!_allowCameraRollSuggest) {
      final enabled = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Доступ к галерее',
            style: TextStyle(color: AppColors.highlight),
          ),
          content: const Text(
            'Включите доступ к галерее в настройках камеры, чтобы выбирать фото для историй.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Настройки'),
            ),
          ],
        ),
      );
      if (enabled == true && mounted) await _openCameraSettings();
      return;
    }
    if (_assets.isEmpty) await _bootstrapGallery();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<AssetEntity>(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.72;
        return SizedBox(
          height: h,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3C),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Выбрать из галереи',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (c, i) {
                    final asset = _assets[i];
                    return _AssetThumb(
                      asset: asset,
                      selected: false,
                      onTap: () => Navigator.pop(ctx, asset),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    final file = await _originalFile(chosen);
    if (!mounted) return;
    setState(() {
      _selected = chosen;
      _selectedFile = file;
      _boomerangFrames = const [];
      _boomerangAnim.stop();
    });
    await _disposeCamera();
  }

  Future<void> _pickAlbum() async {
    if (_albums.isEmpty) return;
    final chosen = await showModalBottomSheet<AssetPathEntity>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _albums.length,
          itemBuilder: (c, i) {
            final a = _albums[i];
            final selected = a.id == _album?.id;
            return ListTile(
              title: Text(
                a.name.isEmpty ? 'Альбом' : a.name,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryLight : Colors.white,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primaryLight, size: 18)
                  : null,
              onTap: () => Navigator.pop(ctx, a),
            );
          },
        ),
      ),
    );
    if (chosen == null || !mounted || chosen.id == _album?.id) return;
    setState(() {
      _album = chosen;
      _selected = null;
      _selectedFile = null;
    });
    await _loadAssets(reset: true);
  }

  Future<void> _publish() async {
    var file = _selectedFile;
    if (file == null || _publishing) return;
    setState(() => _publishing = true);
    try {
      if (_mode == CreateMediaMode.story) {
        String? videoPath;
        final boomVideo = _boomerangVideo;
        if (boomVideo != null) {
          // Poster from still; video is the boomerang clip.
          file = await composeStoryImage(
            source: file,
            filter: _storyFilter,
            effect: _storyEffect,
            layout: _storyLayout,
            text: _storyText,
          );
          videoPath =
              await ref.read(socialRepositoryProvider).uploadVideoPath(boomVideo);
        } else if (_boomerangFrames.length >= 2) {
          // Legacy multi-still path → GIF fallback.
          final baked = <File>[];
          for (final frame in _boomerangFrames) {
            baked.add(
              await composeStoryImage(
                source: frame,
                filter: _storyFilter,
                effect: _storyEffect,
                layout: _storyLayout,
                text: _storyText,
              ),
            );
          }
          file = await encodeBoomerangGif(baked);
        } else {
          file = await composeStoryImage(
            source: file,
            filter: _storyFilter,
            effect: _storyEffect,
            layout: _storyLayout,
            text: _storyText,
          );
        }
        final path =
            await ref.read(socialRepositoryProvider).uploadImagePath(file);
        await ref.read(socialRepositoryProvider).createStory(
              imageUrl: path,
              placeId: _selectedPlace?.id,
              videoUrl: videoPath,
            );
        ref.invalidate(storiesFeedProvider);
      } else {
        file = await composeSquarePostImage(
          source: file,
          coverCrop: _squareCrop,
        );
        final path =
            await ref.read(socialRepositoryProvider).uploadImagePath(file);
        await ref.read(socialRepositoryProvider).createPost(
              imageUrl: path,
              caption: _captionCtrl.text,
              placeId: _selectedPlace?.id,
            );
        ref.invalidate(postsFeedProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == CreateMediaMode.post
                ? 'Пост опубликован'
                : 'История опубликована',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _openPostCompose() {
    if (_selectedFile == null || _publishing) return;
    setState(() => _postComposeStep = true);
  }

  void _openStoryCompose() {
    if (_selectedFile == null || _publishing) return;
    setState(() => _storyComposeStep = true);
  }

  Future<void> _pickPostPlace() async {
    final result = await showModalBottomSheet<PlaceSummary?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlaceSearchSheet(
        initial: _selectedPlace,
        onUpsert: ({
          required String name,
          required double lat,
          required double lng,
          String? address,
        }) =>
            ref.read(placesRepositoryProvider).upsert(
                  name: name,
                  lat: lat,
                  lng: lng,
                  address: address,
                ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedPlace = result);
  }

  Future<void> _goMode(CreateMediaMode mode) async {
    if (_mode == mode) return;
    final page = mode == CreateMediaMode.post ? 0 : 1;
    await _pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onPageChanged(int page) async {
    final mode = page == 0 ? CreateMediaMode.post : CreateMediaMode.story;
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _postComposeStep = false;
      _storyComposeStep = false;
      if (mode == CreateMediaMode.story) {
        _selectedFile = null;
        _selected = null;
      }
    });
    if (mode == CreateMediaMode.story) {
      await _ensureCamera();
    } else {
      await _disposeCamera();
      if (_assets.isNotEmpty) await _selectAsset(_assets.first);
      if (mounted) setState(() {});
    }
  }

  void _discardStoryCapture() {
    _boomerangAnim.stop();
    setState(() {
      _selectedFile = null;
      _selected = null;
      _boomerangFrames = const [];
      _boomerangVideo = null;
      _storyComposeStep = false;
      _storyText = '';
      _storyFilter = StoryFilter.none;
      _storyEffect = StoryEffect.none;
      _storyLayout = StoryLayout.fill;
    });
    _ensureCamera();
  }

  Future<void> _editStoryText() async {
    final controller = TextEditingController(text: _storyText);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Текст истории',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 120,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Напишите что-нибудь…',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.highlight,
                  ),
                  child: const Text('Готово'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() => _storyText = result);
    if (!_storyReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Текст добавится после снимка'),
          duration: Duration(milliseconds: 1400),
        ),
      );
    }
  }

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<StoryFilter>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Фильтр',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  for (final f in StoryFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, f),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _storyFilter == f
                                      ? AppColors.primaryLight
                                      : AppColors.border,
                                  width: 2,
                                ),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryBright,
                                    AppColors.primaryDark,
                                  ],
                                ),
                              ),
                              foregroundDecoration: f.colorFilter == null
                                  ? null
                                  : BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      backgroundBlendMode: BlendMode.modulate,
                                      color: AppColors.lilac.withValues(alpha: 0.35),
                                    ),
                              child: Center(
                                child: Text(
                                  f.label.substring(0, 1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.highlight,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: _storyFilter == f
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _storyFilter = picked);
  }

  Future<void> _pickEffect() async {
    final picked = await showModalBottomSheet<StoryEffect>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Эффект',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final e in StoryEffect.values)
              ListTile(
                title: Text(e.label),
                trailing: _storyEffect == e
                    ? const Icon(Icons.check, color: AppColors.primaryLight)
                    : null,
                onTap: () => Navigator.pop(ctx, e),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _storyEffect = picked);
  }

  Future<void> _pickLayout() async {
    final picked = await showModalBottomSheet<StoryLayout>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Макет',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final l in StoryLayout.values)
              ListTile(
                title: Text(l.label),
                subtitle: Text(
                  switch (l) {
                    StoryLayout.fill => 'На весь экран',
                    StoryLayout.fit => 'С полями',
                    StoryLayout.mirror => 'Два зеркальных кадра',
                  },
                ),
                trailing: _storyLayout == l
                    ? const Icon(Icons.check, color: AppColors.primaryLight)
                    : null,
                onTap: () => Navigator.pop(ctx, l),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _storyLayout = picked);
  }

  void _toggleBoomerangMode() {
    setState(() {
      _boomerangMode = !_boomerangMode;
      if (!_boomerangMode) {
        _boomerangFrames = const [];
        _boomerangVideo = null;
        _boomerangAnim.stop();
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _boomerangMode
              ? 'Бумеранг: нажмите shutter для серии кадров'
              : 'Бумеранг выключен',
        ),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceAlt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pager,
        physics: _storyReview
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: [
          _buildPostPage(),
          _buildStoryPage(),
        ],
      ),
    );
  }

  // ─── POST ─────────────────────────────────────────────────────────

  Widget _buildPostPage() {
    if (_postComposeStep) return _buildPostComposePage();

    final albumName = _album == null
        ? 'Галерея'
        : (_album!.isAll
            ? 'Недавние'
            : (_album!.name.isEmpty ? 'Альбом' : _album!.name));
    final side = MediaQuery.sizeOf(context).width;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Новый пост',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectedFile == null || _publishing
                      ? null
                      : _openPostCompose,
                  child: Text(
                    'Далее',
                    style: TextStyle(
                      color: _selectedFile == null
                          ? AppColors.textTertiary
                          : AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: side,
          height: side,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (_selectedFile != null)
                Image.file(
                  _selectedFile!,
                  fit: _squareCrop ? BoxFit.cover : BoxFit.contain,
                  width: side,
                  height: side,
                  filterQuality: FilterQuality.high,
                )
              else if (_loadingGallery)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                )
              else
                const Center(
                  child: Text(
                    'Выберите фото',
                    style: TextStyle(color: Color(0xFF8E8E93)),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _squareCrop = !_squareCrop),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          _squareCrop
                              ? PhosphorIconsRegular.arrowsOutSimple
                              : PhosphorIconsRegular.square,
                          color: AppColors.highlight,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _albums.isEmpty ? null : _pickAlbum,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    albumName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildGalleryBody()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: _ModeTumbler(mode: _mode, onChanged: _goMode),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostComposePage() {
    final side = MediaQuery.sizeOf(context).width;
    final thumb = math.min(96.0, side * 0.28);
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  onPressed: _publishing
                      ? null
                      : () => setState(() => _postComposeStep = false),
                  icon: const Icon(
                    PhosphorIconsRegular.caretLeft,
                    color: Colors.white,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Новый пост',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _selectedFile == null || _publishing ? null : _publish,
                  child: _publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Поделиться',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: thumb,
                      height: thumb,
                      child: _selectedFile == null
                          ? const ColoredBox(color: Color(0xFF1C1C1E))
                          : Image.file(
                              _selectedFile!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _captionCtrl,
                      maxLines: 5,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: AppColors.highlight,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Добавьте подпись…',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFF2C2C2E)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  PhosphorIconsRegular.mapPin,
                  color: AppColors.highlight,
                ),
                title: Text(
                  _selectedPlace?.name ?? 'Добавить место',
                  style: const TextStyle(
                    color: AppColors.highlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: _selectedPlace?.address == null
                    ? null
                    : Text(
                        _selectedPlace!.address!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                trailing: const Icon(
                  PhosphorIconsRegular.caretRight,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                onTap: _publishing ? null : _pickPostPlace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoryComposePage() {
    final side = MediaQuery.sizeOf(context).width;
    final thumb = math.min(96.0, side * 0.28);
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  onPressed: _publishing
                      ? null
                      : () => setState(() => _storyComposeStep = false),
                  icon: const Icon(
                    PhosphorIconsRegular.caretLeft,
                    color: Colors.white,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Новая история',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _selectedFile == null || _publishing ? null : _publish,
                  child: _publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Поделиться',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: thumb,
                      height: thumb * 16 / 9,
                      child: _selectedFile == null
                          ? const ColoredBox(color: Color(0xFF1C1C1E))
                          : Image.file(
                              _selectedFile!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Текст и эффекты уже на кадре. Здесь можно добавить место и опубликовать.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFF2C2C2E)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  PhosphorIconsRegular.mapPin,
                  color: AppColors.highlight,
                ),
                title: Text(
                  _selectedPlace?.name ?? 'Добавить место',
                  style: const TextStyle(
                    color: AppColors.highlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: _selectedPlace?.address == null
                    ? null
                    : Text(
                        _selectedPlace!.address!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                trailing: const Icon(
                  PhosphorIconsRegular.caretRight,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                onTap: _publishing ? null : _pickPostPlace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryBody() {
    if (_loadingGallery && _assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_permission.isAuth && !_permission.hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Нужен доступ к фото',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _bootstrapGallery,
                child: const Text('Разрешить'),
              ),
              TextButton(
                onPressed: PhotoManager.openSetting,
                child: const Text('Настройки'),
              ),
            ],
          ),
        ),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _openCameraForPost,
          icon: const Icon(PhosphorIconsRegular.camera),
          label: const Text('Сделать снимок'),
        ),
      );
    }

    final count = _assets.length + 1;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          _loadAssets();
        }
        return false;
      },
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
        ),
        itemCount: count + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _openCameraForPost,
              child: const ColoredBox(
                color: Color(0xFF1C1C1E),
                child: Icon(
                  PhosphorIconsRegular.camera,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            );
          }
          if (index > _assets.length) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final asset = _assets[index - 1];
          return _AssetThumb(
            asset: asset,
            selected: asset.id == _selected?.id,
            onTap: () => _selectAsset(asset),
          );
        },
      ),
    );
  }

  // ─── STORY ────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    final next = !_flashOn;
    setState(() => _flashOn = next);
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      // Simulator / unsupported — keep UI state.
    }
  }

  Future<void> _openCameraSettings() async {
    final result = await showModalBottomSheet<_CameraSettingsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CameraSettingsSheet(
        defaultFrontCamera: _defaultFrontCamera,
        toolsOnLeft: _toolsOnLeft,
        allowCameraRollSuggest: _allowCameraRollSuggest,
      ),
    );
    if (result == null || !mounted) return;
    final frontChanged = result.defaultFrontCamera != _defaultFrontCamera;
    setState(() {
      _defaultFrontCamera = result.defaultFrontCamera;
      _toolsOnLeft = result.toolsOnLeft;
      _allowCameraRollSuggest = result.allowCameraRollSuggest;
    });
    if (frontChanged && _mode == CreateMediaMode.story && !_storyReview) {
      await _ensureCamera();
    }
  }

  Widget _buildStoryPage() {
    if (_storyComposeStep) return _buildStoryComposePage();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Rounded viewport like Instagram story
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 4,
            bottom: _storyReview ? 0 : 118,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_storyReview ? 0 : 28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_storyReview)
                  _StoryReviewCanvas(
                    file: _selectedFile!,
                    frames: _boomerangFrames,
                    videoFile: _boomerangVideo,
                    animation: _boomerangAnim,
                    filter: _storyFilter,
                    effect: _storyEffect,
                    layout: _storyLayout,
                    text: _storyText,
                  )
                else if (_camera != null && _camera!.value.isInitialized)
                  _CameraPreviewCover(controller: _camera!)
                else
                  ColoredBox(
                    color: AppColors.black,
                    child: Center(
                      child: _cameraBusy
                          ? const CircularProgressIndicator(
                              color: AppColors.primaryLight,
                            )
                          : Text(
                              _cameraError ?? 'Подключение камеры…',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (!_storyReview)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC0A0A0B)],
                  ),
                ),
              ),
            ),
          ),

        // Top chrome: close · flash · settings — pinned to top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 10, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _storyReview
                          ? _discardStoryCapture
                          : () => context.pop(),
                      icon: const Icon(
                        PhosphorIconsRegular.x,
                        color: AppColors.highlight,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    if (!_storyReview)
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _flashOn
                              ? PhosphorIconsFill.lightning
                              : PhosphorIconsRegular.lightningSlash,
                          color: _flashOn
                              ? AppColors.primaryLight
                              : AppColors.highlight,
                          size: 24,
                        ),
                      ),
                    const Spacer(),
                    if (!_storyReview)
                      IconButton(
                        onPressed: _openCameraSettings,
                        icon: const Icon(
                          PhosphorIconsRegular.slidersHorizontal,
                          color: AppColors.highlight,
                          size: 28,
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Tools rail — available before and after capture
        Positioned(
            left: _toolsOnLeft ? 10 : null,
            right: _toolsOnLeft ? null : 10,
            top: MediaQuery.paddingOf(context).top + 64,
            child: Column(
              children: [
                _StoryToolButton(
                  icon: PhosphorIconsRegular.textAa,
                  active: _storyText.isNotEmpty,
                  onTap: _editStoryText,
                ),
                _StoryToolButton(
                  icon: PhosphorIconsRegular.magicWand,
                  active: _storyEffect != StoryEffect.none,
                  onTap: _pickEffect,
                ),
                _StoryToolButton(
                  icon: PhosphorIconsRegular.infinity,
                  active: _boomerangMode ||
                      _boomerangFrames.isNotEmpty ||
                      _boomerangVideo != null,
                  onTap: _toggleBoomerangMode,
                ),
                _StoryToolButton(
                  icon: PhosphorIconsRegular.circlesThree,
                  active: _storyFilter != StoryFilter.none,
                  onTap: _pickFilter,
                ),
                _StoryToolButton(
                  icon: PhosphorIconsRegular.squaresFour,
                  active: _storyLayout != StoryLayout.fill,
                  onTap: _pickLayout,
                ),
              ],
            ),
          ),

        // Bottom controls
        if (!_storyReview)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
                    child: Row(
                      children: [
                        _GalleryThumb(
                          bytes: _allowCameraRollSuggest ? _lastThumb : null,
                          locked: !_allowCameraRollSuggest,
                          onTap: _pickFromGalleryForStory,
                        ),
                        const Spacer(),
                        _ShutterButton(
                          busy: _cameraBusy,
                          onTap: _captureStory,
                        ),
                        const Spacer(),
                        _FlipCameraButton(onTap: _flipCamera),
                      ],
                    ),
                  ),
                  _ModeTumbler(mode: _mode, onChanged: _goMode),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

        if (_storyReview)
          Positioned(
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: FilledButton(
                  onPressed: _publishing ? null : _openStoryCompose,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.highlight,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Далее',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fills screen with camera preview (cover crop).
class _StoryReviewCanvas extends StatelessWidget {
  const _StoryReviewCanvas({
    required this.file,
    required this.frames,
    required this.animation,
    required this.filter,
    required this.effect,
    required this.layout,
    required this.text,
    this.videoFile,
  });

  final File file;
  final List<File> frames;
  final File? videoFile;
  final AnimationController animation;
  final StoryFilter filter;
  final StoryEffect effect;
  final StoryLayout layout;
  final String text;

  @override
  Widget build(BuildContext context) {
    Widget image;
    final video = videoFile;
    if (video != null) {
      image = PingPongVideo.file(file: video);
    } else if (frames.length > 1) {
      image = AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final idx = (animation.value * (frames.length - 1))
              .round()
              .clamp(0, frames.length - 1);
          return Image.file(
            frames[idx],
            fit: layout == StoryLayout.fit ? BoxFit.contain : BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        },
      );
    } else if (layout == StoryLayout.mirror) {
      image = Row(
        children: [
          Expanded(
            child: Image.file(file, fit: BoxFit.cover, height: double.infinity),
          ),
          Expanded(
            child: Transform.flip(
              flipX: true,
              child: Image.file(file, fit: BoxFit.cover, height: double.infinity),
            ),
          ),
        ],
      );
    } else {
      image = Image.file(
        file,
        fit: layout == StoryLayout.fit ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }

    final cf = filter.colorFilter;
    if (cf != null && video == null) {
      image = ColorFiltered(colorFilter: cf, child: image);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.black),
        image,
        if (effect == StoryEffect.vignette)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x00000000), Color(0x99000000)],
                stops: [0.45, 1],
              ),
            ),
          ),
        if (effect == StoryEffect.haze)
          ColoredBox(color: AppColors.primary.withValues(alpha: 0.22)),
        if (effect == StoryEffect.grain)
          CustomPaint(painter: _GrainPainter()),
        if (text.trim().isNotEmpty)
          Align(
            alignment: const Alignment(0, 0.45),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.highlight,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  height: 1.25,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 500; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final preview = controller.value.previewSize;
    if (preview == null) {
      return CameraPreview(controller);
    }
    // previewSize is landscape-oriented from camera plugin.
    final previewSize = Size(preview.height, preview.width);
    return ClipRect(
      child: OverflowBox(
        maxWidth: size.width,
        maxHeight: size.width * previewSize.height / previewSize.width,
        alignment: Alignment.center,
        child: SizedBox(
          width: size.width,
          height: size.width * previewSize.height / previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: busy ? 0.55 : 1,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.black.withValues(alpha: 0.55),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.highlight,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipCameraButton extends StatelessWidget {
  const _FlipCameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface.withValues(alpha: 0.55),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              PhosphorIconsRegular.cameraRotate,
              color: AppColors.highlight,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.bytes,
    required this.onTap,
    this.locked = false,
  });

  final Uint8List? bytes;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white54, width: 1.5),
          color: const Color(0xFF1C1C1E),
          image: !locked && bytes != null
              ? DecorationImage(
                  image: MemoryImage(bytes!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: locked
            ? const Icon(
                PhosphorIconsRegular.lockSimple,
                color: Colors.white70,
                size: 20,
              )
            : (bytes == null
                ? const Icon(
                    PhosphorIconsRegular.image,
                    color: Colors.white70,
                    size: 22,
                  )
                : null),
      ),
    );
  }
}

class _StoryToolButton extends StatelessWidget {
  const _StoryToolButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 36,
          child: Icon(
            icon,
            color: active ? AppColors.primaryLight : AppColors.highlight,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Unified POST / STORY tumbler — same on gallery and camera.
class _ModeTumbler extends StatelessWidget {
  const _ModeTumbler({required this.mode, required this.onChanged});

  final CreateMediaMode mode;
  final ValueChanged<CreateMediaMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPost = mode == CreateMediaMode.post;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 232,
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabW = constraints.maxWidth / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    left: isPost ? 0 : tabW,
                    top: 0,
                    bottom: 0,
                    width: tabW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryBright,
                            AppColors.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TumblerTab(
                          label: 'ПОСТ',
                          selected: isPost,
                          onTap: () => onChanged(CreateMediaMode.post),
                        ),
                      ),
                      Expanded(
                        child: _TumblerTab(
                          label: 'ИСТОРИЯ',
                          selected: !isPost,
                          onTap: () => onChanged(CreateMediaMode.story),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TumblerTab extends StatelessWidget {
  const _TumblerTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            height: 1,
            color: selected ? AppColors.highlight : AppColors.textSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _AssetThumb extends StatefulWidget {
  const _AssetThumb({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AssetThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(220),
      quality: 85,
    );
    if (!mounted) return;
    setState(() => _bytes = data);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_bytes != null)
            Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true)
          else
            const ColoredBox(color: AppColors.surfaceAlt),
          if (widget.selected)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryLight, width: 2.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraSettingsResult {
  const _CameraSettingsResult({
    required this.defaultFrontCamera,
    required this.toolsOnLeft,
    required this.allowCameraRollSuggest,
  });

  final bool defaultFrontCamera;
  final bool toolsOnLeft;
  final bool allowCameraRollSuggest;
}

class _CameraSettingsSheet extends StatefulWidget {
  const _CameraSettingsSheet({
    required this.defaultFrontCamera,
    required this.toolsOnLeft,
    required this.allowCameraRollSuggest,
  });

  final bool defaultFrontCamera;
  final bool toolsOnLeft;
  final bool allowCameraRollSuggest;

  @override
  State<_CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<_CameraSettingsSheet> {
  late bool _front;
  late bool _toolsLeft;
  late bool _roll;
  late final TapGestureRecognizer _moreTap;

  @override
  void initState() {
    super.initState();
    _front = widget.defaultFrontCamera;
    _toolsLeft = widget.toolsOnLeft;
    _roll = widget.allowCameraRollSuggest;
    _moreTap = TapGestureRecognizer()..onTap = _showGalleryPrivacyDetails;
    _syncGalleryPermission();
  }

  @override
  void dispose() {
    _moreTap.dispose();
    super.dispose();
  }

  Future<void> _syncGalleryPermission() async {
    final ps = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
    if (!mounted) return;
    final allowed = ps.isAuth || ps.hasAccess;
    if (allowed != _roll) {
      setState(() => _roll = allowed && widget.allowCameraRollSuggest);
    }
  }

  Future<void> _onGalleryAccessChanged(bool enabled) async {
    if (!enabled) {
      setState(() => _roll = false);
      return;
    }
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (ps.isAuth || ps.hasAccess) {
      setState(() => _roll = true);
      return;
    }
    setState(() => _roll = false);
    await PhotoManager.openSetting();
  }

  void _showGalleryPrivacyDetails() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Доступ к галерее',
          style: TextStyle(color: AppColors.highlight),
        ),
        content: const Text(
          'Пульс может предлагать фото и видео с устройства для историй и постов. '
          'Данные о качестве кадра, геолокации и людях на снимке обрабатываются на устройстве '
          'и не используются для показа рекламы. Вы можете отозвать доступ в настройках системы в любой момент.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              PhotoManager.openSetting();
            },
            child: const Text('Настройки'),
          ),
        ],
      ),
    );
  }

  void _done() {
    Navigator.pop(
      context,
      _CameraSettingsResult(
        defaultFrontCamera: _front,
        toolsOnLeft: _toolsLeft,
        allowCameraRollSuggest: _roll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.88;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: h,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 64),
                      const Expanded(
                        child: Text(
                          'Настройки камеры',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.highlight,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _done,
                        child: const Text(
                          'Готово',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    const Text(
                      'Управление',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.highlight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggleRow(
                      title: 'Фронтальная камера по умолчанию',
                      value: _front,
                      onChanged: (v) => setState(() => _front = v),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Инструменты камеры',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.highlight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Выберите, с какой стороны экрана показывать панель инструментов.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsRadioRow(
                      title: 'Слева',
                      selected: _toolsLeft,
                      onTap: () => setState(() => _toolsLeft = true),
                    ),
                    _SettingsRadioRow(
                      title: 'Справа',
                      selected: !_toolsLeft,
                      onTap: () => setState(() => _toolsLeft = false),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Галерея',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.highlight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggleRow(
                      title: 'Разрешить доступ',
                      value: _roll,
                      onChanged: _onGalleryAccessChanged,
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'Разрешите Пульсу предлагать истории и посты из фото и видео на устройстве, используя данные о качестве снимка, геолокации и наличии людей. ',
                          ),
                          TextSpan(
                            text: 'Подробнее',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: _moreTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.highlight,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.highlight,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsRadioRow extends StatelessWidget {
  const _SettingsRadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.highlight,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.onUpsert,
    this.initial,
  });

  final PlaceSummary? initial;
  final Future<PlaceSummary> Function({
    required String name,
    required double lat,
    required double lng,
    String? address,
  }) onUpsert;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _ctrl = TextEditingController();
  final _manualName = TextEditingController();
  final _manualAddress = TextEditingController();
  final _search = PlaceSearch();
  List<PlaceHit> _hits = const [];
  bool _loading = false;
  bool _manualMode = false;
  bool _saving = false;
  String? _error;
  Timer? _debounce;
  double? _manualLat;
  double? _manualLng;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _manualName.dispose();
    _manualAddress.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hits = await _search.search(
        query,
        near: kDefaultCity.center,
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
        if (hits.isEmpty) {
          _manualName.text = query;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Поиск недоступен. Можно указать место вручную.';
        _loading = false;
        _manualMode = true;
        if (_manualName.text.trim().isEmpty) {
          _manualName.text = query;
        }
      });
    }
  }

  Future<void> _selectHit(PlaceHit hit) async {
    setState(() => _saving = true);
    try {
      final place = await widget.onUpsert(
        name: hit.title,
        lat: hit.point.latitude,
        lng: hit.point.longitude,
        address: hit.subtitle.isEmpty ? null : hit.subtitle,
      );
      if (mounted) Navigator.pop(context, place);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _saveManual() async {
    final name = _manualName.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final place = await widget.onUpsert(
        name: name,
        lat: _manualLat ?? kDefaultCity.lat,
        lng: _manualLng ?? kDefaultCity.lng,
        address: _manualAddress.text.trim().isEmpty
            ? null
            : _manualAddress.text.trim(),
      );
      if (mounted) Navigator.pop(context, place);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initial: GeoPoint(
            latitude: _manualLat ?? kDefaultCity.lat,
            longitude: _manualLng ?? kDefaultCity.lng,
          ),
          initialAddress: _manualAddress.text.trim().isEmpty
              ? null
              : _manualAddress.text.trim(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _manualMode = true;
      _manualLat = picked.point.latitude;
      _manualLng = picked.point.longitude;
      final label = picked.address?.trim();
      if (label != null && label.isNotEmpty) {
        _manualAddress.text = label;
      }
      final name = picked.placeName?.trim();
      if (name != null && name.isNotEmpty) {
        _manualName.text = name;
      } else if (_manualName.text.trim().isEmpty &&
          label != null &&
          label.isNotEmpty) {
        _manualName.text = label;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Добавить место',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.highlight,
              ),
            ),
            const SizedBox(height: 12),
            if (!_manualMode) ...[
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onQuery,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Кафе, клуб, адрес…',
                  prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              Expanded(
                child: _hits.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _ctrl.text.trim().length < 2
                                    ? 'Начните вводить название'
                                    : 'Ничего не найдено',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _manualMode = true;
                                    if (_manualName.text.trim().isEmpty) {
                                      _manualName.text = _ctrl.text.trim();
                                    }
                                  });
                                },
                                child: const Text('Указать вручную'),
                              ),
                              TextButton.icon(
                                onPressed: _saving ? null : _pickOnMap,
                                icon: const Icon(
                                  PhosphorIconsRegular.mapPin,
                                  size: 18,
                                ),
                                label: const Text('На карте'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _hits.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final hit = _hits[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              PhosphorIconsRegular.mapPin,
                              color: AppColors.primaryLight,
                            ),
                            title: Text(
                              hit.title,
                              style: const TextStyle(
                                color: AppColors.highlight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: hit.subtitle.isEmpty
                                ? null
                                : Text(
                                    hit.subtitle,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                            onTap: _saving ? null : () => _selectHit(hit),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _pickOnMap,
                      icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
                      label: const Text('На карте'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _manualMode = true;
                          if (_manualName.text.trim().isEmpty) {
                            _manualName.text = _ctrl.text.trim();
                          }
                        });
                      },
                      child: const Text('Вручную'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: _manualName,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Название места',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _manualAddress,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Адрес (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickOnMap,
                icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
                label: Text(
                  _manualLat == null
                      ? 'Указать на карте'
                      : 'Точка выбрана · изменить',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _manualLat == null
                    ? 'Без карты место сохранится с центром города.'
                    : 'Координаты: ${_manualLat!.toStringAsFixed(5)}, ${_manualLng!.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _saveManual,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить место'),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _manualMode = false),
                child: const Text('К поиску'),
              ),
            ],
            if (widget.initial != null)
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, null),
                child: const Text('Убрать место'),
              ),
          ],
        ),
      ),
    );
  }
}
