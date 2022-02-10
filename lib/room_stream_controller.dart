import 'dart:async';
import 'dart:convert';

import 'package:slideparty_server/client_event_handler.dart';
import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, RoomStreamController> roomStreamControllers = {};
Map<String, Stopwatch?> timerRoom = {};

class RoomStreamController {
  final StreamController<ServerState> _controller =
      StreamController.broadcast();
  RoomStreamController(RoomInfo info)
      : _data = RoomData(code: getId(info), players: {});

  ServerState _data;
  ServerState get data => _data;
  set data(ServerState data) {
    _data = data;
    _controller.add(data);
  }

  List<String> playersId = [];

  StreamSubscription listen(void Function(ServerState data) onListen) =>
      _controller.stream.distinct().listen(onListen);

  void fireState(WebSocketChannel ws, RoomData data) {
    ws.sink.add(
      jsonEncode({
        'type': ServerStateType.roomData,
        'payload': data.toJson(),
      }),
    );
  }
}
