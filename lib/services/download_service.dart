import 'dart:typed_data';

import 'download_io.dart'
    if (dart.library.js_interop) 'download_web.dart'
    as platform;

/// Makes the browser save [bytes] as [fileName] with [mimeType].
///
/// Only reachable on the web; other platforms throw.
void downloadBytes(Uint8List bytes, String fileName, String mimeType) =>
    platform.downloadBytes(bytes, fileName, mimeType);
