import 'dart:js_interop';

@JS('window.navigator.mediaDevices.__polaroidGuard.sanitize')
external JSPromise<JSAny?> _sanitize();

Future<void> sanitizeCameras() async {
  try {
    await _sanitize().toDart;
  } catch (_) {
    return;
  }
}
