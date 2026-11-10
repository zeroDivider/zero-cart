import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Temporary APP-002 glyph check; removed before task handoff.
    return const MaterialApp(home: _FontCheckScreen());
  }
}

class _FontCheckScreen extends StatelessWidget {
  const _FontCheckScreen();

  static const _sample = 'Zeroč ćšžđ ČĆŠŽĐ';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Font check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.balance),
            tooltip: 'Licences',
            onPressed: () {
              showLicensePage(context: context, applicationName: 'ZeroCart');
            },
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sample,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _sample,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _sample,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'ZeroCart',
              style: TextStyle(
                fontFamily: 'DynaPuff',
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
