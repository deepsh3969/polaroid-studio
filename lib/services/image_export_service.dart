import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/image_source.dart';
import '../widgets/polaroid_frame.dart';
import 'download_service.dart';

/// A rendered Polaroid ready to be saved, downloaded or shared.
///
/// [file] is the temporary PNG on mobile; on the web only the in-memory
/// [bytes] exist, because browsers have no shared file system.
class ExportedImage {
  const ExportedImage({required this.bytes, required this.fileName, this.file});

  final Uint8List bytes;
  final String fileName;
  final File? file;
}

/// Renders the complete Polaroid composition (photo + paper + caption + date +
/// filter + shadow) and stores / shares the result.
///
/// The original photo file is only ever read, never modified.
class ImageExportService {
  const ImageExportService();

  /// Captures a widget that is currently mounted in the tree through its
  /// [RepaintBoundary] `GlobalKey`.
  ///
  /// Returns `null` when the key is not attached or the capture fails; raw
  /// errors are logged for developers instead of being surfaced.
  Future<Uint8List?> captureBoundary(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = AppMetrics.exportPixelRatio,
  }) async {
    try {
      final context = repaintBoundaryKey.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        debugPrint(
          '[PolaroidStudio] captureBoundary: no RenderRepaintBoundary',
        );
        return null;
      }
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('[PolaroidStudio] captureBoundary failed: $error');
      return null;
    }
  }

  /// Renders the full composition off-screen at high resolution.
  ///
  /// The widget is rendered at [AppMetrics.exportLogicalWidth] logical pixels
  /// and rasterised at 3x, producing a 2160px wide image. When the device runs
  /// out of memory the render is retried at a lower pixel ratio instead of
  /// crashing.
  ///
  /// On mobile the result is written to a temporary PNG file; on the web it
  /// stays in memory for downloading / sharing.
  Future<ExportedImage> exportPolaroid({
    required BuildContext context,
    required PolaroidConfig config,
    double pixelRatio = AppMetrics.exportPixelRatio,
  }) async {
    late Uint8List png;
    try {
      final composition = await _buildComposition(context, config);
      try {
        png = await _render(composition.widget, composition.size, pixelRatio);
      } catch (error) {
        debugPrint('[PolaroidStudio] export at ${pixelRatio}x failed: $error');
        png = await _render(
          composition.widget,
          composition.size,
          AppMetrics.exportPixelRatioFallback,
        );
      }
    } on AppException {
      rethrow;
    } catch (error) {
      throw toAppException(error, AppStrings.errExportFailed);
    }

    final id = generateCreationId();
    final fileName = 'polaroid_$id.png';
    if (kIsWeb) {
      return ExportedImage(bytes: png, fileName: fileName);
    }

    try {
      final file = await _writeTempFile(png, id);
      return ExportedImage(bytes: png, fileName: fileName, file: file);
    } catch (error) {
      throw toAppException(error, AppStrings.errExportFailed);
    }
  }

  /// Saves [image] into the device gallery (mobile) or downloads it through
  /// the browser (web) under the Polaroid Studio album.
  Future<void> save(ExportedImage image) async {
    if (kIsWeb) {
      try {
        downloadBytes(image.bytes, image.fileName, 'image/png');
      } catch (error) {
        throw toAppException(error, AppStrings.errSaveFailed);
      }
      return;
    }

    final file = image.file;
    if (file == null) {
      throw const AppException(AppStrings.errSaveFailed);
    }

    try {
      final granted =
          await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const AppException(
          AppStrings.errSaveFailed,
          logDetails: 'media library access denied',
        );
      }
      await Gal.putImage(file.path, album: AppMetrics.galleryAlbum);
    } on AppException {
      rethrow;
    } on GalException catch (error) {
      debugPrint('[PolaroidStudio] gal error: ${error.type.name}');
      throw AppException(AppStrings.errSaveFailed, logDetails: error.type.name);
    } catch (error) {
      throw toAppException(error, AppStrings.errSaveFailed);
    }
  }

  /// Opens the native share sheet for an exported Polaroid.
  ///
  /// On the web this uses the Web Share API and falls back to a download when
  /// the browser cannot share files.
  ///
  /// Returns `true` when the user actually shared the image.
  Future<bool> sharePolaroid(ExportedImage image, {String? caption}) async {
    try {
      final XFile file;
      if (kIsWeb) {
        file = XFile.fromData(
          image.bytes,
          mimeType: 'image/png',
          name: image.fileName,
        );
      } else {
        final target = image.file;
        if (target == null) {
          throw const AppException(AppStrings.errShareFailed);
        }
        file = XFile(target.path, mimeType: 'image/png', name: image.fileName);
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          title: AppStrings.appName,
          text: (caption == null || caption.trim().isEmpty)
              ? null
              : caption.trim(),
          files: <XFile>[file],
          fileNameOverrides: kIsWeb ? <String>[image.fileName] : null,
        ),
      );
      return result.status == ShareResultStatus.success;
    } on AppException {
      rethrow;
    } catch (error) {
      throw toAppException(error, AppStrings.errShareFailed);
    }
  }

  // -------------------------------------------------------------------------

  /// Builds the export sized composition and makes sure every pixel of the
  /// photo is decoded before rasterising.
  Future<_Composition> _buildComposition(
    BuildContext context,
    PolaroidConfig config,
  ) async {
    const double width = AppMetrics.exportLogicalWidth;
    final layout = FrameLayout.forStyle(config.frameStyle, width);
    final size = Size(width, layout.height);

    final image = photoProvider(
      config.imagePath,
      width: AppMetrics.exportDecodeWidth,
    );

    try {
      await precacheImage(image, context);
    } catch (error) {
      debugPrint('[PolaroidStudio] precache failed: $error');
      throw AppException(AppStrings.errExportFailed, logDetails: '$error');
    }

    final widget = SizedBox.fromSize(
      size: size,
      child: PolaroidFrame(
        image: image,
        caption: config.caption,
        date: config.formattedDate,
        frameStyle: config.frameStyle,
        filter: config.filter,
        showDate: config.showDate,
        width: width,
        captionStyle: config.captionStyle,
        transform: config.transform,
      ),
    );

    return _Composition(widget, size);
  }

  Future<Uint8List> _render(Widget child, Size size, double pixelRatio) {
    final controller = ScreenshotController();
    return controller.captureFromWidget(
      child,
      pixelRatio: pixelRatio,
      targetSize: size,
      delay: AppMetrics.exportRenderDelay,
    );
  }

  Future<File> _writeTempFile(Uint8List bytes, String id) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$id.png');
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw const AppException(AppStrings.errExportFailed);
    }
    return file;
  }
}

class _Composition {
  const _Composition(this.widget, this.size);

  final Widget widget;
  final Size size;
}
