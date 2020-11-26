library escape_handler;

import 'dart:convert';
import 'dart:async';

import '../model/display_attributes.dart';
import '../model/model.dart';

class EscapeHandler {
  // Taken from: http://www.termsys.demon.co.uk/vtansi.htm
  // And for VT102: http://www.ibiblio.org/pub/historic-linux/ftp-archives/tsx-11.mit.edu/Oct-07-1996/info/vt102.codes
  static Map<String, String> constantEscapes = {
    // Device Status
    jsonEncode([27, 91, 99]): 'Query Device Code',
    jsonEncode([27, 91, 48, 99]): 'Query Device Code',
    jsonEncode([27, 90]): 'Query Device Code',
    jsonEncode([27, 91, 53, 110]): 'Query Device Status',
    jsonEncode([27, 91, 54, 110]): 'Query Cursor Position',
    // Terminal Setup
    jsonEncode([27, 99]): 'Reset Device',
    jsonEncode([27, 55, 104]): 'Enable Line Wrap',
    jsonEncode([27, 55, 108]): 'Disable Line Wrap',
    // Fonts
    jsonEncode([27, 40]): 'Font Set G0',
    jsonEncode([27, 41]): 'Font Set G1',
    // Cursor Control
    jsonEncode([27, 91, 115]): 'Save Cursor',
    jsonEncode([27, 91, 117]): 'Unsave Cursor',
    jsonEncode([27, 55]): 'Save Cursor & Attrs',
    jsonEncode([27, 56]): 'Restore Cursor & Attrs',
    // Scrolling
    jsonEncode([27, 91, 114]): 'Scroll Screen',
    jsonEncode([27, 68]): 'Scroll Down',
    jsonEncode([27, 77]): 'Scroll Up',
    // Tab Control
    jsonEncode([27, 72]): 'Set Tab',
    jsonEncode([27, 91, 103]): 'Clear Tab',
    jsonEncode([27, 91, 51, 103]): 'Clear All Tabs',
    // Keypad Character Selection
    jsonEncode([27, 61]): 'Keypad Application',
    jsonEncode([27, 62]): 'Keypad Numeric',
    // Erasing Text
    jsonEncode([27, 91, 75]): 'Erase End of Line',
    jsonEncode([27, 91, 49, 75]): 'Erase Start of Line',
    jsonEncode([27, 91, 50, 75]): 'Erase Line',
    jsonEncode([27, 91, 74]): 'Erase Down',
    jsonEncode([27, 91, 49, 74]): 'Erase Up',
    jsonEncode([27, 91, 50, 74]): 'Erase Screen',
    // Printing
    jsonEncode([27, 91, 105]): 'Print Screen',
    jsonEncode([27, 91, 49, 105]): 'Print Line',
    jsonEncode([27, 91, 52, 105]): 'Stop Print Log',
    jsonEncode([27, 91, 53, 105]): 'Start Print Log'
  };

  static Map<int, String> variableEscapeTerminators = {
    // Device Status
    99: 'Report Device Code',
    82: 'Report Cursor Position',
    // Cursor Control
    72: 'Cursor Home',
    65: 'Cursor Up',
    66: 'Cursor Down',
    67: 'Cursor Forward',
    68: 'Cursor Backward',
    102: 'Force Cursor Position',
    // Scrolling
    114: 'Scroll Screen',
    // Define Key
    112: 'Set Key Definition',
    // Set Display Attribute
    109: 'Set Attribute Mode',
    // Reset and Set Modes
    104: 'Set Mode',
    108: 'Reset Mode'
  };

  static String printEsc(List<int> escape) {
    return '<ESC>' + base64Encode(escape.sublist(1));
  }

  static bool handleEscape(List<int> escape, StreamController<List<int>> stdin,
      Model model, DisplayAttributes currAttributes) {
    if (escape.length != 1 && escape.last == 27) {
      print(
          'Unknown escape detected: ${printEsc(escape.sublist(0, escape.length - 1))}');
      return true;
    }

    var encodedEscape = jsonEncode(escape);
    if (constantEscapes.containsKey(encodedEscape)) {
      _handleConstantEscape(
          encodedEscape, stdin, model, currAttributes, escape);
      return true;
    } else if (variableEscapeTerminators.containsKey(escape.last)) {
      _handleVariableEscape(encodedEscape, escape, currAttributes, model);
      return true;
    }

    return false;
  }

