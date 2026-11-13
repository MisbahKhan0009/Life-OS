import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/focus_engine.dart';
import 'data/money_store.dart';
import 'data/store.dart';
import 'shell/root_shell.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class LifeOsApp extends StatelessWidget {
  const LifeOsApp({super.key, required this.store, required this.money, required this.focus});

  final NoteStore store;
  final MoneyStore money;
  final FocusEngine focus;

  @override
  Widget build(BuildContext context) {
    return FocusEngineScope(
      engine: focus,
      child: MoneyScope(
        store: money,
        child: StoreScope(
          store: store,
          child: Builder(builder: (context) {
            final mode = StoreScope.of(context).themeMode;
            return MaterialApp(
              title: 'Life OS',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: AppTheme.build(AppColors.light),
              darkTheme: AppTheme.build(AppColors.dark),
              builder: (context, child) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
                  child: child!,
                );
              },
              home: const RootShell(),
            );
          }),
        ),
      ),
    );
  }
}
