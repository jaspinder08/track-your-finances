import 'package:flutter/material.dart';

/// One tab in the floating nav bar.
class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Pill-shaped bottom bar floating above content, with a large + button
/// in the middle. Two tabs sit on each side of the + button.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  }) : assert(items.length == 4);

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tab(int i) {
      final selected = i == currentIndex;
      final item = items[i];
      return Expanded(
        child: Tooltip(
          message: item.label,
          child: InkResponse(
            onTap: () => onTap(i),
            radius: 32,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: selected ? scheme.primary : scheme.onSurface,
                semanticLabel: item.label,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF26262E) : Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'add',
                    onPressed: onAdd,
                    elevation: 0,
                    shape: const CircleBorder(),
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    tooltip: 'Add transaction',
                    child: const Icon(Icons.add_rounded, size: 32),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
