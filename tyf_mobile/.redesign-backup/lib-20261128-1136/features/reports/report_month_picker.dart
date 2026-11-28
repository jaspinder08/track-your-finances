import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/app_icons.dart';
import '../transactions/data/entry_repository.dart';
import 'pdf_report.dart';

/// Lets the user pick a month (last 12), then shares its PDF report.
Future<void> pickAndShareReport(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final months = [
    for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
  ];
  final month = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Report for which month?',
              style: Theme.of(c).textTheme.titleLarge,
            ),
          ),
          for (final m in months)
            ListTile(
              leading: const Icon(AppIcons.filePdf),
              title: Text(DateFormat('MMMM y').format(m)),
              onTap: () => Navigator.pop(c, m),
            ),
        ],
      ),
    ),
  );
  if (month == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Preparing your report…'),
    ),
  );
  await shareMonthPdf(ref.read(entriesProvider).value ?? const [], month);
  messenger.hideCurrentSnackBar();
}
