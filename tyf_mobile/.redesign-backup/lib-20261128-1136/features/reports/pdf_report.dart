import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/money.dart';
import '../transactions/data/entry.dart';
import '../transactions/data/transaction_options.dart';
import 'data/month_report.dart';

/// Builds a one-month PDF report: summary, spending by category,
/// payment methods and every transaction.
Future<List<int>> buildMonthPdf(List<Entry> entries, DateTime month) async {
  // Inter has the ₹ sign; the PDF's built-in fonts don't.
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-400.ttf'),
  );
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-700.ttf'));
  final r = MonthReport.build(entries, month);
  final rows =
      entries
          .where(
            (e) =>
                !e.isDeleted &&
                e.type != EntryType.goal &&
                e.date.year == month.year &&
                e.date.month == month.month,
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  const accent = PdfColor.fromInt(0xFF5B5BD6);
  const muted = PdfColor.fromInt(0xFF6B7280);
  final title = DateFormat('MMMM y').format(month);
  final day = DateFormat('d MMM');

  pw.Widget stat(String label, int paise, PdfColor color) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(right: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.08),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: muted, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${paise < 0 ? '−' : ''}${Money.format(paise.abs())}',
            style: pw.TextStyle(font: bold, fontSize: 15, color: color),
          ),
        ],
      ),
    ),
  );

  pw.Widget table(
    List<String> head,
    List<List<String>> data, {
    Map<int, pw.Alignment>? align,
  }) => pw.TableHelper.fromTextArray(
    headers: head,
    data: data,
    border: null,
    headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: accent),
    cellStyle: const pw.TextStyle(fontSize: 9),
    rowDecoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    ),
    cellAlignments: align ?? {},
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'TYF report – $title',
    author: 'TYF',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TYF · Track Your Finances',
            style: pw.TextStyle(font: bold, color: accent, fontSize: 11),
          ),
          pw.Text(title, style: const pw.TextStyle(color: muted, fontSize: 10)),
        ],
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber} of ${c.pagesCount}',
          style: const pw.TextStyle(color: muted, fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Text(
          'Monthly report',
          style: pw.TextStyle(font: bold, fontSize: 22),
        ),
        pw.Text(title, style: const pw.TextStyle(color: muted, fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            stat('Income', r.income, const PdfColor.fromInt(0xFF16A34A)),
            stat('Spent', r.expense, const PdfColor.fromInt(0xFFDC2626)),
            stat('Saved', r.saved, accent),
          ],
        ),
        if (r.categories.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            'Spending by category',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 6),
          table(
            ['Category', 'Amount', 'Share'],
            [
              for (final s in r.categories)
                [s.name, Money.format(s.paise), '${(s.share * 100).round()}%'],
            ],
            align: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
          ),
        ],
        if (r.paymentMethods.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Payment methods',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 6),
          table(
            ['Method', 'Amount', 'Share'],
            [
              for (final s in r.paymentMethods)
                [s.name, Money.format(s.paise), '${(s.share * 100).round()}%'],
            ],
            align: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text('Transactions', style: pw.TextStyle(font: bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text(
            'No transactions this month.',
            style: const pw.TextStyle(color: muted),
          )
        else
          table(
            ['Date', 'Name', 'Category', 'Method', 'Amount'],
            [
              for (final e in rows)
                [
                  day.format(e.date),
                  e.title,
                  e.type == EntryType.transfer
                      ? '${e.data.fromAccount} → ${e.data.toAccount}'
                      : (e.data.category ?? ''),
                  e.data.paymentMethod ?? '',
                  '${switch (e.type) {
                    EntryType.income => '+',
                    EntryType.expense => '−',
                    _ => '',
                  }}${Money.format(e.amountPaise)}',
                ],
            ],
            align: {4: pw.Alignment.centerRight},
          ),
      ],
    ),
  );
  return doc.save();
}

/// Builds the month's PDF and opens the share sheet (save, email, print).
Future<void> shareMonthPdf(List<Entry> entries, DateTime month) async {
  final bytes = await buildMonthPdf(entries, month);
  final dir = await getTemporaryDirectory();
  final name = 'tyf-report-${DateFormat('yyyy-MM').format(month)}.pdf';
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'TYF report – ${DateFormat('MMMM y').format(month)}',
    ),
  );
}
