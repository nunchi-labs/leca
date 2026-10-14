import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

/// On-device check: both files are real photos, they are not the same file,
/// the typed name matches the name on the card, and the ID number is present.
class Identity {
  static String norm(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static Future<String?> check({
    required String legalName,
    required String nameOnId,
    required String idNumber,
    required Uint8List? selfie,
    required Uint8List? idCard,
  }) async {
    if (selfie == null || idCard == null || selfie.isEmpty || idCard.isEmpty) {
      return 'photo_missing';
    }
    if (_same(selfie, idCard)) return 'photo_same';
    if (!await _decodes(selfie) || !await _decodes(idCard)) {
      return 'photo_invalid';
    }
    if (norm(legalName).isEmpty || norm(legalName) != norm(nameOnId)) {
      return 'name_mismatch';
    }
    final digits = idNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return 'id_invalid';
    return null;
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<bool> _decodes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ok = frame.image.width >= 1 && frame.image.height >= 1;
      frame.image.dispose();
      return ok;
    } catch (_) {
      return false;
    }
  }
}

class PhotoPick {
  static Future<Uint8List?> Function()? override;

  static Future<Uint8List?> image() async {
    final hooked = override;
    if (hooked != null) return hooked();
    const group = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: <String>['image/jpeg', 'image/png', 'image/webp'],
      uniformTypeIdentifiers: <String>[
        'public.jpeg',
        'public.png',
        'public.image',
      ],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;
    return file.readAsBytes();
  }
}
