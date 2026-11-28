import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Category icons. A category's `emoji` field holds either an emoji or
/// `ph:<key>` for one of these icons, so nothing changes in storage or
/// sync. Older emojis that have a matching icon are shown as that icon.
abstract final class CategoryIcons {
  static const prefix = 'ph:';

  /// Picker order: daily life first, then money.
  static const all = <String, IconData>{
    'house': PhosphorIconsRegular.house,
    'forkKnife': PhosphorIconsRegular.forkKnife,
    'shoppingCart': PhosphorIconsRegular.shoppingCart,
    'pizza': PhosphorIconsRegular.pizza,
    'coffee': PhosphorIconsRegular.coffee,
    'beerStein': PhosphorIconsRegular.beerStein,
    'car': PhosphorIconsRegular.car,
    'gasPump': PhosphorIconsRegular.gasPump,
    'bus': PhosphorIconsRegular.bus,
    'taxi': PhosphorIconsRegular.taxi,
    'train': PhosphorIconsRegular.train,
    'airplane': PhosphorIconsRegular.airplane,
    'bed': PhosphorIconsRegular.bed,
    'umbrella': PhosphorIconsRegular.umbrellaSimple,
    'filmSlate': PhosphorIconsRegular.filmSlate,
    'gameController': PhosphorIconsRegular.gameController,
    'musicNotes': PhosphorIconsRegular.musicNotes,
    'television': PhosphorIconsRegular.television,
    'soccerBall': PhosphorIconsRegular.soccerBall,
    'confetti': PhosphorIconsRegular.confetti,
    'shoppingBag': PhosphorIconsRegular.shoppingBag,
    'tShirt': PhosphorIconsRegular.tShirt,
    'sneaker': PhosphorIconsRegular.sneaker,
    'sparkle': PhosphorIconsRegular.sparkle,
    'flowerLotus': PhosphorIconsRegular.flowerLotus,
    'scissors': PhosphorIconsRegular.scissors,
    'sprayBottle': PhosphorIconsRegular.sprayBottle,
    'barbell': PhosphorIconsRegular.barbell,
    'pill': PhosphorIconsRegular.pill,
    'stethoscope': PhosphorIconsRegular.stethoscope,
    'hospital': PhosphorIconsRegular.hospital,
    'tooth': PhosphorIconsRegular.tooth,
    'books': PhosphorIconsRegular.books,
    'graduationCap': PhosphorIconsRegular.graduationCap,
    'laptop': PhosphorIconsRegular.laptop,
    'deviceMobile': PhosphorIconsRegular.deviceMobile,
    'receipt': PhosphorIconsRegular.receipt,
    'lightbulb': PhosphorIconsRegular.lightbulb,
    'drop': PhosphorIconsRegular.drop,
    'fire': PhosphorIconsRegular.fire,
    'wifiHigh': PhosphorIconsRegular.wifiHigh,
    'broom': PhosphorIconsRegular.broom,
    'wrench': PhosphorIconsRegular.wrench,
    'pawPrint': PhosphorIconsRegular.pawPrint,
    'baby': PhosphorIconsRegular.baby,
    'pottedPlant': PhosphorIconsRegular.pottedPlant,
    'handsPraying': PhosphorIconsRegular.handsPraying,
    'heart': PhosphorIconsRegular.heart,
    'gift': PhosphorIconsRegular.gift,
    'creditCard': PhosphorIconsRegular.creditCard,
    'bank': PhosphorIconsRegular.bank,
    'trendUp': PhosphorIconsRegular.trendUp,
    'coins': PhosphorIconsRegular.coins,
    'money': PhosphorIconsRegular.money,
    'handCoins': PhosphorIconsRegular.handCoins,
    'piggyBank': PhosphorIconsRegular.piggyBank,
    'briefcase': PhosphorIconsRegular.briefcase,
    'storefront': PhosphorIconsRegular.storefront,
    'buildings': PhosphorIconsRegular.buildings,
    'arrowUUpLeft': PhosphorIconsRegular.arrowUUpLeft,
    'tag': PhosphorIconsRegular.tag,
  };

