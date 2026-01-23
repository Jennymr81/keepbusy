import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  FileUtils._();

  // CSV helpers
  static String csvEscape(String? value) {
    final s = (value ?? '');
    final needsQuotes =
        s.contains(',') || s.contains('\n') || s.contains('\r') || s.contains('"');
    final escaped = s.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static String csvLine(List<String?> cols) => cols.map(csvEscape).join(',');

  static String buildCsv({
    required List<String> header,
    required List<List<String?>> rows,
  }) {
    final b = StringBuffer();
    b.writeln(csvLine(header));
    for (final r in rows) {
      b.writeln(csvLine(r));
    }
    return b.toString();
  }

  // Downloads folder selection
  static Future<Directory> downloadsDir() async {
    if (kIsWeb) throw UnsupportedError('No file system on web.');

    // Desktop: Downloads
    try {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    } catch (_) {}

    // Android common path
    if (Platform.isAndroid) {
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (androidDownload.existsSync()) return androidDownload;

      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }

    // iOS & fallback
    return getApplicationDocumentsDirectory();
  }

  // Write text file to Downloads
  static Future<File> writeTextToDownloads({
    required String fileName,
    required String contents,
    Encoding encoding = utf8,
  }) async {
    final dir = await downloadsDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(contents, encoding: encoding);
  }
}
