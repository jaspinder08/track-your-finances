import 'dart:async';

import 'package:flutter/material.dart';
import '../core/design/app_icons.dart';

class Test extends StatelessWidget {
  const Test({super.key});

  @override
  Widget build(BuildContext context) {
    return Column();
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class Me extends StatefulWidget {
  const Me({super.key});

  @override
  State<Me> createState() => _Me();
}

class _Me extends State<Me> {
  @override
  Widget build(BuildContext context) {
    return Column();
  }
}

class EmployeeSearchScreen extends StatefulWidget {
  const EmployeeSearchScreen({super.key});

  @override
  State<EmployeeSearchScreen> createState() => _EmployeeSearchScreenState();
}

class _EmployeeSearchScreenState extends State<EmployeeSearchScreen> {
  Timer? _debounce;

  final TextEditingController _controller = TextEditingController();

  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchEmployees(value);
    });
  }

  void searchEmployees(String query) {
    // Call your API here
    debugPrint('Searching for: $query');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search employees',
            prefixIcon: Icon(AppIcons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
