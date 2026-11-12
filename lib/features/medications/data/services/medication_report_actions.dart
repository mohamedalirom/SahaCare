import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../../domain/entities/medication_report.dart';
import 'report_file_platform.dart';

enum ReportShareOutcome { dialogCompleted, dismissed, unavailable }

class MedicationReportActions {
  Future<String> save(MedicationReportArtifact artifact) {
    artifact.assertCurrent();
    return saveReportFile(
      artifact.bytes,
      artifact.filename,
      check: artifact.assertCurrent,
    );
  }

  Future<ReportShareOutcome> share(
    MedicationReportArtifact artifact, {
    required Rect origin,
  }) async {
    artifact.assertCurrent();
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            artifact.bytes,
            mimeType: 'application/pdf',
            name: artifact.filename,
          ),
        ],
        fileNameOverrides: [artifact.filename],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
      ),
    );
    artifact.assertCurrent();
    return switch (result.status) {
      ShareResultStatus.success => ReportShareOutcome.dialogCompleted,
      ShareResultStatus.dismissed => ReportShareOutcome.dismissed,
      ShareResultStatus.unavailable => ReportShareOutcome.unavailable,
    };
  }
}
