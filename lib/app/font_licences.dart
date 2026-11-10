import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers Roboto and DynaPuff licence texts with [LicenseRegistry].
void registerBundledFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final robotoLicense = await rootBundle.loadString(
      'assets/fonts/Roboto-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['Roboto'], robotoLicense);

    final dynaPuffLicense = await rootBundle.loadString(
      'assets/fonts/DynaPuff-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['DynaPuff'], dynaPuffLicense);
  });
}
