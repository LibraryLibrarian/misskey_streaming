import 'package:flutter_test/flutter_test.dart';
import 'package:misskey_streaming/misskey_streaming.dart';
import 'package:misskey_api_core/misskey_api_core.dart' as core;

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

  test('fromClient が HTTPクライアントの設定を継承することをテスト', () async {
    final http = core.MisskeyHttpClient(
      config:
          core.MisskeyApiConfig(baseUrl: Uri.parse('https://h.example/api')),
      tokenProvider: () async => 'T',
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
}
