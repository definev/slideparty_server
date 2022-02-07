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
        late String userId;

        if (!roomStreamControllers.containsKey(roomCode)) {
          controller = RoomStreamController(roomCode);
          roomStreamControllers[roomCode] = controller;
        } else {
          controller = roomStreamControllers[roomCode]!;
        }

        final playerSub = controller.listen(
          (newData) => controller.fireState(ws, newData),
        );

        ws.stream.map((raw) {
          try {
            return jsonDecode(raw);
          } catch (e) {
            print('Error event in room $roomCode: $e');
            print('Raw: $raw');
            return null;
          }
        }).listen(
          (event) async {
            if (event == null) return;

            switch (event['type']) {
              case ClientEventType.joinRoom:
                final payload = JoinRoom.fromJson(event['payload']);
                userId = payload.userId;
                if (controller.data.players.length == 4) {
                  print('Error: Room $roomCode is full');
                  ws.sink.add(jsonEncode({'type': ServerStateType.roomFull}));
                  return;
                }
                print('User $userId joined room $roomCode');
                ws.sink.add(jsonEncode({'type': ServerStateType.connected}));
                return;
              case ClientEventType.sendBoard:
                final payload = SendBoard.fromJson(event['payload']);
                final oldPlayerData = controller.data.players[userId];
                if (oldPlayerData == null) {
                  controller.data = controller.data.copyWith(
                    players: {
                      ...controller.data.players,
                      userId: PlayerData(
                        affectedActions: {},
                        color:
                            PlayerColors.values[controller.data.players.length],
                        currentBoard: payload.board,
                        usedActions: [],
                      ),
                    },
                  );
                } else {
                  controller.data = controller.data.copyWith(
                    players: {
                      ...controller.data.players,
                      userId:
                          oldPlayerData.copyWith(currentBoard: payload.board),
                    },
                  );
                }
                break;
              case ClientEventType.sendAction:
                final payload = SendAction.fromJson(event['payload']);
                final oldData = controller.data;
                final players = oldData.players;

                switch (payload.action) {
                  case SlidepartyActions.clear:
                    players[payload.affectedPlayerId] =
                        players[payload.affectedPlayerId]!.copyWith(
                      affectedActions: {},
                    );
                    controller.data =
                        controller.data.copyWith(players: players);
                    controller.updateState(controller.data);
                    return;
                  default:
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
                    controller.data = oldData.copyWith(players: players);
                    Future.delayed(
                      const Duration(seconds: 10),
                      () {
                        final oldData = controller.data;
                        final players = oldData.players;
                        players[payload.affectedPlayerId] =
                            players[payload.affectedPlayerId]!.copyWith(
                          affectedActions: {
                            ...players[payload.affectedPlayerId]!
                                .affectedActions,
                          }..removeWhere(
                              (key, value) =>
                                  key == userId && value == payload.action,
                            ),
                        );
                        controller.data =
                            controller.data.copyWith(players: players);
                        controller.updateState(controller.data);
                        return;
                      },
                    );
                }
                break;
              default:
            }

            controller.updateState(controller.data);
          },
          onDone: () {
            playerSub.cancel();
            if (controller.data.players.length == 1) {
              roomStreamControllers.remove(roomCode);
              print('Remove room $roomCode');
            } else {
              controller.data = controller.data
                  .copyWith(players: controller.data.players..remove(userId));
              controller.updateState(controller.data);
              print('Remove player $userId from room $roomCode');
            }
          },
          cancelOnError: true,
        );
      },
    ),
  );
}
