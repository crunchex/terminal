library model;

import './display_attributes.dart';
import './glyph.dart';

class Cursor {
  int row = 0;
  int col = 0;

  @override
  String toString() {
    return 'row: $row, col: $col';
  }
}

enum KeypadMode { NUMERIC, APPLICATION }
enum CursorkeysMode { NORMAL, APPLICATION }

/// Represents the data model for [Terminal].
class Model {
  static const int _MAXBUFFER = 500;

  bool get atBottom => _forwardBuffer.isEmpty;

  Cursor cursor;
  int numRows, numCols;
  KeypadMode keypad;
  CursorkeysMode cursorkeys;

  // Implemented as stacks in scrolling.
  List<List<Glyph>> _reverseBuffer;
  List<List<Glyph>> _forwardBuffer;

  // Implemented as a queue in scrolling.
  List<List<Glyph>> _frame;

  // Tab locations.
  List<List> _tabs;

  int _scrollStart, _scrollEnd;

  Model(this.numRows, this.numCols) {
    cursor = Cursor();
    keypad = KeypadMode.NUMERIC;
    cursorkeys = CursorkeysMode.NORMAL;

    _reverseBuffer = [];
    _forwardBuffer = [];
    _frame = [];

    _initModel();
  }

  Model.fromOldModel(this.numRows, this.numCols, Model oldModel) {
    cursor = Cursor();
    keypad = oldModel.keypad;
    cursorkeys = oldModel.cursorkeys;

    oldModel.scrollToBottom();
    // Puts all old content into the reverse buffer and starts clean.
    _reverseBuffer = oldModel._reverseBuffer;
    // Don't add blank lines.
    for (var row in oldModel._frame) {
      var blank = true;
      for (var g in row) {
        if (g.value != Glyph.SPACE && g.value != Glyph.CURSOR) {
          blank = false;
          break;
        }
      }
      if (!blank) _reverseBuffer.add(row);
    }

    // Trim off oldest content to keep buffer below max.
    if (_reverseBuffer.length > _MAXBUFFER) {
      _reverseBuffer =
          _reverseBuffer.sublist(_reverseBuffer.length - _MAXBUFFER);
    }
    _forwardBuffer = [];
    _frame = [];

    _initModel();
  }

  /// Returns the [Glyph] at row, col.
  Glyph getGlyphAt(int row, int col) {
    if (col >= _frame[row].length) {
      _frame[row].add(Glyph(Glyph.SPACE, DisplayAttributes()));
    }
    return _frame[row][col];
  }

  /// Sets a [Glyph] at location row, col.
  void setGlyphAt(Glyph g, int row, int col) {
    // TODO: add guards for setting Glyphs that are out of bounds
    // after a resize.
    if (_forwardBuffer.isEmpty) {
      _frame[row][col] = g;
      return;
    }

    _forwardBuffer.first[col] = g;
  }

  void backspace() {
    //setGlyphAt(new Glyph(Glyph.SPACE, new DisplayAttributes()), cursor.row, cursor.col);
    cursorBackward();
  }

  void cursorHome(int row, int col) {
    // Detect screen scrolling when _scrollEnd switches from last line to second-to-last line.
    if (_scrollEnd == numRows - 2) {
      if (row == _scrollEnd) {
        _scrollDown(1);
      } else if (row == _scrollStart) {
        _scrollUp(1);
      }
    }

    cursor.row = row;
    cursor.col = col;
  }

  void cursorUp([int count]) {
    if (cursor.row <= 0) return;

    if (count == null) {
      cursor.row--;
    } else {
      cursor.row = (cursor.row - count <= 0) ? 0 : cursor.row - count;
    }
  }

  void cursorDown([int count]) {
    if (cursor.row >= numRows) return;

    if (count == null) {
      cursor.row++;
    } else {
      cursor.row =
          (cursor.row + count >= numRows) ? numRows - 1 : cursor.row + count;
    }
  }

  void cursorForward([int count]) {
    if (cursor.col >= numCols) return;

    if (count == null) {
      cursor.col++;
    } else {
      cursor.col =
          (cursor.col + count >= numCols) ? numCols - 1 : cursor.col + count;
    }
  }

  void cursorBackward([int count]) {
    if (cursor.col <= 0) return;

    if (count == null) {
      cursor.col--;
    } else {
      cursor.col = (cursor.col - count <= 0) ? 0 : cursor.col - count;
    }
  }

  void cursorCarriageReturn() {
    //print('cursorCarriageReturn');
    cursor.col = 0;
  }

