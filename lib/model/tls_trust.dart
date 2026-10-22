import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../log.dart';

/// [HttpOverrides] for Android,
/// making every dart:io [HttpClient] trust the device's root store.
///
/// If no root store can be read,
/// this leaves dart:io's default trust in place.
class AndroidRootStoreHttpOverrides extends HttpOverrides {
  AndroidRootStoreHttpOverrides({
    @visibleForTesting this._rootStoreDirectory,
  });

  final Directory? _rootStoreDirectory;

  late final SecurityContext? _securityContext = _buildSecurityContext();

  SecurityContext? _buildSecurityContext() {
    final directories = _rootStoreDirectory != null
      ? [_rootStoreDirectory] : _androidRootStoreDirectories;
    for (final directory in directories) {
      try {
        final context = securityContextFromRootStore(directory);
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

/// A [SecurityContext] trusting the root certificates in [directory].
///
/// Returns null if none could be loaded.
/// Throws if [directory] can't be listed.
@visibleForTesting
SecurityContext? securityContextFromRootStore(Directory directory) {
  final context = SecurityContext(withTrustedRoots: false);
  var count = 0;
  for (final pem in readTrustedRoots(directory)) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
      count++;
    } on TlsException catch (e) {
      assert(debugLog('Skipping a root certificate: $e'));
    }
  }
  return count == 0 ? null : context;
}

/// The root certificates in [directory], as PEM.
///
/// Each file in an Android root store holds one certificate in PEM,
/// followed by a text description of it.
/// Files with no certificate, or that can't be read, are skipped.
/// Throws if [directory] can't be listed.
@visibleForTesting
List<String> readTrustedRoots(Directory directory) {
  final result = <String>[];
  for (final entry in directory.listSync()) {
    if (entry is! File) continue;
    try {
      final match = _pemCertificatePattern.firstMatch(
        entry.readAsStringSync(encoding: latin1));
      if (match == null) continue;
      result.add(match.group(0)!);
    } on Exception catch (e) {
      assert(debugLog('Skipping ${entry.path}: $e'));
    }
  }
  return result;
}

final _pemCertificatePattern = RegExp(
  r'-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----');
