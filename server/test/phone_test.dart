import 'package:leca_auth/phone_book.dart';
import 'package:test/test.dart';

void main() {
  test('a listing expires, and a name finds the live device', () {
    final endpoint = 'y' * 52;
    var now = DateTime.utc(2026, 10, 19, 12);
    final book = PhoneDirectory(now: () => now);
    expect(
      book.publish(
        userId: 'ada',
        name: 'Ada',
        endpoint: endpoint,
        addr: 'addr-one1',
      ),
      isTrue,
    );
    expect(book.find('ada').single.endpoint, endpoint);
    expect(book.find(''), isEmpty);
    expect(
      book.publish(
        userId: 'ada',
        name: 'Ada',
        endpoint: 'not-an-endpoint',
        addr: 'addr-one1',
      ),
      isFalse,
    );
    expect(
      book.publish(
        userId: 'ada',
        name: 'Ada',
        endpoint: endpoint,
        addr: 'has space',
      ),
      isFalse,
    );
    now = now.add(const Duration(seconds: 91));
    expect(book.find('Ada'), isEmpty);
    expect(book.at(endpoint), isNull);

    now = DateTime.utc(2026, 10, 19, 13);
    expect(
      book.publish(
        userId: 'ada',
        name: 'Ada Real',
        endpoint: endpoint,
        addr: 'addr-two22',
      ),
      isTrue,
    );
    expect(book.at(endpoint)?.addr, 'addr-two22');
    expect(book.find('real').single.name, 'Ada Real');
  });
}
