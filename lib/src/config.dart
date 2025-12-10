import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Misskey Streaming 接続設定
class MisskeyStreamConfig {
  MisskeyStreamConfig({
    required this.origin,
    this.token,
    this.tokenProvider,
    this.enableAutoReconnect = true,
    this.pingInterval = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 15),
    this.reconnectInitialDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts,
    this.customHeaders,
    this.debugLog = false,
    this.protocols,
    this.connector,
    this.logger,
    this.exceptionMapper,
  });

  /// Misskey のベースURL (例: https://misskey.io)
  final Uri origin;

  /// アクセストークン (Misskey Auth で取得した `i`)
  /// 未ログインの場合は null
  final String? token;

  /// トークンの動的取得関数。指定があればこちらが優先されます
  final FutureOr<String?> Function()? tokenProvider;

  /// 自動再接続を有効化
  final bool enableAutoReconnect;

  /// 定期 ping 間隔。null で ping 無効
  final Duration? pingInterval;

  /// 接続試行のタイムアウト
  final Duration connectTimeout;

  /// 再接続の初期待機時間
  final Duration reconnectInitialDelay;

  /// 再接続の最大待機時間
  final Duration reconnectMaxDelay;

  /// 最大再接続回数。null で無制限
  final int? maxReconnectAttempts;

  /// 追加ヘッダ（必要に応じて）
  final Map<String, dynamic>? customHeaders;

  /// ログ出力を有効化
  final bool debugLog;

  /// WebSocket サブプロトコル
  final Iterable<String>? protocols;

  /// WebSocket 接続の差し替え用ファクトリ（テスト用 / カスタム実装用）
  final WebSocketChannel Function(Uri uri)? connector;

  /// ロガー差し替え（レベルは任意の文字列: debug/info/warn/error 等）
  final void Function(String level, String message)? logger;

  /// 例外マッピング（任意の例外→ライブラリ独自例外等に変換）
  final Object Function(Object error)? exceptionMapper;

  /// Streaming エンドポイントの生成
  /// tokenOverride により `?i=` の有無を制御（null/空文字で省略）
  Uri buildStreamingUri(String? tokenOverride) {
    final String scheme;
    if (origin.scheme == 'https') {
      scheme = 'wss';
    } else if (origin.scheme == 'http') {
      scheme = 'ws';
    } else if (origin.scheme == 'wss' || origin.scheme == 'ws') {
      scheme = origin.scheme;
    } else {
      scheme = 'wss';
    }

    final qp = <String, String>{};
    final t = tokenOverride ?? token;
    if (t != null && t.isNotEmpty) {
      qp['i'] = t;
    }

    final basePath = origin.path.isEmpty
        ? '/'
        : (origin.path.endsWith('/') ? origin.path : '${origin.path}/');
    final streamingPath = '${basePath}streaming';

    return origin.replace(
      scheme: scheme,
      path: streamingPath,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  MisskeyStreamConfig copyWith({
    Uri? origin,
    String? token,
    FutureOr<String?> Function()? tokenProvider,
    bool? enableAutoReconnect,
    Duration? pingInterval,
    Duration? connectTimeout,
    Duration? reconnectInitialDelay,
    Duration? reconnectMaxDelay,
    int? maxReconnectAttempts,
    Map<String, dynamic>? customHeaders,
    bool? debugLog,
    Iterable<String>? protocols,
    WebSocketChannel Function(Uri uri)? connector,
    void Function(String level, String message)? logger,
    Object Function(Object error)? exceptionMapper,
  }) {
    return MisskeyStreamConfig(
      origin: origin ?? this.origin,
      token: token ?? this.token,
      tokenProvider: tokenProvider ?? this.tokenProvider,
      enableAutoReconnect: enableAutoReconnect ?? this.enableAutoReconnect,
      pingInterval: pingInterval ?? this.pingInterval,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      reconnectInitialDelay:
          reconnectInitialDelay ?? this.reconnectInitialDelay,
      reconnectMaxDelay: reconnectMaxDelay ?? this.reconnectMaxDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      customHeaders: customHeaders ?? this.customHeaders,
      debugLog: debugLog ?? this.debugLog,
      protocols: protocols ?? this.protocols,
      connector: connector ?? this.connector,
      logger: logger ?? this.logger,
      exceptionMapper: exceptionMapper ?? this.exceptionMapper,
    );
  }
}

/// APIベースURL(例: https://host/api) から Streaming 用の origin を導出
Uri deriveOriginFromApiBase(Uri apiBaseUrl) {
  final path = apiBaseUrl.path;
  var newPath = path;
  if (path.endsWith('/api')) {
    newPath = path.substring(0, path.length - 4);
  }
  if (newPath.isEmpty) newPath = '/';
  return apiBaseUrl.replace(path: newPath);
}
