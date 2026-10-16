import 'package:flutter/material.dart';

/// Static user facing strings used across the application.
abstract final class AppStrings {
  static const String appName = 'Polaroid Studio';
  static const String brandLine1 = 'POLAROID';
  static const String brandLine2 = 'STUDIO';
  static const String brandTagline = 'Vintage prints from your camera roll';

  static const String takePhoto = 'Take Photo';
  static const String chooseFromGallery = 'Choose From Gallery';
  static const String recentCreations = 'Recent Creations';
  static const String emptyCreations =
      'Your Polaroid memories will appear here.';

  static const String privacyNotice =
      'Your photos stay on your device.\n'
      'Polaroid Studio does not upload your images.';

  static const String editor = 'EDITOR';
  static const String preview = 'PREVIEW';
  static const String settings = 'SETTINGS';
  static const String camera = 'CAMERA';
  static const String showcase = 'SHOWCASE';

  // Showcase / line carousel ---------------------------------------------
  static const String showcaseTitle = 'Polaroid Line Carousel';
  static const String showcaseIntro =
      'Instant prints pegged to a sagging string. Drag the line to slide '
      'them, tap a print to centre it, or let them wander on their own - '
      'every swing is simulated live.';
  static const String hintDrag = 'Drag the line';
  static const String hintTap = 'Tap a print';
  static const String hintKeys = 'Arrow keys';
  static const String hintAutoplay = 'Autoplay';
  static const String showcaseMeta =
      '6 slides · rendered offline from one bundled photo';
  static const String showcaseSource =
      'lib/widgets/line_carousel.dart · CustomPainter';
  static const String startCreating = 'Start Creating';
  static const String previousPrint = 'Previous';
  static const String nextPrint = 'Next';

  static const String exportPhoto = 'EXPORT PHOTO';
  static const String saveToGallery = 'Save to Gallery';
  static const String creatingPolaroid = 'Creating your Polaroid...';
  static const String preparingImage = 'Preparing image...';
  static const String savingToGallery = 'Saving to your gallery...';
  static const String download = 'Download';
  static const String downloading = 'Downloading your Polaroid...';
  static const String tryAgain = 'Try again';
  static const String mirrorPreview = 'Mirror preview';
  static const String mirrorPhoto = 'Mirror photo';
  static const String switchCamera = 'Switch camera';
  static const String backCamera = 'Back camera';
  static const String frontCamera = 'Front camera';

  static String numberedCamera(int index) => 'Camera $index';

  static const String savedTitle = 'Saved Successfully';
  static const String share = 'Share';
  static const String createAnother = 'Create Another';
  static const String done = 'Done';
  static const String edit = 'Edit';
  static const String back = 'Back';

  static const String skipAnimation = 'Skip';

  // Section labels -------------------------------------------------------
  static const String sectionFrame = 'Frame';
  static const String sectionFilter = 'Filter';
  static const String sectionCaption = 'Caption';
  static const String sectionAdjust = 'Adjust';
  static const String sectionDate = 'Date';
  static const String sectionTypography = 'Typography';

  static const String showDate = 'Show Date';
  static const String dateFormatLabel = 'Date format';
  static const String resetPosition = 'Reset';
  static const String retake = 'Retake';
  static const String usePhoto = 'Use Photo';
  static const String deleteCreation = 'Delete';
  static const String deleteTitle = 'Delete this Polaroid?';
  static const String deleteMessage =
      'This removes it from Polaroid Studio only.';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';

  // Friendly error messages (never expose raw exceptions to users) -------
  static const String errGalleryDenied =
      'Photo access is needed to choose a picture. You can allow it in Settings.';
  static const String errGalleryFailed =
      "We couldn't open your photos. Please try again.";
  static const String errInvalidImage =
      "That file doesn't look like a photo we can use. Try a JPG or PNG.";
  static const String errImageTooLarge =
      'That photo is too large to process. Please choose a smaller one.';
  static const String errImageMissing = "We couldn't find that photo anymore.";
  static const String errCameraDenied =
      'Camera access is needed to take photos. You can allow it in Settings.';
  static const String errCameraUnavailable =
      "We couldn't access the camera on this device.";
  static const String errCameraBlocked =
      'Camera access was blocked. Allow camera access from the camera icon in '
      'your browser address bar, then try again.';
  static const String errCameraNotFound =
      "We couldn't find a camera on this device.";
  static const String errCameraInUse =
      'Your camera is being used by another app. Close it, then try again.';
  static const String errCameraUnsupported =
      "This browser can't use a camera. Try Chrome, Edge or Safari over "
      'https.';
  static const String errCameraInsecure =
      'Camera access needs a secure connection. Open this page over https or '
      'localhost.';
  static const String errExportFailed =
      "We couldn't create your Polaroid. Please try again.";
  static const String errSaveFailed =
      "We couldn't save your Polaroid. Please try again.";
  static const String errShareFailed =
      "Sharing isn't available right now. Please try again.";

  static const String successSaved = '✓ Polaroid saved to your gallery';
  static const String successDownloaded = '✓ Polaroid downloaded';
}

/// Layout, quality and behaviour constants.
abstract final class AppMetrics {
  /// Maximum caption length accepted by the caption editor.
  static const int captionMaxLength = 40;

  /// Logical width of the off-screen composition rendered during export.
  static const double exportLogicalWidth = 720;

  /// Render scale used when exporting (3.0 * 720 = 2160 px wide output).
  static const double exportPixelRatio = 3.0;

  /// First attempt pixel ratio, lowered automatically on low memory devices.
  static const double exportPixelRatioFallback = 2.0;

  /// Decode width used for the on-screen preview (keeps editing cheap).
  static const int previewDecodeWidth = 1400;

  /// Decode width used only for the final high resolution export.
  static const int exportDecodeWidth = 2400;

  /// Images bigger than this are rejected before decoding.
  static const int maxImageBytes = 64 * 1024 * 1024;

  /// Maximum number of recent creations kept on disk.
  static const int maxCreations = 40;

  static const double minZoom = 1.0;
  static const double maxZoom = 4.0;

  /// Maximum photo tilt, in radians (~20 degrees).
  static const double maxRotation = 0.35;

  /// Album (Android) / folder (iOS) used when saving exported images.
  static const String galleryAlbum = 'Polaroid Studio';

  static const Duration developingDuration = Duration(milliseconds: 2800);
  static const Duration exportRenderDelay = Duration(milliseconds: 350);
  static const Duration snackBarDuration = Duration(seconds: 3);
}

/// SharedPreferences keys.
abstract final class PrefsKeys {
  static const String themeMode = 'settings.themeMode';
  static const String dateFormat = 'settings.dateFormat';
  static const String animateDeveloping = 'settings.animateDeveloping';
  static const String creations = 'creations.list';
}

/// Colour palette for the vintage photography identity.
abstract final class AppPalette {
  static const Color ink = Color(0xFF23201C);
  static const Color charcoal = Color(0xFF2E2A25);
  static const Color cream = Color(0xFFF6EFE2);
  static const Color paper = Color(0xFFFFFDF7);
  static const Color beige = Color(0xFFE6DAC5);
  static const Color accent = Color(0xFF9B6A4A);
  static const Color accentDeep = Color(0xFF7A4F34);
  static const Color muted = Color(0xFF8A8177);
  static const Color success = Color(0xFF3E7A52);
  static const Color danger = Color(0xFFA63D2F);

  static const Color darkBackground = Color(0xFF16140F);
  static const Color darkSurface = Color(0xFF221F1A);
  static const Color darkCard = Color(0xFF2C2823);
}
