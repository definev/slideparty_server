import 'dart:async';
import 'dart:convert';

import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, RoomStreamController> roomStreamControllers = {};

class RoomStreamController {
  final StreamController<RoomData> _controller = StreamController.broadcast();
  RoomStreamController(String roomCode)
      : _data = RoomData(code: roomCode, players: {});

  RoomData _data;
  RoomData get data => _data;
  set data(RoomData data) {
    _data = data;
    _controller.add(data);
  }

  void fireState(WebSocketChannel ws) {
    final json = {
      'type': ServerStateType.roomData,
      'payload': data.toJson(),
    };
    final prettyString = JsonEncoder.withIndent('  ').convert(json);

    print('SEND STATE: ');
    print(prettyString);

    ws.sink.add(jsonEncode(json));
  }
}
