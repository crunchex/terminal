library glyph;

import 'dart:convert';
import 'package:quiver/core.dart';
import './display_attributes.dart';

/// The data model class for an individual glyph within [Model].
class Glyph {
  static const SPACE = '&nbsp';
  static const AMP = '&amp';
  static const LT = '&lt';
  static const GT = '&gt';
  static const CURSOR = '▏';

  // Cursor types:
  //  (226 150 129) ▁
  //  (226 150 136) █
  //  (226 150 143) ▏

  bool bright, dim, underscore, blink, reverse, hidden;
  String value, fgColor, bgColor;

  Glyph(this.value, DisplayAttributes attr) {
    bright = attr.bright;
    dim = attr.dim;
    underscore = attr.underscore;
    blink = attr.blink;
    reverse = attr.reverse;
    hidden = attr.hidden;
    fgColor = attr.fgColor;
    bgColor = attr.bgColor;
  }

  @override
  bool operator ==(Object other) {
    var o = other as Glyph;
    return (value == o.value &&
        bright == o.bright &&
        dim == o.dim &&
        underscore == o.underscore &&
        blink == o.blink &&
        reverse == o.reverse &&
        hidden == o.hidden &&
        fgColor == o.fgColor &&
        bgColor == o.bgColor);
  }

  bool hasSameAttributes(Glyph other) {
    return (bright == other.bright &&
        dim == other.dim &&
        underscore == other.underscore &&
        blink == other.blink &&
        reverse == other.reverse &&
        hidden == other.hidden &&
        fgColor == other.fgColor &&
        bgColor == other.bgColor);
  }

  bool hasDefaults() {
    return (bright == false &&
        dim == false &&
        underscore == false &&
        blink == false &&
        reverse == false &&
        hidden == false &&
        fgColor == 'white' &&
        bgColor == 'black');
  }

  @override
  int get hashCode {
    var members = [
      bright,
      dim,
      underscore,
      blink,
      reverse,
      hidden,
      fgColor,
      bgColor
    ];
    return hashObjects(members);
  }

  
  @override
  String toString() {
    var properties = {
      'value': value,
      'bright': bright,
      'dim': dim,
      'underscore': underscore,
      'blink': blink,
      'reverse': reverse,
      'hidden': hidden,
      'fgColor': fgColor,
      'bgColor': bgColor
    };
    return jsonEncode(properties);
  }
}
