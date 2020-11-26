library output;

import 'dart:async';

import '../model/model.dart';
import '../model/glyph.dart';
import '../controller.dart';

import './escape_handler.dart';
import '../model/display_attributes.dart';

class OutputHandler {
  static const int ESC = 27;

  StreamController<List<int>> stdout;

  List<int> _incompleteEscape;

  OutputHandler() {
    stdout = StreamController<List<int>>.broadcast();
    _incompleteEscape = [];
  }

  /// Processes [output] by coordinating handling of strings
  /// and escape parsing.
  void processStdOut(List<int> output, Controller controller,
      StreamController stdin, Model model, DisplayAttributes currAttributes) {
    //print('incoming output: ' + output.toString());

    // Insert the incompleteEscape from last processing if exists.
    var outputToProcess = List<int>.from(_incompleteEscape);
    _incompleteEscape = [];
    outputToProcess.addAll(output);

    int nextEsc;
    while (outputToProcess.isNotEmpty) {
      nextEsc = outputToProcess.indexOf(ESC);
      if (nextEsc == -1) {
        _handleOutString(outputToProcess, model, controller, currAttributes);
        return;
      } else {
        _handleOutString(outputToProcess.sublist(0, nextEsc), model, controller,
            currAttributes);
        outputToProcess = _parseEscape(outputToProcess.sublist(nextEsc),
            controller, stdin, model, currAttributes);
      }
    }
  }

  /// Parses out escape sequences. When it finds one,
  /// it handles it and returns the remainder of [output].
  List<int> _parseEscape(List<int> output, Controller controller,
      StreamController<dynamic> stdin, Model model, DisplayAttributes currAttributes) {
    List<int> escape;
    int termIndex;

    for (var i = 1; i <= output.length; i++) {
      termIndex = i;
      escape = output.sublist(0, i);

      var escapeHandled =
          EscapeHandler.handleEscape(escape, stdin as StreamController<List<int>>, model, currAttributes);
      if (escapeHandled) {
        controller.refreshDisplay();
        return output.sublist(termIndex);
      }
    }

    _incompleteEscape = List.from(output);
    return [];
  }

  /// Appends a new [SpanElement] with the contents of [_outString]
  /// to the [_buffer] and updates the display.
  void _handleOutString(List<int> codes, Model model, Controller controller,
      DisplayAttributes currAttributes) {
    for (var code in codes) {
      var char = String.fromCharCode(code);

      if (code == 8) {
        model.backspace();
        continue;
      }

      switch (code) {
        case 32:
          char = Glyph.SPACE;
          break;
        case 60:
          char = Glyph.LT;
          break;
        case 62:
          char = Glyph.GT;
          break;
        case 38:
          char = Glyph.AMP;
          break;
        case 10:
          if (controller.resizing) {
            controller.resizing = false;
            continue;
          }
          model.cursorNewLine();
          continue;
        case 13:
          model.cursorCarriageReturn();
          continue;
        case 7:
          continue;
        case 8:
          continue;
      }

      // To differentiate between an early CR (like from a prompt) and linewrap.
      if (model.cursor.col >= model.numCols - 1) {
        model.cursorCarriageReturn();
        model.cursorNewLine();
      } else {
        var g = Glyph(char, currAttributes);
        model.setGlyphAt(g, model.cursor.row, model.cursor.col);
        model.cursorForward();
      }
    }

    controller.refreshDisplay();
  }
}
