import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Picks an image and returns its raw bytes, or null if the user cancelled.
typedef ImagePickerFn = Future<Uint8List?> Function();

/// Compresses raw image bytes and returns compressed JPEG bytes.
typedef ImageCompressFn =
    Future<Uint8List> Function({
      required Uint8List bytes,
      required int minWidth,
      required int minHeight,
      required int quality,
    });

/// Uploads bytes to [storagePath] and returns the public download URL.
typedef StorageUploadFn =
    Future<String> Function({
      required String storagePath,
      required Uint8List bytes,
    });

// ---------------------------------------------------------------------------
// Default implementations (production)
// ---------------------------------------------------------------------------

Future<Uint8List?> _defaultPickImage() async {
  final picker = ImagePicker();
  final xfile = await picker.pickImage(source: ImageSource.gallery);
  if (xfile == null) return null;
  return xfile.readAsBytes();
}

Future<Uint8List> _defaultCompress({
  required Uint8List bytes,
  required int minWidth,
  required int minHeight,
  required int quality,
}) async {
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: minWidth,
    minHeight: minHeight,
    quality: quality,
    format: CompressFormat.jpeg,
  );
}

Future<String> _defaultUpload({
  required String storagePath,
  required Uint8List bytes,
}) async {
  final ref = fs.FirebaseStorage.instance.ref(storagePath);
  final metadata = fs.SettableMetadata(contentType: 'image/jpeg');
  final snapshot = await ref.putData(bytes, metadata);
  return snapshot.ref.getDownloadURL();
}

// ---------------------------------------------------------------------------
// PhotoService
// ---------------------------------------------------------------------------

/// Handles picking an image from the gallery, compressing it to ≤ 1 MB
/// JPEG (1024 px long edge, quality 75), and uploading to Firebase Storage.
///
/// All three operations are injectable via constructor parameters so that
/// unit tests can verify behaviour without a real device, camera, or Firebase
/// project.
///
/// ### Production usage
/// ```dart
/// final service = PhotoService();
/// final url = await service.pickAndUpload(
///   storagePath: 'item_photos/$itemId.jpg',
/// );
/// ```
///
/// ### Test usage
/// ```dart
/// final service = PhotoService(
///   pickImage: () async => fakeBytes,
///   compress: ({required bytes, required minWidth,
///               required minHeight, required quality}) async => smallBytes,
///   upload: ({required storagePath, required bytes}) async => 'https://example.com/photo.jpg',
/// );
/// ```
class PhotoService {
  /// Maximum long-edge pixel size after compression.
  static const int kMaxDimension = 1024;

  /// JPEG quality used during compression (0–100).
  static const int kJpegQuality = 75;

  /// Maximum allowed file size after compression (1 MB).
  static const int kMaxBytes = 1024 * 1024;

  final ImagePickerFn _pickImage;
  final ImageCompressFn _compress;
  final StorageUploadFn _upload;

  PhotoService({
    ImagePickerFn? pickImage,
    ImageCompressFn? compress,
    StorageUploadFn? upload,
  }) : _pickImage = pickImage ?? _defaultPickImage,
       _compress = compress ?? _defaultCompress,
       _upload = upload ?? _defaultUpload;

  /// Picks an image from the gallery, compresses it to ≤ 1 MB JPEG, uploads
  /// to [storagePath] in Firebase Storage, and returns the download URL.
  ///
  /// Returns [null] if the user cancelled the picker without selecting an
  /// image.
  ///
  /// [storagePath] must follow the convention:
  ///   - User photos: `user_photos/{uid}.jpg`
  ///   - Item photos: `item_photos/{itemId}.jpg`
  Future<String?> pickAndUpload({required String storagePath}) async {
    final rawBytes = await _pickImage();
    if (rawBytes == null) return null;

    final compressed = await _compress(
      bytes: rawBytes,
      minWidth: kMaxDimension,
      minHeight: kMaxDimension,
      quality: kJpegQuality,
    );

    final url = await _upload(storagePath: storagePath, bytes: compressed);
    return url;
  }

  /// Compresses [rawBytes] with the standard settings and returns the byte
  /// count of the result.
  ///
  /// Used by tests to assert the output is below [kMaxBytes] without
  /// performing a real Storage upload.
  Future<int> compressedSizeOf(Uint8List rawBytes) async {
    final compressed = await _compress(
      bytes: rawBytes,
      minWidth: kMaxDimension,
      minHeight: kMaxDimension,
      quality: kJpegQuality,
    );
    return compressed.length;
  }
}
