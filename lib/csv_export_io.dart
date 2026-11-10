import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

Future<void> savePlatformCsvFile({
  required String csv,
  required String fileName,
  Rect? shareOrigin,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
    ),
  );
}
