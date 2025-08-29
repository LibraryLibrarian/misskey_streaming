# Misskey Streaming

<p align="center">
  <img src="https://raw.githubusercontent.com/librarylibrarian/misskey_streaming/main/assets/demo_thumb.gif" alt="Demo" width="200" />
</p>

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

**Language**: [🇺🇸 English](#english) | [🇯🇵 日本語](#japanese)

---

## English

A Flutter/Dart library for Misskey Streaming API (WebSocket). Subscribe/unsubscribe by channel name, receive events routed by subscription `id`, with automatic reconnect, exponential backoff, and periodic ping.

### Features

- Subscribe by channel name (string) with optional parameters
- Per-subscription stream routed by `id` (returns a handle with `id/stream/unsubscribe()`)
- Unsubscribe by `id` or by channel name (bulk)
- Automatic reconnect with exponential backoff + jitter and max attempts
- Periodic ping (configurable, can be disabled)
- Connection state stream (`status`) and global message stream (`messages`)

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  misskey_streaming: ^0.0.1-beta
```

### Quick Start

```dart
import 'package:misskey_streaming/misskey_streaming.dart';

Future<void> main() async {
  final client = MisskeyStreaming.create(
    origin: Uri.parse('https://misskey.io'),
    token: 'YOUR_ACCESS_TOKEN',
    debugLog: true,
  );
  await client.connect();

  // Subscribe by channel name (auto-generate UUID if id is omitted)
  final handle = await client.subscribeChannelStream(channel: 'homeTimeline');

  // Receive only events routed to the subscription id
  final sub = handle.stream.listen((msg) {
    if (msg.type == 'note') {
      // Parse msg.body as needed
    }
  });

  // Unsubscribe individually
  handle.unsubscribe();

  // Or unsubscribe all subscriptions for a channel
  client.unsubscribeChannel('homeTimeline');

  await sub.cancel();
  await client.dispose();
}
```

### API Reference

- Connection
  - `Future<void> connect()` / `Future<void> dispose()`
  - `Stream<MisskeyConnectionState> get status`

- Subscribe (high-level)
  - `Future<MisskeySubscriptionHandle> subscribeChannelStream({required String channel, String? id, Map<String, dynamic> params = const {}})`
    - `MisskeySubscriptionHandle.id`
    - `MisskeySubscriptionHandle.stream`
    - `MisskeySubscriptionHandle.unsubscribe()`

- Unsubscribe
  - `void unsubscribeById(String id)`
  - `int unsubscribeChannel(String channel)`

- Low-level API
  - `Future<String> subscribe({required String channel, String? id, Map<String, dynamic> params = const {}})`
  - `void unsubscribe(String id)`
  - `Stream<MisskeyMessage> get messages` / `Stream<MisskeyMessage> messagesFor(String id)`
  - `void sendToChannel(String subscriptionId, String eventType, [Map<String, dynamic>? payload])`

- Configuration (`MisskeyStreamConfig`)
  - `origin`, `token` or `tokenProvider`
  - `enableAutoReconnect` (default: true)
  - `pingInterval` (default: 30s, null to disable)
  - `connectTimeout`, `reconnectInitialDelay`, `reconnectMaxDelay`, `maxReconnectAttempts`

### License

This project is published by 司書 (LibraryLibrarian) under the 3-Clause BSD License. For details, please see the [LICENSE](LICENSE) file.

---

## Japanese

Misskey Streaming API（WebSocket）用のFlutter/Dartライブラリです。チャンネル名（文字列）で購読・解除し、受信イベントは購読ID（`id`）でルーティングされます。自動再接続・指数バックオフ・定期Pingに対応しています。

### 機能

- 任意のチャンネル名で購読（パラメータ指定可）
- `id` 単位のルーティング済みストリーム（`id`・`stream`・`unsubscribe()` を持つハンドルを返却）
- `id` 指定解除／チャンネル名一致の一括解除
- 自動再接続（指数バックオフ＋ジッター、最大試行回数設定）
- 定期Ping（設定可能、無効化可）
- 接続状態ストリーム（`status`）・全件受信ストリーム（`messages`）

### インストール

`pubspec.yaml` に以下を追加してください：

```yaml
dependencies:
  misskey_streaming: ^0.0.1-beta
```

### クイックスタート

```dart
import 'package:misskey_streaming/misskey_streaming.dart';

Future<void> main() async {
  final client = MisskeyStreaming.create(
    origin: Uri.parse('https://misskey.io'),
    token: 'YOUR_ACCESS_TOKEN',
    debugLog: true,
  );
  await client.connect();

  // 任意チャンネル購読（id未指定はUUID自動採番）
  final handle = await client.subscribeChannelStream(channel: 'homeTimeline');

  // 当該購読idにルーティングされたイベントのみ
  final sub = handle.stream.listen((msg) {
    if (msg.type == 'note') {
      // msg.body を用途に応じてパース
    }
  });

  // 個別解除
  handle.unsubscribe();

  // チャンネル名で一括解除
  client.unsubscribeChannel('homeTimeline');

  await sub.cancel();
  await client.dispose();
}
```

### API リファレンス

- 接続
  - `Future<void> connect()` / `Future<void> dispose()`
  - `Stream<MisskeyConnectionState> get status`

- 購読（高レベル）
  - `Future<MisskeySubscriptionHandle> subscribeChannelStream({required String channel, String? id, Map<String, dynamic> params = const {}})`
    - `id`（サーバーの `type: channel` メッセージ `id` と一致）
    - `stream`（当該 `id` 宛てイベント）
    - `unsubscribe()`（個別解除）

- 解除
  - `void unsubscribeById(String id)`（ID指定解除）
  - `int unsubscribeChannel(String channel)`（チャンネル名一致で一括解除）

- 低レベルAPI
  - `Future<String> subscribe({required String channel, String? id, Map<String, dynamic> params = const {}})`
  - `void unsubscribe(String id)`
  - `Stream<MisskeyMessage> messages`（全件）/ `Stream<MisskeyMessage> messagesFor(String id)`（個別）
  - `void sendToChannel(String subscriptionId, String eventType, [Map<String, dynamic>? payload])`

- 設定（`MisskeyStreamConfig`）
  - `origin`、`token` または `tokenProvider`
  - `enableAutoReconnect`（既定: true）
  - `pingInterval`（既定: 30秒、nullで無効）
  - `connectTimeout`、`reconnectInitialDelay`、`reconnectMaxDelay`、`maxReconnectAttempts`

### ライセンス

このプロジェクトは司書(LibraryLibrarian)によって、3-Clause BSD Licenseの下で公開されています。詳細は [LICENSE](LICENSE) をご覧ください。
