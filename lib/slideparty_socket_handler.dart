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
        late String playerId;

        if (!roomStreamControllers.containsKey(roomCode)) {
          controller = RoomStreamController(roomCode);
          roomStreamControllers[roomCode] = controller;
        } else {
          controller = roomStreamControllers[roomCode]!;
        }

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
                final payload = JoinRoom.fromJson(event['payload']);
                playerId = payload.userId;
                if (controller.data.players.length == 4) {
                  print('Error: Room $roomCode is full');
                  ws.sink.add(jsonEncode({'type': ServerStateType.roomFull}));
                  return;
                }
                print('User $playerId joined room $roomCode');
                ws.sink.add(jsonEncode({'type': ServerStateType.connected}));
                return;
              case ClientEventType.sendBoard:
                final payload = SendBoard.fromJson(event['payload']);
                final oldPlayerData = controller.data.players[playerId];
                if (oldPlayerData == null) {
                  controller.data = controller.data.copyWith(
                    players: {
                      ...controller.data.players,
                      playerId: PlayerData(
                        id: playerId,
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
                      playerId:
                          oldPlayerData.copyWith(currentBoard: payload.board),
                    },
                  );
                }
                controller.fireState(ws);
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
                    controller.fireState(ws);
                    return;
                  default:
                    print(
                      'Action ${payload.action}'
                      '\n | From player $playerId'
                      '\n | To player ${payload.affectedPlayerId}',
                    );
                    players[payload.affectedPlayerId] =
                        players[payload.affectedPlayerId]!.copyWith(
                      affectedActions: {
                        ...players[payload.affectedPlayerId]!.affectedActions,
                        playerId: payload.action,
                      },
                    );
                    players[playerId] = players[playerId]!.copyWith(
                      usedActions: [
                        ...players[playerId]!.usedActions,
                        payload.action,
                      ],
                    );
                    controller.data = oldData.copyWith(players: players);
                    controller.fireState(ws);
                    Future.delayed(
                      const Duration(seconds: 10),
                      () {
                        print(
                          'Remove action ${payload.action}'
                          '\n | From player $playerId'
                          '\n | To player ${payload.affectedPlayerId}',
                        );
                        final oldData = controller.data;
                        final players = oldData.players;
                        players[payload.affectedPlayerId] =
                            players[payload.affectedPlayerId]!.copyWith(
                          affectedActions: {
                            ...players[payload.affectedPlayerId]!
                                .affectedActions,
                          }..removeWhere(
                              (key, value) =>
                                  key == playerId && value == payload.action,
                            ),
                        );
                        controller.data =
                            controller.data.copyWith(players: players);
                        controller.fireState(ws);
                        return;
                      },
                    );
                }
                break;
              default:
            }
          },
          onError: (e) => print('Error event in room $roomCode: $e'),
          onDone: () {
            if (controller.data.players.length == 1) {
              roomStreamControllers.remove(roomCode);
              print('Remove room $roomCode');
            } else {
              controller.data = controller.data.copyWith(
                players: {...controller.data.players}..remove(playerId),
              );
              controller.fireState(ws);
              print('Remove player $playerId from room $roomCode');
            }
          },
          cancelOnError: false,
        );
      },
    ),
  );
}
