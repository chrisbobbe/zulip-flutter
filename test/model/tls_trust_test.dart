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

  test('distrustedRootFingerprints are lowercase hex, as sha256 produces', () {
    for (final fingerprint in distrustedRootFingerprints) {
      check(fingerprint).matchesPattern(RegExp(r'^[0-9a-f]{64}$'));
    }
  });

  group('readTrustedRoots', () {
    test('drop the distrusted roots', () {
      addRoot('aaa.0', aaaCertificateServicesPem);
      addRoot('emsign.0', emSignEccRootCaG3Pem);
      addRoot('test.0', testRootCaPem);
      check(readTrustedRoots(rootStore,
          distrustedFingerprints: distrustedRootFingerprints))
        .deepEquals([testRootCaPem]);
    });

    test('skip files with no certificate', () {
      File('${rootStore.path}/junk').writeAsStringSync('not a certificate\n');
      addRoot('test.0', testRootCaPem);
      check(readTrustedRoots(rootStore, distrustedFingerprints: {}))
        .deepEquals([testRootCaPem]);
    });
  });

  group('securityContextFromRootStore', () {
    test('null for an empty root store', () {
      check(securityContextFromRootStore(rootStore, distrustedFingerprints: {}))
        .isNull();
    });

    test('throw for a missing root store', () {
      final missing = Directory('${rootStore.path}/missing');
      check(() => securityContextFromRootStore(missing, distrustedFingerprints: {}))
        .throws<FileSystemException>();
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
      final overrides = AndroidRootStoreHttpOverrides(
        rootStoreDirectory: rootStore, distrustedFingerprints: {});
      check(await get(overrides)).equals(HttpStatus.ok);
    });

    test('default trust when the root store is missing', () async {
      final missing = Directory('${rootStore.path}/missing');
      final overrides = AndroidRootStoreHttpOverrides(rootStoreDirectory: missing);
      // Default trust doesn't include the test CA, so the handshake fails;
      // but creating the client works.
      await check(get(overrides)).throws<HandshakeException>();
    });

    test('no trust for a distrusted root', () async {
      addRoot('other.0', aaaCertificateServicesPem);
      addRoot('test.0', testRootCaPem);
      final overrides = AndroidRootStoreHttpOverrides(
        rootStoreDirectory: rootStore,
        distrustedFingerprints: {testRootCaFingerprint});
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

const testRootCaFingerprint =
  '7594a92e9f7f868def893660e8f0bdd1ddba2ceaaa420e0a203b2834c322d327';

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

// Two of the distrusted roots, from
// https://emudhra.we-have-a-problem.com/roots.json .

const aaaCertificateServicesPem = '''-----BEGIN CERTIFICATE-----
MIIEMjCCAxqgAwIBAgIBATANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJHQjEb
MBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRow
GAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmlj
YXRlIFNlcnZpY2VzMB4XDTA0MDEwMTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowezEL
MAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
BwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENBIExpbWl0ZWQxITAfBgNVBAMM
GEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAL5AnfRu4ep2hxxNRUSOvkbIgwadwSr+GB+O5AL686tdUIoWMQua
BtDFcCLNSS1UY8y2bmhGC1Pqy0wkwLxyTurxFa70VJoSCsN6sjNg4tqJVfMiWPPe
3M/vg4aijJRPn2jymJBGhCfHdr/jzDUsi14HZGWCwEiwqJH5YZ92IFCokcdmtet4
YgNW8IoaE+oxox6gmf049vYnMlhvB/VruPsUK6+3qszWY19zjNoFmag4qMsXeDZR
rOme9Hg6jc8P2ULimAyrL58OAd7vn5lJ8S3frHRNG5i1R8XlKdH5kBjHYpy+g8cm
ez6KJcfA3Z3mNWgQIJ2P2N7Sw4ScDV7oL8kCAwEAAaOBwDCBvTAdBgNVHQ4EFgQU
oBEKIz6W8Qfs4q8p74Klf9AwpLQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQF
MAMBAf8wewYDVR0fBHQwcjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20v
QUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNqA0oDKGMGh0dHA6Ly9jcmwuY29t
b2RvLm5ldC9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDANBgkqhkiG9w0BAQUF
AAOCAQEACFb8AvCb6P+k+tZ7xkSAzk/ExfYAWMymtrwUSWgEdujm7l3sAg9g1o1Q
GE8mTgHj5rCl7r+8dFRBv/38ErjHT1r0iWAFf2C3BUrz9vHCv8S5dIa2LX1rzNLz
Rt0vxuBqw8M0Ayx9lt1awg6nCpnBBYurDC/zXDrPbDdVCYfeU0BsWO/8tqtlbgT2
G9w84FoVxp7Z8VlIMCFlA2zs6SFz7JsDoeA3raAVGI/6ugLOpyypEBMs1OUIJqsi
l2D4kF501KKaU73yqWjgom7C12yxow+ev+to51byrvLjKzg6CYG1a4XXvi3tPxq3
smPi9WIsgtRqAEFQ8TmDn5XpNpaYbg==
-----END CERTIFICATE-----''';

const emSignEccRootCaG3Pem = '''-----BEGIN CERTIFICATE-----
MIICTjCCAdOgAwIBAgIKPPYHqWhwDtqLhDAKBggqhkjOPQQDAzBrMQswCQYDVQQG
EwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNo
bm9sb2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0g
RzMwHhcNMTgwMjE4MTgzMDAwWhcNNDMwMjE4MTgzMDAwWjBrMQswCQYDVQQGEwJJ
TjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNobm9s
b2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0gRzMw
djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0
WXTsuwYc58Byr+iuL+FBVIcUqEqy6HyC5ltqtdyzdc6LBtCGI79G1Y4PPwT01xyS
fvalY8L1X44uT6EYGQIrMgqCZH0Wk9GjQjBAMB0GA1UdDgQWBBR8XQKEE9TMipuB
zhccLikenEhjQjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggq
hkjOPQQDAwNpADBmAjEAvvNhzwIQHWSVB7gYboiFBS+DCBeQyh+KTOgNG3qxrdWB
CUfvO6wIBHxcmbHtRwfSAjEAnbpV/KlK6O3t5nYBQnvI+GDZjVGLVTv7jHvrZQnD
+JbNR6iC8hZVdyR+EhCVBCyj
-----END CERTIFICATE-----''';
