export 'escpos_encoder.dart';

import 'dart:convert';
import 'dart:typed_data';

/// Minimal TSPL encoder for label jobs.
class TsplEncoder {
  TsplEncoder({required this.paperWidthMm});

  final int paperWidthMm;

  Uint8List encodeText(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer()
      ..writeln('SIZE $paperWidthMm mm, 30 mm')
      ..writeln('GAP 2 mm, 0 mm')
      ..writeln('DIRECTION 1')
      ..writeln('CLS');
    var y = 20;
    for (final line in lines) {
      buffer.writeln('TEXT 20,$y,"3",0,1,1,"$line"');
      y += 40;
    }
    buffer.writeln('PRINT 1');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}

/// Minimal ZPL encoder for label jobs.
class ZplEncoder {
  ZplEncoder({required this.paperWidthMm});

  final int paperWidthMm;

  Uint8List encodeText(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer()..writeln('^XA');
    var y = 50;
    for (final line in lines) {
      buffer.writeln('^FO30,$y^A0N,30,30^FD$line^FS');
      y += 40;
    }
    buffer.writeln('^XZ');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}
