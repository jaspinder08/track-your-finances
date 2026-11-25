import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/budgets/screens/budgets_screen.dart';
import '../../features/budgets/widgets/budget_sheet.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/categories/widgets/category_editor_sheet.dart';
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

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

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
  Widget build(BuildContext context) {
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
              onReports: () => setState(() => _index = 3),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
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
