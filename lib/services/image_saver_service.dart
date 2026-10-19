import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageSaverService {
  static Future<String> saveImage({
    required Uint8List bytes,
    required String workflowName,
    String? promptId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedWorkflow = workflowName
        .replaceAll('.json', '')
        .replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'ComfyUI_${sanitizedWorkflow}_$timestamp.png';

    // 1. Save locally to app documents directory for app access and history
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'comfyui_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final localFile = File(p.join(imagesDir.path, filename));
    await localFile.writeAsBytes(bytes);

    // 2. Save to phone shared image gallery (Android / iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(localFile.path, album: 'ComfyUI');
      } catch (e) {
        debugPrint('Gal save to shared gallery failed or permission denied: $e');
      }
    } else if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      // Desktop fallback: Save to user's Pictures/ComfyUI folder if possible
      try {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          final picturesDir = Directory(p.join(home, 'Pictures', 'ComfyUI'));
          if (!await picturesDir.exists()) {
            await picturesDir.create(recursive: true);
          }
          final sharedFile = File(p.join(picturesDir.path, filename));
          await sharedFile.writeAsBytes(bytes);
        }
      } catch (e) {
        debugPrint('Desktop shared save failed: $e');
      }
    }

    return localFile.path;
  }
}
