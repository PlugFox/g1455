import 'web_client.dart';

/// Not a browser: nothing to read.
WebClient? readWebClient() => null;

/// Nowhere to keep it: never closed.
DateTime? readNoticeClosed() => null;

/// Nowhere to keep it.
void writeNoticeClosed(DateTime at) {}
