import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Number of decoded data URL payloads kept in memory.
const int _dataUrlCacheLimit = 3;

final Map<String, Uint8List> _dataUrlCache = <String, Uint8List>{};

/// Wraps [bytes] into a base64 data URL, sniffing the image type when [mime]
/// is not provided. Unknown types fall back to `application/octet-stream`.
String dataUrlFromBytes(Uint8List bytes, {String? mime}) {
  final type = mime ?? imageMimeFromBytes(bytes) ?? 'application/octet-stream';
  return 'data:$type;base64,${base64Encode(bytes)}';
}

/// Whether [source] points at a `data:` URL instead of a file path.
bool isDataUrl(String source) => source.startsWith('data:');

/// The MIME type declared by a `data:` URL, or `null` for other sources.
String? dataUrlMime(String source) {
  if (!isDataUrl(source)) return null;
  final end = source.indexOf(',');
  final header = source.substring(5, end < 0 ? source.length : end);
  final base64Index = header.indexOf(';base64');
  final mime = base64Index < 0 ? header : header.substring(0, base64Index);
  return mime.isEmpty ? null : mime;
}

/// Decodes the base64 payload of a `data:` URL.
///
/// Throws a [FormatException] when [source] is not a well formed base64 data
/// URL.
Uint8List bytesFromDataUrl(String source) {
  if (!isDataUrl(source)) {
    throw const FormatException('Not a data URL');
  }
  final end = source.indexOf(',');
  if (end < 0) {
    throw const FormatException('Malformed data URL');
  }
  final header = source.substring(5, end);
  if (!header.endsWith(';base64')) {
    throw const FormatException('Only base64 data URLs are supported');
  }
  return base64Decode(source.substring(end + 1));
}

/// Detects the image MIME type from the magic bytes of [bytes].
String? imageMimeFromBytes(List<int> bytes) {
  if (bytes.length < 12) return null;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
    return 'image/png';
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return 'image/bmp';
  }
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand.startsWith('mif') || brand.startsWith('msf')) return 'image/heif';
    return 'image/heic';
  }
  return null;
}

/// Builds the [ImageProvider] for a stored photo [source].
///
/// Sources are file paths on mobile and `data:` / `blob:` / `http(s):` URLs on
/// the web. [width] applies the standard preview downscale.
ImageProvider photoProvider(String source, {int? width}) {
  final ImageProvider provider = _providerFor(source);
  if (width == null) return provider;
  return ResizeImage(provider, width: width);
}

ImageProvider _providerFor(String source) {
  if (source.startsWith('data:')) return MemoryImage(_decodeDataUrl(source));
  if (source.startsWith('blob:') ||
      source.startsWith('http://') ||
      source.startsWith('https://')) {
    return NetworkImage(source);
  }
  return FileImage(File(source));
}

Uint8List _decodeDataUrl(String source) {
  final cached = _dataUrlCache.remove(source);
  if (cached != null) {
    _dataUrlCache[source] = cached;
    return cached;
  }
  final bytes = bytesFromDataUrl(source);
  _dataUrlCache[source] = bytes;
  while (_dataUrlCache.length > _dataUrlCacheLimit) {
    _dataUrlCache.remove(_dataUrlCache.keys.first);
  }
  return bytes;
}

/// Mirrors [bytes] horizontally and returns the result re-encoded as PNG.
Future<Uint8List> flipImageBytesHorizontal(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final ui.Image source;
  try {
    final frame = await codec.getNextFrame();
    source = frame.image;
  } finally {
    codec.dispose();
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..translate(source.width.toDouble(), 0)
    ..scale(-1, 1);
  canvas.drawImage(source, ui.Offset.zero, ui.Paint());
  final picture = recorder.endRecording();
  final output = await picture.toImage(source.width, source.height);
  source.dispose();

  final data = await output.toByteData(format: ui.ImageByteFormat.png);
  output.dispose();
  picture.dispose();
  if (data == null) {
    throw StateError('Failed to mirror the captured photo');
  }
  return data.buffer.asUint8List();
}
