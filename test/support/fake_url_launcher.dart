import 'package:zero_cart/core/url_launcher.dart';

/// Records [openExternal] calls for widget tests. Set [errorToThrow] to fail.
class FakeUrlLauncher implements UrlLauncher {
  final List<Uri> calls = <Uri>[];

  Object? errorToThrow;

  @override
  Future<void> openExternal(Uri url) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    calls.add(url);
  }
}
