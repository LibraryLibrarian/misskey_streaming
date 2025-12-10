import 'package:flutter_test/flutter_test.dart';
import 'package:misskey_api_core/misskey_api_core.dart' as core;
import 'package:misskey_streaming/misskey_streaming.dart';

void main() {
  test('buildStreamingUriのスキーム変換とトークン付与をテスト', () {
    final config = MisskeyStreamConfig(
      origin: Uri.parse('https://misskey.example'),
      token: 'test',
    );
    final uri = config.buildStreamingUri(null);
    expect(uri.scheme, 'wss');
    expect(uri.path, '/streaming');
    expect(uri.queryParameters['i'], 'test');
  });

  test('クライアントがローカルでサブスクリプションを作成・管理できるかテスト', () async {
    final client = MisskeyStreamingClient(MisskeyStreamConfig(
      origin: Uri.parse('https://misskey.example'),
      token: 'x',
    ));
    final id = await client.subscribe(channel: 'homeTimeline');
    expect(id, isNotEmpty);
    client.unsubscribe(id);
    await client.dispose();
  });

  test('deriveOriginFromApiBase が /api を削除することをテスト', () {
    final api = Uri.parse('https://host.example/api');
    final origin = deriveOriginFromApiBase(api);
    expect(origin.toString(), 'https://host.example/');
  });

  test('buildStreamingUri がサブパスを保持し /streaming を付与することをテスト', () {
    final cfg = MisskeyStreamConfig(origin: Uri.parse('https://h.example/sub'));
    final uri = cfg.buildStreamingUri(null);
    expect(uri.path, '/sub/streaming');
  });

  test('fromClient が HTTPクライアントの設定を継承することをテスト', () {
    final http = core.MisskeyHttpClient(
      config:
          core.MisskeyApiConfig(baseUrl: Uri.parse('https://h.example/api')),
      tokenProvider: () => Future.value('T'),
    );
    final streaming = MisskeyStreamingClient.fromClient(
      http,
      debugLog: true,
    );
    final uri = streaming.config.buildStreamingUri('T');
    expect(uri.scheme, 'wss');
    expect(uri.path, '/streaming');
    expect(uri.queryParameters['i'], 'T');
  });

  test('購読解除でdisconnectが送信されストリームが完了する', () {
    final client = MisskeyStreamingClient(MisskeyStreamConfig(
      origin: Uri.parse('https://h.example'),
      token: 'T',
    ));

    return client.subscribeChannelStream(channel: 'homeTimeline').then(
      (handle) {
        final done = expectLater(handle.stream, emitsDone);
        handle.unsubscribe();

        return done.then((_) => client.dispose());
      },
    );
  });

  test('チャンネル名でまとめて購読解除可能か', () async {
    final client = MisskeyStreamingClient(MisskeyStreamConfig(
      origin: Uri.parse('https://h.example'),
      token: 'T',
    ));

    final h1 = await client.subscribe(channel: 'homeTimeline', id: 'h1');
    final h2 = await client.subscribe(channel: 'homeTimeline', id: 'h2');
    final g1 = await client.subscribe(channel: 'globalTimeline', id: 'g1');
    expect(h1, 'h1');
    expect(h2, 'h2');
    expect(g1, 'g1');

    final count = client.unsubscribeChannel('homeTimeline');
    expect(count, 2);

    // 残っているのは globalTimeline のみ
    final rem = await client.subscribe(channel: 'globalTimeline', id: 'g2');
    expect(rem, 'g2');

    // 明示的にクリーンアップ
    client
      ..unsubscribe('g1')
      ..unsubscribe('g2');
    await client.dispose();
  });

  test('ID指定で購読解除できる', () async {
    final client = MisskeyStreamingClient(MisskeyStreamConfig(
      origin: Uri.parse('https://h.example'),
      token: 'T',
    ));

    final id = await client.subscribe(channel: 'homeTimeline', id: 'home-xyz');
    expect(id, 'home-xyz');

    client.unsubscribeById('home-xyz');

    // 同じIDで subscribe できれば、前の購読が解除されていることの簡易確認とする
    final id2 = await client.subscribe(channel: 'homeTimeline', id: 'home-xyz');
    expect(id2, 'home-xyz');

    client.unsubscribe(id2);
    await client.dispose();
  });
}
