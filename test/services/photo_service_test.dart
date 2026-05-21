import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/services/photo_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal valid JPEG byte sequence (~3 KB) so that the real
/// FlutterImageCompress is never invoked in tests — we inject a no-op
/// compressor instead.
Uint8List _makeRawBytes(int sizeBytes) =>
    Uint8List.fromList(List.generate(sizeBytes, (i) => i % 256));

/// A compressor stub that returns exactly [outputSize] bytes regardless of
/// input.  Simulates compression having reduced the file to [outputSize].
ImageCompressFn _compressorReturning(int outputSize) {
  return ({
    required Uint8List bytes,
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async =>
      Uint8List(outputSize);
}

/// An uploader stub that captures the last call and always returns a fixed URL.
class _CapturingUploader {
  String? capturedPath;
  Uint8List? capturedBytes;

  Future<String> call({
    required String storagePath,
    required Uint8List bytes,
  }) async {
    capturedPath = storagePath;
    capturedBytes = bytes;
    return 'https://example.com/photo.jpg';
  }
}

/// A picker stub that always returns [bytes] (simulating user selecting an
/// image), or [null] to simulate a cancelled pick.
ImagePickerFn _pickerReturning(Uint8List? bytes) => () async => bytes;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Unit test: compressed file < 1 MB ─────────────────────────────────────
  //
  // WBS 6.1 acceptance: "Storage bucket file size always < 1 MB"
  // We simulate a large raw image (2 MB) and a compressor that squeezes it
  // to 500 KB, then assert the bytes sent to the uploader are < 1 MB.
  group('PhotoService — compressed output < 1 MB', () {
    test(
        'upload to item_photos/{itemId}.jpg sends < 1 MB bytes to storage',
        () async {
      const rawSize = 2 * 1024 * 1024; // 2 MB raw input
      const compressedSize = 500 * 1024; // 500 KB after compression

      final uploader = _CapturingUploader();

      final service = PhotoService(
        pickImage: _pickerReturning(_makeRawBytes(rawSize)),
        compress: _compressorReturning(compressedSize),
        upload: uploader.call,
      );

      final url = await service.pickAndUpload(
          storagePath: 'item_photos/item-abc123.jpg');

      expect(url, isNotNull);
      // The bytes uploaded must be below the 1 MB threshold.
      expect(uploader.capturedBytes!.length,
          lessThan(PhotoService.kMaxBytes));
    });

    test('compressedSizeOf reports the compressed byte count', () async {
      const rawSize = 3 * 1024 * 1024; // 3 MB raw
      const compressedSize = 800 * 1024; // 800 KB compressed

      final service = PhotoService(
        pickImage: _pickerReturning(null), // not used in this test
        compress: _compressorReturning(compressedSize),
        upload: ({required storagePath, required bytes}) async => '',
      );

      final size = await service.compressedSizeOf(_makeRawBytes(rawSize));
      expect(size, equals(compressedSize));
      expect(size, lessThan(PhotoService.kMaxBytes));
    });
  });

  // ── Unit test: storagePath routed to item_photos/ ─────────────────────────
  group('PhotoService — storage path', () {
    test('pickAndUpload uses the given storagePath', () async {
      const itemId = 'item-xyz789';
      final uploader = _CapturingUploader();

      final service = PhotoService(
        pickImage: _pickerReturning(_makeRawBytes(100)),
        compress: _compressorReturning(100),
        upload: uploader.call,
      );

      await service.pickAndUpload(storagePath: 'item_photos/$itemId.jpg');

      expect(uploader.capturedPath, equals('item_photos/$itemId.jpg'));
    });

    test('pickAndUpload also works with user_photos/ path', () async {
      const uid = 'user-uid-001';
      final uploader = _CapturingUploader();

      final service = PhotoService(
        pickImage: _pickerReturning(_makeRawBytes(100)),
        compress: _compressorReturning(100),
        upload: uploader.call,
      );

      await service.pickAndUpload(storagePath: 'user_photos/$uid.jpg');

      expect(uploader.capturedPath, equals('user_photos/$uid.jpg'));
    });
  });

  // ── Unit test: cancelled picker ───────────────────────────────────────────
  group('PhotoService — cancelled picker', () {
    test('pickAndUpload returns null when user cancels picker', () async {
      final uploader = _CapturingUploader();

      final service = PhotoService(
        pickImage: _pickerReturning(null), // user cancelled
        compress: _compressorReturning(100),
        upload: uploader.call,
      );

      final url =
          await service.pickAndUpload(storagePath: 'item_photos/x.jpg');

      expect(url, isNull);
      // Uploader must NOT have been called.
      expect(uploader.capturedPath, isNull);
    });
  });

  // ── Unit test: compress parameters ────────────────────────────────────────
  group('PhotoService — compression parameters', () {
    test(
        'compress is called with kMaxDimension and kJpegQuality', () async {
      int? capturedMinWidth;
      int? capturedMinHeight;
      int? capturedQuality;

      final service = PhotoService(
        pickImage: _pickerReturning(_makeRawBytes(100)),
        compress: ({
          required Uint8List bytes,
          required int minWidth,
          required int minHeight,
          required int quality,
        }) async {
          capturedMinWidth = minWidth;
          capturedMinHeight = minHeight;
          capturedQuality = quality;
          return Uint8List(50);
        },
        upload: ({required storagePath, required bytes}) async =>
            'https://example.com/photo.jpg',
      );

      await service.pickAndUpload(storagePath: 'item_photos/test.jpg');

      expect(capturedMinWidth, equals(PhotoService.kMaxDimension));
      expect(capturedMinHeight, equals(PhotoService.kMaxDimension));
      expect(capturedQuality, equals(PhotoService.kJpegQuality));
    });

    test('kMaxDimension is 1024 and kJpegQuality is 75', () {
      expect(PhotoService.kMaxDimension, equals(1024));
      expect(PhotoService.kJpegQuality, equals(75));
    });
  });

  // ── Unit test: returned URL is propagated ─────────────────────────────────
  group('PhotoService — URL propagation', () {
    test('pickAndUpload returns the URL from the uploader', () async {
      const expectedUrl =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg';

      final service = PhotoService(
        pickImage: _pickerReturning(_makeRawBytes(100)),
        compress: _compressorReturning(100),
        upload: ({required storagePath, required bytes}) async => expectedUrl,
      );

      final url =
          await service.pickAndUpload(storagePath: 'item_photos/test.jpg');

      expect(url, equals(expectedUrl));
    });
  });
}
