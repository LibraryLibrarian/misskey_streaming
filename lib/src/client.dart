import 'dart:async';
import 'dart:convert';

import 'package:misskey_api_core/misskey_api_core.dart' as core;
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'logging.dart';
import 'subscription.dart';
import 'types.dart';

class MisskeyStreamingClient {
  MisskeyStreamingClient(this.config);

  /// Core HTTP クライアントから設定を引き継いで Streaming クライアントを生成
  factory MisskeyStreamingClient.fromClient(
    core.MisskeyHttpClient client, {
    bool enableAutoReconnect = true,
    bool debugLog = false,
    Duration? pingInterval,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration reconnectInitialDelay = const Duration(seconds: 1),
    Duration reconnectMaxDelay = const Duration(seconds: 30),
    int? maxReconnectAttempts,
    Map<String, dynamic>? customHeaders,
    Iterable<String>? protocols,
    WebSocketChannel Function(Uri uri)? connector,
    void Function(String, String)? logger,
    Object Function(Object error)? exceptionMapper,
  }) {
    final origin = deriveOriginFromApiBase(client.baseUrl);

    final bridgedLogger = logger ??
        (client.logger != null
            ? (String level, String message) {
                switch (level) {
                  case 'debug':
                    client.logger!.debug(message);
                  case 'warn':
                    client.logger!.warn(message);
                  case 'error':
                    client.logger!.error(message);
                  default:
                    client.logger!.info(message);
                }
              }
            : null);

    final cfg = MisskeyStreamConfig(
      origin: origin,
      tokenProvider: client.tokenProvider,
      enableAutoReconnect: enableAutoReconnect,
      pingInterval: pingInterval ?? const Duration(seconds: 30),
      connectTimeout: connectTimeout,
      reconnectInitialDelay: reconnectInitialDelay,
      reconnectMaxDelay: reconnectMaxDelay,
      maxReconnectAttempts: maxReconnectAttempts,
      customHeaders: customHeaders,
      debugLog: debugLog,
      protocols: protocols,
      connector: connector,
      logger: bridgedLogger,
      exceptionMapper: exceptionMapper ?? client.exceptionMapper,
    );
    return MisskeyStreamingClient(cfg);
  }

  final MisskeyStreamConfig config;

  final BehaviorSubject<MisskeyConnectionState> _statusSubject =
      BehaviorSubject<MisskeyConnectionState>.seeded(
          MisskeyConnectionState.idle);
  final PublishSubject<MisskeyMessage> _messageSubject =
      PublishSubject<MisskeyMessage>();
  final Map<String, PublishSubject<MisskeyMessage>> _perSubscriptionSubjects =
      <String, PublishSubject<MisskeyMessage>>{};

  Stream<MisskeyConnectionState> get status => _statusSubject.stream;
  Stream<MisskeyMessage> get messages => _messageSubject.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _pingTimer;

  final Map<String, MisskeySubscription> _subscriptions =
      <String, MisskeySubscription>{};
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  /// ノートキャプチャの対応関係（noteId -> Set&lt;subscriptionId&gt;）
  ///
  /// 同一ノートが複数の購読でキャプチャされる可能性があるためSetで管理
  final Map<String, Set<String>> _capturedNotes = <String, Set<String>>{};

  bool get isConnected => _statusSubject.value == MisskeyConnectionState.open;

  Future<void> connect() async {
    if (_isDisposed) {
      throw StateError('Client already disposed');
    }
    if (_statusSubject.value == MisskeyConnectionState.open ||
        _statusSubject.value == MisskeyConnectionState.connecting) {
      return;
    }
    _statusSubject.add(MisskeyConnectionState.connecting);
    await _openChannel();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _statusSubject.add(MisskeyConnectionState.closed);
    _pingTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    await _statusSubject.close();
    await _messageSubject.close();
    for (final s in _perSubscriptionSubjects.values) {
      await s.close();
    }
    _perSubscriptionSubjects.clear();
  }

