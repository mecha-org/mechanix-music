/// Asks the Mechanix compositor to focus this app's window.
///
/// Kept separate from MPRIS because it is a compositor contract, not a
/// media one; other features (notifications, deep links) can reuse it.
abstract interface class WindowActivator {
  Future<void> activate();
}
