class AppAlreadyRunningException implements Exception {
  final String message;
  AppAlreadyRunningException([
    this.message = 'This app instance is already running.',
  ]);

  @override
  String toString() => message;
}

class PlaybackException implements Exception {
  final String message;
  PlaybackException([this.message = 'An unknown playback error occurred.']);

  @override
  String toString() => message;
}

class PlaybackFileNotFoundException extends PlaybackException {
  PlaybackFileNotFoundException([super.message = 'Playback file not found.']);
}
