import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/model/tls_trust.dart';

void main() {
  late Directory rootStore;

  setUp(() {
    rootStore = Directory.systemTemp.createTempSync('tls_trust_test');
    addTearDown(() => rootStore.deleteSync(recursive: true));
  });

  /// Write a file in the format of Android's root store:
  /// a certificate in PEM, followed by a text description of it.
  void addRoot(String fileName, String pem) {
    File('${rootStore.path}/$fileName').writeAsStringSync(
      '$pem\nCertificate:\n    Data:\n        Version: 3 (0x2)\n');
  }

  group('readTrustedRoots', () {
    test('skip files with no certificate', () {
      File('${rootStore.path}/junk').writeAsStringSync('not a certificate\n');
      addRoot('test.0', testRootCaPem);
      check(readTrustedRoots(rootStore)).deepEquals([testRootCaPem]);
    });
  });

  group('securityContextFromRootStore', () {
    test('null for an empty root store', () {
      check(securityContextFromRootStore(rootStore)).isNull();
    });

    test('throw for a missing root store', () {
      final missing = Directory('${rootStore.path}/missing');
      check(() => securityContextFromRootStore(missing)).throws<FileSystemException>();
    });
  });

  group('AndroidRootStoreHttpOverrides', () {
    late HttpServer server;

    setUp(() async {
      final serverContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(testLeafPem))
        ..usePrivateKeyBytes(utf8.encode(testLeafKeyPem));
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4, 0, serverContext);
      server.listen((request) => request.response.close());
      addTearDown(() => server.close(force: true));
    });

    Future<int> get(AndroidRootStoreHttpOverrides overrides) async {
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(), overrides);
      try {
        final request = await client.getUrl(
          Uri(scheme: 'https', host: '127.0.0.1', port: server.port));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      } finally {
        client.close(force: true);
      }
    }

    test('trust roots in the root store', () async {
      addRoot('test.0', testRootCaPem);
      final overrides = AndroidRootStoreHttpOverrides(rootStoreDirectory: rootStore);
      check(await get(overrides)).equals(HttpStatus.ok);
    });

    test('default trust when the root store is missing', () async {
      final missing = Directory('${rootStore.path}/missing');
      final overrides = AndroidRootStoreHttpOverrides(rootStoreDirectory: missing);
      // Default trust doesn't include the test CA, so the handshake fails;
      // but creating the client works.
      await check(get(overrides)).throws<HandshakeException>();
    });
  });
}

// A test-only root CA, and a certificate for 127.0.0.1 that it issued.
// Generated with OpenSSL, valid until 2126.

const testRootCaPem = '''-----BEGIN CERTIFICATE-----
MIIBlTCCATugAwIBAgIUdlVvv2aF6xOQaeIkuSGeEzpDZoUwCgYIKoZIzj0EAwIw
FzEVMBMGA1UEAwwMVGVzdCBSb290IENBMCAXDTI2MTAyMjIyNDkyOFoYDzIxMjYw
OTI4MjI0OTI4WjAXMRUwEwYDVQQDDAxUZXN0IFJvb3QgQ0EwWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAAS4ku3ZcMNtMsd27nSUz+3XxibjzMb4383ep8LBX5+iFnl4
riz8qSk9lKmMuQjthIT4olPToHpMt0jz1/2talJgo2MwYTAdBgNVHQ4EFgQUVW1b
fGM+akUeOYDtkiWvCcQzZw0wHwYDVR0jBBgwFoAUVW1bfGM+akUeOYDtkiWvCcQz
Zw0wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwID
SAAwRQIgE7E+TX/7F6tGN8XmDWgfmcbRLiNzYABQ3hhzRgMk1tQCIQDQHWf3QGzS
tqs9Gj7QBDp4PreZmgdNgn7Uzf7DyzS6ww==
-----END CERTIFICATE-----''';

const testLeafPem = '''-----BEGIN CERTIFICATE-----
MIIBwjCCAWigAwIBAgIUIWSNGgkX4AcEHO3LjX841LFAjGQwCgYIKoZIzj0EAwIw
FzEVMBMGA1UEAwwMVGVzdCBSb290IENBMCAXDTI2MTAyMjIyNDkyOFoYDzIxMjYw
OTI4MjI0OTI4WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggq
hkjOPQMBBwNCAAQSamYVLLctTl4e0Cod3F749nHVTk0trDxT2Kj/h8mU78t9KVtb
HvdKBBg3f6cLgswtqTn8TNaJ+b0/j8HfYbAPo4GSMIGPMBoGA1UdEQQTMBGCCWxv
Y2FsaG9zdIcEfwAAATATBgNVHSUEDDAKBggrBgEFBQcDATAMBgNVHRMBAf8EAjAA
MA4GA1UdDwEB/wQEAwIHgDAdBgNVHQ4EFgQUJ8WcUl1nQvW+Q0pT6PrJnqkYsWgw
HwYDVR0jBBgwFoAUVW1bfGM+akUeOYDtkiWvCcQzZw0wCgYIKoZIzj0EAwIDSAAw
RQIgNQ2ESbVogoq3ZC9onXK3jpQq3WLyr8UX8HoJ/w4xaXICIQDCSAy/NyHhMQxt
t72zjfDvfmI15F44LySC3Zk+dPc2vQ==
-----END CERTIFICATE-----''';

const testLeafKeyPem = '''-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQghY9yR1K5Ns4W+7yO
91d6wjdHNvVZntY1OI4rR8NTxE+hRANCAAQSamYVLLctTl4e0Cod3F749nHVTk0t
rDxT2Kj/h8mU78t9KVtbHvdKBBg3f6cLgswtqTn8TNaJ+b0/j8HfYbAP
-----END PRIVATE KEY-----''';
