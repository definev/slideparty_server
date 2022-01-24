import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:slideparty_server/room_stream_controller.dart';
import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

shelf.Handler slidepartySocketHandler(String boardSize, String roomCode) {
  return shelf.Pipeline() //
      .addMiddleware(shelf.logRequests())
      .addHandler(
    webSocketHandler(
      (websocket) {
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
        final userId = Uuid().v4();
        RoomStreamController controller;
        if (!roomStreamControllers.containsKey(roomCode)) {
          controller = RoomStreamController(roomCode);
          roomStreamControllers[roomCode] = controller;
        } else {
          controller = roomStreamControllers[roomCode]!;
        }
        var data = controller.data;
        final playerSub = controller.listen((newData) {
          controller.fireState(ws, newData);
          data = newData;
        });

        ws.stream.map((raw) => jsonDecode(raw)).listen(
          (event) async {
            switch (event['type']) {
              case ClientEventType.sendName:
                final payload = SendName.fromJson(event['payload']);
                final oldData = data.players[userId];
                if (oldData == null) {
                  data = data.copyWith(players: {
                    ...data.players,
                    userId: PlayerData(
                      affectedActions: {},
                      color: PlayerColors.values[data.players.length],
                      name: payload.name,
                      currentBoard: List.generate(size * size, (index) => index)
                        ..shuffle(),
                      usedActions: [],
                    ),
                  });
                } else {
                  data = data.copyWith(players: {
                    ...data.players,
                    userId: oldData.copyWith(name: payload.name),
                  });
                }
                break;
              case ClientEventType.sendBoard:
                final payload = SendBoard.fromJson(event['payload']);
                final oldData = data.players[userId];
                if (oldData == null) {
                  data = data.copyWith(players: {
                    ...data.players,
                    userId: PlayerData(
                      affectedActions: {},
                      color: PlayerColors.values[data.players.length],
                      name: 'Guest ${data.players.length + 1}',
                      currentBoard: payload.board,
                      usedActions: [],
                    ),
                  });
                } else {
                  data = data.copyWith(players: {
                    ...data.players,
                    userId: oldData.copyWith(currentBoard: payload.board),
                  });
                }
                break;
              case ClientEventType.sendAction:
                final payload = SendAction.fromJson(event['payload']);
                final oldData = data;
                Map<String, PlayerState> players = oldData.players;
                players[payload.affectedPlayerId] =
                    players[payload.affectedPlayerId]!.copyWith(
                  affectedActions: {
                    ...players[payload.affectedPlayerId]!.affectedActions,
                    userId: payload.action,
                  },
                );
                players[userId] = players[userId]!.copyWith(
                  usedActions: [
                    ...players[userId]!.usedActions,
                    payload.action,
                  ],
                );
                break;
              default:
            }

            controller.updateState(data);
          },
          onDone: () {
            playerSub.cancel();
            if (data.players.length == 1) {
              roomStreamControllers.remove(roomCode);
              print('Remove room $roomCode');
            } else {
              data = data.copyWith(players: data.players..remove(userId));
              controller.updateState(data);
              print('Remove player $userId from room $roomCode');
            }
          },
          cancelOnError: true,
        );
      },
    ),
  );
}