  Future<String> subscribe({
    required String channel,
    String? id,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final subscriptionId = id ?? const Uuid().v4();
    final sub = MisskeySubscription(
      id: subscriptionId,
      channel: channel,
      params: params,
    );
    _subscriptions[subscriptionId] = sub;
    if (isConnected) {
      _sendJson(sub.toConnectPayload());
    }
    _ensureSubject(subscriptionId);
    return subscriptionId;
  }

  void unsubscribe(String id) {
    // この購読に関連するキャプチャをクリア
    _clearCapturesForSubscription(id);

    final sub = _subscriptions.remove(id);
    if (sub != null && isConnected) {
      _sendJson(sub.toDisconnectPayload());
    }
    final subject = _perSubscriptionSubjects.remove(id);
    subject?.close();
  }

  /// 購読IDを指定して解除（`unsubscribe`のエイリアス）
  void unsubscribeById(String id) => unsubscribe(id);

  void sendRaw(Map<String, dynamic> payload) {
    _sendJson(payload);
  }

  Stream<MisskeyMessage> messagesFor(String subscriptionId) {
    _ensureSubject(subscriptionId);
    return _perSubscriptionSubjects[subscriptionId]!.stream;
  }

  /// 指定チャンネル名に一致する購読をまとめて解除
  ///
  /// - `channel`: 対象チャンネル名（例: `homeTimeline`）
  ///
  /// 返り値は解除した購読ID数。該当がなければ0を返す
  int unsubscribeChannel(String channel) {
    final targets = _subscriptions.values
        .where((s) => s.channel == channel)
        .map((s) => s.id)
        .toList(growable: false)
      ..forEach(unsubscribe);
    return targets.length;
  }

  /// 指定チャンネルを購読し`id`でルーティングされたストリームを返す
  ///
  /// - `channel`: 接続するMisskeyのチャンネル名（例: `homeTimeline`）
  /// - `id`: 購読ID。未指定の場合はUUIDを自動採番
  /// - `params`: チャンネル固有の追加パラメータ
  ///
  /// 返り値は、購読IDとストリーム、解除操作を持つハンドル
  Future<MisskeySubscriptionHandle> subscribeAsStream({
    required String channel,
    String? id,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final subId = await subscribe(channel: channel, id: id, params: params);
    final stream = messagesFor(subId);
    return MisskeySubscriptionHandle(
      id: subId,
      stream: stream,
      onUnsubscribe: () => unsubscribe(subId),
    );
  }

  void _ensureSubject(String subscriptionId) {
    _perSubscriptionSubjects.putIfAbsent(
        subscriptionId, PublishSubject<MisskeyMessage>.new);
  }

  Future<void> _openChannel() async {
    try {
      final token = await _resolveToken();
      final uri = config.buildStreamingUri(token);
      streamingLog.i('Connecting to: $uri');
      final channel = (config.connector != null)
          ? config.connector!(uri)
          : WebSocketChannel.connect(uri, protocols: config.protocols);
      _channel = channel;
      _statusSubject.add(
        _reconnectAttempts > 0
            ? MisskeyConnectionState.reconnecting
            : MisskeyConnectionState.connecting,
      );
      _channelSubscription = channel.stream.listen(
        _onMessage,
        onError: (Object error, StackTrace stack) {
          streamingLog.e('Socket error: $error');
          _onError(error);
        },
        onDone: () {
          streamingLog.i('Socket done');
          _onDone();
        },
        cancelOnError: false,
      );

      _onOpen();
    } on Exception catch (e) {
      _onError(e);
      if (config.enableAutoReconnect) {
        _scheduleReconnect();
      } else {
        _statusSubject.add(MisskeyConnectionState.error);
      }
    }
  }

  Future<String?> _resolveToken() async {
    try {
      if (config.tokenProvider != null) {
        return await config.tokenProvider!();
      }
      return config.token;
    } on Exception catch (e) {
      streamingLog.w('tokenProvider failed: $e');
      return config.token;
    }
  }

  void _onOpen() {
    streamingLog.i('Connected');
    _statusSubject.add(MisskeyConnectionState.open);
    _reconnectAttempts = 0;
    _startPing();
    _resubscribeAll();
  }

  void _onMessage(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        _dispatchDecoded(decoded);
      } else if (data is List<int>) {
        final text = utf8.decode(data);
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        _dispatchDecoded(decoded);
      } else {
        streamingLog.w('Unknown message type: ${data.runtimeType}');
      }
    } on Exception catch (e) {
      streamingLog.e('Message parse error: $e');
    }
  }

  /// ノートキャプチャイベントのタイプ一覧
  static const _noteCaptureEventTypes = {
    'reacted',
    'unreacted',
    'deleted',
    'pollVoted',
  };

