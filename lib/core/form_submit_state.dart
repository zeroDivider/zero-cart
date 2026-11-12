/// Shared state for form-submission notifiers.
///
/// Widgets render this with: submitting → disable button,
/// error != null → show error text (pass already-translated message).
class FormSubmitState {
  const FormSubmitState({this.submitting = false, this.error});
  const FormSubmitState.idle() : submitting = false, error = null;

  final bool submitting;
  final String? error; // localized by the widget; null = no error

  bool get canSubmit => !submitting;
}
