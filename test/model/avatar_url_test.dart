import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/api/model/model.dart';
import 'package:zulip/model/avatar_url.dart';

import '../example_data.dart' as eg;

void main() {
  const defaultSize = 30;
  const largeSize = 120;

  final realmUrl = Uri.parse('https://zulip.example/');

  AvatarUrl? tryFromUserData(User user) =>
    AvatarUrl.tryFromUserData(user: user, realmUrl: realmUrl);

  group('GravatarUrl', () {
    test('URL from server', () {
      const url = '${GravatarUrl.origin}/avatar/1234';
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(url)));

      check(avatarUrl!.get(defaultSize).toString()).equals('$url?s=30');
    });

    test('URL from server, keeping the params the server sends', () {
      const url = '${GravatarUrl.origin}/avatar/1234?d=identicon&version=1';
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(url)));

      check(avatarUrl!.get(defaultSize).toString()).equals('$url&s=30');
    });

    test('compute from delivery email when server sends null', () {
      // The MD5 of the email address, from an independent implementation.
      const hash = '6d8cad0fd00256e7b40691d27ddfd466';
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(null),
        deliveryEmail: 'hamlet@zulip.com'));

      check(avatarUrl!.get(defaultSize).toString())
        .equals('${GravatarUrl.origin}/avatar/$hash?d=identicon&s=30');
    });

    test('compute from delivery email, lowercasing it first', () {
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(null),
        deliveryEmail: 'Hamlet@Zulip.com'));

      check(avatarUrl!.get(defaultSize).toString()).equals(
        '${GravatarUrl.origin}/avatar/6d8cad0fd00256e7b40691d27ddfd466'
        '?d=identicon&s=30');
    });

    test('fall back when server sends null but no delivery email', () {
      // Shouldn't happen: the server sends null only for users whose
      // email address is visible to everyone.
      final user = eg.user(
        avatarUrl: const JsonNullable(null), deliveryEmail: null);

      check(tryFromUserData(user)!.get(defaultSize).toString())
        .equals('https://zulip.example/avatar/${user.userId}');
    });

    test('no match on an origin that the Gravatar origin is a prefix of', () {
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(
          '${GravatarUrl.origin}.evil.example/image.png')));

      check(avatarUrl).isA<UploadedAvatarUrl>();
    });
  });

  group('FallbackAvatarUrl', () {
    test('standard size', () {
      final user = eg.user(avatarUrl: null);

      check(tryFromUserData(user)!.get(defaultSize).toString())
        .equals('https://zulip.example/avatar/${user.userId}');
    });

    test('larger size', () {
      final user = eg.user(avatarUrl: null);

      check(tryFromUserData(user)!.get(largeSize).toString())
        .equals('https://zulip.example/avatar/${user.userId}/medium');
    });
  });

  group('UploadedAvatarUrl', () {
    test('png image', () {
      const url = 'https://zulip.example/image.png';
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(url)));

      check(avatarUrl!.get(defaultSize).toString()).equals(url);
    });

    test('png image, larger size', () {
      const url = 'https://zulip.example/image.png';
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable(url)));

      check(avatarUrl!.get(largeSize).toString())
        .equals(url.replaceAll('.png', '-medium.png'));
    });

    test('relative URL, resolved against the realm URL', () {
      final avatarUrl = tryFromUserData(eg.user(
        avatarUrl: const JsonNullable('/image.png')));

      check(avatarUrl!.get(defaultSize).toString())
        .equals('https://zulip.example/image.png');
    });
  });

  test('null when the URL from the server fails to parse', () {
    check(tryFromUserData(eg.user(
      avatarUrl: const JsonNullable('::not a URL::')))).isNull();
  });
}
