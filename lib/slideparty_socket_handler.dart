import 'dart:convert';

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
        RoomStreamController controller;
        late String userId;

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

        ws.stream.map((raw) {
          try {
            return jsonDecode(raw);
          } catch (e) {
            print('Error event in room $roomCode: $e');
            return null;
          }
        }).listen(
          (event) async {
            if (event == null) return;

            print('EVENT: ${event['type']}');

            switch (event['type']) {
              case ClientEventType.joinRoom:
                final payload = JoinRoom.fromJson(event['payload']);
                userId = payload.userId;
                if (data.players.length == 4) {
                  ws.sink.add(jsonEncode({'type': ServerStateType.roomFull}));
                  return;
                }
                print('User $userId joined room $roomCode');
                ws.sink.add(jsonEncode({'type': ServerStateType.connected}));
                return;
              case ClientEventType.sendName:
                final payload = SendName.fromJson(event['payload']);
                final oldData = data.players[userId]!;

                data = data.copyWith(
                  players: {
                    ...data.players,
                    userId: oldData.copyWith(name: payload.name),
                  },
                );
                break;
              case ClientEventType.sendBoard:
                final payload = SendBoard.fromJson(event['payload']);
                final oldPlayerData = data.players[userId];
                if (oldPlayerData == null) {
                  data = data.copyWith(
                    players: {
                      ...data.players,
                      userId: PlayerData(
                        affectedActions: {},
                        color: PlayerColors.values[data.players.length],
                        name: 'Guest ${data.players.length + 1}',
                        currentBoard: payload.board,
                        usedActions: [],
                      ),
                    },
                  );
                } else {
                  data = data.copyWith(players: {
                    ...data.players,
                    userId: oldPlayerData.copyWith(currentBoard: payload.board),
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
