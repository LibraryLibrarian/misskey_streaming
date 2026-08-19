# Migrating to misskey_client / misskey_client への移行

The standalone `misskey_streaming` package is deprecated. Streaming support is
integrated into
[`misskey_client`](https://pub.dev/packages/misskey_client) as of
`1.0.0-beta.7`.

単独版 `misskey_streaming` は非推奨です。Streaming機能は
`misskey_client 1.0.0-beta.7` に統合されています。

Existing releases remain published and are not retracted, so migration can be
performed incrementally.

公開済みバージョンはretractされないため、段階的に移行できます。

## Dependencies and imports / 依存とimport

```yaml
dependencies:
  misskey_client: ^1.0.0-beta.7
```

```dart
// Before
import 'package:misskey_streaming/misskey_streaming.dart';

// After
import 'package:misskey_client/misskey_client.dart';
```

Remove the `misskey_streaming` dependency only after every call site has been
migrated.

すべての呼び出し箇所を移行してから `misskey_streaming` 依存を削除してください。

## Client setup / クライアント生成

The integrated Streaming API shares the base URL, token provider, logger, and
log setting with `MisskeyClient`.

統合版Streaming APIは、base URL、token provider、logger、ログ設定を
`MisskeyClient` と共有します。

```dart
// Before
final streaming = MisskeyStreaming.create(
  origin: Uri.parse('https://misskey.example.com'),
  token: token,
  enableAutoReconnect: true,
  debugLog: true,
);

// After
final client = MisskeyClient(
  config: MisskeyClientConfig(
    baseUrl: Uri.parse('https://misskey.example.com'),
    enableLog: true,
  ),
  tokenProvider: () => token,
  streamingConfig: MisskeyStreamingConfig(
    enableAutoReconnect: true,
  ),
);

await client.streaming.connect();
```

`MisskeyStreaming.fromClient()` is no longer needed. Access
`client.streaming` directly.

## Subscriptions / 購読

Prefer typed channel definitions for official Misskey channels:

```dart
// Before
final handle = await streaming.subscribeChannelStream(
  channel: 'homeTimeline',
  params: {'withRenotes': true, 'withFiles': false},
);
final messageSubscription = handle.stream.listen((message) {
  print(message.body);
});

// After
final home = await client.streaming.subscribe(
  const MisskeyStreamingChannel.homeTimeline(
    withRenotes: true,
    withFiles: false,
  ),
);
final messageSubscription = home.messages.listen((message) {
  print(message.body);
});
```

For fork-specific channels, use `client.streaming.subscribeRaw()`.
`unsubscribe()` is asynchronous in the integrated API:

```dart
await messageSubscription.cancel();
await home.unsubscribe();
```

## API mapping / API対応表

| Standalone `misskey_streaming` | Integrated `misskey_client` API |
|---|---|
| `MisskeyStreaming.create()` | `MisskeyClient(...).streaming` |
| `subscribeChannelStream()` | `client.streaming.subscribe()` |
| String channel names | `MisskeyStreamingChannel` typed factories |
| `handle.stream` | `subscription.messages` |
| Manual Note decoding | `subscription.notes` |
| Manual Notification decoding | `subscription.notifications` |
| Manual captured-note decoding | `subscription.events` |
| `MisskeyMessage` | `MisskeyStreamingMessage` |
| `status` | `state` and `stateChanges` |
| Connection errors | `errors` and typed `MisskeyStreamingException` classes |
| `dispose()` | `disconnect()` for reuse, or terminal `dispose()` |

Unknown or fork-specific event payloads are preserved as
`MisskeyUnknownEvent` instead of being dropped.

## Capturing note updates / ノート更新のcapture

Capture operations belong to the subscription handle, so a subscription ID is
no longer passed separately:

```dart
// Before
streaming.captureNote(handle.id, noteId);
streaming.uncaptureNote(handle.id, noteId);

// After
home.captureNote(noteId);
home.uncaptureNote(noteId);
```

## Configuration mapping / 設定対応表

| `MisskeyStreamConfig` | Replacement |
|---|---|
| `origin` | `MisskeyClientConfig.baseUrl` |
| `token` / `tokenProvider` | `MisskeyClient` constructor `tokenProvider` |
| `debugLog` | `MisskeyClientConfig.enableLog` |
| `enableAutoReconnect` | `MisskeyStreamingConfig.enableAutoReconnect` |
| `connectTimeout` | `MisskeyStreamingConfig.connectTimeout` |
| `reconnectInitialDelay` | `MisskeyStreamingConfig.reconnectInitialDelay` |
| `reconnectMaxDelay` | `MisskeyStreamingConfig.reconnectMaxDelay` |
| `maxReconnectAttempts` | `MisskeyStreamingConfig.maxReconnectAttempts` |
| `pingInterval` | Removed; no application-level JSON ping is required |

## Lifecycle / ライフサイクル

- `disconnect()` stops the current connection and allows later reconnection.
- `dispose()` is terminal and releases controllers, timers, subscriptions, and
  the socket.
- `MisskeyClient.dispose()` also disposes Streaming if it was initialized.

`disconnect()` は再接続可能な切断、`dispose()` はリソースを完全に破棄する終端操作
です。`MisskeyClient.dispose()` は初期化済みのStreamingも破棄します。

## Migration checklist / 移行チェックリスト

1. Replace the dependency and import.
2. Move the server URL, token provider, and logger to `MisskeyClient`.
3. Move reconnection settings to `MisskeyStreamingConfig`.
4. Replace official string channel names with typed channel factories.
5. Replace `handle.stream` with `messages`, `events`, `notes`, or
   `notifications`.
6. Move capture calls onto the subscription handle.
7. Await `unsubscribe()` and dispose the owning `MisskeyClient`.
8. Remove the standalone package dependency.

1. 依存とimportを置き換える。
2. server URL、token provider、loggerを `MisskeyClient` へ移す。
3. 再接続設定を `MisskeyStreamingConfig` へ移す。
4. 公式チャンネルを型付きfactoryへ置き換える。
5. `handle.stream` を用途に応じたstreamへ置き換える。
6. capture操作を購読ハンドルへ移す。
7. `unsubscribe()` をawaitし、所有する `MisskeyClient` をdisposeする。
8. 単独版パッケージ依存を削除する。

The complete migration reference is also maintained in the
[`misskey_client` repository](https://github.com/LibraryLibrarian/misskey_client/blob/main/MIGRATION_FROM_MISSKEY_STREAMING.md).
