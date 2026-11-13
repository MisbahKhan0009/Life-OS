import 'package:flutter/material.dart';

import 'app.dart';
import 'data/focus_engine.dart';
import 'data/focus_store.dart';
import 'data/money_store.dart';
import 'data/share_inbox.dart';
import 'data/store.dart';
import 'features/focus/focus_audio.dart';
import 'features/focus/focus_music.dart';
import 'features/focus/focus_sheets.dart';
import 'features/share/share_app.dart';
import 'ui/grain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await NoteStore.open();
  final money = await MoneyStore.open();
  final focus = FocusEngine(await FocusStore.open())..attach();
  focusAudio = FocusAudio(focus);
  focusMusic = FocusMusic(focus)..attach();
  shareInbox = await ShareInbox.open();
  final inbox = shareInbox;
  if (inbox != null) {
    inbox.writeFolders(store.folders);
    store.addListener(() => inbox.writeFolders(store.folders));
  }
  GrainTexture.load();
  runApp(LifeOsApp(store: store, money: money, focus: focus));
}

/// Entry point for the "Save to Life OS" share popup (started by ShareActivity on Android).
/// It never opens the app's database; it hands the share over through [ShareInbox].
@pragma('vm:entry-point')
Future<void> shareMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  GrainTexture.load();
  runApp(const ShareApp());
}
