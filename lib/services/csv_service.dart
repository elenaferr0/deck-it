import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/deck.dart';

class CsvService {
  /// Export deck cards to CSV using the deck's side labels as header.
  /// Returns saved file path, or null if cancelled.
  static Future<String?> exportDeck(Deck deck) async {
    final buffer = StringBuffer();
    buffer.writeln('${_escapeCsv(deck.side1Label)},${_escapeCsv(deck.side2Label)}');
    for (final card in deck.cards) {
      buffer.write(_escapeCsv(card.question));
      buffer.write(',');
      buffer.writeln(_escapeCsv(card.answer));
    }
    final csvContent = buffer.toString();
    final bytes = Uint8List.fromList(csvContent.codeUnits);
    final fileName = '${deck.name.replaceAll(RegExp(r'[^\w\s\-]'), '_')}.csv';

    // Desktop: show save dialog
    try {
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Export Deck',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );
      if (outputPath != null) {
        // On some platforms saveFile with bytes writes automatically;
        // on others it just returns the path.
        final file = File(outputPath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsString(csvContent);
        }
        return outputPath;
      }
    } catch (_) {
      // Fall through for mobile/unsupported platforms.
    }

    // Mobile fallback: save to documents directory.
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsString(csvContent);
    return path;
  }

  /// Pick a CSV file and parse cards from it.
  /// Returns list of {question, answer} maps, or null if cancelled.
  static Future<List<Map<String, String>>?> importCards() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import Cards from CSV',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    String content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return null;
    }

    return _parseCsv(content);
  }

  static List<Map<String, String>> _parseCsv(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    // Always skip first row (header).
    const int start = 1;

    final cards = <Map<String, String>>[];
    for (int i = start; i < lines.length; i++) {
      final parts = _splitCsvLine(lines[i]);
      if (parts.length >= 2 && parts[0].isNotEmpty) {
        cards.add({'question': parts[0], 'answer': parts[1]});
      }
    }
    return cards;
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