  void _dispatchDecoded(Map<String, dynamic> decoded) {
    final type = decoded['type']?.toString() ?? 'unknown';
    final dynamic body = decoded['body'];

    // 受信したメッセージをログ出力（pong以外）
    if (type != 'pong') {
      final bodyStr = body.toString();
      final truncated =
          bodyStr.length > 200 ? '${bodyStr.substring(0, 200)}...' : bodyStr;
      streamingLog.d('<< type=$type body=$truncated');
    }

    // チャンネルからのメッセージ
    if (type == 'channel' && body is Map<String, dynamic>) {
      final subId = body['id']?.toString();
      final innerType = body['type']?.toString() ?? 'unknown';
      final dynamic innerBody = body['body'];
      final msg = MisskeyMessage(
        type: innerType,
        body: innerBody,
        id: subId,
        raw: decoded,
      );
      _messageSubject.add(msg);
      if (subId != null && _perSubscriptionSubjects.containsKey(subId)) {
        _perSubscriptionSubjects[subId]!.add(msg);
      }
      return;
    }

    // ノートキャプチャイベント（noteUpdated: reacted/unreacted/deleted/pollVoted）
    // Misskeyは type: "noteUpdated", body: { id, type, body } の形式で送信する
    if (type == 'noteUpdated' && body is Map<String, dynamic>) {
      final noteId = body['id']?.toString();
      final eventType = body['type']?.toString();
      final eventBody = body['body'];
      streamingLog.d(
        '[NOTE UPDATED] eventType=$eventType noteId=$noteId',
      );
      if (noteId != null && _noteCaptureEventTypes.contains(eventType)) {
        final subscriptionIds = _capturedNotes[noteId];
        streamingLog.d(
          '[CAPTURED NOTE LOOKUP] noteId=$noteId '
          'subscriptions=${subscriptionIds?.length ?? 0} '
          'totalCaptured=${_capturedNotes.length}',
        );
        if (subscriptionIds != null && subscriptionIds.isNotEmpty) {
          // eventType (reacted等) をメッセージタイプとして使用
          final msg = MisskeyMessage(
            type: eventType!,
            body: eventBody,
            id: noteId,
            raw: decoded,
          );
          _messageSubject.add(msg);
          // キャプチャしている全ての購読ストリームに転送
          for (final subId in subscriptionIds) {
            // ignore: close_sinks
            final subject = _perSubscriptionSubjects[subId];
            if (subject != null) {
              streamingLog.d(
                '[FORWARDING] $eventType to subscription $subId',
              );
              subject.add(msg);
            }
          }
          return;
        } else {
          streamingLog.d(
            '[NOTE UPDATED] uncaptured note: noteId=$noteId',
          );
        }
      }
    }

    final id = decoded['id']?.toString();
    _messageSubject
        .add(MisskeyMessage(type: type, body: body, id: id, raw: decoded));
  }

  void _onError(Object error) {
    if (_isDisposed) return;
    final mapped =
        config.exceptionMapper != null ? config.exceptionMapper!(error) : error;
    _statusSubject.add(MisskeyConnectionState.error);
    if (config.enableAutoReconnect) {
      _scheduleReconnect();
    }
    streamingLog.e('onError: $mapped');
  }

