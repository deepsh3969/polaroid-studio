import 'package:camera/camera.dart';

import 'constants.dart';

/// Maps a camera error code to a user friendly message.
///
/// Understands platform exception codes, the `DOMException` names thrown by
/// browsers through `getUserMedia` and the `camera_web` error codes, so the
/// same screen can explain what blocked the camera on any platform.
String cameraErrorMessage(String code, {required bool isWeb}) {
  switch (code) {
    case 'NotAllowedError':
    case 'PermissionDeniedError':
    case 'SecurityError':
    case 'CameraAccessDenied':
      return isWeb ? AppStrings.errCameraBlocked : AppStrings.errCameraDenied;
    case 'NotFoundError':
    case 'DevicesNotFoundError':
    case 'cameraNotFound':
    case 'cameraOverconstrained':
      return AppStrings.errCameraNotFound;
    case 'NotReadableError':
    case 'AbortError':
    case 'TrackStartError':
    case 'cameraNotReadable':
    case 'cameraAbort':
      return AppStrings.errCameraInUse;
    case 'NotSupportedError':
    case 'cameraNotSupported':
    case 'cameraType':
      return AppStrings.errCameraUnsupported;
    case 'cameraSecurity':
      return AppStrings.errCameraInsecure;
    default:
      return AppStrings.errCameraUnavailable;
  }
}

/// Human readable label for a device in the camera switcher.
///
/// Browsers expose the user facing device name (often empty before the first
/// permission grant); native cameras are identified by their lens instead.
String cameraDeviceLabel(
  CameraDescription camera,
  int index, {
  required bool isWeb,
}) {
  if (isWeb) {
    final label = camera.name.trim();
    if (label.isNotEmpty) return label;
  }
  return switch (camera.lensDirection) {
    CameraLensDirection.back => AppStrings.backCamera,
    CameraLensDirection.front => AppStrings.frontCamera,
    CameraLensDirection.external => AppStrings.numberedCamera(index + 1),
  };
}
