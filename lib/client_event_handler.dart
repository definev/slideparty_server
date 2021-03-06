import 'dart:async';
import 'dart:convert';

import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:slideparty_server/room_stream_controller.dart';

class ClientEventHandler {
  ClientEventHandler({
    required this.controller,
    required this.websocket,
    required this.info,
  });

  final RoomStreamController controller;
  final WebSocketChannel websocket;
  final RoomInfo info;
  late final String playerId;

  StreamSubscription<RoomData> listenRoomData() {
    return controller.listen(
      (state) {
        state.mapOrNull(
          connected: (value) => websocket.sink
              .add(jsonEncode({'type': ServerStateType.connected})),
          roomData: (data) {
            var newData = data.copyWith();
            if (newData.players.isEmpty) {
              controller.fireState(websocket, newData);
              return;
            }

            final winner = newData.players.values
                .where((element) => element.currentBoard.remainTile == 0);
            if (winner.isNotEmpty) {
              final winnerPlayer = winner.first;

              websocket.sink.add(
                jsonEncode({
                  'type': ServerStateType.endGame,
                  'payload': EndGame(
                    winnerPlayer,
                    [
                      ...newData.players.entries.map(
                        (e) => PlayerStatsAnalysis.data(
                          playerColor: e.value.color,
                          remainTile: e.value.currentBoard.remainTile,
                          totalTile: e.value.currentBoard.length,
                        ),
                      ),
                    ],
                  ).toJson(),
                }),
              );
              return;
            }
            controller.fireState(websocket, newData);
          },
        );
      },
    );
  }

  void onJoinRoom(dynamic json) {
    controller.data.mapOrNull(
      roomData: (data) {
        final payload = JoinRoom.fromJson(json);
        playerId = payload.userId;
        if (data.players.length == 4) {
          print('Error: Room ${info.roomCode} is full');
          websocket.sink.add(jsonEncode({'type': ServerStateType.roomFull}));
          return;
        }
        print('Player $playerId joined room ${info.roomCode}');
        websocket.sink.add(jsonEncode({'type': ServerStateType.connected}));
      },
    );
  }

  void onSendBoard(dynamic json) {
    final payload = SendBoard.fromJson(json);

    controller.data.mapOrNull(
      connected: (value) {
        controller.data = RoomData(
          code: getId(info),
          players: {
            playerId: PlayerData(
              id: playerId,
              affectedActions: {},
              color: PlayerColors.values[0],
              currentBoard: payload.board,
              usedActions: [],
            ),
          },
        );
      },
      roomData: (data) {
        if (data.players[playerId] == null) {
          var playerColors = [...PlayerColors.values];
          final existedPlayerColors =
              data.players.entries.map((e) => e.value.color);
          playerColors.removeWhere(
            (element) => existedPlayerColors.contains(element),
          );
          controller.data = data.copyWith(
            players: {
              ...data.players,
              playerId: PlayerData(
                id: playerId,
                affectedActions: {},
                color: playerColors[0],
                currentBoard: payload.board,
                usedActions: [],
              ),
            },
          );
        } else {
          controller.data = data.copyWith(
            players: {
              ...data.players,
              playerId:
                  data.players[playerId]!.copyWith(currentBoard: payload.board),
            },
          );
        }
      },
    );
  }

  void onSendAction(dynamic json) {
    final payload = SendAction.fromJson(json);

    switch (payload.action) {
      case SlidepartyActions.clear:
        var players = {...controller.data.players};
        if (controller.data.players[playerId] == null) {
          onLeaveRoom();
          return;
        }
        players[playerId] = controller.data.players[playerId]!.copyWith(
          affectedActions: {},
          usedActions: [
            ...controller.data.players[playerId]!.usedActions,
            payload.action,
          ],
        );
        controller.data = controller.data.copyWith(players: players);
        break;
      default:
        print(
          'Action ${payload.action}'
          '\n | From player $playerId'
          '\n | To player ${payload.affectedPlayerId}',
        );
        var players = {...controller.data.players};
        players[payload.affectedPlayerId] = controller
            .data //
            .players[payload.affectedPlayerId]!
            .copyWith(
          affectedActions: {
            ...controller
                .data //
                .players[payload.affectedPlayerId]!
                .affectedActions,
            playerId: [
              ...controller
                      .data //
                      .players[payload.affectedPlayerId]!
                      .affectedActions[playerId] ??
                  [],
              payload.action,
            ],
          },
        );
        players[playerId] = controller.data.players[playerId]!.copyWith(
          usedActions: [
            ...controller.data.players[playerId]!.usedActions,
            payload.action,
          ],
        );
        controller.data = controller.data.copyWith(players: players);
        Future.delayed(
          const Duration(seconds: 10),
          () {
            print(
              'Remove action ${payload.action}'
              '\n | From player $playerId'
              '\n | To player ${payload.affectedPlayerId}',
            );
            if (controller.data.players[payload.affectedPlayerId] == null) {
              return;
            }
            var players = {...controller.data.players};
            if (players[payload.affectedPlayerId] != null) {
              if (players[payload.affectedPlayerId]!
                      .affectedActions[playerId] ==
                  null) {
                return;
              }
              players[payload.affectedPlayerId] =
                  controller.data.players[payload.affectedPlayerId]!.copyWith(
                affectedActions: {
                  ...players[payload.affectedPlayerId]!.affectedActions,
                  playerId: [
                    ...players[payload.affectedPlayerId]!
                        .affectedActions[playerId]!
                      ..remove(payload.action),
                  ],
                }..removeWhere((key, value) => value.isEmpty),
              );
              controller.data = controller.data.copyWith(players: players);
            }
            return;
          },
        );
        break;
    }
  }

  void onRestart() {
    print('Restart room ${getId(info)}');
    controller
        .addWebSocketEvent(jsonEncode({'type': ServerStateType.restarting}));
  }

  void onLeaveRoom() {
    controller.data.mapOrNull(
      roomData: (data) {
        print('Remove player $playerId from room ${info.roomCode}');
        controller.data = data.copyWith(
          players: {...data.players}..remove(playerId),
        );
      },
      connected: (_) {
        print(
          'Disconnected while try reconnect: player $playerId from room ${info.roomCode}',
        );
      },
    );
  }

  void onDeleteRoom() {
    roomStreamControllers.remove(getId(info));
    print('Remove room ${info.roomCode}');
  }
}

extension _RemainTileExt on List<int> {
  int get remainTile {
    int remain = 0;
    for (int i = 0; i < length; i++) {
      if (this[i] != i) {
        remain++;
      }
    }
    return remain;
  }
}

String getId(RoomInfo info) => '${info.roomCode}-${info.boardSize}';
