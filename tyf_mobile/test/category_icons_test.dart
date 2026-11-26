import 'package:flutter_test/flutter_test.dart';
import 'package:tyf_mobile/core/design/category_icons.dart';
import 'package:tyf_mobile/features/transactions/data/transaction_options.dart';

void main() {
  test('icon codes and old emojis both resolve to icons', () {
    expect(
      CategoryIcons.resolve(CategoryIcons.encode('forkKnife')),
      CategoryIcons.all['forkKnife'],
    );
    expect(CategoryIcons.resolve('🍔'), CategoryIcons.all['forkKnife']);
    expect(CategoryIcons.resolve('🦄'), isNull); // custom emoji stays emoji
    expect(CategoryIcons.resolve(null), isNull);
  });

  test('every default category shows an icon', () {
    for (final c in [...expenseCategories, ...incomeCategories]) {
      expect(CategoryIcons.resolve(c.emoji), isNotNull, reason: c.name);
    }
  });
}