  /// Emojis used before icons (defaults and the old picker) → icon key.
  static const _fromEmoji = <String, String>{
    '🏠': 'house',
    '🍔': 'forkKnife',
    '🛒': 'shoppingCart',
    '🍕': 'pizza',
    '☕': 'coffee',
    '🍺': 'beerStein',
    '🚗': 'car',
    '⛽': 'gasPump',
    '🚌': 'bus',
    '✈️': 'airplane',
    '🏨': 'bed',
    '🎬': 'filmSlate',
    '🎮': 'gameController',
    '🎵': 'musicNotes',
    '🛍️': 'shoppingBag',
    '👕': 'tShirt',
    '👟': 'sneaker',
    '💄': 'sparkle',
    '💆': 'flowerLotus',
    '💇': 'scissors',
    '🏋️': 'barbell',
    '💊': 'pill',
    '🩺': 'stethoscope',
    '🦷': 'tooth',
    '📚': 'books',
    '🎓': 'graduationCap',
    '💻': 'laptop',
    '📱': 'deviceMobile',
    '🧾': 'receipt',
    '💡': 'lightbulb',
    '💧': 'drop',
    '🔥': 'fire',
    '📶': 'wifiHigh',
    '💳': 'creditCard',
    '🏦': 'bank',
    '📈': 'trendUp',
    '💰': 'coins',
    '💼': 'briefcase',
    '🧑‍💻': 'laptop',
    '🏪': 'storefront',
    '🎁': 'gift',
    '↩️': 'arrowUUpLeft',
    '🐶': 'pawPrint',
    '👶': 'baby',
    '🧹': 'broom',
    '🔧': 'wrench',
    '🌱': 'pottedPlant',
    '🙏': 'handsPraying',
    '🎉': 'confetti',
    '⚽': 'soccerBall',
    '🏖️': 'umbrella',
    '🚕': 'taxi',
    '🚆': 'train',
    '🏥': 'hospital',
    '🧴': 'sprayBottle',
    '🪙': 'coins',
    '🏷️': 'tag',
    '✨': 'sparkle',
    '🏘️': 'buildings',
    '💸': 'money',
  };

  static String encode(String key) => '$prefix$key';

  /// The icon for a stored value (icon code or emoji), or null to show
  /// the value as an emoji.
  static IconData? resolve(String? value) {
    if (value == null) return null;
    final key = value.startsWith(prefix)
        ? value.substring(prefix.length)
        : _fromEmoji[value];
    return key == null ? null : all[key];
  }
}

/// Draws a category's icon (or its emoji if it's a custom one).
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph(this.value, {super.key, this.size = 22, this.color});
  final String? value;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = CategoryIcons.resolve(value);
    if (icon != null) {
      return Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      );
    }
    return Text(
      value ?? '',
      style: TextStyle(fontSize: size * 0.95, height: 1),
    );
  }
}

/// Each category's own colour. The defaults have fixed colours; others
/// get one from the palette by name, so a category looks the same on
/// every screen.
const categoryPalette = [
  Color(0xFF8B7CF6), // violet
  Color(0xFF34C77B), // green
  Color(0xFFF0616D), // red
  Color(0xFFE8A93A), // amber
  Color(0xFF2EC4C4), // teal
  Color(0xFF5B8DEF), // blue
  Color(0xFF3FB56E), // emerald
  Color(0xFFF2557E), // pink
  Color(0xFFA06BF0), // purple
  Color(0xFFEF8A3C), // orange
];

const _fixedColors = {
  'Home': 0,
  'Food': 1,
  'Travel': 2,
  'Entertainment': 3,
  'Shopping': 4,
  'Bills': 5,
  'Investment': 6,
  'Health': 7,
  'Personal': 8,
  'Education': 9,
  'Salary': 1,
  'Freelance': 5,
  'Business': 3,
  'Investments': 6,
  'Rental': 4,
  'Gift': 7,
  'Refund': 0,
  'Other': 9,
};

Color categoryColor(String? name) {
  if (name == null || name.isEmpty) return categoryPalette.first;
  final int i =
      _fixedColors[name] ??
      name.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return categoryPalette[i % categoryPalette.length];
}

/// The one category tile used everywhere: a rounded square in the
/// category's colour with a white icon.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.name,
    required this.glyph,
    this.size = 48,
    this.color,
  });
  final String? name;
  final String? glyph;
  final double size;

  /// Overrides the category colour (e.g. to match a chart slice).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? categoryColor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: 0.95),
            Color.lerp(c, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: CategoryGlyph(glyph, size: size * 0.5, color: Colors.white),
    );
  }
}
