import 'package:flutter/foundation.dart';

/// Misskey Streaming API の接続状態
enum MisskeyConnectionState {
  idle,
  connecting,
  open,
  reconnecting,
  closed,
  error,
}

/// 受信したメッセージの最小構造
@immutable
class MisskeyMessage {
  const MisskeyMessage({
    required this.type,
    required this.body,
    this.id,
    this.raw,
  });

  final String type;
  final dynamic body;
  final String? id;
  final Map<String, dynamic>? raw;
}

/// チャンネル経由で配信されるメッセージの別名
///
/// MisskeyのStreamingAPIでは`type: channel`メッセージの`body`に
/// `id`/`type`/`body`が含まれます。本ライブラリではこれを`MisskeyMessage`
/// として表現しているため、用途を明確化するための型エイリアスを提供
typedef MisskeyChannelMessage = MisskeyMessage;

/// 購読のライフサイクルを管理するハンドル
///
/// - `id`: サーバーへ接続時に指定した購読ID（チャンネル内ルーティングに使用）
/// - `stream`: 当該購読ID宛てに届くイベントストリーム
/// - `unsubscribe()`: サーバーへ`disconnect`を送信し、ローカルリソースを解放
class MisskeySubscriptionHandle {
  /// 新しい購読ハンドルを作成
  MisskeySubscriptionHandle({
    required this.id,
    required Stream<MisskeyChannelMessage> stream,
    required void Function() onUnsubscribe,
  })  : _stream = stream,
        _onUnsubscribe = onUnsubscribe;

  /// 購読ID。サーバーからの`channel`メッセージの`id`と一致
  final String id;

  final Stream<MisskeyChannelMessage> _stream;
  final void Function() _onUnsubscribe;

  /// 当該購読に紐づくイベントストリーム
  Stream<MisskeyChannelMessage> get stream => _stream;

  /// サーバーに`disconnect`を送信し、購読を停止
  void unsubscribe() => _onUnsubscribe();
}
