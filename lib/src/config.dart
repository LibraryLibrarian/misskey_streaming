import 'package:web_socket_channel/web_socket_channel.dart';

/// Misskey Streaming 接続設定
class MisskeyStreamConfig {
  MisskeyStreamConfig({
    required this.origin,
    required this.token,
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
  });

  /// Misskey のベースURL (例: https://misskey.io)
  final Uri origin;

  /// アクセストークン (Misskey Auth で取得した `i`)
  final String token;

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

  /// Streaming エンドポイント (例: wss://misskey.io/streaming?i=token)
  Uri get streamingUri {
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

    return origin.replace(
      scheme: scheme,
      path: '/streaming',
      queryParameters: <String, String>{'i': token},
    );
  }

  MisskeyStreamConfig copyWith({
    Uri? origin,
    String? token,
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
  }) {
    return MisskeyStreamConfig(
      origin: origin ?? this.origin,
      token: token ?? this.token,
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
    );
  }
}
