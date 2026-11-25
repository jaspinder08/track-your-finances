import 'package:flutter/foundation.dart';

import 'transaction_options.dart';

/// What the add sheet hands back when the user taps Add.
class EntryDraft {
  EntryDraft({
    required this.type,
    required this.amountPaise,
    required this.date,
    this.name,
    this.description,
    this.category,
    this.subcategory,
    this.paymentMethod,
    this.fromAccount,
    this.toAccount,
    this.savedSoFarPaise,
    this.repeat,
  });

  final EntryType type;
  final int amountPaise;
  final DateTime date;
  final String? name;
  final String? description;
  final String? category;
  final String? subcategory;
  final String? paymentMethod;
  final String? fromAccount;
  final String? toAccount;
  final int? savedSoFarPaise;

  /// Set when the entry repeats, e.g. rent every 1 month.
  final Repeat? repeat;

  /// Same draft with a new saved amount (used by goal contributions).
  EntryDraft withSaved(int savedPaise) => EntryDraft(
    type: type,
    amountPaise: amountPaise,
    date: date,
    name: name,
    description: description,
    category: category,
    subcategory: subcategory,
    paymentMethod: paymentMethod,
    fromAccount: fromAccount,
    toAccount: toAccount,
    savedSoFarPaise: savedPaise,
    repeat: repeat,
  );
}

enum RepeatUnit {
  day('Day', 'Days'),
  week('Week', 'Weeks'),
  month('Month', 'Months'),
  year('Year', 'Years');

  const RepeatUnit(this.one, this.many);
  final String one;
  final String many;
}

@immutable
class Repeat {
  const Repeat({required this.every, required this.unit});
  final int every;
  final RepeatUnit unit;
}

/// An entry saved in SQLite: the draft plus its id and timestamps.
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.seriesId,
    this.isDeleted = false,
  });

  final String id;
  final EntryDraft data;

  /// For an auto-created copy of a recurring entry: the original's id.
  final String? seriesId;
  final bool isDeleted;

  /// The original of a recurring series (copies don't repeat themselves).
  bool get isSeriesRoot => data.repeat != null && seriesId == null;
  final DateTime createdAt;
  final DateTime updatedAt;

  EntryType get type => data.type;
  int get amountPaise => data.amountPaise;
  DateTime get date => data.date;

  /// Signed effect on the balance: income +, expense −, others 0.
  int get balanceEffect => switch (type) {
    EntryType.income => amountPaise,
    EntryType.expense => -amountPaise,
    EntryType.transfer || EntryType.goal => 0,
  };

  /// Line shown in lists: name, else category, else transfer route.
  String get title =>
      data.name ??
      data.category ??
      (type == EntryType.transfer
          ? '${data.fromAccount} → ${data.toAccount}'
          : type.label);
}
