import 'package:meta/meta.dart';

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
