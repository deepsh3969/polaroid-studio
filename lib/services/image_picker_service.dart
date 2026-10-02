import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/image_source.dart';

/// Wraps `image_picker` with validation and friendly error messages.
class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const Set<String> _allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
    'bmp',
  };

  static const Set<String> _allowedMimes = <String>{
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
    'image/bmp',
  };

  /// Opens the system photo picker.
  ///
  /// Returns `null` when the user cancels. Throws an [AppException] with a
  /// user friendly message for permission problems or invalid files.
  ///
  /// On the web the picked file is converted into a self contained data URL
  /// so the editor, export and share paths can treat it like any other photo.
  Future<String?> pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return null; // user cancelled, not an error

      if (kIsWeb) {
        final source = dataUrlFromBytes(await picked.readAsBytes());
        await validate(source);
        return source;
      }

      await validate(picked.path);
      return picked.path;
    } on AppException {
      rethrow;
    } on PlatformException catch (error) {
      debugPrint(
        '[PolaroidStudio] image_picker failed: ${error.code} ${error.message}',
      );
      if (error.code == 'invalid_image') {
        throw const AppException(AppStrings.errInvalidImage);
      }
      throw const AppException(AppStrings.errGalleryFailed);
    } catch (error) {
      throw toAppException(error, AppStrings.errGalleryFailed);
    }
  }

  /// Makes sure [source] points at an existing, reasonably sized, decodable
  /// photo. Never throws raw platform errors.
  Future<void> validate(String source) async {
    if (source.isEmpty) {
      throw const AppException(AppStrings.errImageMissing);
    }

    if (isDataUrl(source)) {
      await _validateDataUrl(source);
      return;
    }

    final file = File(source);
    if (!await file.exists()) {
      throw const AppException(AppStrings.errImageMissing);
    }

    final length = await file.length();
    if (length == 0) {
      throw const AppException(AppStrings.errInvalidImage);
    }
    if (length > AppMetrics.maxImageBytes) {
      throw const AppException(AppStrings.errImageTooLarge);
    }

    final extension = _extensionOf(source);
    if (extension == null || !_allowedExtensions.contains(extension)) {
      throw const AppException(AppStrings.errInvalidImage);
    }

    await _validateDecodable(await file.readAsBytes());
  }

  Future<void> _validateDataUrl(String source) async {
    final mime = dataUrlMime(source);
    if (mime == null || !_allowedMimes.contains(mime)) {
      throw const AppException(AppStrings.errInvalidImage);
    }

    final Uint8List bytes;
    try {
      bytes = bytesFromDataUrl(source);
    } on FormatException {
      throw const AppException(AppStrings.errInvalidImage);
    }
    if (bytes.isEmpty) {
      throw const AppException(AppStrings.errInvalidImage);
    }
    if (bytes.length > AppMetrics.maxImageBytes) {
      throw const AppException(AppStrings.errImageTooLarge);
    }

    await _validateDecodable(bytes);
  }

  /// Cheap header level decode: rejects corrupt / unsupported files without
  /// materialising the whole bitmap.
  Future<void> _validateDecodable(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      descriptor.dispose();
      buffer.dispose();
    } catch (error) {
      debugPrint('[PolaroidStudio] image decode validation failed: $error');
      throw const AppException(AppStrings.errInvalidImage);
    }
  }

  static String? _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }
}
