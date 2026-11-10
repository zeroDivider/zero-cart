import 'package:flutter/material.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/app/font_licences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicences();
  runApp(ZeroCartApp());
}
