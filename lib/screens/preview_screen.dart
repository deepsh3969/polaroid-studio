import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/settings_scope.dart';
import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../services/creations_repository.dart';
import '../services/image_export_service.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../utils/image_source.dart';
import '../widgets/developing_animation.dart';
import '../widgets/polaroid_frame.dart';

/// Shows the finished Polaroid with the developing animation and handles
/// exporting, saving to the gallery, sharing and returning to the editor.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.config});

  final PolaroidConfig config;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  static const ImageExportService _exportService = ImageExportService();

  ExportedImage? _exported;
  bool _exporting = true;
  bool _saving = false;
  bool _sharing = false;
  String? _error;

  late final ImageProvider _photo;

  bool get _busy => _exporting || _saving || _sharing;

  @override
  void initState() {
    super.initState();
    _photo = photoProvider(
      widget.config.imagePath,
      width: AppMetrics.previewDecodeWidth,
    );
    // Wait for the first frame so MediaQuery / asset bundle lookups used by
    // the off screen renderer are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_export());
    });
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _error = null;
      _exported = null;
    });

    ExportedImage exported;
    try {
      exported = await _exportService.exportPolaroid(
        context: context,
        config: widget.config,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _exporting = false;
      });
      return;
    } catch (error) {
      debugPrint('[PolaroidStudio] export failed: $error');
      if (!mounted) return;
      setState(() {
        _error = AppStrings.errExportFailed;
        _exporting = false;
      });
      return;
    }

    // Keep the offline history even if storing it fails - the export itself
    // already succeeded at this point. Browsers have no shared file system,
    // so on the web there is nothing to store.
    final file = exported.file;
    if (file != null) {
      try {
        final repository = await CreationsRepository.open();
        await repository.add(exportedFile: file, config: widget.config);
      } catch (error) {
        debugPrint('[PolaroidStudio] history store failed: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _exported = exported;
      _exporting = false;
    });
  }

  Future<void> _save() async {
    final image = _exported;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _exportService.save(image);
      if (!mounted) return;
      context.showSnack(
        kIsWeb ? AppStrings.successDownloaded : AppStrings.successSaved,
      );
    } on AppException catch (error) {
      if (mounted) context.showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final image = _exported;
    if (image == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await _exportService.sharePolaroid(image, caption: widget.config.caption);
    } on AppException catch (error) {
      if (mounted) context.showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _editAgain() => Navigator.of(context).maybePop();

  void _createAnother() =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final config = widget.config;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          AppStrings.preview,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _buildStage(config, settings.animateDeveloping)),
              SizedBox(height: 56, child: _buildStatus()),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(PolaroidConfig config, bool animate) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final aspect = FrameLayout.forStyle(
          config.frameStyle,
          AppMetrics.exportLogicalWidth,
        ).aspectRatio;

        double width = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (maxHeight.isFinite && width * aspect > maxHeight) {
          width = maxHeight / aspect;
        }
        width = width.clamp(180.0, 420.0).toDouble();

        return Center(
          child: DevelopingAnimation(
            enabled: animate,
            builder: (BuildContext context, double progress) => PolaroidFrame(
              image: _photo,
              caption: config.caption,
              date: config.formattedDate,
              frameStyle: config.frameStyle,
              filter: config.filter,
              showDate: config.showDate,
              width: width,
              captionStyle: config.captionStyle,
              transform: config.transform,
              developmentProgress: progress,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus() {
    if (_exporting) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              AppStrings.creatingPolaroid,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              key: const ValueKey<String>('export-retry'),
              onPressed: _export,
              child: const Text(AppStrings.tryAgain),
            ),
          ],
        ),
      );
    }

    if (_saving) {
      return Center(
        child: Text(
          kIsWeb ? AppStrings.downloading : AppStrings.savingToGallery,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActions() {
    final canSave = _exported != null && !_busy;
    final canShare = _exported != null && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                key: const ValueKey<String>('save-button'),
                onPressed: canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        kIsWeb ? AppStrings.download : AppStrings.saveToGallery,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey<String>('share-button'),
                onPressed: canShare ? _share : null,
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: const Text(AppStrings.share),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                key: const ValueKey<String>('edit-button'),
                onPressed: _editAgain,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(AppStrings.edit),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                key: const ValueKey<String>('create-another-button'),
                onPressed: _createAnother,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text(AppStrings.createAnother),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
