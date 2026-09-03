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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomePage(controller: widget.controller),
      BatchPage(controller: widget.controller),
      HistoryPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];
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
        child: IndexedStack(index: _selectedIndex, children: pages),
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
