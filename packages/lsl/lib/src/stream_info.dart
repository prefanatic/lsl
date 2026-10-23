// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:lsl/src/errors.dart';
import 'package:lsl/src/third_party/liblsl.g.dart' as native;

/// The native LSL channel formats.
enum ChannelFormat {
  float32(1, 4),
  double64(2, 8),
  string(3, 0),
  int32(4, 4),
  int16(5, 2),
  int8(6, 1),
  int64(7, 8);

  const ChannelFormat(this.nativeValue, this.byteWidth);
  final int nativeValue;
  final int byteWidth;
}

/// An owned stream description. Call [destroy] after use.
class StreamInfo implements Finalizable {
  factory StreamInfo({
    required String name,
    required String type,
    required int channelCount,
    double nominalSamplingRate = 0,
    ChannelFormat channelFormat = ChannelFormat.float32,
    String sourceId = '',
  }) {
    checkText(name, 'name');
    checkText(type, 'type');
    checkText(sourceId, 'sourceId');
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if (channelCount <= 0 || channelCount > 0x7fffffff) {
      throw RangeError.range(channelCount, 1, 0x7fffffff, 'channelCount');
    }
    if (!nominalSamplingRate.isFinite || nominalSamplingRate < 0) {
      throw ArgumentError.value(nominalSamplingRate, 'nominalSamplingRate');
    }
    return using(
      (arena) => StreamInfo.fromPointer(
        native.lsl_create_streaminfo(
          name.toNativeUtf8(allocator: arena).cast(),
          type.toNativeUtf8(allocator: arena).cast(),
          channelCount,
          nominalSamplingRate,
          channelFormat.nativeValue,
          sourceId.toNativeUtf8(allocator: arena).cast(),
        ),
      ),
    );
  }

  /// Takes ownership of [pointer]. Do not free the pointer separately.
  StreamInfo.fromPointer(Pointer<native.lsl_streaminfo_struct_> pointer)
    : _pointer = requirePointer(pointer, 'create stream info') {
    _finalizer.attach(this, _pointer.cast(), detach: this);
  }

  /// Imports XML from a published or resolved stream.
  /// LSL requires a nonempty UID in this XML.
  factory StreamInfo.fromXml(String xml) {
    checkText(xml, 'xml');
    final info = using(
      (arena) => StreamInfo.fromPointer(
        native.lsl_streaminfo_from_xml(
          xml.toNativeUtf8(allocator: arena).cast(),
        ),
      ),
    );
    if (info.channelCount <= 0 || info.uid.isEmpty) {
      info.destroy();
      throw const FormatException(
        'The XML must describe a published LSL stream.',
      );
    }
    return info;
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<native.lsl_streaminfo_struct_>)>
        >(native.lsl_destroy_streaminfo)
        .cast(),
  );
  final Pointer<native.lsl_streaminfo_struct_> _pointer;
  bool _destroyed = false;

  Pointer<native.lsl_streaminfo_struct_> get pointer {
    if (_destroyed) throw StateError('StreamInfo has been destroyed.');
    return _pointer;
  }

  String get name => native.lsl_get_name(pointer).cast<Utf8>().toDartString();
  String get type => native.lsl_get_type(pointer).cast<Utf8>().toDartString();
  String get sourceId =>
      native.lsl_get_source_id(pointer).cast<Utf8>().toDartString();
  String get uid => native.lsl_get_uid(pointer).cast<Utf8>().toDartString();
  String get hostname =>
      native.lsl_get_hostname(pointer).cast<Utf8>().toDartString();
  int get channelCount => native.lsl_get_channel_count(pointer);
  double get nominalSamplingRate => native.lsl_get_nominal_srate(pointer);
  ChannelFormat get channelFormat => ChannelFormat.values.firstWhere(
    (format) => format.nativeValue == native.lsl_get_channel_format(pointer),
  );

  String get xml {
    final text = requirePointer(native.lsl_get_xml(pointer), 'read stream XML');
    try {
      return text.cast<Utf8>().toDartString();
    } finally {
      native.lsl_destroy_string(text);
    }
  }

  /// Adds a text field below the stream's `desc` element.
  void setDescription(String key, String value) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Must be an XML element name.');
    }
    checkText(value, 'value');
    using((arena) {
      final desc = native.lsl_get_desc(pointer);
      final name = key.toNativeUtf8(allocator: arena).cast<Char>();
      final text = value.toNativeUtf8(allocator: arena).cast<Char>();
      final child = native.lsl_child(desc, name);
      if (native.lsl_empty(child) != 0) {
        native.lsl_append_child_value(desc, name, text);
      } else {
        native.lsl_set_child_value(desc, name, text);
      }
    });
  }

  StreamInfo copy() =>
      StreamInfo.fromPointer(native.lsl_copy_streaminfo(pointer));

  void destroy() {
    if (_destroyed) return;
    _finalizer.detach(this);
    native.lsl_destroy_streaminfo(_pointer);
    _destroyed = true;
  }
}
