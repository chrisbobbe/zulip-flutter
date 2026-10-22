import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../log.dart';

/// SHA-256 fingerprints of root certificates we don't trust,
/// even when the device's root store includes them.
///
/// These are the roots in https://emudhra.we-have-a-problem.com/roots.json :
/// the roots that eight eMudhra intermediate CAs chain to,
/// whose private keys were found in October 2026 to be recoverable
/// by anyone.  See https://emudhra.we-have-a-problem.com/ .
///
/// Android blocks those intermediates by their public keys,
/// but dart:io doesn't consult that blocklist,
/// and it has no way to distrust an intermediate.
/// So we distrust their roots instead.
// TODO(#NNNN): remove once TLS on Android no longer goes through dart:io
@visibleForTesting
const distrustedRootFingerprints = {
  // emSign Root TLS CA - G3
  '7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d',
  // emSign Root CS CA - G3
  'f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5',
  // AAA Certificate Services
  'd7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4',
  // emSign ECC Root CA - G3
  '86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b',
};

/// [HttpOverrides] for Android,
/// making every dart:io [HttpClient] trust the device's root store
/// minus some roots we distrust.
///
/// If no root store can be read,
/// this leaves dart:io's default trust in place.
class AndroidRootStoreHttpOverrides extends HttpOverrides {
  AndroidRootStoreHttpOverrides({
    @visibleForTesting this._rootStoreDirectory,
    @visibleForTesting this._distrustedFingerprints = distrustedRootFingerprints,
  });

  final Directory? _rootStoreDirectory;
  final Set<String> _distrustedFingerprints;

  late final SecurityContext? _securityContext = _buildSecurityContext();

  SecurityContext? _buildSecurityContext() {
    final directories = _rootStoreDirectory != null
      ? [_rootStoreDirectory] : _androidRootStoreDirectories;
    for (final directory in directories) {
      try {
        final context = securityContextFromRootStore(directory,
          distrustedFingerprints: _distrustedFingerprints);
        if (context != null) return context;
      } catch (e) {
        assert(debugLog('Failed to load root certificates from ${directory.path}: $e'));
      }
    }
    return null;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? _securityContext);
  }
}

/// The directories where Android keeps its root certificates,
/// in order of preference.
///
/// Since Android 14, the root store lives in the updatable Conscrypt module,
/// and the copy in /system is only a fallback.
/// This is the same choice dart:io makes, as of dart-lang/sdk@3ee784c40.
final _androidRootStoreDirectories = [
  Directory('/apex/com.android.conscrypt/cacerts'),
  Directory('/system/etc/security/cacerts'),
];

/// A [SecurityContext] trusting the root certificates in [directory],
/// except those whose SHA-256 fingerprints are in [distrustedFingerprints].
///
/// Returns null if none could be loaded.
/// Throws if [directory] can't be listed.
@visibleForTesting
SecurityContext? securityContextFromRootStore(Directory directory, {
  required Set<String> distrustedFingerprints,
}) {
  final context = SecurityContext(withTrustedRoots: false);
  var count = 0;
  for (final pem in readTrustedRoots(directory,
         distrustedFingerprints: distrustedFingerprints)) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
      count++;
    } on TlsException catch (e) {
      assert(debugLog('Skipping a root certificate: $e'));
    }
  }
  return count == 0 ? null : context;
}

/// The root certificates in [directory], as PEM,
/// except those whose SHA-256 fingerprints are in [distrustedFingerprints].
///
/// Each file in an Android root store holds one certificate in PEM,
/// followed by a text description of it.
/// Files with no certificate, or that can't be read, are skipped.
/// Throws if [directory] can't be listed.
@visibleForTesting
List<String> readTrustedRoots(Directory directory, {
  required Set<String> distrustedFingerprints,
}) {
  final result = <String>[];
  for (final entry in directory.listSync()) {
    if (entry is! File) continue;
    try {
      final match = _pemCertificatePattern.firstMatch(
        entry.readAsStringSync(encoding: latin1));
      if (match == null) continue;
      final der = base64.decode(match.group(1)!.replaceAll(_whitespacePattern, ''));
      if (distrustedFingerprints.contains(sha256.convert(der).toString())) continue;
      result.add(match.group(0)!);
    } on Exception catch (e) {
      assert(debugLog('Skipping ${entry.path}: $e'));
    }
  }
  return result;
}

final _pemCertificatePattern = RegExp(
  r'-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----');
final _whitespacePattern = RegExp(r'\s');
