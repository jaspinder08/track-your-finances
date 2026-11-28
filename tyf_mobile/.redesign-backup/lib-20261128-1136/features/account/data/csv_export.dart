import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../transactions/data/entry.dart';

/// Builds a CSV of [entries] (oldest first). Pure, so it's easy to test.
String entriesToCsv(List<Entry> entries) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final day = DateFormat('yyyy-MM-dd');
  final rows = [
    [
      'Date',
      'Type',
      'Amount (INR)',
      'Name',
      'Category',
      'Subcategory',
      'Payment method',
      'From',
      'To',
      'Notes',
    ],
    for (final e in [...entries]..sort((a, b) => a.date.compareTo(b.date)))
      [
        day.format(e.date),
        e.type.label,
        (e.amountPaise / 100).toStringAsFixed(2),
        e.data.name,
        e.data.category,
        e.data.subcategory,
        e.data.paymentMethod,
        e.data.fromAccount,
        e.data.toAccount,
        e.data.description,
      ],
  ];
  return rows.map((r) => r.map(cell).join(',')).join('\n');
}

/// Writes the CSV to a temp file and opens the share sheet (save to Files,
/// email, Drive…).
Future<void> shareEntriesCsv(List<Entry> entries) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final file = File('${dir.path}/tyf-export-$stamp.csv');
  await file.writeAsString(entriesToCsv(entries));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'TYF export $stamp'),
  );
}
