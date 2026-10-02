import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import '../services/permission_service.dart';
import '../utils/camera_support.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../utils/image_source.dart';

/// Full screen camera flow: preview -> capture -> retake / accept.
///
/// Pops the captured photo source when the user accepts the photo: a file
/// path on mobile, a base64 data URL on the web.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _service = CameraService();
  final PermissionService _permissions = const PermissionService();

  CameraController? _controller;
  String? _error;
  bool _needsSettings = false;
  bool _initializing = true;
  bool _busy = false;
  String? _captured;
  bool _mirrorPreview = true;
  bool _mirrorPhoto = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!kIsWeb) await _permissions.ensureCameraPermission();
      final controller = await _service.initialize();
      if (!mounted) {
        unawaited(_service.dispose());
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _needsSettings = !kIsWeb && error.message == AppStrings.errCameraDenied;
        _initializing = false;
      });
    } catch (error) {
      debugPrint('[PolaroidStudio] camera start failed: $error');
      if (!mounted) return;
      setState(() {
        _error = AppStrings.errCameraUnavailable;
        _initializing = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _needsSettings = false;
      _initializing = true;
      _controller = null;
    });
    unawaited(_start());
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final source = await _service.capture(mirror: _mirrorPhoto);
      if (!mounted) return;
      setState(() => _captured = source);
    } on AppException catch (error) {
      if (mounted) context.showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchTo(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = await _service.selectCamera(index);
      if (mounted) setState(() => _controller = controller);
    } on AppException catch (error) {
      if (mounted) context.showSnack(error.message, error: true);
    } catch (error) {
      debugPrint('[PolaroidStudio] camera switch failed: $error');
      if (mounted) {
        context.showSnack(AppStrings.errCameraUnavailable, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flip() {
    final next = (_service.cameraIndex + 1) % _service.cameras.length;
    unawaited(_switchTo(next));
  }

  void _accept() {
    final captured = _captured;
    if (captured == null) return;
    Navigator.of(context).pop(captured);
  }

  void _retake() {
    setState(() => _captured = null);
  }

  @override
  void dispose() {
    unawaited(_service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final previewActive =
        _error == null &&
        !_initializing &&
        _captured == null &&
        controller != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_error != null)
            _buildErrorView()
          else if (_initializing || controller == null)
            const _StartingView()
          else if (_captured != null)
            _buildReviewView()
          else
            _buildPreview(controller),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(previewActive),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    if (_mirrorPreview) {
      return Transform.flip(flipX: true, child: CameraPreview(controller));
    }
    return CameraPreview(controller);
  }

  Widget _buildTopBar(bool previewActive) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('camera-close'),
              tooltip: 'Close camera',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const Spacer(),
            const Text(
              AppStrings.camera,
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 4,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (previewActive && _service.canSwitchCamera)
              _service.cameras.length > 2
                  ? _buildCameraMenu()
                  : IconButton(
                      key: const ValueKey<String>('camera-flip'),
                      tooltip: AppStrings.switchCamera,
                      onPressed: _busy ? null : _flip,
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraMenu() {
    final cameras = _service.cameras;
    final activeIndex = _service.cameraIndex;
    return PopupMenuButton<int>(
      key: const ValueKey<String>('camera-menu'),
      tooltip: AppStrings.switchCamera,
      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
      enabled: !_busy,
      onSelected: _switchTo,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        for (var i = 0; i < cameras.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: <Widget>[
                if (i == activeIndex)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_rounded, size: 18),
                  )
                else
                  const SizedBox(width: 26),
                Text(cameraDeviceLabel(cameras[i], i, isWeb: kIsWeb)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControls(CameraController? controller) {
    if (_captured != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('camera-retake'),
                  onPressed: _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(AppStrings.retake),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey<String>('camera-accept'),
                  onPressed: _accept,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(AppStrings.usePhoto),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null || _initializing) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _mirrorToggle(
              key: 'camera-mirror-preview',
              tooltip: AppStrings.mirrorPreview,
              icon: Icons.flip_rounded,
              active: _mirrorPreview,
              onChanged: (value) => setState(() => _mirrorPreview = value),
            ),
            const SizedBox(width: 20),
            Semantics(
              button: true,
              label: 'Take photo',
              child: GestureDetector(
                key: const ValueKey<String>('camera-shutter'),
                onTap: _busy ? null : _capture,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _busy ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            _mirrorToggle(
              key: 'camera-mirror-photo',
              tooltip: AppStrings.mirrorPhoto,
              icon: Icons.flip_camera_ios_rounded,
              active: _mirrorPhoto,
              onChanged: (value) => setState(() => _mirrorPhoto = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mirrorToggle({
    required String key,
    required String tooltip,
    required IconData icon,
    required bool active,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      button: true,
      toggled: active,
      label: tooltip,
      child: IconButton(
        key: ValueKey<String>(key),
        tooltip: tooltip,
        onPressed: () => onChanged(!active),
        icon: Icon(
          icon,
          color: active ? Colors.white : Colors.white54,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildReviewView() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Image(
          image: photoProvider(_captured!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 64,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? AppStrings.errCameraUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey<String>('camera-retry'),
              onPressed: _retry,
              child: const Text(AppStrings.tryAgain),
            ),
            if (_needsSettings) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _permissions.openSettings(),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Open Settings'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartingView extends StatelessWidget {
  const _StartingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}
