import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Where a photo came from. Both are always offered: a teacher may be
/// photographing the desk in front of them, or adding a shot taken earlier in
/// the lesson.
enum PhotoSource { camera, gallery }

/// A photo the teacher has chosen. Local only. Nothing here has been uploaded.
class PickedPhoto {
  const PickedPhoto({required this.file, required this.sizeBytes});

  final File file;
  final int sizeBytes;
}

/// Wraps the platform picker so the evidence flow can be tested without a
/// camera or a gallery.
abstract class PhotoPicker {
  Future<PickedPhoto?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Downscaled and re-encoded on the way in. A modern phone camera produces
  /// files well over the 3 MB cap, and a teacher on school wifi should not be
  /// uploading a 12 MP original of a pen stand.
  static const double _maxDimension = 1600;
  static const int _quality = 85;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final picked = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );
    if (picked == null) return null;
    final file = File(picked.path);
    return PickedPhoto(file: file, sizeBytes: await file.length());
  }
}
