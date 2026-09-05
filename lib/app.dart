import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/nfc_scan_controller.dart';
import 'presentation/pages/batch_page.dart';
import 'presentation/pages/history_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/settings_page.dart';

class TagVerityApp extends StatelessWidget {
  const TagVerityApp({required this.controller, super.key});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appStoreName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _AppShell(controller: controller),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.controller});
  final NfcScanController controller;
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  Widget _pageFor(int index) => switch (index) {
    0 => HomePage(controller: widget.controller),
    1 => BatchPage(controller: widget.controller),
    2 => HistoryPage(controller: widget.controller),
    _ => SettingsPage(controller: widget.controller),
  };
  @override
  Widget build(BuildContext context) {
    final List<String> titles = <String>[
      AppConstants.appName,
      'Batch scan',
      'History',
      'Settings',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex]), centerTitle: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _GlobalErrorBanner(controller: widget.controller),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _pageFor(_selectedIndex),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) =>
            setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.nfc_rounded),
            label: 'Inspect',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_add_check_rounded),
            label: 'Batch',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _GlobalErrorBanner extends StatelessWidget {
  const _GlobalErrorBanner({required this.controller});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final String? message = controller.errorMessage;
        if (message == null || message.isEmpty) {
          return const SizedBox.shrink();
        }
        final ColorScheme colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss error',
                    onPressed: controller.clearError,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
