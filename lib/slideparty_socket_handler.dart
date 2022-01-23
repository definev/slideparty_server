import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:slideparty_socket/slideparty_socket_be.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, RoomData> rooms = {};

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
        if (rooms[roomCode] == null) {
          rooms[roomCode] = RoomData(code: roomCode, players: {});
        }
        ws.stream.map((raw) => jsonDecode(raw)).listen(
          (event) async {
            print('Request: $roomCode');
            print('Type: ${event['type']}');
            print('Payload: ${event['payload']}');

            switch (event['type']) {
              case ClientEventType.sendName:
                final payload = SendName.fromJson(event['payload']);
                final oldData = rooms[roomCode]!.players[userId];
                if (oldData == null) {
                  rooms[roomCode] = rooms[roomCode]!.copyWith(players: {
                    ...rooms[roomCode]!.players,
                    userId: PlayerData(
                      affectedActions: {},
                      color:
                          PlayerColors.values[rooms[roomCode]!.players.length],
                      name: payload.name,
                      currentBoard: '[]',
                      usedActions: [],
                    ),
                  });
                }
                break;
              default:
            }
          },
          onDone: () {
            print('\nConnection disconnect\n');
          },
          cancelOnError: true,
        );
      },
    ),
  );
}
