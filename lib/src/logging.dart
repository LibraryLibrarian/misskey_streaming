import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// Misskey Streaming ライブラリ共通のロガーを提供する。
///
/// - デバッグビルド: 詳細ログ（debug/trace）を出力
/// - リリースビルド: 警告以上のみ出力（大量ログを抑制）
final Logger streamingLog = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: _CustomLogPrinter(),
);

/// カスタムログプリンター
///
/// 出力形式: [misskey_streaming] [LEVEL] YYYY-MM-DD HH:MM:SS.ffffff メッセージ
class _CustomLogPrinter extends LogPrinter {
  static final Map<Level, String> _levelLabels = {
    Level.trace: 'TRACE',
    Level.debug: 'DEBUG',
    Level.info: 'INFO',
    Level.warning: 'WARNING',
    Level.error: 'ERROR',
    Level.fatal: 'FATAL',
  };

  @override
  List<String> log(LogEvent event) {
    final level = _levelLabels[event.level] ?? 'UNKNOWN';
    final time = DateTime.now().toString();
    final message = event.message;

    return ['[misskey_streaming] [$level] $time $message'];
  }
}
