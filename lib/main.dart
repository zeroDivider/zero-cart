import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/app/font_licences.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicences();
  final database = AppDatabase.file();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: ZeroCartApp(),
    ),
  );
}
