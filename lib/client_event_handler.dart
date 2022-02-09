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

  StreamSubscription listenRoomData() {
    return controller.listen(
      (newData) {
        if (newData.players.values
            .where((element) => element.currentBoard.remainTile == 0)
            .isNotEmpty) {
          final winnerPlayer = newData //
              .players
              .values
              .where((element) => element.currentBoard.remainTile == 0)
              .first;

          timerRoom['R:${info.roomCode}S:${info.boardSize}']!.stop();

          websocket.sink.add(
            jsonEncode({
              'type': ServerStateType.endGame,
              'payload': EndGame(
                winnerPlayer.id,
                timerRoom['R:${info.roomCode}S:${info.boardSize}']!.elapsed,
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
  }

  void onJoinRoom(dynamic json) {
    final payload = JoinRoom.fromJson(json);
    playerId = payload.userId;
    if (controller.data.players.length == 4) {
      print('Error: Room ${info.roomCode} is full');
      websocket.sink.add(jsonEncode({'type': ServerStateType.roomFull}));
      return;
    }
    print('Player $playerId joined room ${info.roomCode}');
    websocket.sink.add(jsonEncode({'type': ServerStateType.connected}));
  }

  void onSendBoard(dynamic json) {
    final payload = SendBoard.fromJson(json);
    if (controller.data.players[playerId] == null) {
      var playerColors = [...PlayerColors.values];
      final existedPlayerColors =
          controller.data.players.entries.map((e) => e.value.color);
      playerColors.removeWhere(
        (element) => existedPlayerColors.contains(element),
      );
      controller.data = controller.data.copyWith(
        players: {
          ...controller.data.players,
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
      controller.data = controller.data.copyWith(
        players: {
          ...controller.data.players,
          playerId: controller //
              .data
              .players[playerId]!
              .copyWith(currentBoard: payload.board),
        },
      );
    }
  }

  void onSendAction(dynamic json) {
    final payload = SendAction.fromJson(json);

    switch (payload.action) {
      case SlidepartyActions.clear:
        var players = {...controller.data.players};
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
        players[payload.affectedPlayerId] = controller //
            .data
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
            var players = {...controller.data.players};
            players[payload.affectedPlayerId] =
                controller.data.players[payload.affectedPlayerId]!.copyWith(
              affectedActions: {
                ...controller
                    .data.players[payload.affectedPlayerId]!.affectedActions,
                playerId: [
                  ...controller.data.players[payload.affectedPlayerId]!
                      .affectedActions[playerId]!
                    ..remove(payload.action),
                ],
              }..removeWhere((key, value) => value.isEmpty),
            );
            controller.data = controller.data.copyWith(players: players);
            return;
          },
        );
    }
  }

  void onSolved(dynamic json) {
    final payload = Solved.fromJson(json);
    timerRoom['R:${info.roomCode}S:${info.boardSize}']!.stop();
    timerRoom.remove('R:${info.roomCode}S:${info.boardSize}');
    websocket.sink.add(jsonEncode({
      'type': ServerStateType.endGame,
      'payload': EndGame(
        payload.playerId,
        timerRoom['R:${info.roomCode}S:${info.boardSize}']!.elapsed,
        [
          ...controller.data.players.entries.map(
            (e) => PlayerStatsAnalysis.data(
              playerColor: e.value.color,
              remainTile: e.value.currentBoard.remainTile,
              totalTile: e.value.currentBoard.length,
            ),
          ),
        ],
      ).toJson(),
    }));
  }

  void onLeaveRoom() {
    print('Remove player $playerId from room ${info.roomCode}');
    controller.data = controller.data.copyWith(
      players: {...controller.data.players}..remove(playerId),
    );
  }

  void onDeleteRoom() {
    timerRoom['R:${info.roomCode}S:${info.boardSize}']!.stop();
    timerRoom.remove('R:${info.roomCode}S:${info.boardSize}');
    roomStreamControllers.remove(info.roomCode);
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
