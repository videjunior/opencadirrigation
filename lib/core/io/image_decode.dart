/// Decoding of pictures with the errors the app knows: the image package
/// throws its own [img.ImageException] for pictures beyond its pixel limit
/// (268 million) and for damaged data; here they become
/// `FormatException('image_too_large')` and
/// `FormatException('image_unreadable')`, which the import and export
/// messages translate.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The app's code for an [img.ImageException].
FormatException imageError(img.ImageException e) => FormatException(e.message.contains('exceed') ? 'image_too_large' : 'image_unreadable');

T _guard<T>(T Function() f) {
  try {
    return f();
  } on img.ImageException catch (e) {
    throw imageError(e);
  }
}

/// [img.decodeImage] (any format), with the app's errors.
img.Image? decodeImageSafe(Uint8List bytes, {int? frame}) => _guard(() => img.decodeImage(bytes, frame: frame));

/// [img.decodeTiff], with the app's errors.
img.Image? decodeTiffSafe(Uint8List bytes) => _guard(() => img.decodeTiff(bytes));

/// [img.decodeJpg], with the app's errors.
img.Image? decodeJpgSafe(Uint8List bytes) => _guard(() => img.decodeJpg(bytes));

/// [img.decodePng], with the app's errors.
img.Image? decodePngSafe(Uint8List bytes) => _guard(() => img.decodePng(bytes));

/// Width and height a picture declares (its header only), with the app's
/// errors; null when no decoder knows the data.
img.DecodeInfo? pictureInfo(Uint8List bytes) => _guard(() => img.findDecoderForData(bytes)?.startDecode(bytes));
