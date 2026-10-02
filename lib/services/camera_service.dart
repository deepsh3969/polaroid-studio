import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/camera_support.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/image_source.dart';
import 'camera_guard.dart';

/// Owns the [CameraController] lifecycle so screens stay free of camera
/// plumbing. Always call [dispose] when leaving the camera screen.
///
/// The same service drives the native camera plugin on mobile and its
/// endorsed `camera_web` implementation in the browser, where it relies on
/// `getUserMedia` (and therefore on the browser permission prompt).
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;

  /// Currently initialised controller, if any.
  CameraController? get controller => _controller;

  /// Cameras discovered during the last [initialize] / [selectCamera].
  List<CameraDescription> get cameras => _cameras;

  /// Index of the active camera inside [cameras].
  int get cameraIndex => _cameraIndex;

  /// True when another camera can be switched to.
  bool get canSwitchCamera => _cameras.length > 1;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// True when the device exposes at least one camera.
  Future<bool> isDeviceSupported() async {
    try {
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (error) {
      debugPrint('[PolaroidStudio] availableCameras failed: $error');
      return false;
    }
  }

  /// Initialises a camera preview, preferring [preferred].
  Future<CameraController> initialize({
    CameraLensDirection preferred = CameraLensDirection.back,
  }) async {
    final cameras = await _listCameras();
    var index = cameras.indexWhere(
      (camera) => camera.lensDirection == preferred,
    );
    if (index < 0) index = 0;
    return _openCamera(cameras, index);
  }

  /// Opens the camera at [index] of the freshly enumerated device list.
  Future<CameraController> selectCamera(int index) async {
    final cameras = await _listCameras();
    final target = index < 0 || index >= cameras.length ? 0 : index;
    return _openCamera(cameras, target);
  }

  /// Switches to the next camera in the list, if there is one.
  Future<CameraController?> switchCamera() async {
    if (_cameras.length < 2) return null;
    return selectCamera((_cameraIndex + 1) % _cameras.length);
  }

  /// Captures a still photo and returns its source string: a temporary file
  /// path on mobile, a base64 data URL on the web.
  ///
  /// With [mirror] the photo is flipped horizontally before it is returned.
  Future<String> capture({bool mirror = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const AppException(AppStrings.errCameraUnavailable);
    }

    final XFile file;
    try {
      file = await controller.takePicture();
    } on CameraException catch (error) {
      debugPrint(
        '[PolaroidStudio] capture failed: ${error.code} ${error.description}',
      );
      throw AppException(
        cameraErrorMessage(error.code, isWeb: kIsWeb),
        logDetails: '${error.code}: ${error.description}',
      );
    } catch (error) {
      throw toAppException(error, AppStrings.errCameraUnavailable);
    }

    if (kIsWeb) {
      try {
        final bytes = await file.readAsBytes();
        final payload = mirror ? await flipImageBytesHorizontal(bytes) : bytes;
        return dataUrlFromBytes(payload);
      } catch (error) {
        throw toAppException(error, AppStrings.errCameraUnavailable);
      }
    }

    if (!mirror) return file.path;

    try {
      final flipped = await flipImageBytesHorizontal(await file.readAsBytes());
      final directory = await getTemporaryDirectory();
      final target = File(
        '${directory.path}/${generateCreationId()}_mirror.png',
      );
      await target.writeAsBytes(flipped, flush: true);
      return target.path;
    } catch (error) {
      throw toAppException(error, AppStrings.errCameraUnavailable);
    }
  }

  /// Releases the camera so other apps can use it again.
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('[PolaroidStudio] camera dispose failed: $error');
    }
  }

  Future<List<CameraDescription>> _listCameras() async {
    final List<CameraDescription> cameras;
    try {
      if (kIsWeb) await sanitizeCameras();
      cameras = await availableCameras();
    } on CameraException catch (error) {
      debugPrint(
        '[PolaroidStudio] availableCameras failed: ${error.code} '
        '${error.description}',
      );
      throw AppException(
        cameraErrorMessage(error.code, isWeb: kIsWeb),
        logDetails: '${error.code}: ${error.description}',
      );
    } catch (error) {
      throw toAppException(error, AppStrings.errCameraUnavailable);
    }
    if (cameras.isEmpty) {
      throw const AppException(
        kIsWeb ? AppStrings.errCameraNotFound : AppStrings.errCameraUnavailable,
      );
    }
    return cameras;
  }

  Future<CameraController> _openCamera(
    List<CameraDescription> cameras,
    int index,
  ) async {
    await dispose();

    final controller = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } on CameraException catch (error) {
      debugPrint(
        '[PolaroidStudio] camera init failed: ${error.code} '
        '${error.description}',
      );
      await controller.dispose();
      throw AppException(
        cameraErrorMessage(error.code, isWeb: kIsWeb),
        logDetails: '${error.code}: ${error.description}',
      );
    } catch (error) {
      await controller.dispose();
      throw toAppException(error, AppStrings.errCameraUnavailable);
    }

    _controller = controller;
    _cameras = cameras;
    _cameraIndex = index;
    return controller;
  }
}
