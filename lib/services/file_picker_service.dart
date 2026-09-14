import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilePickerService {
  static const String _keyLastDir = 'tuneworld_last_picked_directory';

  static Future<List<PlatformFile>> pickFiles({
    required FileType type,
    bool allowMultiple = false,
  }) async {
    String? initialDir;
    try {
      final prefs = await SharedPreferences.getInstance();
      initialDir = prefs.getString(_keyLastDir);
      if (initialDir != null && !Directory(initialDir).existsSync()) {
        initialDir = null;
      }
    } catch (_) {}

    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: type,
      allowMultiple: allowMultiple,
      initialDirectory: initialDir,
      withData: true,
    );

    if (files.isNotEmpty) {
      final path = files.first.path;
      if (path != null && path.isNotEmpty) {
        try {
          final parentDir = File(path).parent.path;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyLastDir, parentDir);
        } catch (_) {}
      }
    }

    return files;
  }
}
