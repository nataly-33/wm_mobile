import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_url.dart';

typedef EventoCallback = void Function(Map<String, dynamic> evento);

class SocketService {
  StompClient? _client;
  bool _connected = false;
  final Map<String, StompUnsubscribe> _subscriptions = {};

  void conectar({String? token, VoidCallback? onConnected}) {
    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: (frame) {
          _connected = true;
          debugPrint('[SocketService] Conectado al WebSocket');
          onConnected?.call();
        },
        onDisconnect: (frame) {
          _connected = false;
          _subscriptions.clear();
          debugPrint('[SocketService] Desconectado del WebSocket');
        },
        onWebSocketError: (error) {
          debugPrint('[SocketService] Error WebSocket: $error');
        },
        onStompError: (frame) {
          debugPrint('[SocketService] Error STOMP: ${frame.body}');
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatOutgoing: const Duration(seconds: 4),
        heartbeatIncoming: const Duration(seconds: 4),
        webSocketConnectHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
        stompConnectHeaders: token != null ? {'Authorization': 'Bearer $token'} : {},
      ),
    );
    _client!.activate();
  }

  void suscribirAMonitor(String politicaId, EventoCallback callback) {
    final topic = '/topic/politica/$politicaId';
    if (_subscriptions.containsKey(topic)) return;

    if (!_connected || _client == null) {
      debugPrint('[SocketService] No conectado, no se puede suscribir a $topic');
      return;
    }

    final unsub = _client!.subscribe(
      destination: topic,
      callback: (frame) {
        try {
          final evento = jsonDecode(frame.body ?? '{}') as Map<String, dynamic>;
          debugPrint('[SocketService] Evento monitor [$politicaId]: ${frame.body}');
          callback(evento);
        } catch (e) {
          debugPrint('[SocketService] Error parseando evento: $e');
        }
      },
    );
    _subscriptions[topic] = unsub;
  }

  void desuscribir(String topic) {
    _subscriptions[topic]?.call();
    _subscriptions.remove(topic);
  }

  void desconectar() {
    for (final unsub in _subscriptions.values) {
      unsub();
    }
    _subscriptions.clear();
    _client?.deactivate();
    _connected = false;
  }

  bool get isConnected => _connected;
}
