import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/utils/camera_support.dart';
import 'package:polaroid_studio/utils/constants.dart';

CameraDescription _camera(String name, CameraLensDirection direction) {
  return CameraDescription(
    name: name,
    lensDirection: direction,
    sensorOrientation: 90,
  );
}

void main() {
  group('cameraErrorMessage', () {
    test('explains permission denial per platform', () {
      expect(
        cameraErrorMessage('NotAllowedError', isWeb: true),
        AppStrings.errCameraBlocked,
      );
      expect(
        cameraErrorMessage('NotAllowedError', isWeb: false),
        AppStrings.errCameraDenied,
      );
      expect(
        cameraErrorMessage('PermissionDeniedError', isWeb: true),
        AppStrings.errCameraBlocked,
      );
      expect(
        cameraErrorMessage('CameraAccessDenied', isWeb: true),
        AppStrings.errCameraBlocked,
      );
      expect(
        cameraErrorMessage('SecurityError', isWeb: false),
        AppStrings.errCameraDenied,
      );
    });

    test('explains missing cameras', () {
      for (final code in <String>[
        'NotFoundError',
        'DevicesNotFoundError',
        'cameraNotFound',
        'cameraOverconstrained',
      ]) {
        expect(
          cameraErrorMessage(code, isWeb: true),
          AppStrings.errCameraNotFound,
        );
      }
    });

    test('explains cameras that are busy', () {
      for (final code in <String>[
        'NotReadableError',
        'AbortError',
        'TrackStartError',
        'cameraNotReadable',
        'cameraAbort',
      ]) {
        expect(
          cameraErrorMessage(code, isWeb: true),
          AppStrings.errCameraInUse,
        );
      }
    });

    test('explains unsupported and insecure contexts', () {
      expect(
        cameraErrorMessage('NotSupportedError', isWeb: true),
        AppStrings.errCameraUnsupported,
      );
      expect(
        cameraErrorMessage('cameraSecurity', isWeb: true),
        AppStrings.errCameraInsecure,
      );
    });

    test('falls back to a generic message', () {
      expect(
        cameraErrorMessage('cameraUnknown', isWeb: true),
        AppStrings.errCameraUnavailable,
      );
      expect(
        cameraErrorMessage('', isWeb: false),
        AppStrings.errCameraUnavailable,
      );
    });
  });

  group('cameraDeviceLabel', () {
    test('uses the browser device name on the web', () {
      expect(
        cameraDeviceLabel(
          _camera('Integrated Webcam', CameraLensDirection.external),
          0,
          isWeb: true,
        ),
        'Integrated Webcam',
      );
    });

    test('falls back to numbered names for unnamed web devices', () {
      expect(
        cameraDeviceLabel(
          _camera('', CameraLensDirection.external),
          1,
          isWeb: true,
        ),
        AppStrings.numberedCamera(2),
      );
    });

    test('uses the lens direction on native platforms', () {
      expect(
        cameraDeviceLabel(
          _camera('0', CameraLensDirection.back),
          0,
          isWeb: false,
        ),
        AppStrings.backCamera,
      );
      expect(
        cameraDeviceLabel(
          _camera('1', CameraLensDirection.front),
          1,
          isWeb: false,
        ),
        AppStrings.frontCamera,
      );
      expect(
        cameraDeviceLabel(
          _camera('2', CameraLensDirection.external),
          2,
          isWeb: false,
        ),
        AppStrings.numberedCamera(3),
      );
    });
  });
}
