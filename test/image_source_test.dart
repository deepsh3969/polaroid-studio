import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/services/image_picker_service.dart';
import 'package:polaroid_studio/utils/constants.dart';
import 'package:polaroid_studio/utils/helpers.dart';
import 'package:polaroid_studio/utils/image_source.dart';

Future<Uint8List> _tinyPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color.fromARGB(255, 10, 20, 30),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Uint8List _bytesOf(List<int> header, {int length = 16}) {
  final bytes = Uint8List(length);
  for (var i = 0; i < header.length && i < bytes.length; i++) {
    bytes[i] = header[i];
  }
  return bytes;
}

void main() {
  group('image mime sniffing', () {
    test('detects common formats from magic bytes', () {
      expect(
        imageMimeFromBytes(_bytesOf(<int>[0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
      expect(
        imageMimeFromBytes(_bytesOf(<int>[0x89, 0x50, 0x4E, 0x47])),
        'image/png',
      );
      expect(
        imageMimeFromBytes(_bytesOf(<int>[0x47, 0x49, 0x46, 0x38])),
        'image/gif',
      );
      expect(imageMimeFromBytes(_bytesOf(<int>[0x42, 0x4D])), 'image/bmp');
      expect(
        imageMimeFromBytes(
          _bytesOf(<int>[
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
        ),
        'image/webp',
      );
      expect(
        imageMimeFromBytes(
          _bytesOf(<int>[
            0,
            0,
            0,
            0,
            0x66,
            0x74,
            0x79,
            0x70,
            0x68,
            0x65,
            0x69,
            0x63,
          ]),
        ),
        'image/heic',
      );
      expect(
        imageMimeFromBytes(_bytesOf(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9])),
        isNull,
      );
      expect(imageMimeFromBytes(<int>[1, 2, 3]), isNull);
    });
  });

  group('data URLs', () {
    test('round trips jpeg bytes', () {
      final bytes = _bytesOf(<int>[0xFF, 0xD8, 0xFF, 0xE0]);
      final source = dataUrlFromBytes(bytes);
      expect(source, startsWith('data:image/jpeg;base64,'));
      expect(dataUrlMime(source), 'image/jpeg');
      expect(bytesFromDataUrl(source), bytes);
      expect(isDataUrl(source), isTrue);
      expect(isDataUrl('/tmp/photo.jpg'), isFalse);
      expect(dataUrlMime('/tmp/photo.jpg'), isNull);
    });

    test('unknown bytes fall back to octet-stream', () {
      final source = dataUrlFromBytes(
        _bytesOf(<int>[9, 9, 9, 9, 9, 9, 9, 9, 9]),
      );
      expect(source, startsWith('data:application/octet-stream;base64,'));
      expect(dataUrlMime(source), 'application/octet-stream');
    });

    test('rejects malformed payloads', () {
      expect(() => bytesFromDataUrl('not a data url'), throwsFormatException);
      expect(
        () => bytesFromDataUrl('data:image/png;utf8,abc'),
        throwsFormatException,
      );
      expect(
        () => bytesFromDataUrl('data:image/png;base64'),
        throwsFormatException,
      );
      expect(
        () => bytesFromDataUrl('data:image/png;base64,%%%'),
        throwsFormatException,
      );
    });
  });

  group('photoProvider', () {
    test('builds a memory image from a data URL', () {
      final source = dataUrlFromBytes(_bytesOf(<int>[0xFF, 0xD8, 0xFF, 0xE0]));
      expect(photoProvider(source), isA<MemoryImage>());
      final resized = photoProvider(source, width: 64);
      expect(resized, isA<ResizeImage>());
      expect((resized as ResizeImage).width, 64);
    });

    test('builds a file image from a path', () {
      expect(photoProvider('/tmp/photo.jpg'), isA<FileImage>());
      final resized = photoProvider('/tmp/photo.jpg', width: 64);
      expect(resized, isA<ResizeImage>());
      expect((resized as ResizeImage).width, 64);
    });
  });

  group('flipImageBytesHorizontal', () {
    test('mirrors the image contents', () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 2, 4),
        ui.Paint()..color = const ui.Color.fromARGB(255, 255, 0, 0),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(2, 0, 2, 4),
        ui.Paint()..color = const ui.Color.fromARGB(255, 0, 0, 255),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(4, 4);
      final source = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();

      final flipped = await flipImageBytesHorizontal(source);

      final codec = await ui.instantiateImageCodec(flipped);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      final raw = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      frame.image.dispose();
      codec.dispose();

      expect(width, 4);
      expect(height, 4);
      expect(raw[0], 0);
      expect(raw[1], 0);
      expect(raw[2], 255);
      expect(raw[3], 255);
      expect(raw[12], 255);
      expect(raw[13], 0);
      expect(raw[14], 0);
      expect(raw[15], 255);
    });
  });

  group('ImagePickerService.validate', () {
    final service = ImagePickerService();

    test('accepts a PNG data URL', () async {
      final source = dataUrlFromBytes(await _tinyPng());
      await expectLater(service.validate(source), completes);
    });
    test('rejects unsupported data URL types', () async {
      const source = 'data:text/plain;base64,aGVsbG8gd29ybGQ=';
      await expectLater(
        service.validate(source),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            AppStrings.errInvalidImage,
          ),
        ),
      );
    });

    test('rejects garbage payloads', () async {
      await expectLater(
        service.validate('data:image/png;base64,%%%'),
        throwsA(isA<AppException>()),
      );
      await expectLater(service.validate(''), throwsA(isA<AppException>()));
      await expectLater(
        service.validate('/definitely/missing.jpg'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
