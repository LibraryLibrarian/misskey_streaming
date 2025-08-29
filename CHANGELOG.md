# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1-beta] - 2025-08-30

### Added
- Generic channel subscription API via `subscribeChannelStream({required channel, String? id, Map<String, dynamic> params})`
  - Returns `MisskeySubscriptionHandle` (`id` / `stream` / `unsubscribe()`)
- Unsubscribe helpers
  - `unsubscribeById(String id)` (alias of `unsubscribe(id)`)
  - `unsubscribeChannel(String channel)` to bulk-unsubscribe by channel name
- Message routing by subscription `id` (`messagesFor(id)`), plus global `messages`
- Automatic reconnect with exponential backoff + jitter, configurable limits
- Periodic ping (`pingInterval`), token resolution on reconnect via `tokenProvider`
- Status stream (`status`) and convenience factory `MisskeyStreaming.create()`