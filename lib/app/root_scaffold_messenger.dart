import 'package:flutter/material.dart';

/// Root [ScaffoldMessenger] so Undo snackbars survive tab switches (architecture 2.5).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
