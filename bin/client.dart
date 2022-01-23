import 'dart:async';

import 'package:slideparty_socket/slideparty_socket_fe.dart';

// Example of connect to a server
void main() {
  SlidepartySocket ssk = SlidepartySocket('ws://localhost:8080/ws/6/1234');
  Timer.periodic(Duration(milliseconds: 700), (timer) {
    ssk.send(
      ClientEvent.sendBoard(
        List.generate(9, (index) => index)..shuffle(),
      ),
    );
  });
  ssk.state.listen(
    (event) => print(event),
    onDone: () => print('Done connect'),
    onError: (err) => print('Error connect: $err'),
  );
}
