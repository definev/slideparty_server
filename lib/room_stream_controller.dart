import 'dart:async';
import 'dart:convert';

import 'package:slideparty_server/client_event_handler.dart';
import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, RoomStreamController> roomStreamControllers = {};

class RoomStreamController {
  final StreamController<RoomData> _controller = StreamController.broadcast();
  final StreamController<String> _webSocketEventController =
      StreamController.broadcast();
  RoomStreamController(RoomInfo info)
      : _data = RoomData(code: getId(info), players: {});

  RoomData _data;
  RoomData get data => _data;
  set data(RoomData data) {
    _data = data;
    _controller.add(data);
  }

  void addWebSocketEvent(String message) =>
      _webSocketEventController.add(message);

  StreamSubscription<RoomData> listen(void Function(RoomData data) onListen) =>
      _controller.stream.distinct().listen(onListen);
  StreamSubscription<String> listenWebSocketStream(WebSocketChannel ws) =>
      _webSocketEventController.stream.distinct().listen((message) {
        print('fire websocket: $message');
        ws.sink.add(message);
      });

  void fireState(WebSocketChannel ws, RoomData data) {
    ws.sink.add(
      jsonEncode({
        'type': ServerStateType.roomData,
        'payload': data.toJson(),
      }),
    );
  }
}
