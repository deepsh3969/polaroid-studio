import 'camera_guard_io.dart'
    if (dart.library.js_interop) 'camera_guard_web.dart'
    as platform;

/// Probes every camera and hides the ones that cannot be opened from
/// `navigator.mediaDevices.enumerateDevices`.
///
/// Some virtual camera drivers (for example OBS Virtual Camera when its host
/// app is not running) enumerate fine but fail to open; `camera_web` aborts
/// its whole camera listing on the first such failure, which would otherwise
/// make the camera screen unusable on web.
Future<void> sanitizeCameras() => platform.sanitizeCameras();
