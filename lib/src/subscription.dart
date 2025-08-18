class MisskeySubscription {
  MisskeySubscription({
    required this.id,
    required this.channel,
    this.params = const <String, dynamic>{},
  });

  final String id;
  final String channel;
  final Map<String, dynamic> params;

  Map<String, dynamic> toConnectPayload() {
    return <String, dynamic>{
      'type': 'connect',
      'body': <String, dynamic>{
        'channel': channel,
        'id': id,
        if (params.isNotEmpty) 'params': params,
      },
    };
  }

  Map<String, dynamic> toDisconnectPayload() {
    return <String, dynamic>{
      'type': 'disconnect',
      'body': <String, dynamic>{
        'id': id,
      },
    };
  }
}
