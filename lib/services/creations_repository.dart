import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// One exported Polaroid kept in the local, offline history.
@immutable
class Creation {
  const Creation({
    required this.id,
    required this.filePath,
    required this.thumbPath,
    required this.caption,
    required this.createdAt,
    required this.config,
  });

  final String id;

  /// App local copy of the exported composition (not the original photo).
  final String filePath;

  /// Lightweight thumbnail used by the home grid.
  final String? thumbPath;

  final String caption;
  final DateTime createdAt;

  /// Configuration used to produce it, so it can be re-edited later.
  final PolaroidConfig config;

  File get file => File(filePath);
  File? get thumbFile => thumbPath == null ? null : File(thumbPath!);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'filePath': filePath,
    'thumbPath': thumbPath,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'config': config.toJson(),
  };

  factory Creation.fromJson(Map<String, dynamic> json) => Creation(
    id: json['id'] as String? ?? '',
    filePath: json['filePath'] as String? ?? '',
    thumbPath: json['thumbPath'] as String?,
    caption: json['caption'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    config: json['config'] is Map<String, dynamic>
        ? PolaroidConfig.fromJson(json['config'] as Map<String, dynamic>)
        : PolaroidConfig(imagePath: ''),
  );
}

/// Offline storage for recent creations (files + metadata in shared
/// preferences). Nothing ever leaves the device.
class CreationsRepository {
  CreationsRepository._(this._prefs, this._directory);

  /// Opens (and creates on first run) the app local creations folder.
  static Future<CreationsRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/polaroid_creations');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return CreationsRepository._(prefs, directory);
  }

  /// Injection point for tests.
  CreationsRepository.forTest(this._prefs, this._directory);

  final SharedPreferences _prefs;
  final Directory _directory;

  /// Newest first. Entries whose files disappeared are pruned automatically.
  Future<List<Creation>> all() async {
    final stored = _read();
    final valid = <Creation>[];
    final changed = <Creation>[];

    for (final creation in stored) {
      if (await File(creation.filePath).exists()) {
        valid.add(creation);
        changed.add(creation);
      } else {
        debugPrint('[PolaroidStudio] dropping missing creation ${creation.id}');
        await _deleteFiles(creation);
      }
    }
    if (changed.length != stored.length) {
      await _write(changed);
    }
    return valid;
  }

  /// Stores a copy of the exported Polaroid plus a thumbnail.
  Future<Creation> add({
    required File exportedFile,
    required PolaroidConfig config,
  }) async {
    final id = generateCreationId();
    final target = File('${_directory.path}/$id.png');
    await exportedFile.copy(target.path);

    final thumbPath = await _createThumbnail(target, id);

    final creation = Creation(
      id: id,
      filePath: target.path,
      thumbPath: thumbPath,
      caption: config.caption,
      createdAt: DateTime.now(),
      config: config,
    );

    final updated = <Creation>[creation, ..._read()];
    await _write(updated.take(AppMetrics.maxCreations).toList());
    await _pruneOlderThan(AppMetrics.maxCreations);
    return creation;
  }

  /// Removes a creation and its files.
  Future<void> delete(Creation creation) async {
    await _deleteFiles(creation);
    final updated = _read().where((item) => item.id != creation.id).toList();
    await _write(updated);
  }

  // -------------------------------------------------------------------------

  List<Creation> _read() {
    try {
      final raw = _prefs.getString(PrefsKeys.creations);
      if (raw == null || raw.isEmpty) return <Creation>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <Creation>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Creation.fromJson)
          .toList();
    } catch (error) {
      debugPrint('[PolaroidStudio] reading creations failed: $error');
      return <Creation>[];
    }
  }

  Future<void> _write(List<Creation> creations) async {
    try {
      final encoded = jsonEncode(creations.map((c) => c.toJson()).toList());
      await _prefs.setString(PrefsKeys.creations, encoded);
    } catch (error) {
      debugPrint('[PolaroidStudio] writing creations failed: $error');
    }
  }

  Future<void> _pruneOlderThan(int keep) async {
    final creations = _read();
    if (creations.length <= keep) return;
    final overflow = creations.skip(keep).toList();
    for (final creation in overflow) {
      await _deleteFiles(creation);
    }
    await _write(creations.take(keep).toList());
  }

  Future<void> _deleteFiles(Creation creation) async {
    try {
      if (await File(creation.filePath).exists()) {
        await File(creation.filePath).delete();
      }
      final thumb = creation.thumbPath;
      if (thumb != null && await File(thumb).exists()) {
        await File(thumb).delete();
      }
    } catch (error) {
      debugPrint('[PolaroidStudio] deleting files failed: $error');
    }
  }

  /// Builds a small JPEG thumbnail with the `image` package so the history
  /// grid stays cheap to render.
  Future<String?> _createThumbnail(File source, String id) async {
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final thumb = img.copyResize(
        decoded,
        width: 420,
        interpolation: img.Interpolation.average,
      );
      final file = File('${_directory.path}/${id}_thumb.jpg');
      await file.writeAsBytes(img.encodeJpg(thumb, quality: 84), flush: true);
      return file.path;
    } catch (error) {
      debugPrint('[PolaroidStudio] thumbnail failed: $error');
      return null;
    }
  }
}
