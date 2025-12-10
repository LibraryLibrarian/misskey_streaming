import 'client.dart';
import 'config.dart';

/// 簡易利用ヘルパー
class MisskeyStreaming {
  /// デフォルトコンストラクタ
  const MisskeyStreaming();

  /// origin と token からクライアントを生成（インスタンスメソッド版）
  MisskeyStreamingClient createClient({
    required Uri origin,
    String? token,
    bool enableAutoReconnect = true,
    bool debugLog = false,
  }) =>
      create(
        origin: origin,
        token: token,
        enableAutoReconnect: enableAutoReconnect,
        debugLog: debugLog,
      );

  /// origin と token からクライアントを生成
  static MisskeyStreamingClient create({
    required Uri origin,
    String? token,
    bool enableAutoReconnect = true,
    bool debugLog = false,
  }) {
    final config = MisskeyStreamConfig(
      origin: origin,
      token: token,
      enableAutoReconnect: enableAutoReconnect,
      debugLog: debugLog,
    );
    return MisskeyStreamingClient(config);
  }

  /// misskey_api_core の MisskeyClient からストリーミングクライアントを作成
  ///
  /// dynamicで受け取り、以下のプロパティ/関数を参照します:
  /// - baseUrl: Uri
  /// - tokenProvider: FutureOr(String?) Function()? （任意）
  /// - logger: void Function(String level, String message)? （任意）
  /// - exceptionMapper: Object Function(Object error)? （任意）
  static MisskeyStreamingClient fromClient(
    Object client, {
    bool enableAutoReconnect = true,
    bool debugLog = false,
  }) {
    try {
      // dynamic型のプロパティアクセスをリフレクション的に扱う
      final baseUrl = (client as dynamic).baseUrl as Uri;

      Future<String?> Function()? tokenProvider;
      if ((client as dynamic).tokenProvider is Function) {
        final provider = (client as dynamic).tokenProvider;
        // ignore: avoid_dynamic_calls
        tokenProvider = () async => await provider() as String?;
      }

      void Function(String, String)? logger;
      if ((client as dynamic).logger is Function) {
        logger = (client as dynamic).logger as void Function(String, String)?;
      }

      Object Function(Object)? exceptionMapper;
      if ((client as dynamic).exceptionMapper is Function) {
        exceptionMapper =
            (client as dynamic).exceptionMapper as Object Function(Object)?;
      }

      final config = MisskeyStreamConfig(
        origin: deriveOriginFromApiBase(baseUrl),
        tokenProvider: tokenProvider,
        logger: logger,
        exceptionMapper: exceptionMapper,
        enableAutoReconnect: enableAutoReconnect,
        debugLog: debugLog,
      );
      return MisskeyStreamingClient(config);
    } catch (e) {
      throw ArgumentError(
        'fromClient requires an object with baseUrl, '
        'tokenProvider(optional), logger(optional), '
        'exceptionMapper(optional): $e',
      );
    }
  }
}
