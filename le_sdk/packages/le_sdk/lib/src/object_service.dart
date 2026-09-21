import 'dart:typed_data';

/// Result of uploading an object.
class ObjectUploadResult {
  final String path;
  final String? checksum;

  const ObjectUploadResult({required this.path, this.checksum});
}

/// Metadata for a single object in the Object Store.
class ObjectMetadata {
  final String path;
  final int sizeBytes;
  final DateTime lastUpdatedAt;
  final DateTime? expiryTime;
  final String? checksum;

  const ObjectMetadata({
    required this.path,
    required this.sizeBytes,
    required this.lastUpdatedAt,
    this.expiryTime,
    this.checksum,
  });
}

/// Service for storing and retrieving binary objects via the Lattice CDN.
///
/// Objects are binary data (images, documents, sensor payloads, etc.) stored
/// across the Lattice mesh network. Use this when entity payloads exceed the
/// entity API size limits.
///
/// Example:
/// ```dart
/// // Upload
/// final result = await context.objects.upload('myapp-data.json', bytes);
/// print('Stored at: ${result.path}');
///
/// // Download
/// final data = await context.objects.download('myapp-data.json');
///
/// // List
/// final items = await context.objects.list(prefix: 'myapp-');
///
/// // Delete
/// await context.objects.delete('myapp-data.json');
/// ```
abstract class ObjectService {
  /// Uploads binary data to the Object Store.
  ///
  /// [path] — unique object path (alphanumeric, `.`, `_`, `-` only).
  /// [bytes] — the binary content to store.
  /// [contentType] — optional MIME type (e.g. `image/png`).
  /// [ttl] — optional time-to-live; object is auto-deleted after this duration.
  ///
  /// Returns the content identifier path and SHA-256 checksum.
  Future<ObjectUploadResult> upload(
    String path,
    Uint8List bytes, {
    String? contentType,
    Duration? ttl,
  });

  /// Downloads an object by path and returns the raw bytes.
  /// Returns null if the object does not exist.
  Future<Uint8List?> download(String path);

  /// Lists all objects, optionally filtered by prefix. Auto-pages internally.
  Future<List<ObjectMetadata>> list({String? prefix});

  /// Deletes an object by path. Permanent and cannot be undone.
  Future<void> delete(String path);

  /// Gets metadata for an object without downloading its contents.
  /// Returns null if the object does not exist.
  Future<ObjectMetadata?> getMetadata(String path);
}
