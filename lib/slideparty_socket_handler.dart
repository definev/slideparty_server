import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:slideparty_server/client_event_handler.dart';
import 'package:slideparty_server/room_stream_controller.dart';
import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

shelf.Handler slidepartySocketHandler(String boardSize, String roomCode) {
  return shelf.Pipeline() //
      .addMiddleware(shelf.logRequests())
      .addHandler(
    webSocketHandler(
      (websocket) async {
        final size = int.tryParse(boardSize);
        final ws = websocket as WebSocketChannel;

        if (size == null) {
          ws.sink.add(jsonEncode({
            'type': ServerStateType.wrongBoardSize,
            'payload': null,
          }));
          return;
        }
        if (size < 3 || size > 5) {
          ws.sink.add(jsonEncode({
            'type': ServerStateType.wrongBoardSize,
            'payload': null,
          }));
          return;
        }
        print('New connection for $roomCode');

        RoomStreamController controller;

        if (!roomStreamControllers.containsKey(roomCode)) {
          controller = RoomStreamController(roomCode);
          roomStreamControllers[roomCode] = controller;
        } else {
          controller = roomStreamControllers[roomCode]!;
        }

        final handler = ClientEventHandler(
          info: RoomInfo(size, roomCode),
          controller: controller,
          websocket: websocket,
        );

        ws.stream.map(
          (raw) {
            try {
              return jsonDecode(raw);
            } catch (e) {
              print('Error event in room $roomCode: $e');
              print('Raw: $raw');
              return null;
            }
          },
        ).listen(
          (event) async {
            if (event == null) return;

            switch (event['type']) {
              case ClientEventType.joinRoom:
                handler.onJoinRoom(event['payload']);
                break;
              case ClientEventType.sendBoard:
                handler.onSendBoard(event['payload']);
                break;
              case ClientEventType.sendAction:
                handler.onSendAction(event['payload']);
                break;
            }
          },
          onError: (e) => print('Error event in room $roomCode: $e'),
          onDone: () {
            if (controller.data.players.length == 1) {
              handler.onDeleteRoom();
            } else {
              handler.onLeaveRoom();
            }
          },
          cancelOnError: false,
        );
      },
    ),
  );
}
