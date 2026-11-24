import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

Widget _app({required Widget home}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('stays open and shows inline error when onSubmit throws', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {
                          throw const ListArchivedException();
                        },
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text(l10n.errorListArchived), findsOneWidget);
  });

  testWidgets('FormValidationAbort stays open without scaffold error', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {
                          throw const FormValidationAbort();
                        },
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text(l10n.errorGeneric), findsNothing);
  });

  testWidgets('closes with the result on success', (tester) async {
    late AppLocalizations l10n;
    late BuildContext hostContext;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            hostContext = context;
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final resultFuture = showModalBottomSheet<String>(
      context: hostContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FormSheetScaffold<String>(
          title: const Text('Edit'),
          submitLabel: l10n.save,
          onSubmit: () async => 'draft-value',
          body: (context, controller) {
            return TextField(
              onChanged: (_) => controller.clearError(),
              decoration: const InputDecoration(labelText: 'Name'),
            );
          },
        );
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(await resultFuture, 'draft-value');
    expect(find.byType(FormSheetScaffold<String>), findsNothing);
  });

  testWidgets('secondary submit keeps sheet open and calls onKeepOpenSuccess', (
    tester,
  ) async {
    late AppLocalizations l10n;
    var keepOpenCalls = 0;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Quick add'),
                        submitLabel: l10n.add,
                        onSubmit: () async {},
                        secondaryAction: FormSheetSecondaryAction.submit(
                          label: l10n.addAnother,
                          key: const Key('secondary_submit'),
                          popOnSuccess: false,
                          onKeepOpenSuccess: () => keepOpenCalls++,
                        ),
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secondary_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsOneWidget);
    expect(keepOpenCalls, 1);
  });

  testWidgets('secondary submit failure shows inline error and stays open', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Quick add'),
                        submitLabel: l10n.add,
                        onSubmit: () async {
                          throw Exception('write failed');
                        },
                        secondaryAction: FormSheetSecondaryAction.submit(
                          label: l10n.addAnother,
                          key: const Key('secondary_submit'),
                          popOnSuccess: false,
                        ),
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secondary_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsOneWidget);
    expect(find.text(l10n.errorGeneric), findsOneWidget);
  });

  testWidgets('secondary button calls onPressed without submitting', (
    tester,
  ) async {
    late AppLocalizations l10n;
    var pressed = 0;
    var submitted = 0;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {
                          submitted++;
                        },
                        secondaryAction: FormSheetSecondaryAction.button(
                          label: l10n.remove,
                          key: const Key('secondary_button'),
                          onPressed: () => pressed++,
                        ),
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secondary_button')));
    await tester.pumpAndSettle();

    expect(pressed, 1);
    expect(submitted, 0);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('short body stays content sized', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {},
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(FormSheetScaffold<void>)).height,
      lessThan(320),
    );
  });

  testWidgets('tall body scrolls and keeps the error above the keyboard', (
    tester,
  ) async {
    const keyboard = 360.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                        ),
                        child: FormSheetScaffold<void>(
                          title: const Text('Edit'),
                          submitLabel: l10n.save,
                          onSubmit: () async {
                            throw const ListArchivedException();
                          },
                          body: (context, controller) {
                            return const Column(
                              children: [
                                SizedBox(height: 480),
                                Text('tail', key: Key('form_sheet_tail')),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final keyboardTop = 800 - keyboard;
    expect(
      tester.getRect(find.text(l10n.save)).bottom,
      lessThanOrEqualTo(keyboardTop),
    );

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text(l10n.errorListArchived)).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester.getRect(find.text(l10n.save)).bottom,
      lessThanOrEqualTo(keyboardTop),
    );

    final scrollable = _sheetScrollable(
      tester,
      find.byType(FormSheetScaffold<void>),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    final tail = tester.getRect(find.byKey(const Key('form_sheet_tail')));
    final box = scrollable.context.findRenderObject()! as RenderBox;
    final view = box.localToGlobal(Offset.zero) & box.size;
    expect(tail.bottom, lessThanOrEqualTo(view.bottom));
    expect(
      tail.bottom,
      lessThanOrEqualTo(tester.getRect(find.text(l10n.errorListArchived)).top),
    );
  });
}

/// The sheet list, not a text field's inner scroller.
ScrollableState _sheetScrollable(WidgetTester tester, Finder scope) {
  final matches = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .evaluate()
      .toList();
  matches.sort((a, b) {
    final aHeight = (a.renderObject! as RenderBox).size.height;
    final bHeight = (b.renderObject! as RenderBox).size.height;
    return bHeight.compareTo(aHeight);
  });
  return tester.state<ScrollableState>(find.byWidget(matches.first.widget));
}
