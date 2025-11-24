import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:photos/models/file/file.dart';
import 'package:photos/utils/file_util.dart';

class GalleryEditService {
  static const MethodChannel _channel = MethodChannel('ente_gallery_channel');
  static final _logger = Logger('GalleryEditService');

  /// Opens the external app for viewing a specific photo
  ///
  /// [file] - The photo file to open
  /// Returns true if successful, false otherwise
  static Future<bool> openGalleryAppForEdit(EnteFile file) async {
    try {
      // Get the local file path
      final ioFile = await getFile(file);
      if (ioFile == null) {
        return false;
      }

      final photoPath = ioFile.absolute.path;

      // Call the native method channel
      final result =
          await _channel.invokeMethod<bool>('openGalleryAppForEdit', {
        'photoPath': photoPath,
      });

      return result ?? false;
    } catch (e, stackTrace) {
      _logger.severe('Failed to open external app', e, stackTrace);
      return false;
    }
  }
}
