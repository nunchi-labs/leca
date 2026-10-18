import 'dart:convert';
import 'dart:typed_data';

/// The small slice of CBOR that WebAuthn attestation objects use.
class Cbor {
  static Object? decode(List<int> bytes) {
    final reader = _Reader(bytes);
    final value = reader.read();
    if (!reader.done) {
      throw const FormatException('cbor trailing bytes');
    }
    return value;
  }

  static Uint8List encode(Object? value) {
    final writer = _Writer();
    writer.write(value);
    return writer.bytes;
  }
}

class _Reader {
  _Reader(this.bytes);

  final List<int> bytes;
  var index = 0;

  bool get done => index >= bytes.length;

  Object? read() {
    if (done) throw const FormatException('cbor truncated');
    final initial = bytes[index++];
    final major = initial >> 5;
    final info = initial & 0x1f;
    final length = _length(info);
    switch (major) {
      case 0:
        return length;
      case 1:
        return -1 - length;
      case 2:
        return Uint8List.fromList(_take(length));
      case 3:
        return utf8.decode(_take(length));
      case 4:
        return [for (var i = 0; i < length; i++) read()];
      case 5:
        return {for (var i = 0; i < length; i++) read(): read()};
      case 7:
        if (info == 20) return false;
        if (info == 21) return true;
        if (info == 22) return null;
        throw FormatException('cbor simple $info');
      default:
        throw FormatException('cbor major $major');
    }
  }

  int _length(int info) {
    if (info < 24) return info;
    if (info == 24) return _take(1)[0];
    if (info == 25) {
      final pair = _take(2);
      return (pair[0] << 8) | pair[1];
    }
    if (info == 26) {
      final quad = _take(4);
      return (quad[0] << 24) | (quad[1] << 16) | (quad[2] << 8) | quad[3];
    }
    throw FormatException('cbor length $info');
  }

  List<int> _take(int n) {
    if (index + n > bytes.length) throw const FormatException('cbor truncated');
    final out = bytes.sublist(index, index + n);
    index += n;
    return out;
  }
}

class _Writer {
  final _builder = BytesBuilder(copy: false);

  Uint8List get bytes => _builder.toBytes();

  void write(Object? value) {
    switch (value) {
      case final int n when n >= 0:
        _head(0, n);
      case final int n:
        _head(1, -1 - n);
      case final List<int> raw:
        _head(2, raw.length);
        _builder.add(raw);
      case final String text:
        final raw = utf8.encode(text);
        _head(3, raw.length);
        _builder.add(raw);
      case final List list:
        _head(4, list.length);
        for (final item in list) {
          write(item);
        }
      case final Map map:
        _head(5, map.length);
        for (final entry in map.entries) {
          write(entry.key);
          write(entry.value);
        }
      default:
        throw ArgumentError('cbor value $value');
    }
  }

  void _head(int major, int length) {
    final prefix = major << 5;
    if (length < 24) {
      _builder.addByte(prefix | length);
    } else if (length < 256) {
      _builder.addByte(prefix | 24);
      _builder.addByte(length);
    } else if (length < 65536) {
      _builder.addByte(prefix | 25);
      _builder.addByte(length >> 8);
      _builder.addByte(length & 0xff);
    } else {
      _builder.addByte(prefix | 26);
      _builder.addByte((length >> 24) & 0xff);
      _builder.addByte((length >> 16) & 0xff);
      _builder.addByte((length >> 8) & 0xff);
      _builder.addByte(length & 0xff);
    }
  }
}
