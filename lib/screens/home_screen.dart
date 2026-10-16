import 'dart:async';

import 'package:flutter/material.dart';

import '../models/filter_model.dart';
import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../services/creations_repository.dart';
import '../services/image_picker_service.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../widgets/polaroid_frame.dart';
import 'camera_screen.dart';
import 'editor_screen.dart';
import 'preview_screen.dart';
import 'settings_screen.dart';
import 'showcase_screen.dart';

/// Landing screen: brand, primary actions and the offline creation history.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePickerService _pickerService = ImagePickerService();

  CreationsRepository? _repository;
  List<Creation> _creations = const <Creation>[];
  bool _loadingHistory = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repository = await CreationsRepository.open();
      final creations = await repository.all();
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _creations = creations;
        _loadingHistory = false;
      });
    } catch (error) {
      debugPrint('[PolaroidStudio] history load failed: $error');
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _chooseFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _pickerService.pickFromGallery();
      if (path == null || !mounted) return; // cancelled
      await _openEditor(path);
    } on AppException catch (error) {
      if (mounted) context.showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await Navigator.of(context).push<String?>(
        MaterialPageRoute<String?>(builder: (_) => const CameraScreen()),
      );
      if (path == null || !mounted) return;
      await _openEditor(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor(String imagePath) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          initialConfig: PolaroidConfig.initial(imagePath: imagePath),
        ),
      ),
    );
    // Refresh history in case the user exported something while editing.
    if (mounted) unawaited(_loadHistory());
  }

  Future<void> _confirmDelete(Creation creation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(AppStrings.deleteTitle),
        content: const Text(AppStrings.deleteMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = _repository;
    if (repository == null) return;
    await repository.delete(creation);
    if (!mounted) return;
    setState(
      () => _creations = _creations.where((c) => c.id != creation.id).toList(),
    );
    context.showSnack('Polaroid deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName, style: TextStyle(fontSize: 15)),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('showcase-button'),
            tooltip: AppStrings.showcase,
            onPressed: () =>
                Navigator.of(context).pushNamed(ShowcaseScreen.routeName),
            icon: const Icon(Icons.view_carousel_outlined),
          ),
          IconButton(
            key: const ValueKey<String>('settings-button'),
            tooltip: AppStrings.settings,
            onPressed: () =>
                Navigator.of(context).pushNamed(SettingsScreen.routeName),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 640;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildSample(constraints),
                      const SizedBox(height: 28),
                      _buildActions(),
                      const SizedBox(height: 18),
                      _buildPrivacy(),
                      const SizedBox(height: 32),
                      _buildRecent(isWide),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppStrings.brandLine1, style: textTheme.displayLarge),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                AppStrings.brandLine2,
                style: textTheme.titleLarge?.copyWith(
                  letterSpacing: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.brandTagline,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSample(BoxConstraints constraints) {
    final double width = (constraints.maxWidth - 140)
        .clamp(190.0, 250.0)
        .toDouble();
    final String today = DateStampFormat.dayMonthYear.format(DateTime.now());

    return Center(
      child: Transform.rotate(
        angle: -0.05,
        child: Semantics(
          excludeSemantics: true,
          label: 'Example Polaroid print',
          child: PolaroidFrame(
            image: samplePhotoProvider,
            caption: 'Analogue days',
            width: width,
            frameStyle: FrameStyle.warmWhite,
            filter: FilterType.vintage,
            showDate: true,
            date: today,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          key: const ValueKey<String>('take-photo-button'),
          onPressed: _busy ? null : _takePhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text(AppStrings.takePhoto),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: const ValueKey<String>('choose-gallery-button'),
          onPressed: _busy ? null : _chooseFromGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text(AppStrings.chooseFromGallery),
        ),
        if (_busy) ...<Widget>[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            AppStrings.preparingImage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacy() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.privacyNotice,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(bool isWide) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(AppStrings.recentCreations, style: textTheme.titleLarge),
            const SizedBox(width: 10),
            if (!_loadingHistory && _creations.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_creations.length}',
                  style: textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_creations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.8),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.emptyCreations,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 4 : 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _creations.length,
            itemBuilder: (BuildContext context, int index) {
              final creation = _creations[index];
              return _CreationTile(
                creation: creation,
                onOpen: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PreviewScreen(config: creation.config),
                  ),
                ),
                onDelete: () => _confirmDelete(creation),
              );
            },
          ),
      ],
    );
  }
}

class _CreationTile extends StatelessWidget {
  const _CreationTile({
    required this.creation,
    required this.onOpen,
    required this.onDelete,
  });

  final Creation creation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final String title = creation.caption.trim().isEmpty
        ? 'Untitled'
        : creation.caption.trim();

    return Semantics(
      button: true,
      label: 'Polaroid, $title. Long press to delete.',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        onLongPress: onDelete,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Image.file(
                  creation.thumbFile ?? creation.file,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.outline,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  creation.config.dateFormat.format(creation.createdAt),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
