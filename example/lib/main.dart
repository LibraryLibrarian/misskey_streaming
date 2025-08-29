import 'dart:async';

import 'package:flutter/material.dart';
import 'package:misskey_api_core/misskey_api_core.dart' as core;
import 'package:misskey_auth/misskey_auth.dart';
import 'package:misskey_streaming/misskey_streaming.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    return MaterialApp(
      title: 'Misskey Streaming Demo',
      theme: ThemeData(
        colorScheme: scheme,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: scheme.surface,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthState {
  final bool authenticated;
  final Uri? baseUrl;
  final String? accessToken;
  const AuthState({
    required this.authenticated,
    this.baseUrl,
    this.accessToken,
  });
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TextEditingController _instance = TextEditingController(
    text: 'https://misskey.io',
  );
  AuthState _state = const AuthState(authenticated: false);
  bool _busy = false;
  String? _error;
  late final MisskeyAuthManager _authManager;

  @override
  void initState() {
    super.initState();
    _authManager = MisskeyAuthManager.defaultInstance();
    // 起動時に保存済みアカウントを確認
    unawaited(_tryAutoLogin());
  }

  Future<void> _tryAutoLogin() async {
    try {
      final key = await _authManager.getActive();
      if (key == null) return;
      final tok = await _authManager.tokenOf(key);
      if (tok == null) return;
      setState(() {
        _state = AuthState(
          authenticated: true,
          baseUrl: Uri.parse('https://${key.host}'),
          accessToken: tok.accessToken,
        );
        _instance.text = 'https://${key.host}';
      });
    } catch (_) {
      // 失敗時は無視して手動認証へ
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final instance = Uri.parse(_instance.text);
      final cfg = MisskeyOAuthConfig(
        host: instance.host,
        clientId: 'https://librarylibrarian.github.io/misskey_streaming/',
        redirectUri:
            'https://librarylibrarian.github.io/misskey_streaming/redirect.html',
        scope: 'read:account read:notes write:notes read:following',
        callbackScheme: 'misskeystreaming',
      );
      final key = await _authManager.loginWithOAuth(cfg);
      final token = await _authManager.tokenOf(key);
      setState(() {
        _state = AuthState(
          authenticated: true,
          baseUrl: Uri.parse('https://${key.host}'),
          accessToken: token?.accessToken,
        );
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    try {
      final key = await _authManager.getActive();
      if (key != null) {
        await _authManager.signOut(key);
        await _authManager.clearActive();
      }
    } finally {
      if (mounted) {
        setState(() {
          _state = const AuthState(authenticated: false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _instance,
                decoration: const InputDecoration(labelText: 'Instance URL'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy ? null : _authenticate,
                child: Text(_busy ? 'Authenticating...' : 'Authenticate'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return HomeScreen(state: _state, onLogout: _logout);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, required this.onLogout});
  final AuthState state;
  final Future<void> Function() onLogout;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final core.MisskeyHttpClient _http;
  late final MisskeyStreamingClient _streaming;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _http = core.MisskeyHttpClient(
      config: core.MisskeyApiConfig(
        baseUrl: widget.state.baseUrl!,
        enableLog: false,
      ),
      tokenProvider: () async => widget.state.accessToken,
    );
    _streaming = MisskeyStreamingClient.fromClient(_http, debugLog: false);
    // 接続は一度だけ実施。購読は各ページで行う
    unawaited(_streaming.connect());
  }

  @override
  void dispose() {
    _streaming.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TimelineChannelPage(
        title: 'Global',
        streaming: _streaming,
        subscribe: (c) => c.subscribe(channel: 'globalTimeline'),
      ),
      TimelineChannelPage(
        title: 'Home',
        streaming: _streaming,
        subscribe: (c) => c.subscribe(channel: 'homeTimeline'),
      ),
      TimelineChannelPage(
        title: 'Social',
        streaming: _streaming,
        subscribe: (c) => c.subscribe(channel: 'hybridTimeline'),
      ),
      TimelineChannelPage(
        title: 'Local',
        streaming: _streaming,
        subscribe: (c) => c.subscribe(channel: 'localTimeline'),
      ),
      SettingPage(onLogout: widget.onLogout),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Timelines')),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Global'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.merge_type),
            label: 'Hybrid',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: 'Local',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}

class TimelineChannelPage extends StatefulWidget {
  const TimelineChannelPage({
    super.key,
    required this.title,
    required this.streaming,
    required this.subscribe,
  });
  final String title;
  final MisskeyStreamingClient streaming;
  final Future<String> Function(MisskeyStreamingClient client) subscribe;

  @override
  State<TimelineChannelPage> createState() => _TimelineChannelPageState();
}

class _TimelineChannelPageState extends State<TimelineChannelPage>
    with AutomaticKeepAliveClientMixin<TimelineChannelPage> {
  String? _subId;
  StreamSubscription? _sub;
  final List<_NoteViewData> _items = <_NoteViewData>[];
  final List<_NoteViewData> _pending = <_NoteViewData>[];
  final ScrollController _controller = ScrollController();
  bool _isAtTop = true;

  @override
  void initState() {
    super.initState();
    _ensureSubscribed();
    _controller.addListener(() {
      final bool atTop = !_controller.hasClients || _controller.offset <= 8.0;
      if (atTop != _isAtTop) {
        setState(() => _isAtTop = atTop);
      }
      if (_isAtTop && _pending.isNotEmpty) {
        setState(() {
          _items.insertAll(0, _pending);
          _pending.clear();
        });
      }
    });
  }

  Future<void> _ensureSubscribed() async {
    final id = await widget.subscribe(widget.streaming);
    if (!mounted) return;
    setState(() => _subId = id);
    _sub?.cancel();
    _sub = widget.streaming.messagesFor(id).listen((msg) {
      if (!mounted) return;
      if (msg.type == 'note' && msg.body is Map<String, dynamic>) {
        final note = (msg.body as Map<String, dynamic>);
        final user = (note['user'] as Map?)?.cast<String, dynamic>();
        final createdAtStr = note['createdAt']?.toString();
        DateTime? createdAt;
        if (createdAtStr != null) {
          try {
            createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
          } catch (_) {}
        }

        final List<_MediaItem> media = <_MediaItem>[];
        final files = note['files'];
        if (files is List) {
          for (final f in files) {
            if (f is Map) {
              final m = f.cast<String, dynamic>();
              final String? url = (m['thumbnailUrl'] ?? m['url'])?.toString();
              if (url != null && url.isNotEmpty) {
                media.add(
                  _MediaItem(url: url, isSensitive: (m['isSensitive'] == true)),
                );
              }
            }
          }
        }

        final String username = user?['username']?.toString() ?? 'unknown';
        final String? host = user?['host']?.toString();
        final String acct = host == null || host.isEmpty
            ? '@$username'
            : '@$username@$host';

        final data = _NoteViewData(
          id: (note['id'] ?? '').toString(),
          displayName: (user?['name']?.toString().isNotEmpty == true)
              ? user!['name']!.toString()
              : username,
          acct: acct,
          avatarUrl: user?['avatarUrl']?.toString(),
          cw: (note['cw'] as String?)?.toString(),
          text: (note['text'] ?? '').toString(),
          createdAt: createdAt,
          media: media,
        );
        if (!mounted) return;
        if (_isAtTop) {
          setState(() {
            _items.insert(0, data);
            if (_items.length > 200) _items.removeRange(200, _items.length);
          });
        } else {
          setState(() {
            _pending.insert(0, data);
            if (_pending.length > 200) {
              _pending.removeRange(200, _pending.length);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_subId != null) {
      widget.streaming.unsubscribe(_subId!);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        ListView.separated(
          controller: _controller,
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final e = _items[index];
            return _NoteCard(key: ValueKey(e.id), data: e);
          },
        ),
        if (_pending.isNotEmpty && !_isAtTop)
          Positioned(
            right: 12,
            top: 12,
            child: ExcludeSemantics(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!_controller.hasClients) return;
                  await _controller.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                  // at top listener will flush pending
                },
                icon: const Icon(Icons.arrow_upward),
                label: Text('新着 ${_pending.length}'),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SettingPage extends StatelessWidget {
  const SettingPage({super.key, required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    const double size = 40;
    final Widget fallback = const CircleAvatar(
      child: Icon(Icons.person_outline),
    );
    final String? src = url;
    if (src == null || src.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return fallback;
        },
      ),
    );
  }
}

class _MediaItem {
  final String url;
  final bool isSensitive;
  const _MediaItem({required this.url, this.isSensitive = false});
}

class _NoteViewData {
  final String id;
  final String displayName;
  final String acct;
  final String? avatarUrl;
  final String? cw;
  final String text;
  final DateTime? createdAt;
  final List<_MediaItem> media;
  const _NoteViewData({
    required this.id,
    required this.displayName,
    required this.acct,
    required this.avatarUrl,
    required this.cw,
    required this.text,
    required this.createdAt,
    required this.media,
  });
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({super.key, required this.data});
  final _NoteViewData data;
  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _cwExpanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final theme = Theme.of(context);
    final time = _formatRelative(d.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(url: d.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.displayName,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (time != null)
                            Text(time, style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Text(d.acct, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (d.cw != null && d.cw!.isNotEmpty)
              _CwBlock(
                text: d.text,
                cw: d.cw!,
                expanded: _cwExpanded,
                onToggle: () => setState(() => _cwExpanded = !_cwExpanded),
              )
            else
              Text(d.text),
            if (d.media.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MediaPreview(media: d.media),
            ],
          ],
        ),
      ),
    );
  }

  String? _formatRelative(DateTime? time) {
    if (time == null) return null;
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _CwBlock extends StatelessWidget {
  const _CwBlock({
    required this.text,
    required this.cw,
    required this.expanded,
    required this.onToggle,
  });
  final String text;
  final String cw;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('[CW] $cw')),
            TextButton(
              onPressed: onToggle,
              child: Text(expanded ? '非表示' : '表示'),
            ),
          ],
        ),
        if (expanded) Text(text),
      ],
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media});
  final List<_MediaItem> media;
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.4,
      ),
      itemCount: media.length.clamp(0, 4),
      itemBuilder: (context, index) {
        final m = media[index];
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(m.url, fit: BoxFit.cover),
              ),
            ),
            if (m.isSensitive)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NSFW',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
