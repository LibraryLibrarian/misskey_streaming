import 'client.dart';
import 'config.dart';

/// 簡易利用ヘルパー
class MisskeyStreaming {
  /// origin と token からクライアントを生成
  static MisskeyStreamingClient create({
    required Uri origin,
    String? token,
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

  /// misskey_api_core の MisskeyClient からストリーミングクライアントを作成
  /// dynamicで受け取り、以下のプロパティ/関数を参照します:
  /// - baseUrl: Uri
  /// - tokenProvider: FutureOr(String?) Function()? （任意）
  /// - logger: void Function(String level, String message)? （任意）
  /// - exceptionMapper: Object Function(Object error)? （任意）
  static MisskeyStreamingClient fromClient(
    dynamic client, {
    bool enableAutoReconnect = true,
    bool debugLog = false,
  }) {
    try {
      final Uri baseUrl = client.baseUrl as Uri;
      final tokenProvider = (client.tokenProvider is Function)
          ? client.tokenProvider as Future<dynamic> Function()?
          : null;
      final logger = (client.logger is Function)
          ? client.logger as void Function(String, String)?
          : null;
      final exceptionMapper = (client.exceptionMapper is Function)
          ? client.exceptionMapper as Object Function(Object)?
          : null;

      final MisskeyStreamConfig config = MisskeyStreamConfig(
        origin: deriveOriginFromApiBase(baseUrl),
        tokenProvider: tokenProvider == null
            ? null
            : () async => await tokenProvider() as String?,
        logger: logger,
        exceptionMapper: exceptionMapper,
        enableAutoReconnect: enableAutoReconnect,
        debugLog: debugLog,
      );
      return MisskeyStreamingClient(config);
    } catch (e) {
      throw ArgumentError(
          'fromClient requires an object with baseUrl, tokenProvider(optional), logger(optional), exceptionMapper(optional): $e');
    }
  }
}