  static void _handleConstantEscape(
      String encodedEscape,
      StreamController<List<int>> stdin,
      Model model,
      DisplayAttributes currAttributes,
      List<int> escape) {
    //print('Constant escape: ${constantEscapes[encodedEscape]} ${printEsc(escape)}');
    switch (constantEscapes[encodedEscape]) {
      case 'Query Cursor Position':
        _queryCursorPosition(stdin, model);
        break;
      case 'Set Tab':
        model.setTab();
        break;
      case 'Clear All Tabs':
        model.clearAllTabs();
        break;
      case 'Erase End of Line':
        model.eraseEndOfLine();
        break;
      case 'Erase Down':
        model.eraseDown();
        break;
      case 'Erase Screen':
        model.eraseScreen();
        break;
      case 'Scroll Down':
        _scrollDown(model);
        break;
      case 'Scroll Up':
        _scrollUp(model);
        break;
      case 'Keypad Application':
        model.setKeypadMode(KeypadMode.APPLICATION);
        break;
      case 'Keypad Numeric':
        model.setKeypadMode(KeypadMode.NUMERIC);
        break;
      default:
        print(
            'Constant escape : ${constantEscapes[encodedEscape]} (${escape.toString()}) not yet supported');
    }
  }

  static void _handleVariableEscape(String encodedEscape, List<int> escape,
      DisplayAttributes currAttributes, Model model) {
    //print('Variable escape: ${EscapeHandler.variableEscapeTerminators[escape.last]} ${printEsc(escape)}');
    switch (EscapeHandler.variableEscapeTerminators[escape.last]) {
      case 'Set Attribute Mode':
        _setAttributeMode(escape, currAttributes);
        break;
      case 'Cursor Home':
        _cursorHome(escape, model);
        break;
      case 'Cursor Up':
        _cursorUp(escape, model);
        break;
      case 'Cursor Down':
        _cursorDown(escape, model);
        break;
      case 'Cursor Forward':
        _cursorRight(escape, model);
        break;
      case 'Cursor Backward':
        _cursorLeft(escape, model);
        break;
      case 'Set Mode':
        _setMode(escape, model);
        break;
      case 'Reset Mode':
        _resetMode(escape, model);
        break;
      case 'Scroll Screen':
        _scrollScreen(escape, model);
        break;
      default:
        print(
            'Variable escape : ${variableEscapeTerminators[escape.last]} (${escape.toString()}) not yet supported');
    }
  }

  static void _queryCursorPosition(
      StreamController<List<int>> stdin, Model model) {
    // Sends back a Report Cursor Position - <ESC>[{ROW};{COLUMN}R
    stdin.add([27, 91, model.cursor.row, 59, model.cursor.col, 82]);
  }

  static void _setMode(List<int> escape, Model model) {
    //print('Set Mode: ${printEsc(escape)}');
    switch (printEsc(escape)) {
      case '<ESC>[?1h':
        model.cursorkeys = CursorkeysMode.APPLICATION;
        break;
      default:
        print('Set Mode: ${printEsc(escape)} not yet supported');
    }
  }

  static void _resetMode(List<int> escape, Model model) {
    //print('Reset Mode: ${printEsc(escape)}');
    switch (printEsc(escape)) {
      case '<ESC>[?1l':
        model.cursorkeys = CursorkeysMode.NORMAL;
        break;
      default:
        print('Reset Mode: ${printEsc(escape)} not yet supported');
    }
  }

  static void _scrollScreen(List<int> escape, Model model) {
    var indexOfSemi = escape.indexOf(59);
    var start = int.parse(base64Encode(escape.sublist(2, indexOfSemi))) - 1;
    var end = int.parse(
            base64Encode(escape.sublist(indexOfSemi + 1, escape.length - 1))) -
        1;
    //print('Scrolling: $start to $end');
    model.scrollScreen(start, end);
  }

