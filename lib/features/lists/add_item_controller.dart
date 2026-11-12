import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/core/form_submit_state.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';

class AddItemState extends FormSubmitState {
  const AddItemState({super.submitting, super.error, this.pendingScrollId});
  const AddItemState.idle() : pendingScrollId = null, super.idle();

  final String? pendingScrollId;
}

class AddItemController extends Notifier<AddItemState> {
  AddItemController(this.listId);

  final String listId;

  @override
  AddItemState build() => const AddItemState.idle();

  Future<void> addItem({
    required String title,
    String? description,
    required String errorMessage,
  }) async {
    if (state.submitting) {
      return;
    }
    state = const AddItemState(submitting: true);
    try {
      final created = await ref
          .read(listsRepositoryProvider)
          .addItem(listId: listId, title: title, description: description);
      state = AddItemState(pendingScrollId: created.id);
    } on Object {
      state = AddItemState(error: errorMessage);
    }
  }

  void clearPendingScroll() {
    if (state.pendingScrollId != null) {
      state = const AddItemState.idle();
    }
  }

  void clearError() {
    if (state.error != null) {
      state = const AddItemState.idle();
    }
  }
}

final addItemControllerProvider = NotifierProvider.autoDispose
    .family<AddItemController, AddItemState, String>(
      (listId) => AddItemController(listId),
    );
