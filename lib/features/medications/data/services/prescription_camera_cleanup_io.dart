import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<void> cleanupCameraCache(String capturedPath) async {
  final temporary = await getTemporaryDirectory();
  final file = File(capturedPath);
  if (!await file.exists()) return;
  final actual = await file.resolveSymbolicLinks();
  final root = await temporary.resolveSymbolicLinks();
  // Only the capture returned by our camera request, inside the private cache.
  if (path.isWithin(root, actual)) await file.delete();
}