  static void _scrollDown(Model model) => print('Scroll Down not handled!');
  static void _scrollUp(Model model) => print('Scroll Up not handled!');

  /// Sets the cursor position where subsequent text will begin.
  /// If no row/column parameters are provided (ie. <ESC>[H),
  /// the cursor will move to the home position, at the upper left of the screen.
  static void _cursorHome(List<int> escape, Model model) {
    int row, col;

    if (escape.length == 3) {
      row = 0;
      col = 0;
    } else {
      var indexOfSemi = escape.indexOf(59);
      row = int.parse(base64Encode(escape.sublist(2, indexOfSemi))) - 1;
      col = int.parse(base64Encode(
              escape.sublist(indexOfSemi + 1, escape.length - 1))) -
          1;
    }

    model.cursorHome(row, col);
  }

  static void _cursorUp(List<int> escape, Model model) {
    if (escape.length == 3) {
      model.cursorUp();
    } else {
      escape = escape.sublist(2, escape.length - 1);
      model.cursorUp(int.parse(base64Encode(escape)));
    }
  }

  static void _cursorDown(List<int> escape, Model model) {
    if (escape.length == 3) {
      model.cursorDown();
    } else {
      escape = escape.sublist(2, escape.length - 1);
      model.cursorDown(int.parse(base64Encode(escape)));
    }
  }

  static void _cursorRight(List<int> escape, Model model) {
    if (escape.length == 3) {
      model.cursorForward();
    } else {
      escape = escape.sublist(2, escape.length - 1);
      model.cursorForward(int.parse(base64Encode(escape)));
    }
  }

  static void _cursorLeft(List<int> escape, Model model) {
    if (escape.length == 3) {
      model.cursorBackward();
    } else {
      escape = escape.sublist(2, escape.length - 1);
      model.cursorBackward(int.parse(base64Encode(escape)));
    }
  }

  /// Sets multiple display attribute settings.
  /// Sets local [DisplayAttributes], given [escape].
  static void _setAttributeMode(List<int> escape, DisplayAttributes attr) {
    var decodedEsc = base64Encode(escape);

    if (decodedEsc.contains('0m')) {
      attr.resetAll();
    }

    // TODO: implement these when necessary.
    if (decodedEsc.contains(';1')) attr.bright = true;
    if (decodedEsc.contains(';2')) attr.dim = true;
    if (decodedEsc.contains(';4')) attr.underscore = true;
    if (decodedEsc.contains(';5')) attr.blink = true;
    if (decodedEsc.contains(';7')) attr.reverse = true;
    if (decodedEsc.contains(';8')) attr.hidden = true;

    if (decodedEsc.contains(';30')) attr.fgColor = 'black';
    if (decodedEsc.contains(';31')) attr.fgColor = 'red';
    if (decodedEsc.contains(';32')) attr.fgColor = 'green';
    if (decodedEsc.contains(';33')) attr.fgColor = 'yellow';
    if (decodedEsc.contains(';34')) attr.fgColor = 'blue';
    if (decodedEsc.contains(';35')) attr.fgColor = 'magenta';
    if (decodedEsc.contains(';36')) attr.fgColor = 'cyan';
    if (decodedEsc.contains(';37')) attr.fgColor = 'white';

    if (decodedEsc.contains(';40')) attr.bgColor = 'black';
    if (decodedEsc.contains(';41')) attr.bgColor = 'red';
    if (decodedEsc.contains(';42')) attr.bgColor = 'green';
    if (decodedEsc.contains(';43')) attr.bgColor = 'yellow';
    if (decodedEsc.contains(';44')) attr.bgColor = 'blue';
    if (decodedEsc.contains(';45')) attr.bgColor = 'magenta';
    if (decodedEsc.contains(';46')) attr.bgColor = 'cyan';
    if (decodedEsc.contains(';47')) attr.bgColor = 'white';
  }
}
