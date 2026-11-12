import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/core/form_submit_state.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';

class QuickAddNotifier extends Notifier<FormSubmitState> {
  @override
  FormSubmitState build() => const FormSubmitState.idle();

  /// Returns true on success so the widget can pop or reset.
  Future<bool> submit({
    required String title,
    required String description,
    required String errorMessage,
  }) async {
    if (state.submitting) {
      return false;
    }
    state = const FormSubmitState(submitting: true);
    try {
      await ref
          .read(inboxRepositoryProvider)
          .add(title: title, description: description);
      state = const FormSubmitState.idle();
      return true;
    } on Object {
      state = FormSubmitState(error: errorMessage);
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = const FormSubmitState.idle();
    }
  }
}

final quickAddNotifierProvider =
    NotifierProvider.autoDispose<QuickAddNotifier, FormSubmitState>(
      QuickAddNotifier.new,
    );
