import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/core/form_submit_state.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';

class InboxEditController extends Notifier<FormSubmitState> {
  InboxEditController(this.itemId);

  final String itemId;

  @override
  FormSubmitState build() => const FormSubmitState.idle();

  Future<bool> save({
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
          .update(id: itemId, title: title, description: description);
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

final inboxEditControllerProvider = NotifierProvider.autoDispose
    .family<InboxEditController, FormSubmitState, String>(
      (itemId) => InboxEditController(itemId),
    );
