import 'dart:async';
import 'dart:math';

import 'package:slideparty_socket/slideparty_socket_fe.dart';

// Example of connect to a server
void main() {
  List<String> ids = ['1234', '4321'];
  SlidepartySocket ssk =
      SlidepartySocket(
      'ws://118.71.116.26:8080/ws/3/${ids[Random().nextInt(1)]}');
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
