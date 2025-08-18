<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

- Minimal Misskey Streaming wrapper
- Auto reconnect with exponential backoff
- Channel subscribe/unsubscribe API
- Connection state stream and message stream

## Getting started

Add dependency in your `pubspec.yaml`:

```yaml
dependencies:
  misskey_streaming:
    path: .
```

## Usage

```dart
import 'package:misskey_streaming/misskey_streaming.dart';

void main() async {
  final client = MisskeyStreaming.create(
    origin: Uri.parse('https://misskey.io'),
    token: 'YOUR_TOKEN',
    debugLog: true,
  );
  await client.connect();

  // Subscribe to timeline
  final subId = await client.subscribe(channel: 'homeTimeline');

  // Listen messages
  final sub = client.messages.listen((m) {
    // handle
  });

  // ... later
  client.unsubscribe(subId);
  await sub.cancel();
  await client.dispose();
}
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
