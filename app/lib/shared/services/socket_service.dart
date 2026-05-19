import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef SocketEventCallback = void Function(dynamic data);

class SocketService {
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  io.Socket? _socket;

  SocketEventCallback? onQueueJoined;
  SocketEventCallback? onMatchFound;
  SocketEventCallback? onGameStart;
  SocketEventCallback? onNewQuestion;
  SocketEventCallback? onRoundResult;
  SocketEventCallback? onAbilityEffect;
  SocketEventCallback? onGameEnd;
  SocketEventCallback? onOpponentDisconnected;
  SocketEventCallback? onError;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String serverUrl) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket!.connect();

    _socket!.on('connect', (_) {
      // ignore: avoid_print
      print('[SocketService] Connected to $serverUrl');
    });

    _socket!.on('disconnect', (_) {
      // ignore: avoid_print
      print('[SocketService] Disconnected');
    });

    _socket!.on('queue_joined', (data) {
      onQueueJoined?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('match_found', (data) {
      onMatchFound?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('game_start', (data) {
      onGameStart?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('new_question', (data) {
      onNewQuestion?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('round_result', (data) {
      onRoundResult?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('ability_effect', (data) {
      onAbilityEffect?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('game_end', (data) {
      onGameEnd?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });

    _socket!.on('opponent_disconnected', (data) {
      onOpponentDisconnected?.call(data);
    });

    _socket!.on('error', (data) {
      onError?.call(data is Map ? Map<String, dynamic>.from(data) : data);
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_socket!.connected) {
      // ignore: avoid_print
      print('[SocketService] Cannot emit "$event": not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  void joinQueue({
    required String topicId,
    required String userId,
    required String token,
  }) {
    emit('join_queue', {
      'topicId': topicId,
      'userId': userId,
      'token': token,
    });
  }

  void leaveQueue() {
    emit('leave_queue', {});
  }

  void submitAnswer({required int answerIndex, required int timeTaken}) {
    emit('submit_answer', {
      'answerIndex': answerIndex,
      'timeTaken': timeTaken,
    });
  }

  void useAbility({required String abilityType}) {
    emit('use_ability', {'abilityType': abilityType});
  }

  void clearCallbacks() {
    onQueueJoined = null;
    onMatchFound = null;
    onGameStart = null;
    onNewQuestion = null;
    onRoundResult = null;
    onAbilityEffect = null;
    onGameEnd = null;
    onOpponentDisconnected = null;
    onError = null;
  }
}
