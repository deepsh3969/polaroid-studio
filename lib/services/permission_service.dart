import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Requests only the permissions the app actually needs.
///
/// Gallery access is intentionally *not* requested here: both platforms use
/// the system photo picker, which needs no permission at all, and saving uses
/// the system media store / `NSPhotoLibraryAddUsageDescription`.
class PermissionService {
  const PermissionService();

  /// Returns `true` when camera access is granted.
  ///
  /// Throws an [AppException] with a friendly message when the user denies.
  Future<bool> ensureCameraPermission() async {
    try {
      final current = await Permission.camera.status;
      if (current.isGranted) return true;

      final result = await Permission.camera.request();
      if (result.isGranted) return true;

      throw AppException(
        AppStrings.errCameraDenied,
        logDetails: 'camera permission: ${result.name}',
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw toAppException(error, AppStrings.errCameraDenied);
    }
  }

  /// Opens the system settings page (used after a permanent denial).
  Future<bool> openSettings() => openAppSettings();
}
