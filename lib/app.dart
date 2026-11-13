import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'shell/root_shell.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class LifeOsApp extends StatelessWidget {
  const LifeOsApp({super.key, required this.store});

  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
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
    );
  }
}
