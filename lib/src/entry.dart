import 'client.dart';
import 'config.dart';

/// 簡易利用ヘルパー
class MisskeyStreaming {
  /// origin と token からクライアントを生成
  static MisskeyStreamingClient create({
    required Uri origin,
    required String token,
    bool enableAutoReconnect = true,
    bool debugLog = false,
  }) {
    final MisskeyStreamConfig config = MisskeyStreamConfig(
      origin: origin,
      token: token,
      enableAutoReconnect: enableAutoReconnect,
      debugLog: debugLog,
    );
    return MisskeyStreamingClient(config);
  }
}
