import 'package:flutter_test/flutter_test.dart';
import 'package:misskey_streaming/misskey_streaming.dart';

void main() {
  test('config streamingUri scheme conversion', () {
    final config = MisskeyStreamConfig(
      origin: Uri.parse('https://misskey.example'),
      token: 'test',
    );
    expect(config.streamingUri.scheme, 'wss');
    expect(config.streamingUri.path, '/streaming');
    expect(config.streamingUri.queryParameters['i'], 'test');
  });

  test('client creates and manages subscriptions locally', () async {
    final client = MisskeyStreamingClient(
      MisskeyStreamConfig(
          origin: Uri.parse('https://misskey.example'), token: 'x'),
    );
    final id = await client.subscribe(channel: 'homeTimeline');
    expect(id, isNotEmpty);
    client.unsubscribe(id);
    await client.dispose();
  });
}
