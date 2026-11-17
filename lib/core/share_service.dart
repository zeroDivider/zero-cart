import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Platform share edge (text). Fake in tests; extend later for backup files.
abstract class ShareService {
  /// Opens the system share sheet with [text].
  ///
  /// [sharePositionOrigin] anchors the popover on iPad and is required by
  /// callers even when other platforms ignore it.
  Future<void> shareText(String text, {required Rect sharePositionOrigin});
}

/// Production [ShareService] using [share_plus].
class PlatformShareService implements ShareService {
  @override
  Future<void> shareText(
    String text, {
    required Rect sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
    );
  }
}

/// App-lifetime share edge. Override in tests with a fake.
final shareServiceProvider = Provider<ShareService>(
  (ref) => PlatformShareService(),
);
