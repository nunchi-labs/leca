import 'package:flutter_test/flutter_test.dart';
import 'package:leca/swarm.dart';

void main() {
  test('a line reaches the far side once, and the relay hears it too', () {
    final ada = TalkSwarm(self: 'ada', topic: frontRoom);
    final bo = TalkSwarm(self: 'bo', topic: frontRoom);
    final cy = TalkSwarm(self: 'cy', topic: frontRoom);
    final adaToBo = <String>[];
    final boToAda = <String>[];
    final boToCy = <String>[];
    final boToRelay = <String>[];
    ada.link('bo', adaToBo.add);
    bo
      ..link('ada', boToAda.add)
      ..link('cy', boToCy.add)
      ..link(relayLink, boToRelay.add);

    final said = ada.broadcast(
      kind: 'text',
      text: '  hello   there ',
      name: 'Ada',
      who: 'who-ada',
    );
    expect(said?.text, 'hello there');
    expect(adaToBo, hasLength(1));

    final atBo = bo.receive('ada', adaToBo.single);
    expect(atBo.deliver?.text, 'hello there');
    expect(atBo.deliver?.who, 'who-ada');
    expect(boToCy, hasLength(1));
    expect(boToRelay, hasLength(1));
    expect(boToAda, isEmpty);

    final atCy = cy.receive('bo', boToCy.single);
    expect(atCy.deliver?.id, said?.id);
    expect(cy.receive('bo', boToCy.single).deliver, isNull);
    expect(ada.receive('bo', adaToBo.single).deliver, isNull);
  });

  test('a hello teaches a peer and answers with one they do not have', () {
    final ada = TalkSwarm(self: 'ada', topic: frontRoom);
    final bo = TalkSwarm(self: 'bo', topic: frontRoom);
    ada.introduce(const [SwarmPeer('cy', 'addr-cy')]);
    bo.introduce(const [SwarmPeer('dee', 'addr-dee')]);
    final replies = <String>[];
    bo.link('ada', replies.add);

    final effect = bo.receive('ada', ada.hello());
    expect(effect.deliver, isNull);
    expect(effect.dial.map((peer) => peer.id), ['cy']);
    expect(replies, hasLength(1));
    final reply = SwarmMessage.decode(replies.single);
    expect(reply?.kind, 'peers');
    expect(reply?.peers.single.id, 'dee');

    final back = ada.receive('bo', replies.single);
    expect(back.dial.map((peer) => peer.id), ['dee']);
    expect(ada.broadcast(kind: 'text', text: '   '), isNull);
    expect(ada.receive('bo', '{').deliver, isNull);
    final other = TalkSwarm(self: 'zed', topic: 'kitchen');
    final foreign = other.broadcast(kind: 'text', text: 'nope');
    expect(ada.receive('zed', foreign!.encode()).deliver, isNull);
  });

  test('a chat radius is mutual, and the whole country does not cut', () {
    expect(chatSees(km: 4, radiusKm: 10, theirRadiusKm: 10), isTrue);
    expect(chatSees(km: 4, radiusKm: 1, theirRadiusKm: 10), isFalse);
    expect(chatSees(km: 4, radiusKm: 10, theirRadiusKm: 1), isFalse);
    expect(chatSees(km: 80, radiusKm: 101, theirRadiusKm: 101), isTrue);
    expect(chatSees(km: 80, radiusKm: 101, theirRadiusKm: 10), isFalse);
  });

  test('a price line is a chat frame', () {
    final ada = TalkSwarm(self: 'ada', topic: frontRoom);
    final bo = TalkSwarm(self: 'bo', topic: frontRoom);
    final frames = <String>[];
    ada.link(meshLink, frames.add);
    final said = ada.broadcast(
      kind: 'price',
      text: 'ask 4.50 customer',
      name: 'Ada',
      who: 'who-ada',
    );
    final got = bo.receive(meshLink, frames.single);
    expect(got.deliver?.kind, 'price');
    expect(got.deliver?.id, said?.id);
    expect(got.deliver?.text, 'ask 4.50 customer');
  });
}
