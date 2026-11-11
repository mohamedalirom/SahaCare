import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/medication_report.dart';
import '../../domain/services/medication_adherence.dart';

class MedicationReportPdf {
  MedicationReportPdf({AssetBundle? assets}) : assets = assets ?? rootBundle;
  final AssetBundle assets;
  static final teal = PdfColor.fromHex('#0D9488');
  static final ink = PdfColor.fromHex('#153D42');
  static final muted = PdfColor.fromHex('#64748B');
  static final light = PdfColor.fromHex('#EEF8F6');
  String _date(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date.toLocal());
  String _time(DateTime date) =>
      DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  String _rate(double? rate) => rate == null
      ? 'Non calculable'
      : '${rate.toStringAsFixed(1).replaceAll('.', ',')} %';
  String _text(String? text) =>
      text == null || text.trim().isEmpty ? 'Non renseigné' : text;

  Future<Uint8List> build(MedicationReportData data) async {
    final regular = pw.Font.ttf(await assets.load('assets/fonts/Vera.ttf'));
    final bold = pw.Font.ttf(await assets.load('assets/fonts/VeraBd.ttf'));
    final document = pw.Document(
      title: 'Rapport de suivi des traitements',
      author: 'SahaCare',
      creator: 'SahaCare - génération locale',
      compress: true,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 200,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          margin: const pw.EdgeInsets.only(bottom: 18),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: teal, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SahaCare',
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: teal,
                ),
              ),
              pw.Text(
                'SUIVI DES TRAITEMENTS',
                style: pw.TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                MedicationReportData.footer,
                style: pw.TextStyle(fontSize: 7, color: muted, lineSpacing: 2),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Document local - identité non renseignée',
                    style: pw.TextStyle(fontSize: 7, color: muted),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 8, color: ink),
                  ),
                ],
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 30),
          pw.Text(
            'Rapport de suivi\ndes traitements',
            style: pw.TextStyle(
              fontSize: 29,
              fontWeight: pw.FontWeight.bold,
              color: ink,
              lineSpacing: 6,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            'Une synthèse claire des informations enregistrées',
            style: pw.TextStyle(fontSize: 12, color: muted),
          ),
          pw.SizedBox(height: 28),
          _box(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('PÉRIODE SÉLECTIONNÉE'),
                pw.SizedBox(height: 7),
                pw.Text(
                  '${_date(data.options.from)} au ${_date(data.options.through)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Généré le ${_time(data.generatedAt)} - heure locale',
                  style: pw.TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              pw.Expanded(
                child: _metric(
                  'TRAITEMENTS RETENUS',
                  '${data.treatments.length}',
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _metric(
                  'PRISES ENREGISTRÉES',
                  '${data.adherence.entries.length}',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          _box(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Confidentialité et identité',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  MedicationReportData.privacyNotice,
                  style: pw.TextStyle(fontSize: 10, color: ink, lineSpacing: 3),
                ),
              ],
            ),
            background: PdfColor.fromHex('#FFF4E5'),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Contenu : traitements${data.options.includeAdherence ? ' - observance' : ''}${data.options.includeHistory ? ' - historique des prises' : ''}${data.options.includeSymptoms ? ' - disponibilité des symptômes' : ''}.',
            style: pw.TextStyle(fontSize: 10, color: muted, lineSpacing: 3),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Aucun diagnostic, conseil thérapeutique ou nom de patient n’est ajouté automatiquement.',
            style: pw.TextStyle(fontSize: 9, color: muted, lineSpacing: 3),
          ),
          pw.NewPage(),
          _section('01', 'Traitements'),
          if (data.treatments.isEmpty)
            _paragraph(
              'Aucun traitement enregistré correspondant aux critères sélectionnés.',
            ),
          for (final treatment in data.treatments) ...[
            pw.NewPage(freeSpace: 180),
            pw.SizedBox(height: 10),
            pw.Text(
              treatment.medication.name,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 8),
            _table(
              ['Information', 'Valeur'],
              [
                [
                  'Substance active',
                  _text(treatment.medication.activeIngredient),
                ],
                [
                  'Présentation',
                  _text(treatment.medication.commercialPresentation),
                ],
                ['Dosage déclaré', _text(treatment.medication.dosage)],
                [
                  'Horaires',
                  (treatment.medication.scheduleTimes.isEmpty
                          ? [treatment.medication.time]
                          : treatment.medication.scheduleTimes)
                      .join(' / '),
                ],
                [
                  'Jours de prise',
                  _weekdays(treatment.medication.weekdaysMask),
                ],
                ['Début', _date(treatment.medication.startDate)],
                [
                  'Fin',
                  treatment.medication.endDate == null
                      ? 'Sans date de fin'
                      : _date(treatment.medication.endDate!),
                ],
                [
                  'Statut',
                  treatment.archivedAt != null
                      ? 'Archivé le ${_date(treatment.archivedAt!)}'
                      : treatment.completedAt(data.generatedAt)
                      ? 'Terminé'
                      : treatment.medication.startDate.isAfter(data.generatedAt)
                      ? 'À venir'
                      : 'Actif',
                ],
              ],
              widths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(2.8),
              },
            ),
            pw.SizedBox(height: 14),
          ],
          if (data.options.includeAdherence) ...[
            pw.NewPage(freeSpace: 180),
            _section('02', 'Observance'),
            _box(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _label('TAUX D’OBSERVANCE'),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _rate(data.adherence.percentage),
                    style: pw.TextStyle(
                      fontSize: 27,
                      fontWeight: pw.FontWeight.bold,
                      color: teal,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${data.adherence.confirmed} prise(s) confirmée(s) / ${data.adherence.denominator} prise(s) échue(s) enregistrée(s).',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            _table(
              ['Statut', 'Nombre'],
              [
                for (final status in AdherenceStatus.values)
                  [status.label, '${data.adherence.count(status)}'],
              ],
              widths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
              },
            ),
            pw.SizedBox(height: 10),
            _paragraph(
              'Le dénominateur inclut uniquement les prises dont l’horaire effectif est échu. Les futures sont exclues, même confirmées en avance. Un report remplace l’horaire initial et ne compte qu’une fois. En attente : moins de 60 min aujourd’hui. En retard : au moins 60 min aujourd’hui, sans confirmation. Manquée : date locale passée sans confirmation. Un report échu reste reporté.',
            ),
            _paragraph(
              'Les jours sans ligne SQLite et les prises précédemment supprimées ne sont pas reconstitués. Un taux non calculable n’est ni 0 % ni 100 %. Le document décrit des déclarations enregistrées, pas la réalité physique des prises.',
            ),
            if (data.adherence.medications.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _table(
                ['Médicament', 'Confirmées / échues', 'Taux'],
                [
                  for (final m in data.adherence.medications)
                    [
                      m.name,
                      '${m.confirmed} / ${m.denominator}',
                      _rate(m.percentage),
                    ],
                ],
              ),
            ],
          ],
          if (data.options.includeHistory) ...[
            pw.NewPage(freeSpace: 240),
            _section('03', 'Historique des prises'),
            _paragraph(
              'Classement du plus récent au plus ancien selon l’horaire effectif. L’heure de confirmation est déclarative ; elle n’est pas une mesure de l’ingestion. Une confirmation tardive reste comptée une seule fois.',
            ),
            if (data.adherence.entries.isEmpty)
              _paragraph('Aucune prise enregistrée pour cette période.'),
            if (data.adherence.entries.isNotEmpty)
              _table(
                ['Médicament', 'Prévue / reportée', 'Confirmation', 'Statut'],
                [
                  for (final e in data.adherence.entries)
                    [
                      e.record.occurrence.medicationName,
                      '${_time(e.record.plannedAt)}${e.record.occurrence.rescheduledDate == null ? '' : '\nReport : ${_time(e.record.effectiveAt)}'}',
                      e.record.occurrence.confirmedAt == null
                          ? 'Non renseignée'
                          : _time(e.record.occurrence.confirmedAt!),
                      '${e.status.label}${e.confirmedLate ? '\nConfirmation tardive' : ''}${e.postponedOverdue ? '\nReport échu' : ''}',
                    ],
                ],
                widths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.1),
                },
                small: true,
              ),
          ],
          if (data.options.includeSymptoms) ...[
            pw.NewPage(freeSpace: 120),
            _section('04', 'Symptômes disponibles'),
            _paragraph(MedicationReportData.symptomsNotice),
          ],
          pw.SizedBox(height: 16),
          _paragraph(
            'Conservez ce document dans un endroit sûr. Le partage n’est déclenché que par votre action explicite dans l’application.',
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _label(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: .7,
      color: teal,
    ),
  );
  pw.Widget _box(pw.Widget child, {PdfColor? background}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: background ?? light,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: child,
  );
  pw.Widget _metric(String title, String value) => _box(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(title),
        pw.SizedBox(height: 8),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 25,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
      ],
    ),
  );
  pw.Widget _section(String index, String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 12),
    child: pw.Row(
      children: [
        pw.Text(
          index,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: teal,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
  pw.Widget _paragraph(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, color: muted, lineSpacing: 3),
    ),
  );
  pw.Widget _table(
    List<String> headers,
    List<List<String>> data, {
    Map<int, pw.TableColumnWidth>? widths,
    bool small = false,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    columnWidths: widths,
    cellAlignment: pw.Alignment.centerLeft,
    headerDecoration: pw.BoxDecoration(color: teal),
    headerStyle: pw.TextStyle(
      fontSize: small ? 8 : 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    cellStyle: pw.TextStyle(fontSize: small ? 8 : 9, color: ink),
    cellPadding: const pw.EdgeInsets.all(8),
    oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3F8F8')),
    border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
  );
  String _weekdays(int mask) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final days = [
      for (var i = 0; i < 7; i++)
        if (mask & (1 << i) != 0) labels[i],
    ];
    return days.isEmpty ? 'Aucun jour renseigné' : days.join(' / ');
  }
}
