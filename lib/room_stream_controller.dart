import 'dart:async';
import 'dart:convert';

import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, RoomStreamController> roomStreamControllers = {};

class RoomStreamController {
  final StreamController<RoomData> _controller = StreamController.broadcast();
  RoomStreamController(String roomCode) {
    _controller.sink.add(RoomData(code: roomCode, players: {}));
  }
  Future<RoomData> get data {
    return _controller.stream.last;
  }

  void updateState(RoomData data) {
    _controller.sink.add(data);
  }

  StreamSubscription listen(void Function(RoomData data) onListen) =>
      _controller.stream.listen(onListen);

  void fireState(WebSocketChannel ws, RoomData data) {
    ws.sink.add(jsonEncode({
      'type': ServerStateType.roomData,
      'payload': data.toJson(),
    }));
  }
}