  void cursorNewLine() {
    //print('cursorNewLine');
    if (_forwardBuffer.isNotEmpty) {
      _forwardBuffer.insert(0, <Glyph>[]);
      for (var c = 0; c < numCols; c++) {
        _forwardBuffer.first.add(Glyph(Glyph.SPACE, DisplayAttributes()));
      }
      return;
    }

    if (cursor.row < numRows - 1) {
      cursor.row++;
    } else {
      _pushBuffer();
    }
  }

  void setTab() {
    _tabs.add(<int>[cursor.row, cursor.col]);
  }

  void clearAllTabs() {
    _tabs.clear();
  }

  /// Erases from the current cursor position to the end of the current line.
  void eraseEndOfLine() {
    //cursorBackward();
    for (var i = cursor.col; i < _frame[cursor.row].length; i++) {
      setGlyphAt(Glyph(Glyph.SPACE, DisplayAttributes()), cursor.row, i);
    }
  }

  void eraseDown() {
    var cursorRow = cursor.row;
    for (var r in _frame.sublist(cursorRow)) {
      for (var c = 0; c < r.length; c++) {
        r[c].value = Glyph.SPACE;
      }
    }
  }

  void eraseScreen() {
    for (var r in _frame) {
      for (var c = 0; c < r.length; c++) {
        r[c].value = Glyph.SPACE;
      }
    }

    cursor.row = 0;
    cursor.col = 0;
  }

  void setKeypadMode(KeypadMode mode) {
    keypad = mode;
  }

  /// Manipulates the frame & scroll bubber to handle scrolling down in normal,
  /// non-application mode.
  void scrollUp(int numLines) {
    for (var i = 0; i < numLines; i++) {
      if (_reverseBuffer.isEmpty) return;

      _frame.insert(0, _reverseBuffer.last);
      _reverseBuffer.removeLast();
      _forwardBuffer.add(_frame[_frame.length - 1]);
      _frame.removeLast();
    }
  }

  /// Manipulates the frame & scroll bubber to handle scrolling down in normal,
  /// non-application mode.
  void scrollDown(int numLines) {
    for (var i = 0; i < numLines; i++) {
      if (_forwardBuffer.isEmpty) return;

      _frame.add(_forwardBuffer.last);
      _forwardBuffer.removeLast();
      _reverseBuffer.add(_frame[0]);
      _frame.removeAt(0);
    }
  }

  void scrollToBottom() {
    while (_forwardBuffer.isNotEmpty) {
      _frame.add(_forwardBuffer.last);
      _forwardBuffer.removeLast();
      _reverseBuffer.add(_frame[0]);
      _frame.removeAt(0);
    }
  }

  void _pushBuffer() {
    _reverseBuffer.add(_frame[0]);
    if (_reverseBuffer.length > _MAXBUFFER) _reverseBuffer.removeAt(0);
    _frame.removeAt(0);

    var newRow = <Glyph>[];
    for (var c = 0; c < numCols; c++) {
      newRow.add(Glyph(Glyph.SPACE, DisplayAttributes()));
    }
    _frame.add(newRow);
  }

  void scrollScreen(int start, int end) {
    _scrollStart = start;
    _scrollEnd = end;
  }

  /// Manipulates the frame to handle scrolling
  /// upward of a single line in application mode.
  void _scrollUp(int numLines) {
    for (var i = 0; i < numLines; i++) {
      _frame.removeAt(numRows - 2);
      _frame.insert(0, <Glyph>[]);
      for (var c = 0; c < numCols; c++) {
        _frame[0].add(Glyph(Glyph.SPACE, DisplayAttributes()));
      }
    }
  }

  /// Manipulates the frame to handle scrolling
  /// downward of a single line in application mode.
  void _scrollDown(int numLines) {
    for (var i = 0; i < numLines; i++) {
      _frame.removeAt(0);
      _frame.insert(numRows - 2, <Glyph>[]);
      for (var c = 0; c < numCols; c++) {
        _frame[numRows - 2].add(Glyph(Glyph.SPACE, DisplayAttributes()));
      }
    }
  }

  /// Initializes the internal model with a List of Lists.
  /// Each location defaults to a Glyph.SPACE.
  void _initModel() {
    for (var r = 0; r < numRows; r++) {
      _frame.add(<Glyph>[]);
      for (var c = 0; c < numCols; c++) {
        _frame[r].add(Glyph(Glyph.SPACE, DisplayAttributes()));
      }
    }
  }
}
