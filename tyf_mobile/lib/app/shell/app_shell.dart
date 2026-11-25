import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/motion.dart';

import '../../features/budgets/screens/budgets_screen.dart';
import '../../features/budgets/widgets/budget_sheet.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/categories/widgets/category_editor_sheet.dart';
import '../../features/budgets/data/budget_repository.dart';
import '../../features/onboarding/setup_sheet.dart';
import '../../features/sync/sync_controller.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/transactions/data/entry_repository.dart';
import '../../features/transactions/screens/add_transaction_sheet.dart';
import 'app_drawer.dart';
import 'floating_nav_bar.dart';
import 'top_bar.dart';

/// The main frame of the app: top bar, the current tab, floating nav bar.
/// Tabs live in an IndexedStack so each keeps its scroll position.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  final _visits = [1, 0, 0, 0];

  /// Fades and lifts the tab in when you switch to it.
  late final _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visits[i]++;
    });
    _switch.forward(from: 0);
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  static const _items = [
    NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
    NavItem(
      Icons.pie_chart_outline_rounded,
      Icons.pie_chart_rounded,
      'Budgets',
    ),
    NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
    NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Reports'),
  ];

  static const _pages = [
    CalendarScreen(),
    BudgetsScreen(),
    CategoriesScreen(),
    ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // After a sign-in from the daily/locked screen, the shell is built
    // fresh with the request already pending.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSetup());
  }

  /// Shows the setup sheet only for an account with nothing in it yet:
  /// first bring down what the account already has (e.g. a new phone).
  Future<void> _maybeShowSetup() async {
    if (!mounted || !ref.read(setupPromptProvider)) return;
    ref.read(setupPromptProvider.notifier).consume();
    await ref.read(syncProvider.notifier).syncNow();
    if (!mounted) return;
    final entries = await ref.read(entriesProvider.future);
    final budgets = await ref.read(budgetsProvider.future);
    if (!mounted || entries.isNotEmpty || budgets.isNotEmpty) return;
    showSetupSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    // After a sign-in from the sidebar, the shell is already on screen.
    ref.listen(setupPromptProvider, (_, pending) {
      if (pending) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSetup());
      }
    });
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      extendBody: true, // content scrolls behind the floating nav bar
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TopBar(
              balancePaise: ref.watch(balanceProvider),
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onReports: () => _go(3),
            ),
            Expanded(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _switch,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position:
                      Tween(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _switch,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        TabVisit(visits: _visits[i], child: _pages[i]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        items: _items,
        currentIndex: _index,
        onTap: _go,
        // + matches the tab: Budgets sets a budget, others add an entry.
        onAdd: () {
          if (_index == 1) {
            showBudgetSheet(context);
          } else if (_index == 2) {
            showCategoryEditor(
              context,
              kind: ref.read(categoryKindViewProvider),
            );
          } else {
            showAddTransactionSheet(context);
          }
        },
      ),
    );
  }
}
