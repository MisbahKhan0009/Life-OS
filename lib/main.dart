import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';
import 'ui/grain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await NoteStore.open();
  GrainTexture.load();
  runApp(LifeOsApp(store: store));
}
