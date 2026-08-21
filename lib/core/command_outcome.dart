/// Distinguishes Mihomo Core string results from SlClash transport outcomes.
///
/// For command-style String Core APIs:
/// - Core `""` is confirmed success.
/// - Core nonempty string is a confirmed Core error.
/// - Transport null / pre-invoke not-ready is unconfirmed — never `""`.
class CoreCommandOutcome {
  CoreCommandOutcome._();

  /// Transport or pre-invoke did not confirm. Not a Mihomo semantic error.
  static const unconfirmed = 'Core did not confirm the operation';

  static String fromInvoke(String? raw) {
    if (raw == null) {
      return unconfirmed;
    }
    return raw;
  }

  static bool isConfirmedSuccess(String result) => result.isEmpty;
}
