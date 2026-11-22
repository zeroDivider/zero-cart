import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

/// Opens http(s) links in the system browser (platform edge; fake in tests).
abstract class UrlLauncher {
  /// Hands [url] to the external browser. Throws if the platform cannot open it.
  Future<void> openExternal(Uri url);
}

/// Production [UrlLauncher] using `url_launcher`.
class PlatformUrlLauncher implements UrlLauncher {
  @override
  Future<void> openExternal(Uri url) async {
    final ok = await ul.launchUrl(url, mode: ul.LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open $url');
    }
  }
}

/// App-lifetime URL edge. Override in tests with a fake.
final urlLauncherProvider = Provider<UrlLauncher>(
  (ref) => PlatformUrlLauncher(),
);
