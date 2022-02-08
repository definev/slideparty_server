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
      controller.data = controller.data.copyWith(
        players: {
          ...controller.data.players,
          playerId: PlayerData(
            id: playerId,
            affectedActions: {},
            color: PlayerColors.values[controller.data.players.length],
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

    controller.fireState(websocket);
  }

  void onSendAction(dynamic json) {
    final payload = SendAction.fromJson(json);

    switch (payload.action) {
      case SlidepartyActions.clear:
        final players = controller.data.players;
        players[playerId] = players[playerId]!.copyWith(
          affectedActions: {},
          usedActions: [...players[playerId]!.usedActions, payload.action],
        );
        controller.data = controller.data.copyWith(players: players);
        break;
      default:
        print(
          'Action ${payload.action}'
          '\n | From player $playerId'
          '\n | To player ${payload.affectedPlayerId}',
        );
        final players = controller.data.players;
        players[payload.affectedPlayerId] =
            players[payload.affectedPlayerId]!.copyWith(
          affectedActions: {
            ...players[payload.affectedPlayerId]!.affectedActions,
            playerId: payload.action,
          },
        );
        players[playerId] = players[playerId]!.copyWith(
          usedActions: [...players[playerId]!.usedActions, payload.action],
        );
        controller.data = controller.data.copyWith(players: players);
        controller.fireState(websocket);
        break;
      // Future.delayed(
      //   const Duration(seconds: 10),
      //   () {
      //     print(
      //       'Remove action ${payload.action}'
      //       '\n | From player $playerId'
      //       '\n | To player ${payload.affectedPlayerId}',
      //     );
      //     final oldData = controller.data;
      //     final players = oldData.players;
      //     players[payload.affectedPlayerId] =
      //         players[payload.affectedPlayerId]!.copyWith(
      //       affectedActions: {
      //         ...players[payload.affectedPlayerId]!
      //             .affectedActions,
      //       }..removeWhere(
      //           (key, value) =>
      //               key == playerId && value == payload.action,
      //         ),
      //     );
      //     controller.data =
      //         controller.data.copyWith(players: players);
      //     controller.fireState(websocket);
      //     return;
      //   },
      // );
    }
    controller.fireState(websocket);
  }

  void onLeaveRoom() {
    controller.data = controller.data.copyWith(
      players: {...controller.data.players}..remove(playerId),
    );
    controller.fireState(websocket);
    print('Remove player $playerId from room ${info.roomCode}');
  }

  void onDeleteRoom() {
    roomStreamControllers.remove(info.roomCode);
    print('Remove room ${info.roomCode}');
  }
}
