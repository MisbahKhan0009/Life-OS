import 'package:flutter/material.dart';

import 'app.dart';
import 'data/focus_engine.dart';
import 'data/focus_store.dart';
import 'data/money_store.dart';
import 'data/store.dart';
import 'features/focus/focus_audio.dart';
import 'features/focus/focus_sheets.dart';
import 'ui/grain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await NoteStore.open();
  final money = await MoneyStore.open();
  final focus = FocusEngine(await FocusStore.open())..attach();
  focusAudio = FocusAudio(focus);
  GrainTexture.load();
  runApp(LifeOsApp(store: store, money: money, focus: focus));
}
