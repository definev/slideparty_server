import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_router/shelf_router.dart';
import 'package:slideparty_server/slideparty_socket_handler.dart';

void main(List<String> args) async {
  // final port = args[0];
  // final mongoUrl = args[1];

  // mongo = await Db.create(mongoUrl);
  // await mongo.open();
  print('MongoDB connected');

  final router = Router() //
    ..get(
        '/ws/<size>/<roomCode>',
        (request, size, roomCode) =>
            slidepartySocketHandler(size, roomCode)(request));

  sio
      .serve(router, 'localhost', int.parse('8080')) //
      .then((server) =>
          print('Server is serving at ${server.address.host}:${server.port}'));
}
