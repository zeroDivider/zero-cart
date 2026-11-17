import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('maps every RepositoryException to a distinct non-generic string', () {
    const cases = <RepositoryException>[
      StoreArchivedException(),
      ListArchivedException(),
      ListUnavailableException(),
      StaleOrderException(),
    ];

    final messages = <String>[];
    for (final error in cases) {
      final message = messageFor(l10n, error);
      expect(message, isNot(l10n.errorGeneric), reason: '$error');
      expect(message, isNotEmpty);
      messages.add(message);
    }

    expect(messages.toSet(), hasLength(cases.length));
    expect(
      messageFor(l10n, const StoreArchivedException()),
      l10n.errorStoreArchived,
    );
    expect(
      messageFor(l10n, const ListArchivedException()),
      l10n.errorListArchived,
    );
    expect(
      messageFor(l10n, const ListUnavailableException()),
      l10n.errorListUnavailable,
    );
    expect(messageFor(l10n, const StaleOrderException()), l10n.errorStaleOrder);
  });

  test('InvalidWishlistCopyException maps to the generic string', () {
    expect(
      messageFor(l10n, const InvalidWishlistCopyException()),
      l10n.errorGeneric,
    );
  });

  test('unknown errors use the generic fallback', () {
    expect(messageFor(l10n, StateError('x')), l10n.errorGeneric);
    expect(messageFor(l10n, Exception('boom')), l10n.errorGeneric);
    expect(messageFor(l10n, 'string'), l10n.errorGeneric);
  });
}
