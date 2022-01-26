import 'dart:async';

import 'package:slideparty_socket/slideparty_socket_fe.dart';
import 'package:uuid/uuid.dart';

// Example of connect to a server
void main() {
  SlidepartySocket ssk = SlidepartySocket(RoomInfo(3, '1234'), true);
  ssk.send(ClientEvent.joinRoom(Uuid().v4()));

  ssk.state.listen(
    (event) {
      if (event is Connected) {
        Timer.periodic(Duration(milliseconds: 2000), (timer) {
          ssk.send(
            ClientEvent.sendBoard(
              List.generate(3 * 3, (index) => index)..shuffle(),
            ),
          );
        });
      }
      print('\n$event\n');
    },
    onDone: () => print('Done connect'),
    onError: (err) => print('Error connect: $err'),
  );
}
