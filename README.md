# Slideparty Server

A dart server for slideparty.

To run it local run command:
```bash
dart run bin/server.dart
```

## Endpoint
- `/`: 
    - Return a welcome text.
- `/<size>/<roomCode>`:
    - A websocket with board size and room code.