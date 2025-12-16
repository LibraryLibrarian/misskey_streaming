# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2-beta] - 2025-12-10

### Added
- Note capture functionality for real-time updates on specific notes
  - `captureNote(String subscriptionId, String noteId)` - Capture a note to receive real-time events
  - `uncaptureNote(String subscriptionId, String noteId)` - Stop capturing a note
  - Supported events: `reacted`, `unreacted`, `deleted`, `pollVoted`
  - Events are properly routed to the subscription stream that captured the note
  - Automatic cleanup when unsubscribing
- Documentation and examples for note capture in README

### Changed
- Migrated internal logging from custom implementation to `logger` package
- Debug logs now respect build mode (verbose in debug, warnings only in release)
- Improved log formatting with consistent prefixes

### Fixed
- Corrected note capture event detection to handle Misskey's `noteUpdated` wrapper format
- Note capture events (`reacted`, `unreacted`, `deleted`, `pollVoted`) now properly routed to subscriptions

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