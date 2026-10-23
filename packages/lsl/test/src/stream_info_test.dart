// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'package:lsl/lsl.dart';
import 'package:test/test.dart';

void main() {
  test('build hook loads the pinned native library', () {
    expect(libraryVersion, '1.17');
    expect(protocolVersion, matches(r'^\d+\.\d+$'));
    expect(libraryInfo, contains('liblsl:1.17.7'));
    expect(localClock(), greaterThan(0));
  });

  test('stream metadata and copies have separate ownership', () {
    final info = StreamInfo(
      name: 'signal',
      type: 'EEG',
      channelCount: 2,
      nominalSamplingRate: 100,
      channelFormat: ChannelFormat.double64,
      sourceId: 'sensor',
    );
    info.setDescription('manufacturer', 'Test & Co');
    info.setDescription('manufacturer', 'Updated');
    final copy = info.copy();

    info.destroy();
    info.destroy();
    expect(() => info.name, throwsStateError);
    expect(copy.name, 'signal');
    expect(copy.type, 'EEG');
    expect(copy.channelCount, 2);
    expect(copy.nominalSamplingRate, 100);
    expect(copy.channelFormat, ChannelFormat.double64);
    expect(copy.sourceId, 'sensor');
    expect(copy.xml, contains('<manufacturer>Updated</manufacturer>'));
    expect(() => StreamInfo.fromXml(copy.xml), throwsFormatException);
    expect(() => StreamInfo.fromXml('<invalid/>'), throwsFormatException);
    final outlet = Outlet(streamInfo: copy);
    final published = outlet.streamInfo;
    final decoded = StreamInfo.fromXml(published.xml);
    expect(decoded.name, published.name);
    expect(decoded.uid, published.uid);
    expect(decoded.xml, contains('<manufacturer>Updated</manufacturer>'));
    for (final rate in ['nan', 'inf', '-1']) {
      expect(
        () => StreamInfo.fromXml(
          published.xml.replaceFirst(
            RegExp(r'<nominal_srate>[^<]*</nominal_srate>'),
            '<nominal_srate>$rate</nominal_srate>',
          ),
        ),
        throwsFormatException,
      );
    }
    published.destroy();
    outlet.destroy();
    decoded.destroy();
    copy.destroy();
  });

  test('rejects invalid metadata before native calls', () {
    for (final count in [0, -1, 0x80000000]) {
      expect(
        () => StreamInfo(name: 'n', type: 't', channelCount: count),
        throwsRangeError,
      );
    }
    expect(
      () => StreamInfo(name: '', type: 't', channelCount: 1),
      throwsArgumentError,
    );
    expect(
      () => StreamInfo(name: 'a\u0000b', type: 't', channelCount: 1),
      throwsArgumentError,
    );
    expect(
      () => StreamInfo(
        name: 'n',
        type: 't',
        channelCount: 1,
        nominalSamplingRate: double.nan,
      ),
      throwsArgumentError,
    );
    final info = StreamInfo(name: 'n', type: 't', channelCount: 1);
    expect(() => info.setDescription('bad key', 'value'), throwsArgumentError);
    info.destroy();
  });
}
