import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../data/models/ai_report.dart';
import '../../data/models/road_photo.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class PdfReportExportService {
  Future<void> exportReport(AiReport report, List<RoadPhoto> photos) async {
    final pdf = pw.Document(
      title: report.title,
      author: 'RoadSense System',
      creator: 'RoadSense PDF Generator',
    );

    // Font setup
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Fetch images beforehand (up to 10 to prevent large PDF)
    final limitedPhotos = photos.take(10).toList();
    final List<pw.Widget> photoWidgets = [];
    
    if (limitedPhotos.isNotEmpty) {
      photoWidgets.add(pw.Header(level: 1, child: pw.Text('Lampiran Foto Dokumentasi', style: pw.TextStyle(font: fontBold))));
    }

    int downloadedCount = 0;
    for (var photo in limitedPhotos) {
      if (photo.signedUrl != null) {
        bool loaded = false;
        try {
          final response = await http.get(Uri.parse(photo.signedUrl!));
          if (response.statusCode == 200) {
            final imageProvider = pw.MemoryImage(response.bodyBytes);
            loaded = true;
            downloadedCount++;
            photoWidgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      height: 240,
                      width: 420,
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Waktu: ${DateFormat('yyyy-MM-dd HH:mm').format(photo.takenAt.toLocal())}', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Text('Tipe Foto: ${photo.photoType}', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Text('Keterangan: ${photo.caption ?? 'Tidak ada'}', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Text('Lokasi: ${photo.latitude != null && photo.longitude != null ? '${photo.latitude}, ${photo.longitude}' : 'Tidak tersedia'}', style: pw.TextStyle(font: font, fontSize: 10)),
                    if (photo.latitude != null && photo.longitude != null && photo.gpsAccuracy != null)
                      pw.Text('Presisi GPS: ±${photo.gpsAccuracy!.toStringAsFixed(1)} m', style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ),
            );
          } else {
             debugPrint('PDF Export - Failed to download image ${photo.id}: Status ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('PDF Export - Exception loading image ${photo.id}: $e');
        }

        if (!loaded) {
          photoWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 120,
                    width: 420,
                    color: PdfColors.grey200,
                    child: pw.Center(child: pw.Text('Foto tidak dapat dimuat', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700))),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Waktu: ${DateFormat('yyyy-MM-dd HH:mm').format(photo.takenAt.toLocal())}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('Tipe Foto: ${photo.photoType}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('Keterangan: ${photo.caption ?? 'Tidak ada'}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('Lokasi: ${photo.latitude != null && photo.longitude != null ? '${photo.latitude}, ${photo.longitude}' : 'Tidak tersedia'}', style: pw.TextStyle(font: font, fontSize: 10)),
                  if (photo.latitude != null && photo.longitude != null && photo.gpsAccuracy != null)
                    pw.Text('Presisi GPS: ±${photo.gpsAccuracy!.toStringAsFixed(1)} m', style: pw.TextStyle(font: font, fontSize: 10)),
                ],
              ),
            ),
          );
        }
      }
    }

    debugPrint('PDF Export - Total photos: ${photos.length}, processing: ${limitedPhotos.length}, successfully embedded: $downloadedCount');

    if (photos.length > 10) {
      photoWidgets.add(pw.Paragraph(text: 'Catatan: Ada ${photos.length - 10} foto tambahan yang tidak dimuat di PDF ini.', style: pw.TextStyle(font: font, fontSize: 10)));
    }

    final cleanedMarkdown = _cleanMarkdownString(report.reportMarkdown);
    final parsedWidgets = _parseMarkdownToWidgets(cleanedMarkdown, font, fontBold);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'RoadSense - Generated automatically | Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan Analisis RoadSense', style: pw.TextStyle(font: fontBold, fontSize: 24)),
            ),
            pw.Paragraph(
              text: 'ID Sesi: ${report.sessionId}\n'
                    'Dibuat: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(report.generatedAt.toLocal())}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.SizedBox(height: 20),
            
            // Parsed Markdown blocks
            ...parsedWidgets,

            pw.SizedBox(height: 30),
            
            // Photos
            ...photoWidgets,
            
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.Paragraph(
              text: 'Disclaimer: Laporan ini dihasilkan secara otomatis oleh sistem AI RoadSense '
                    'berdasarkan data sensor perangkat bergerak. Laporan ini merupakan '
                    'penilaian awal (preliminary assessment) dan tetap memerlukan verifikasi lapangan oleh instansi berwenang.',
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'RoadSense_Report_${report.sessionId.substring(0,8)}.pdf');
  }

  List<pw.Widget> _parseMarkdownToWidgets(String markdown, pw.Font font, pw.Font fontBold) {
    final lines = markdown.split('\n');
    final widgets = <pw.Widget>[];
    
    StringBuffer currentText = StringBuffer();
    List<List<String>> currentTable = [];
    bool inTable = false;

    void flushText() {
      if (currentText.toString().trim().isNotEmpty) {
        widgets.add(pw.Paragraph(text: currentText.toString().trim(), style: pw.TextStyle(font: font, fontSize: 10)));
        currentText.clear();
      }
    }

    void flushTable() {
      if (currentTable.isNotEmpty) {
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            children: currentTable.asMap().entries.map((entry) {
              final isHeader = entry.key == 0;
              final row = entry.value;
              return pw.TableRow(
                decoration: isHeader ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
                children: row.map((cell) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      cell, 
                      style: pw.TextStyle(font: isHeader ? fontBold : font, fontSize: 8),
                      textAlign: pw.TextAlign.left,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
        widgets.add(pw.SizedBox(height: 10));
        currentTable = [];
      }
    }

    for (var line in lines) {
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        flushText();
        inTable = true;
        if (line.contains('---')) continue;
        final cells = line.split('|').map((e) => e.trim()).toList();
        if (cells.length > 2) {
          currentTable.add(cells.sublist(1, cells.length - 1));
        }
      } else {
        if (inTable) {
          inTable = false;
          flushTable();
        }
        
        if (line.startsWith('# ')) {
          flushText();
          widgets.add(pw.SizedBox(height: 12));
          widgets.add(pw.Text(line.substring(2).trim(), style: pw.TextStyle(font: fontBold, fontSize: 16)));
          widgets.add(pw.SizedBox(height: 6));
        } else if (line.startsWith('## ')) {
          flushText();
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.Text(line.substring(3).trim(), style: pw.TextStyle(font: fontBold, fontSize: 14)));
          widgets.add(pw.SizedBox(height: 4));
        } else if (line.startsWith('### ')) {
          flushText();
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Text(line.substring(4).trim(), style: pw.TextStyle(font: fontBold, fontSize: 12)));
          widgets.add(pw.SizedBox(height: 4));
        } else if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
          flushText();
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Expanded(child: pw.Text(line.trim().substring(2).trim(), style: pw.TextStyle(font: font, fontSize: 10))),
              ]
            ),
          ));
        } else if (line.trim().isEmpty) {
          flushText();
          widgets.add(pw.SizedBox(height: 6));
        } else {
          currentText.writeln(line);
        }
      }
    }
    
    flushText();
    if (inTable) flushTable();

    return widgets;
  }

  String _cleanMarkdownString(String text) {
    String cleanText = text.replaceAll('**', '');
    cleanText = cleanText.replaceAll(RegExp(r'\bNot Assessed\b', caseSensitive: false), 'Tidak Dapat Dinilai');
    cleanText = cleanText.replaceAll(RegExp(r'\bnot_assessed\b', caseSensitive: false), 'Tidak Dapat Dinilai');
    cleanText = cleanText.replaceAll(RegExp(r'\bDemo Only\b', caseSensitive: false), 'Data Demo');
    cleanText = cleanText.replaceAll(RegExp(r'\bdemo_only\b', caseSensitive: false), 'Data Demo');
    cleanText = cleanText.replaceAll(RegExp(r'\blimited\b', caseSensitive: false), 'Terbatas');
    
    // Confidence and accuracy mapping
    cleanText = cleanText.replaceAll(RegExp(r'\bConfidence Level\b', caseSensitive: false), 'Tingkat Kepercayaan Data');
    cleanText = cleanText.replaceAll(RegExp(r'Rendah\s+[cC]onfidence', caseSensitive: false), 'Tingkat Kepercayaan Data: Rendah');
    cleanText = cleanText.replaceAll(RegExp(r'\bLow Confidence\b', caseSensitive: false), 'Tingkat Kepercayaan Data: Rendah');
    cleanText = cleanText.replaceAll(RegExp(r'\blow\b', caseSensitive: false), 'Rendah');
    cleanText = cleanText.replaceAll(RegExp(r'\bdemo_data\b', caseSensitive: false), 'Data Demo');
    cleanText = cleanText.replaceAll('GPS Accuracy', 'Presisi GPS');
    
    // Formal wording updates
    cleanText = cleanText.replaceAll('Tidak ada kerusakan terdeteksi', 'Tidak ada event kerusakan jalan valid yang terdeteksi pada sesi ini.');
    cleanText = cleanText.replaceAll('Mengabaikan data ini untuk analisis kerusakan jalan', 'Menandai data ini sebagai data demo dan tidak menggunakannya sebagai dasar operasional.');
    cleanText = cleanText.replaceAll('Mengabaikan data ini untuk pelaporan resmi', 'Menandai data ini sebagai data demo dan tidak menggunakannya sebagai dasar pelaporan operasional.');
    
    // Vibration context at low speed
    cleanText = cleanText.replaceAll(
      RegExp(r'Normal.*?kecepatan rendah.*?', caseSensitive: false), 
      'Getaran tinggi, tetapi tidak valid sebagai event karena kendaraan diam.'
    );

    // Fix inconsistent score 60 for low confidence/demo
    if (cleanText.contains('Data Demo') || cleanText.contains('Rendah')) {
      cleanText = cleanText.replaceAll('| 60 |', '| 40 |');
    }
    
    // Distance formatting (e.g. 0.011 km -> 0.011 km (±11 m))
    // We use (?!\s*\/) to ensure we don't accidentally match "km/h" and turn it into "km (±0 m)/h"
    cleanText = cleanText.replaceAllMapped(RegExp(r'(\d+\.\d+)\s*km(?!\s*\/\s*h)'), (match) {
      double? km = double.tryParse(match.group(1) ?? '');
      if (km != null && km < 1.0) {
        int meters = (km * 1000).round();
        return '${match.group(1)} km (±$meters m)';
      }
      return match.group(0)!;
    });

    return cleanText;
  }
}
