import 'dart:html';
import 'dart:typed_data';
import 'package:terminal/terminal.dart';
import 'package:terminal/theme.dart';

WebSocket ws;
InputElement address;
ButtonElement connect, invert;
SpanElement status;
Terminal term;

void main() {
  print('Terminal started');
  address = querySelector('#address') as InputElement;
  connect = querySelector('#connect') as ButtonElement;
  invert = querySelector('#invert') as ButtonElement;
  status = querySelector('#status') as SpanElement;

  term = Terminal(querySelector('#console') as DivElement)
    ..scrollSpeed = 3
    ..cursorBlink = true
    ..theme = Theme.SolarizedDark();

  var size = term.currentSize();
  var rows = size[0];
  var cols = size[1];
  print('Terminal spawned with size: $rows x $cols');
  print('└─> cmdr-pty size should be set to $rows x ${cols - 1}');

  address.onKeyPress
      .where((e) => e.keyCode == KeyCode.ENTER)
      .listen((_) => restartWebsocket());

  connect.onClick.listen((_) => restartWebsocket());
  invert.onClick.listen((_) => invertTheme());

  // Terminal input.
  term.stdin.stream.listen((data) {
    ws.sendByteBuffer(Uint8List.fromList(data).buffer);
  });
}

void updateStatusConnect() {
  status.classes.add('connected');
  status.text = 'Connected';
  print('Terminal connected to server with status ${ws.readyState}.');
}

void updateStatusDisconnect(Event e) {
  status.classes.remove('connected');
  status.text = 'Disconnected';
  print('Terminal disconnected with status ${ws.readyState}.');
}

void restartWebsocket() {
  if (address.value == '') return;

  print(address.value);

  if (ws != null && ws.readyState == WebSocket.OPEN) ws.close();
  initWebSocket('ws://${address.value}/pty');
}

void initWebSocket(String url, [int retrySeconds = 2]) {
  ws = WebSocket(url);
  ws.binaryType = 'arraybuffer';

  ws.onOpen.listen((e) => updateStatusConnect());

  // Terminal output.
  ws.onMessage.listen((e) {
    var buf = e.data as ByteBuffer;
    term.stdout.add(buf.asUint8List());
  });

  ws.onClose.listen((e) => updateStatusDisconnect(e));
  ws.onError.listen((e) => updateStatusDisconnect(e));
}

void invertTheme() {
  if (term.theme.name == 'solarized-dark') {
    term.theme = Theme.SolarizedLight();
  } else {
    term.theme = Theme.SolarizedDark();
  }
}
