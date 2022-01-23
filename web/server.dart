import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_router/shelf_router.dart';
import 'package:slideparty_server/slideparty_socket_handler.dart';

void main(List<String> args) async {
  final router = Router() //
    ..get(
        '/ws/<size>/<roomCode>',
        (request, size, roomCode) =>
            slidepartySocketHandler(size, roomCode)(request));

  sio
      .serve(router, '0.0.0.0', int.parse('8080')) //
      .then((server) =>
          print('Server is serving at ${server.address.host}:${server.port}'));
}