import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../api/model/model.dart';
import 'store.dart';

/// The size threshold above which is "medium" size for an avatar.
///
/// This is in physical pixels, i.e. image pixels:
/// the server serves the default avatar size as a 100x100 px image,
/// so a display size above that in physical pixels
/// calls for the "medium" 500x500 px variant.
///
/// This is DEFAULT_AVATAR_SIZE in zerver/lib/thumbnail.py.
const defaultUploadSizePx = 100;

abstract class AvatarUrl {
  /// The right [AvatarUrl] subclass for the given user,
  /// or null if the server sent an `avatar_url` we failed to parse.
  static AvatarUrl? tryFromUserData({
    required User user,
    required Uri realmUrl,
  }) {
    final rawUrl = user.avatarUrl;
    if (rawUrl == null) {
      // The server omitted the field; see [User.avatarUrl].
      return FallbackAvatarUrl(realmUrl: realmUrl, userId: user.userId);
    }

    final url = rawUrl.value;
    if (url == null) {
      // The avatar is a Gravatar, for us to compute; see [User.avatarUrl].
      // The server does that only for users whose email address is visible
      // to everyone, and it hashes the delivery email; so we should have it.
      final email = user.deliveryEmail;
      if (email == null) { // TODO(log)
        return FallbackAvatarUrl(realmUrl: realmUrl, userId: user.userId);
      }
      return GravatarUrl.computeFromEmail(email);
    }

    final resolvedUrl = tryResolveUrl(realmUrl, url);
    if (resolvedUrl == null) return null;

    // The trailing slash ensures we've examined the whole origin.
    if (resolvedUrl.toString().startsWith('${GravatarUrl.origin}/')) {
      return GravatarUrl(resolvedUrl: resolvedUrl);
    } else {
      return UploadedAvatarUrl(resolvedUrl: resolvedUrl);
    }
  }

  Uri get(int sizePhysicalPx);
}

class GravatarUrl implements AvatarUrl {
  GravatarUrl({required Uri resolvedUrl}) : standardUrl = resolvedUrl;

  /// The Gravatar URL for the given email address.
  ///
  /// This is the URL the server would have sent as the user's `avatar_url`
  /// if we hadn't claimed `client_gravatar`:
  ///   https://zulip.com/api/register-queue#parameter-client_gravatar
  /// It follows `_get_unversioned_gravatar_url` in zerver/lib/avatar.py,
  /// minus the `version` parameter the server adds for cache-busting
  /// (which is meaningless for an image Gravatar serves).
  ///
  /// One divergence: a server with Gravatar disabled for this realm alone,
  /// with GRAVATAR_REALM_OVERRIDE, still says null under `client_gravatar`,
  /// so we compute this where the server would have used a default avatar.
  GravatarUrl.computeFromEmail(String email)
    : standardUrl = Uri.parse('$origin/avatar/${_hash(email)}?d=identicon');

  static const String origin = 'https://secure.gravatar.com';

  /// The Gravatar hash of an email address.
  ///
  /// This is `gravatar_hash` in zerver/lib/avatar_hash.py.
  static String _hash(String email) =>
    md5.convert(utf8.encode(email.toLowerCase())).toString();

  Uri standardUrl;

  @override
  Uri get(int sizePhysicalPx) {
    return standardUrl.replace(queryParameters: {
      ...standardUrl.queryParameters,
      's': sizePhysicalPx.toString(),
    });
  }
}

/// The fallback avatar URL, `/avatar/{user_id}` on the realm,
/// for a user whose `avatar_url` field the server omitted.
///
/// The server may omit the field at its discretion
/// when we pass true for `user_avatar_url_field_optional`
/// in the register request:
///   https://zulip.com/api/register-queue#parameter-client_capabilities
/// The fallback endpoint redirects to the user's actual avatar.
/// Its API documentation is pending, in an unmerged PR
/// (as of 2026-07-10):
///   https://github.com/zulip/zulip/pull/32495
///
/// Requests to this endpoint require auth,
/// but the redirect may point off-realm (to Gravatar, or S3-style storage),
/// where auth headers must not be sent.
/// Happily `dart:io`'s HttpClient handles that correctly:
/// it drops sensitive headers, like Authorization,
/// on cross-origin redirects.
class FallbackAvatarUrl implements AvatarUrl {
  FallbackAvatarUrl({required Uri realmUrl, required int userId})
    : standardUrl = realmUrl.resolve('/avatar/$userId');

  final Uri standardUrl;

  @override
  Uri get(int sizePhysicalPx) {
    if (sizePhysicalPx > defaultUploadSizePx) {
      return standardUrl.replace(path: '${standardUrl.path}/medium');
    }

    return standardUrl;
  }
}

class UploadedAvatarUrl implements AvatarUrl {
  UploadedAvatarUrl({required Uri resolvedUrl}) : standardUrl = resolvedUrl;

  Uri standardUrl;

  @override
  Uri get(int sizePhysicalPx) {
    if (sizePhysicalPx > defaultUploadSizePx) {
      return standardUrl.replace(
        path: standardUrl.path.replaceFirst(RegExp(r'(?:\.png)?$'), "-medium.png"));
    }

    return standardUrl;
  }
}
