import 'dart:async';
import 'dart:math';

import 'package:slideparty_socket/slideparty_socket_fe.dart';
import 'package:uuid/uuid.dart';

// Example of connect to a server
void main() {
  SlidepartySocket ssk = SlidepartySocket(RoomInfo(3, '1234'));
  ssk.send(ClientEvent.joinRoom(Uuid().v4()));
  Timer.periodic(Duration(seconds: 1), (timer) {
    ssk.send(
      ClientEvent.sendBoard(
        List.generate(3 * 3, (index) => index)..shuffle(),
      ),
    );
  });
  ssk.state.listen(
    (event) => print(event),
    onDone: () => print('Done connect'),
    onError: (err) => print('Error connect: $err'),
  );
}