  void _onDone() {
    if (_isDisposed) return;
    _statusSubject.add(MisskeyConnectionState.closed);
    if (config.enableAutoReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    final attempt = ++_reconnectAttempts;
    if (config.maxReconnectAttempts != null &&
        attempt > config.maxReconnectAttempts!) {
      streamingLog.e('Max reconnect attempts reached');
      _statusSubject.add(MisskeyConnectionState.error);
      return;
    }
    final delay = _computeBackoffDelay(attempt);
    streamingLog
        .i('Reconnecting in ${delay.inMilliseconds}ms (attempt: $attempt)');
    Future<void>.delayed(delay, () {
      if (_isDisposed) return;
      _statusSubject.add(MisskeyConnectionState.reconnecting);
      _openChannel();
    });
  }

  Duration _computeBackoffDelay(int attempt) {
    final baseMs = config.reconnectInitialDelay.inMilliseconds;
    final maxMs = config.reconnectMaxDelay.inMilliseconds;
    var delayMs = baseMs * (1 << (attempt - 1));
    if (delayMs > maxMs) delayMs = maxMs;
    const jitter = 0.2;
    final factor = 1 +
        (jitter * (DateTime.now().millisecondsSinceEpoch % 1000) / 500.0 -
            jitter);
    delayMs = (delayMs * factor).clamp(baseMs, maxMs).toInt();
    return Duration(milliseconds: delayMs);
  }

  void _resubscribeAll() {
    if (!isConnected) return;

    // チャンネル購読を再送信
    for (final sub in _subscriptions.values) {
      _sendJson(sub.toConnectPayload());
    }

    // キャプチャ中のノートを再送信
    // サーバー側は再接続時にキャプチャ状態をリセットするため、
    // クライアント側で保持している全てのキャプチャを再送信する必要がある
    if (_capturedNotes.isNotEmpty) {
      streamingLog.i(
        '[RECONNECT] Re-capturing ${_capturedNotes.length} notes',
      );
      for (final noteId in _capturedNotes.keys) {
        _sendJson(<String, dynamic>{
          'type': 'subNote',
          'body': <String, dynamic>{'id': noteId},
        });
      }
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    final interval = config.pingInterval;
    if (interval == null) return;
    _pingTimer = Timer.periodic(interval, (_) {
      if (!isConnected) return;
      _sendJson(<String, dynamic>{'type': 'ping'});
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    final text = jsonEncode(payload);
    streamingLog.d('>> $text');
    channel.sink.add(text);
  }

  /// ノートをキャプチャしてリアクション等のイベントを受信可能にする
  ///
  /// キャプチャ後、以下のイベントが購読ストリームで受信可能
  /// - `reacted`: リアクション追加
  /// - `unreacted`: リアクション削除
  /// - `deleted`: ノート削除
  /// - `pollVoted`: 投票が行われた（アンケート付きノートの場合）
  ///
  /// [subscriptionId]: イベントを受信するチャンネルの購読ID
  /// [noteId]: キャプチャするノートのID
  ///
  /// Example:
  /// ```dart
  /// final handle = await client.subscribeChannelStream(
  ///   channel: 'homeTimeline',
  /// );
  ///
  /// handle.stream.listen((msg) {
  ///   if (msg.type == 'note') {
  ///     final noteId = msg.body['id'];
  ///     client.captureNote(handle.id, noteId);
  ///   } else if (msg.type == 'reacted') {
  ///     // リアクションイベントを処理
  ///   }
  /// });
  /// ```
  void captureNote(String subscriptionId, String noteId) {
    // 対応関係を追跡
    _capturedNotes.putIfAbsent(noteId, () => <String>{}).add(subscriptionId);

    // サーバーにsubNoteを送信
    _sendJson(<String, dynamic>{
      'type': 'subNote',
      'body': <String, dynamic>{'id': noteId},
    });

    streamingLog.d('[CAPTURE NOTE] noteId=$noteId subId=$subscriptionId');
  }

  /// ノートのキャプチャを解除
  ///
  /// [subscriptionId]: イベントを受信していたチャンネルの購読ID
  /// [noteId]: キャプチャを解除するノートのID
  void uncaptureNote(String subscriptionId, String noteId) {
    // 対応関係から削除
    final subscriptionIds = _capturedNotes[noteId];
    if (subscriptionIds != null) {
      subscriptionIds.remove(subscriptionId);
      if (subscriptionIds.isEmpty) {
        _capturedNotes.remove(noteId);
        // 最後の購読が解除された場合のみサーバーに送信
        _sendJson(<String, dynamic>{
          'type': 'unsubNote',
          'body': <String, dynamic>{'id': noteId},
        });
      }
    }

    streamingLog.d('[UNCAPTURE NOTE] noteId=$noteId subId=$subscriptionId');
  }

  /// 指定購読の全キャプチャを解除（購読解除時に内部的に呼ばれる）
  void _clearCapturesForSubscription(String subscriptionId) {
    final noteIdsToRemove = <String>[];

    for (final entry in _capturedNotes.entries) {
      entry.value.remove(subscriptionId);
      if (entry.value.isEmpty) {
        noteIdsToRemove.add(entry.key);
      }
    }

    for (final noteId in noteIdsToRemove) {
      _capturedNotes.remove(noteId);
      // サーバーにunsubNoteを送信
      _sendJson(<String, dynamic>{
        'type': 'unsubNote',
        'body': <String, dynamic>{'id': noteId},
      });
    }
  }
}

extension MisskeyStreamingClientChannel on MisskeyStreamingClient {
  /// 任意のチャンネル名を購読し、ルーティング済みストリームを返す
  Future<MisskeySubscriptionHandle> subscribeChannelStream({
    required String channel,
    String? id,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) {
    return subscribeAsStream(channel: channel, id: id, params: params);
  }

  /// 任意のチャンネル名宛てにイベントを送信（必要なチャンネルでのみ有効）
  void sendToChannel(String subscriptionId, String eventType,
      [Map<String, dynamic>? payload]) {
    sendRaw(<String, dynamic>{
      'type': 'channel',
      'body': <String, dynamic>{
        'id': subscriptionId,
        'type': eventType,
        if (payload != null) 'body': payload,
      },
    });
  }
}

// 注意: ノートキャプチャ機能は MisskeyStreamingClient 本体の
// captureNote / uncaptureNote メソッドに移動しました。
// 拡張メソッドは後方互換性のため残していますが、本体のメソッドを推奨します。
