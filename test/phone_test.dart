import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leca/phone.dart';
import 'package:leca/state.dart';
import 'package:leca/vault.dart';

void main() {
  test('z-base-32 matches the iroh alphabet', () {
    expect(z32Encode('peter'.codeUnits), 'qb1ze3m1');
    expect(z32Encode('testdata'.codeUnits), 'qt1zg7drcf4gn');
    final id = z32Encode(List<int>.filled(32, 7));
    expect(id.length, 52);
    expect(phoneEndpoint.hasMatch(id), isTrue);
  });

  test('μ-law round-trips a handset sample', () {
    expect(ulawEncode(0), 0xFF);
    expect(ulawDecode(0xFF), 0);
    final back = ulawDecode(ulawEncode(8000));
    expect((back - 8000).abs() < 500, isTrue);
    final pcm = Uint8List(4);
    ByteData.sublistView(pcm).setInt16(0, 1000, Endian.little);
    final ulaw = pcm16ToUlaw(pcm);
    expect(ulaw.length, 2);
    final restored = ulawToPcm16(ulaw);
    expect(restored.length, 4);
  });

  test('a number is an iroh card', () {
    final id = z32Encode(List<int>.filled(32, 3));
    final parsed = PhoneAddress.parse('leca1 $id addr-data');
    expect(parsed?.endpoint, id);
    expect(parsed?.addr, 'addr-data');
    expect(PhoneAddress.parse('012 345 678'), isNull);
    expect(phoneCard(endpoint: id, addr: ''), 'leca1 $id');
  });

  test('two handsets carry voice and a busy line stays busy', () async {
    final adaId = z32Encode(List<int>.filled(32, 1));
    final boId = z32Encode(List<int>.filled(32, 2));
    final caId = z32Encode(List<int>.filled(32, 3));
    final party = PartyLine();
    final adaGear = ScriptGear();
    final boGear = ScriptGear();
    final ada = _handset(party, adaGear, adaId, 'addr-ada1');
    final bo = _handset(party, boGear, boId, 'addr-bo01');
    final ca = _handset(party, ScriptGear(), caId, 'addr-ca001');
    addTearDown(() async {
      ada.hangup();
      bo.hangup();
      ca.hangup();
      await adaGear.close();
      await boGear.close();
      ada.dispose();
      bo.dispose();
      ca.dispose();
    });
    await ada.open();
    await bo.open();
    await ca.open();

    await ada.dial(
      PhoneAddress(endpoint: boId, addr: 'addr-bo01', name: 'Bo'),
      myName: 'Ada',
    );
    expect(bo.phase, CallPhase.ringing);
    expect(bo.peerName, 'Ada');
    expect(bo.peerAddr, isNotEmpty);

    await ca.dial(
      PhoneAddress(endpoint: boId, addr: 'addr-bo01', name: 'Bo'),
      myName: 'Ca',
    );
    expect(ca.fault, PhoneFault.busy);
    expect(ca.phase, CallPhase.idle);
    expect(bo.phase, CallPhase.ringing);

    bo.accept();
    expect(ada.phase, CallPhase.live);
    expect(bo.phase, CallPhase.live);

    final frame = Uint8List(phoneFrame)..[0] = 9;
    adaGear.say(frame);
    await Future<void>.delayed(Duration.zero);
    expect(boGear.heard, [frame]);

    ada.link.audio(endpoint: boId, packet: packAudio(5, frame));
    ada.link.audio(endpoint: boId, packet: packAudio(4, frame));
    expect(boGear.heard.length, 2);

    ada.hangup();
    expect(ada.phase, CallPhase.idle);
    expect(bo.phase, CallPhase.idle);
  });

  test('decline, no route, and a short ring all end the call', () async {
    final adaId = z32Encode(List<int>.filled(32, 4));
    final boId = z32Encode(List<int>.filled(32, 5));
    final party = PartyLine();
    final ada = _handset(
      party,
      ScriptGear(),
      adaId,
      'addr-ada1',
      ringFor: const Duration(milliseconds: 30),
    );
    final bo = _handset(party, ScriptGear(), boId, 'addr-bo01');
    addTearDown(() {
      ada.hangup();
      bo.hangup();
      ada.dispose();
      bo.dispose();
    });
    await ada.open();
    await bo.open();

    await ada.dial(
      PhoneAddress(endpoint: adaId, addr: 'addr-ada1'),
      myName: 'Ada',
    );
    expect(ada.fault, PhoneFault.self);

    await ada.dial(
      PhoneAddress(
        endpoint: z32Encode(List<int>.filled(32, 9)),
        addr: 'addr-miss1',
      ),
      myName: 'Ada',
    );
    expect(ada.fault, PhoneFault.unreachable);
    expect(ada.phase, CallPhase.idle);

    await ada.dial(
      PhoneAddress(endpoint: boId, addr: 'addr-bo01', name: 'Bo'),
      myName: 'Ada',
    );
    bo.decline();
    expect(ada.fault, PhoneFault.declined);
    expect(bo.phase, CallPhase.idle);

    await ada.dial(
      PhoneAddress(endpoint: boId, addr: 'addr-bo01', name: 'Bo'),
      myName: 'Ada',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(ada.fault, PhoneFault.timeout);
    expect(bo.phase, CallPhase.idle);
    expect(bo.fault, PhoneFault.none);
  });

  test('a saved contact is dialed by name and survives a restart', () async {
    final id = z32Encode(List<int>.filled(32, 6));
    final contacts = [
      PhoneContact(endpoint: id, addr: 'addr-bo01', name: 'Bopha'),
    ];
    final named = await resolvePhone(
      raw: 'bop',
      contacts: contacts,
      lookup: (_) async => const [],
    );
    expect(named.single.name, 'Bopha');
    final remote = await resolvePhone(
      raw: 'Kem',
      contacts: const [],
      lookup: (query) async {
        expect(query, 'Kem');
        return [PhoneAddress(endpoint: id, addr: 'addr-kem1', name: 'Kem')];
      },
    );
    expect(remote.single.addr, 'addr-kem1');

    final vault = MemoryVault();
    final state = LecaState(vault: vault)
      ..rememberPhone(contacts.single)
      ..logPhone(
        CallRecord(
          endpoint: id,
          addr: 'addr-bo01',
          name: 'Bopha',
          way: CallWay.outgoing,
          seconds: 3,
          at: DateTime.utc(2026, 10, 19),
        ),
      );
    await state.save();
    final next = LecaState(vault: vault);
    await next.restore();
    expect(next.phoneContacts.single.name, 'Bopha');
    expect(next.phoneLog.single.seconds, 3);
    expect(next.phoneLog.single.way, CallWay.outgoing);
  });

  test('a signal line is the phone wire format', () {
    final line = phoneLine(
      op: 'invite',
      call: '00ab12cd',
      name: 'Ada',
      addr: 'addr-ada1',
    );
    final signal = phoneSignal('peer', line);
    expect(signal?.op, 'invite');
    expect(signal?.name, 'Ada');
    expect(signal?.addr, 'addr-ada1');
    expect(phoneSignal('peer', '{"op":"invite","call":"nope"}'), isNull);
    final matches = phoneMatches([
      {
        'name': 'Bo',
        'endpoint': z32Encode(List<int>.filled(32, 8)),
        'addr': 'addr-bo01',
      },
      {'name': 'No', 'endpoint': 'short', 'addr': 'addr-long1'},
    ]);
    expect(matches.single.name, 'Bo');
  });
}

Handset _handset(
  PartyLine party,
  PhoneGear gear,
  String endpoint,
  String addr, {
  Duration ringFor = const Duration(seconds: 45),
}) {
  return Handset(
    link: MemoryPhoneLink(party, endpoint: endpoint, addr: addr),
    gear: gear,
    ringFor: ringFor,
  );
}
