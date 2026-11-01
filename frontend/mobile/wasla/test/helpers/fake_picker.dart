import 'dart:convert';
import 'dart:io';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// A 1x1 PNG, so Image.file can decode what the fake camera "took".
final tinyPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

/// Stands in for the camera and gallery: every pick returns a fresh real file
/// and is recorded with its source. Install with [FakeImagePicker.install].
class FakeImagePicker extends ImagePickerPlatform {
  final picks = <ImageSource>[];
  final preferredCameras = <CameraDevice>[];
  int _n = 0;

  /// Makes this the picker for the rest of the test file.
  static FakeImagePicker install() {
    final fake = FakeImagePicker();
    ImagePickerPlatform.instance = fake;
    return fake;
  }

  XFile _file() {
    final file = File('${Directory.systemTemp.createTempSync('wasla_pick').path}/photo${_n++}.png')
      ..writeAsBytesSync(tinyPng);
    return XFile(file.path);
  }

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    picks.add(source);
    preferredCameras.add(options.preferredCameraDevice);
    return _file();
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async {
    picks.add(ImageSource.gallery);
    return [_file(), _file()];
  }
}
