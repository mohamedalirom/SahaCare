import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/database/database_helper.dart';
import '../domain/entities/medical_history.dart';
import '../domain/entities/user_profile.dart';

/// Service responsible for gathering medical data strictly from local SQLite
/// and generating a beautifully formatted PDF record to share via native share sheet.
class PdfExportService {
  PdfExportService._();

  /// Queries the local SQLite database for the user's vitals, diseases, allergies, and history,
  /// generates the PDF document, and triggers the native OS share sheet.
  static Future<void> exportAndShareMedicalRecord({
    BuildContext? context,
    Rect? sharePositionOrigin,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Identify active user ID (or fallback to first locally cached profile)
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id ?? '';

    List<Map<String, dynamic>> profileMaps = [];
    if (currentUserId.isNotEmpty) {
      profileMaps = await db.query(
        'profiles',
        where: 'id = ?',
        whereArgs: [currentUserId],
        limit: 1,
      );
    }
    if (profileMaps.isEmpty) {
      profileMaps = await db.query('profiles', limit: 1);
    }

    UserProfile? profile;
    String targetId = currentUserId;
    if (profileMaps.isNotEmpty) {
      final map = profileMaps.first;
      targetId = map['id'] as String? ?? currentUserId;
      final email = map['email'] as String? ?? currentUser?.email ?? '';
      profile = UserProfile.fromMap(map, email: email);
    }

    // 2. Query medical history, allergies, and diseases strictly from local SQLite
    final diseaseRows = await db.query(
      'diseases',
      where: 'profile_id = ?',
      whereArgs: [targetId],
      orderBy: 'updated_at DESC',
    );
    final allergyRows = await db.query(
      'allergies',
      where: 'profile_id = ?',
      whereArgs: [targetId],
      orderBy: 'updated_at DESC',
    );
    final historyRows = await db.query(
      'medical_history',
      where: 'profile_id = ?',
      whereArgs: [targetId],
      orderBy: 'updated_at DESC',
    );

    final diseases = diseaseRows.map(Disease.fromMap).toList();
    final allergies = allergyRows.map(Allergy.fromMap).toList();
    final historyEntries = historyRows.map(MedicalHistoryEntry.fromMap).toList();

    // 3. Build the PDF document
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final nowFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#00897B');
    final darkTextColor = PdfColor.fromHex('#1E293B');
    final mutedTextColor = PdfColor.fromHex('#64748B');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final borderColor = PdfColor.fromHex('#E2E8F0');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SahaCare',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Dossier Médical Personnel',
                      style: pw.TextStyle(
                        color: mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Généré le: $nowFormatted',
                      style: pw.TextStyle(color: mutedTextColor, fontSize: 10),
                    ),
                    pw.Text(
                      'Export confidentiel',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SahaCare Mobile · Données personnelles confidentielles protégées',
                  style: pw.TextStyle(color: mutedTextColor, fontSize: 8),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} sur ${ctx.pagesCount}',
                  style: pw.TextStyle(color: mutedTextColor, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          final patientName = (profile?.fullName.isNotEmpty ?? false)
              ? profile!.fullName
              : (profile?.email.isNotEmpty ?? false ? profile!.email : 'Patient');

          return [
            pw.SizedBox(height: 16),

            // Patient Identity Card
            pw.Container(
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderColor),
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    patientName,
                    style: pw.TextStyle(
                      color: darkTextColor,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (profile?.email.isNotEmpty ?? false) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      profile!.email,
                      style: pw.TextStyle(color: mutedTextColor, fontSize: 11),
                    ),
                  ],
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      _buildInfoItem('Date de naissance', profile?.dateOfBirth != null ? dateFormat.format(profile!.dateOfBirth!) : 'Non renseignée', darkTextColor, mutedTextColor),
                      _buildInfoItem('Âge', profile?.age != null ? '${profile!.age} ans' : 'Non renseigné', darkTextColor, mutedTextColor),
                      _buildInfoItem('Sexe biologique', profile?.sex?.label ?? 'Non renseigné', darkTextColor, mutedTextColor),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Section 1: Signes Vitaux (Vitals)
            _buildSectionHeader('Signes Vitaux & Données Physiologiques', primaryColor),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Table(
                border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: borderColor, width: 0.5)),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableHeaderCell('Groupe Sanguin'),
                      _buildTableHeaderCell('Taille'),
                      _buildTableHeaderCell('Poids'),
                      _buildTableHeaderCell('IMC (Catégorie)'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell(profile?.bloodType ?? 'Non renseigné'),
                      _buildTableCell(profile?.heightCm != null ? '${profile!.heightCm!.toStringAsFixed(0)} cm' : 'Non renseignée'),
                      _buildTableCell(profile?.weightKg != null ? '${profile!.weightKg!.toStringAsFixed(1)} kg' : 'Non renseigné'),
                      _buildTableCell(
                        profile?.bmi != null
                            ? '${profile!.bmi!.toStringAsFixed(1)} (${profile.bmiCategory?.label ?? ""})'
                            : 'Non calculé',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // Habitudes de vie
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Row(
                children: [
                  _buildInfoItem('Tabac', profile?.smoking?.label ?? 'Non renseigné', darkTextColor, mutedTextColor),
                  _buildInfoItem('Alcool', profile?.alcohol?.label ?? 'Non renseigné', darkTextColor, mutedTextColor),
                  _buildInfoItem('Activité physique', profile?.activity?.label ?? 'Non renseignée', darkTextColor, mutedTextColor),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Section 2: Maladies (Diseases)
            _buildSectionHeader('Maladies & Diagnostics (${diseases.length})', primaryColor),
            pw.SizedBox(height: 8),
            if (diseases.isEmpty)
              _buildEmptyPlaceholder('Aucune maladie enregistrée dans le dossier.')
            else
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: borderColor, width: 0.5)),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBg),
                      children: [
                        _buildTableHeaderCell('Pathologie / Maladie'),
                        _buildTableHeaderCell('Date du diagnostic'),
                        _buildTableHeaderCell('Statut'),
                      ],
                    ),
                    ...diseases.map(
                      (d) => pw.TableRow(
                        children: [
                          _buildTableCell(d.name, isBold: true),
                          _buildTableCell(d.diagnosedAt != null ? dateFormat.format(d.diagnosedAt!) : 'Date non spécifiée'),
                          _buildTableCell(d.isChronic ? 'Chronique' : 'Ponctuelle'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            pw.SizedBox(height: 24),

            // Section 3: Allergies
            _buildSectionHeader('Allergies Déclarées (${allergies.length})', primaryColor),
            pw.SizedBox(height: 8),
            if (allergies.isEmpty)
              _buildEmptyPlaceholder('Aucune allergie enregistrée dans le dossier.')
            else
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: borderColor, width: 0.5)),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBg),
                      children: [
                        _buildTableHeaderCell('Allergène'),
                        _buildTableHeaderCell('Catégorie'),
                        _buildTableHeaderCell('Sévérité'),
                      ],
                    ),
                    ...allergies.map(
                      (a) => pw.TableRow(
                        children: [
                          _buildTableCell(a.name, isBold: true),
                          _buildTableCell(a.kind.label),
                          _buildTableCell(a.severity.label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            pw.SizedBox(height: 24),

            // Section 4: Antécédents Médicaux (Medical History)
            _buildSectionHeader('Antécédents Médicaux & Chirurgicaux (${historyEntries.length})', primaryColor),
            pw.SizedBox(height: 8),
            if (historyEntries.isEmpty)
              _buildEmptyPlaceholder('Aucun antécédent médical enregistré.')
            else
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: borderColor, width: 0.5)),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBg),
                      children: [
                        _buildTableHeaderCell('Événement / Intervention'),
                        _buildTableHeaderCell('Date'),
                        _buildTableHeaderCell('Description & Détails'),
                      ],
                    ),
                    ...historyEntries.map(
                      (h) => pw.TableRow(
                        children: [
                          _buildTableCell(h.title, isBold: true),
                          _buildTableCell(h.date != null ? dateFormat.format(h.date!) : 'Non spécifiée'),
                          _buildTableCell(h.description.isNotEmpty ? h.description : '—'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    );

    // 4. Save to temporary directory and share via native OS share sheet
    final outputDir = await getTemporaryDirectory();
    final fileName = 'dossier_medical_sahacare_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: 'Dossier_Medical_SahaCare.pdf')],
        subject: 'Dossier Médical SahaCare',
        text: 'Exportation de mon dossier médical personnel SahaCare.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  // --- PDF Styling Helpers ---

  static pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoItem(String label, String value, PdfColor dark, PdfColor muted) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(color: dark, fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#475569'),
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#1E293B'),
          fontSize: 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildEmptyPlaceholder(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#94A3B8'),
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }
}
