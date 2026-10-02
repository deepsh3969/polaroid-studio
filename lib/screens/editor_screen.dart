import 'package:flutter/material.dart';

import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import '../utils/image_source.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/polaroid_frame.dart';
import 'preview_screen.dart';

/// Editing surface: live Polaroid preview with gestures plus the control stack
/// (frame, filter, caption, adjust, typography, date).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.initialConfig});

  final PolaroidConfig initialConfig;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late PolaroidConfig _config;

  /// Full quality preview image (the original file, never modified).
  late final ImageProvider _photo;

  /// Small image used by the filter strip thumbnails.
  late final ImageProvider _thumbnail;

  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final GlobalKey _captionFieldKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _photo = photoProvider(
      _config.imagePath,
      width: AppMetrics.previewDecodeWidth,
    );
    _thumbnail = photoProvider(_config.imagePath, width: 360);
    _captionController.text = _config.caption;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateConfig(PolaroidConfig next) {
    if (next == _config) return;
    setState(() => _config = next);
  }

  void _onCaptionChanged(String value) {
    final clean = sanitizeCaption(value);
    if (clean == _config.caption) return;
    setState(() => _config = _config.copyWith(caption: clean));
  }

  void _resetPosition() =>
      _updateConfig(_config.copyWith(transform: const ImageTransform()));

  void _focusCaption() {
    final fieldContext = _captionFieldKey.currentContext;
    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
    _captionFocusNode.requestFocus();
  }

  void _openPreview() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PreviewScreen(config: _config)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          AppStrings.editor,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = (constraints.maxWidth - 56)
                .clamp(210.0, 360.0)
                .toDouble();

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: PolaroidFrame(
                      image: _photo,
                      caption: _config.caption,
                      date: _config.formattedDate,
                      frameStyle: _config.frameStyle,
                      filter: _config.filter,
                      showDate: _config.showDate,
                      width: width,
                      captionStyle: _config.captionStyle,
                      transform: _config.transform,
                      interactive: true,
                      onTransformChanged: (ImageTransform value) =>
                          _updateConfig(_config.copyWith(transform: value)),
                      onResetTransform: _resetPosition,
                      onCaptionTap: _focusCaption,
                    ),
                  ),
                  const SizedBox(height: 26),
                  EditorToolbar(
                    config: _config,
                    onConfigChanged: _updateConfig,
                    captionController: _captionController,
                    captionFocusNode: _captionFocusNode,
                    captionFieldKey: _captionFieldKey,
                    onCaptionChanged: _onCaptionChanged,
                    thumbnailImage: _thumbnail,
                    onResetPosition: _resetPosition,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey<String>('export-photo-button'),
            onPressed: _openPreview,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text(AppStrings.exportPhoto),
          ),
        ),
      ),
    );
  }
}
