import 'dart:ui' show Rect;

import 'package:zero_cart/core/share_service.dart';

/// Records share calls for widget tests. Set [errorToThrow] to force failures.
class FakeShareService implements ShareService {
  final List<({String text, Rect sharePositionOrigin})> calls =
      <({String text, Rect sharePositionOrigin})>[];

  Object? errorToThrow;

  @override
  Future<void> shareText(
    String text, {
    required Rect sharePositionOrigin,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    calls.add((text: text, sharePositionOrigin: sharePositionOrigin));
  }
}
