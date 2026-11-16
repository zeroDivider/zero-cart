import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Renders loading, localised error with Retry, or data (ADR-0007).
///
/// Never shows raw `Text('$error')`. Typed repository errors use [messageFor];
/// other failures use [AppLocalizations.asyncLoadFailed].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _AsyncError(error: error, onRetry: onRetry),
      data: (data) => builder(context, data),
    );
  }
}

class _AsyncError extends StatelessWidget {
  const _AsyncError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final message = error is RepositoryException
        ? messageFor(l10n, error)
        : l10n.asyncLoadFailed;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: tokens.spacing16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
