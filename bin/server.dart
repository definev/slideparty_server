import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_router/shelf_router.dart';
import 'package:slideparty_server/slideparty_socket_handler.dart';

var portEnv = Platform.environment['PORT'];
var _hostname = portEnv == null ? 'localhost' : '0.0.0.0';

void main(List<String> args) async {
  final router = Router() //
    ..get('/', (_) => Response.ok('Welcome to slideparty!'))
    ..get(
      '/ws/<size>/<roomCode>',
      (request, size, roomCode) =>
          slidepartySocketHandler(size, roomCode)(request),
    );

  sio
      .serve(router, _hostname, int.parse(portEnv ?? '9999')) //
      .then((server) =>
          print('Server is serving at ${server.address.host}:${server.port}'));
}
