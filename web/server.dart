import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_router/shelf_router.dart';
import 'package:slideparty_server/slideparty_socket_handler.dart';

void main(List<String> args) async {
  final router = Router() //
    ..get('/', (_) => Response.ok('Welcome to slideparty!'))
    ..get(
        '/ws/<size>/<roomCode>',
        (request, size, roomCode) =>
            slidepartySocketHandler(size, roomCode)(request));

  sio
      .serve(router, 'slidepartyserver.herokuapp.com', int.parse('8080')) //
      .then((server) =>
          print('Server is serving at ${server.address.host}:${server.port}'));
}
